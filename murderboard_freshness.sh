#!/usr/bin/env bash
# murderboard_freshness.sh — is this repo's VENDORED murderboard current with upstream?
#
# THE GAP THIS CLOSES. `doc_review_process.md` step 0 tells a reviewer to confirm the
# process is current before running it. That is prose: it fires only if someone
# remembers, and the one time nobody did, a deck shipped a slide-overlap defect using a
# copy that predated the slide-overlap rule. The rule existed. The copy was old. Nothing
# said so.
#
# The same failure has now happened at a larger scale: a consumer's `main` sat 10 commits
# and 11 days behind while ~17 worktrees branched from it and inherited the stale copy,
# because re-vendoring kept happening on leaf branches and never flowed back.
#
# So this is the mechanized version of step 0: it compares the vendored stamp against
# upstream HEAD and says so, by itself, at every session start. SILENT when current —
# a check that speaks every time gets tuned out, and then it is just prose again.
#
# USAGE
#   murderboard_freshness.sh                 check; silent if current, report if stale
#   murderboard_freshness.sh --verbose       always print the verdict
#   murderboard_freshness.sh --file PATH     check this vendored file (default: autodetect)
#   murderboard_freshness.sh --upstream SHA  skip upstream lookup (testing / offline)
#   murderboard_freshness.sh --refresh       ignore the cache, re-resolve upstream now
#   murderboard_freshness.sh --hook          never touch the network; serve the cache and
#                                            refresh it detached (for SessionStart hooks)
#   murderboard_freshness.sh --selftest      prove every branch can still fire
#
# EXIT CODES   0 = current   1 = STALE   2 = could not determine (never a false "current")
#
# UPSTREAM RESOLUTION, in order. The first that answers wins; each is capped:
#   1. --upstream SHA                       explicit
#   2. $MURDERBOARD_HEAD                    explicit, via environment
#   3. gh api (the authority — asks the remote)
#   4. a local clone's origin/main          offline fallback; may itself be behind, so
#                                           the verdict is labelled with its source
#
# CACHE. Upstream HEAD is cached for $TTL seconds in the git common dir (machine-local,
# shared by every worktree, never committed), because this runs in a SessionStart hook
# that blocks session startup and cannot afford a network call every time.
#
# Project-neutral: no hardcoded consumer paths. Override anything via the env vars below.

set -u
LC_ALL=C; export LC_ALL

REPO_SLUG="${MURDERBOARD_REPO_SLUG:-syncytium2/murderboard}"
TTL="${MURDERBOARD_TTL:-43200}"          # 12h
NET_CAP="${MURDERBOARD_NET_CAP:-6}"      # max seconds for the upstream lookup

# Where a local clone might live (offline fallback). $MURDERBOARD_REPO wins.
CLONE_CANDIDATES="
${MURDERBOARD_REPO:-}
$HOME/Documents/murderboard
$HOME/Developer/murderboard
$HOME/murderboard
$HOME/src/murderboard
"

# Vendored files to check, relative to the repo root. First existing one is used for the
# stamp; the rest are reported if their stamps disagree with it.
STAMPED_FILES="
docs/doc_review_process.md
doc_review_process.md
tools/fetch_paper.py
fetch_paper.py
tools/murderboard_freshness.sh
"

if [ -t 1 ]; then RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
else RED=; YEL=; GRN=; RST=; fi

VERBOSE=0; FORCE_UPSTREAM=; ONE_FILE=; REFRESH=0; HOOK=0

# --- portable helpers --------------------------------------------------------
# SPAWN BUDGET. This runs inside a SessionStart hook that blocks session startup, on a
# machine where Defender scans every process spawn against a 210 MiB pack store — a
# single `git` or `stat` call costs 0.3-4s there. The first draft used head|grep|sed,
# two git rev-parse calls, stat and date, and measured 4.8s CACHED. Everything on the
# warm path below is therefore a bash BUILTIN, and the cache carries its own expiry so
# no stat(1) is needed to age it. Warm path = one spawn (the combined git rev-parse).
# If you add a pipeline here, measure it; correctness is not the only bar.

# current epoch seconds into $NOW, without spawning where possible
NOW=0
now() {
  if [ -n "${EPOCHSECONDS:-}" ]; then NOW=$EPOCHSECONDS                      # bash 5
  elif NOW=$(printf '%(%s)T' -1 2>/dev/null) && [ -n "$NOW" ]; then :        # bash 4.2+
  else NOW=$(date +%s); fi                                                   # bash 3.2 (macOS)
}

# first 7-40 hex sha after "@ " in the first 5 lines of $1 -> $STAMP (builtins only)
STAMP=
stamp_of() {
  local line n=0
  STAMP=
  [ -r "$1" ] || return 1
  while [ $n -lt 5 ] && IFS= read -r line; do
    n=$((n+1))
    if [[ $line =~ @\ ([0-9a-f]{7,40}) ]]; then STAMP=${BASH_REMATCH[1]}; break; fi
  done < "$1"
  [ -n "$STAMP" ]
}

have() { command -v "$1" >/dev/null 2>&1; }

# Run "$@" detached, so the caller can exit immediately.
#
# TRAP, found by testing: the first version was
#     (setsid nohup bash ... &) || (nohup bash ... &)
# On Git Bash there is NO setsid, but the `&` inside the subshell makes it return 0
# regardless, so the `||` fallback NEVER ran and the refresh silently did nothing —
# leaving the hook permanently silent, which is the worst failure a check can have.
# Probe for the binary; never rely on the exit status of a backgrounded command.
spawn_bg() {
  if have setsid; then setsid "$@" >/dev/null 2>&1 &
  elif have nohup;  then nohup  "$@" >/dev/null 2>&1 &
  else                          "$@" >/dev/null 2>&1 &
  fi
  disown 2>/dev/null || true
}

# cap a command's runtime when timeout(1) is usable. Windows' System32\timeout.exe is a
# DIFFERENT, incompatible tool, so probe for GNU semantics rather than trusting the name.
if /usr/bin/timeout --version >/dev/null 2>&1; then
  CAP() { /usr/bin/timeout "$@"; }
elif timeout --version >/dev/null 2>&1; then
  CAP() { timeout "$@"; }
else
  CAP() { shift; "$@"; }
fi

# do two shas refer to the same commit? (one may be abbreviated)
same_commit() {
  case "$2" in "$1"*) return 0 ;; esac
  case "$1" in "$2"*) return 0 ;; esac
  return 1
}

# --- upstream HEAD -----------------------------------------------------------
upstream_from_gh() {
  [ -n "${MURDERBOARD_NO_NET:-}" ] && return 1   # offline / hermetic selftest
  have gh || return 1
  CAP "$NET_CAP" gh api "repos/$REPO_SLUG/commits/main" --jq .sha 2>/dev/null \
    | grep -o '^[0-9a-f]\{40\}$'
}

upstream_from_clone() {
  local d
  for d in $CLONE_CANDIDATES; do
    [ -n "$d" ] && [ -d "$d/.git" ] || continue
    CAP "$NET_CAP" git -C "$d" rev-parse origin/main 2>/dev/null \
      | grep -o '^[0-9a-f]\{40\}$' && return 0
  done
  return 1
}

resolve_upstream() {
  local sha
  if [ -n "$FORCE_UPSTREAM" ]; then echo "$FORCE_UPSTREAM explicit"; return 0; fi
  if [ -n "${MURDERBOARD_HEAD:-}" ]; then echo "$MURDERBOARD_HEAD env"; return 0; fi
  if sha=$(upstream_from_gh) && [ -n "$sha" ]; then echo "$sha remote"; return 0; fi
  if sha=$(upstream_from_clone) && [ -n "$sha" ]; then echo "$sha local-clone"; return 0; fi
  return 1
}

# --- selftest ----------------------------------------------------------------
# The single highest-yield rule in this project's verification doctrine: run the check
# against data whose answer you ALREADY KNOW, and confirm it reports that answer. A gate
# that cannot fire manufactures confidence. Five cases, no network.
selftest() {
  local rc fails=0 out
  TMPD=$(mktemp -d 2>/dev/null || mktemp -d -t mbft)
  trap 'rm -rf "${TMPD:-}"' EXIT
  local tmp="$TMPD"

  t() { # name expected_rc file_content upstream
    local name="$1" want="$2" body="$3" up="$4" got
    printf '%s\n' "$body" > "$tmp/f.md"
    out=$(bash "$SELF" --file "$tmp/f.md" --upstream "$up" --verbose 2>&1); got=$?
    if [ "$got" -eq "$want" ]; then
      printf '  %sPASS%s  %-34s (rc=%s)\n' "$GRN" "$RST" "$name" "$got"
    else
      printf '  %sFAIL%s  %-34s (rc=%s, want %s)\n%s\n' \
             "$RED" "$RST" "$name" "$got" "$want" "$out"
      fails=$((fails+1))
    fi
  }

  echo "murderboard_freshness selftest"
  t "stale stamp FIRES"            1 "<!-- vendored @ 850bf81 -->"  "6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  t "current stamp is SILENT"      0 "<!-- vendored @ 6fab342 -->"  "6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  t "full-length stamp matches"    0 "<!-- @ 6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa -->" "6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  t "NO stamp is undetermined"     2 "# a file with no stamp at all" "6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
  t "stamp on line 4 is found"     1 "$(printf 'a\nb\nc\n# vendored @ 850bf81')" "6fab342aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"

  # a missing file must be undetermined, never a silent pass
  out=$(bash "$SELF" --file "$tmp/does-not-exist.md" --upstream deadbee --verbose 2>&1); rc=$?
  if [ "$rc" -eq 2 ]; then printf '  %sPASS%s  %-34s (rc=2)\n' "$GRN" "$RST" "missing file is undetermined"
  else printf '  %sFAIL%s  %-34s (rc=%s, want 2)\n' "$RED" "$RST" "missing file is undetermined" "$rc"; fails=$((fails+1)); fi

  # unresolvable upstream must be undetermined, never "current". Hermetic: no network
  # (MURDERBOARD_NO_NET), HOME redirected so no real clone can answer, and MURDERBOARD_CACHE
  # pointed at nothing — WITHOUT that last one this case reads the ambient repo cache and
  # passes or fails depending on which repo you happen to run it in. (It did exactly that:
  # green in the upstream checkout, red in the first consumer that vendored it.)
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO=/nonexistent HOME="$tmp/nohome" \
        MURDERBOARD_CACHE="$tmp/nocache" \
        bash "$SELF" --file "$tmp/f.md" --verbose 2>&1); rc=$?
  if [ "$rc" -eq 2 ]; then printf '  %sPASS%s  %-34s (rc=2)\n' "$GRN" "$RST" "no upstream is undetermined"
  else printf '  %sFAIL%s  %-34s (rc=%s, want 2)\n' "$RED" "$RST" "no upstream is undetermined" "$rc"; fails=$((fails+1)); fi

  # --hook with a COLD cache must be silent and instant, never a network call
  printf '%s\n' "<!-- vendored @ 850bf81 -->" > "$tmp/f.md"
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_CACHE="$tmp/nocache" HOME="$tmp/nohome" \
        MURDERBOARD_REPO=/nonexistent bash "$SELF" --hook --file "$tmp/f.md" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf '  %sPASS%s  %-34s (rc=0, silent)\n' "$GRN" "$RST" "--hook cold cache is silent"
  else
    printf '  %sFAIL%s  %-34s (rc=%s, out=%s)\n' "$RED" "$RST" "--hook cold cache is silent" "$rc" "$out"
    fails=$((fails+1))
  fi

  # --hook with a TRUSTED warm cache (resolved AFTER the file was written) must still fire
  exp=$(( $(date +%s) + 9999 ))
  printf 'aaaaaaa%s remote %s %s\n' "1111111111111111111111111111111" "$exp" "$exp" > "$tmp/warm"
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_CACHE="$tmp/warm" \
        bash "$SELF" --hook --file "$tmp/f.md" 2>&1); rc=$?
  if [ "$rc" -eq 1 ]; then printf '  %sPASS%s  %-34s (rc=1)\n' "$GRN" "$RST" "--hook trusted cache FIRES"
  else printf '  %sFAIL%s  %-34s (rc=%s, want 1)\n%s\n' "$RED" "$RST" "--hook trusted cache FIRES" "$rc" "$out"; fails=$((fails+1)); fi

  # A cache resolved BEFORE the file was last written must never accuse. This is the
  # normal path right after an upstream push + re-vendor: the stamp moved, the cache did
  # not, and the consumer's brand-new copy would be called stale — exactly backwards.
  # Marker: the cache records WHEN it was resolved.
  printf '%s\n' "<!-- vendored @ 6fab342 -->" > "$tmp/new.md"
  printf '0000000%s remote %s 1\n' "1111111111111111111111111111111" "$exp" > "$tmp/behind"
  out=$(MURDERBOARD_CACHE="$tmp/behind" MURDERBOARD_HEAD=6fab342 \
        bash "$SELF" --file "$tmp/new.md" --verbose 2>&1); rc=$?
  if [ "$rc" -eq 0 ]; then printf '  %sPASS%s  %-34s (rc=0)\n' "$GRN" "$RST" "a BEHIND cache is not stale"
  else printf '  %sFAIL%s  %-34s (rc=%s, want 0)\n%s\n' "$RED" "$RST" "a BEHIND cache is not stale" "$rc" "$out"; fails=$((fails+1)); fi

  # ...and in --hook mode, which cannot verify, it must stay SILENT rather than accuse.
  printf '0000000%s remote %s 1\n' "1111111111111111111111111111111" "$exp" > "$tmp/behind2"
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_CACHE="$tmp/behind2" \
        bash "$SELF" --hook --file "$tmp/new.md" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ -z "$out" ]; then
    printf '  %sPASS%s  %-34s (rc=0, silent)\n' "$GRN" "$RST" "--hook BEHIND cache stays silent"
  else
    printf '  %sFAIL%s  %-34s (rc=%s, out=%s)\n' "$RED" "$RST" "--hook BEHIND cache stays silent" "$rc" "$out"
    fails=$((fails+1))
  fi

  # The detached-refresh MECHANISM must actually run. This case exists because the first
  # version's spawn was a silent no-op on this platform, which made --hook permanently
  # quiet — indistinguishable, in the briefing, from "everything is current".
  rm -f "$tmp/probe"
  bash "$SELF" --_spawn-probe "$tmp/probe" >/dev/null 2>&1
  n=0; while [ $n -lt 40 ] && [ ! -e "$tmp/probe" ]; do sleep 0.25; n=$((n+1)); done
  if [ -e "$tmp/probe" ]; then
    printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "detached refresh actually spawns"
  else
    printf '  %sFAIL%s  %-34s (background spawn is a NO-OP on this platform)\n' \
           "$RED" "$RST" "detached refresh actually spawns"; fails=$((fails+1))
  fi

  echo
  if [ "$fails" -eq 0 ]; then echo "${GRN}all checks pass${RST}"; else echo "${RED}$fails FAILED${RST}"; fi
  return $fails
}

# --- args --------------------------------------------------------------------
# absolute, so --selftest can re-invoke this script from a temp cwd
SELF=$(cd -- "$(dirname -- "$0")" 2>/dev/null && pwd -P)/$(basename -- "$0")
[ -r "$SELF" ] || SELF=$0
TMPD=
while [ $# -gt 0 ]; do
  case "$1" in
    --verbose|-v)  VERBOSE=1 ;;
    --file)        ONE_FILE="${2:-}"; shift ;;
    --upstream)    FORCE_UPSTREAM="${2:-}"; shift ;;
    --refresh)     REFRESH=1 ;;
    --hook)        HOOK=1 ;;
    --selftest)    selftest; exit $? ;;
    --_spawn-probe) spawn_bg touch "${2:-}"; exit 0 ;;   # selftest only
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# --- locate the vendored file -------------------------------------------------
# ONE git call for both paths — two rev-parse spawns measured ~1s each on Windows.
root=.; cm=.
if gitout=$(git rev-parse --show-toplevel --git-common-dir 2>/dev/null); then
  root=${gitout%%$'\n'*}
  cm=${gitout##*$'\n'}
  [ -n "$root" ] || root=.
  [ -n "$cm" ] || cm=.
fi

target=; stamp=
if [ -n "$ONE_FILE" ]; then
  target="$ONE_FILE"
  stamp_of "$target" && stamp=$STAMP
else
  for f in $STAMPED_FILES; do
    [ -r "$root/$f" ] || continue
    stamp_of "$root/$f" || continue
    target="$root/$f"; stamp=$STAMP; break
  done
fi

if [ -z "$target" ] || [ ! -r "$target" ]; then
  [ "$VERBOSE" -eq 1 ] && echo "${YEL}murderboard: no vendored copy found${RST}"
  exit 2
fi
if [ -z "$stamp" ]; then
  echo "${YEL}murderboard: ${target#$root/} carries NO vendored stamp — cannot tell if it is current.${RST}"
  echo "   Add one:  vendored from https://github.com/$REPO_SLUG @ <short-sha>"
  exit 2
fi

# --- upstream HEAD, cached ----------------------------------------------------
# The cache stores its OWN expiry, so ageing it costs no stat(1). Machine-local (git
# common dir), shared by every worktree of this repo, never committed.
cache="${MURDERBOARD_CACHE:-$cm/murderboard-head.cache}"
head_sha=; source=; expires=0; resolved=0; trusted=1
now

# stat(1) is GNU on Linux/Git-Bash and BSD on macOS; getting it wrong must not silently
# read as "0", which would mark every cache trustworthy. Only called when a cache exists.
mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 9999999999; }

fresh=0
# $MURDERBOARD_HEAD overrides the LIVE lookup (inside resolve_upstream), not the cache;
# --upstream / --refresh bypass the cache outright.
if [ -z "$FORCE_UPSTREAM" ] && [ "$REFRESH" -eq 0 ]; then
  # NOTE the redirection ORDER. `read ... < "$cache" 2>/dev/null` does NOT suppress a
  # missing-file error: bash applies redirections left to right, so `< "$cache"` fails
  # and reports before 2>/dev/null is in effect. Put the stderr redirect FIRST.
  read -r head_sha source expires resolved 2>/dev/null < "$cache" \
    || { head_sha=; source=; expires=0; resolved=0; }
  if [ -n "$head_sha" ] && [ "${expires:-0}" -gt "$NOW" ] 2>/dev/null; then
    fresh=1; source="$source, cached"
    # TRUST TEST: was this cache resolved AFTER the vendored file was last written?
    # If not, the file may have been re-vendored since and the cached HEAD is merely
    # BEHIND it — not grounds to accuse.
    #
    # An earlier version recorded the STAMP the cache was judged against instead. That is
    # wrong for a multi-worktree repo: the cache lives in the shared git common dir, so
    # ~17 worktrees sitting at different stamps each invalidated the others' trust and the
    # check went silent almost everywhere. A timestamp is per-file and survives sharing.
    [ "${resolved:-0}" -ge "$(mtime "$target")" ] 2>/dev/null || trusted=0
  fi
fi

# --hook: NEVER block on the network. A SessionStart hook blocks session startup, and a
# cold upstream lookup measured ~9s here — enough to push the whole briefing toward the
# SDK's hard 60s abort. So the hook serves whatever the cache holds (even expired) and
# refreshes it DETACHED for next time. With no cache at all it says nothing: one silent
# session is a far better failure than a session that will not start.
if [ "$HOOK" -eq 1 ] && [ "$fresh" -eq 0 ]; then
  spawn_bg bash "$SELF" --refresh
  [ -z "$head_sha" ] && exit 0
  source="${source:-unknown}, cached/stale"
fi

if [ -z "$head_sha" ]; then
  if ans=$(resolve_upstream); then
    head_sha=${ans%% *}; source=${ans##* }; trusted=1
    [ "$source" != "explicit" ] && [ "$source" != "env" ] \
      && printf '%s %s %s %s\n' "$head_sha" "$source" "$((NOW + TTL))" "$NOW" \
         > "$cache" 2>/dev/null
  fi
fi

if [ -z "$head_sha" ]; then
  echo "${YEL}murderboard: cannot reach upstream ($REPO_SLUG) — freshness UNKNOWN.${RST}"
  echo "   Vendored stamp is $stamp. Check by hand before running a review."
  exit 2
fi

# --- verdict ------------------------------------------------------------------
if same_commit "$stamp" "$head_sha"; then
  [ "$VERBOSE" -eq 1 ] && \
    echo "${GRN}murderboard: current${RST} (@ $stamp, via $source)"
  exit 0
fi

# MISMATCH — but do not accuse on hearsay. A CACHED upstream can simply be behind: the
# moment someone pushes upstream and re-vendors, a consumer holding a <=12h old cache sees
# its brand-new stamp disagree with a stale HEAD and gets told it is stale, backwards.
# So re-verify live before declaring it. In --hook mode we must not touch the network, so
# instead queue a detached refresh and label the number as cached.
if [ "$trusted" -eq 0 ]; then
  if [ "$HOOK" -eq 1 ]; then
    # Cannot verify without the network, and must not accuse on an untrusted number.
    # Queue the refresh and say nothing THIS session; the next one judges on a cache
    # that was resolved against this very stamp, and will accuse if it is truly stale.
    spawn_bg bash "$SELF" --refresh
    exit 0
  elif ans=$(resolve_upstream); then
    head_sha=${ans%% *}; source=${ans##* }
    [ "$source" != "explicit" ] && [ "$source" != "env" ] \
      && printf '%s %s %s %s\n' "$head_sha" "$source" "$((NOW + TTL))" "$NOW" \
         > "$cache" 2>/dev/null
    if same_commit "$stamp" "$head_sha"; then
      [ "$VERBOSE" -eq 1 ] && \
        echo "${GRN}murderboard: current${RST} (@ $stamp, via $source — the cache was behind)"
      exit 0
    fi
  fi
fi

echo "${RED}--- !! MURDERBOARD IS STALE — re-vendor BEFORE running a review ---${RST}"
echo "   vendored: $stamp   upstream: ${head_sha%${head_sha#???????}}   (via $source)"
echo "   file:     ${target#$root/}"
echo "   A review run against a stale process silently omits rules already paid for."
echo "   Re-copy from https://github.com/$REPO_SLUG and bump the stamp on EVERY"
echo "   vendored file, then land it on the DEFAULT BRANCH — vendoring onto a leaf"
echo "   branch leaves every new worktree inheriting the old copy."

# disagreeing stamps across the vendored set are their own defect
for f in $STAMPED_FILES; do
  [ -r "$root/$f" ] || continue
  stamp_of "$root/$f" || continue
  same_commit "$STAMP" "$stamp" || echo "   note: $f is stamped $STAMP, not $stamp"
done

exit 1
