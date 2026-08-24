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
#   murderboard_freshness.sh --file PATH     check this vendored file (default: autodetect).
#                                            Repeatable; naming files also SCOPES the
#                                            cross-stamp check to just those files.
#   murderboard_freshness.sh --label NAME    what is being checked (default: murderboard).
#                                            Appears in every message.
#   murderboard_freshness.sh --slug O/R      upstream repo (default: syncytium2/murderboard)
#   murderboard_freshness.sh --clone PATH    where a local clone of that upstream lives
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
# A BEHIND CLONE MUST NOT ACCUSE THE CONSUMER. Resolution 4 only knows what that clone last
# fetched, so a disagreement can mean "the consumer is stale" OR "this clone is". Before
# deciding, the verdict asks which way it runs: if the clone holds the stamped commit and
# its own origin/main is an ANCESTOR of it, the consumer is at-or-ahead and the run is
# silent; if the clone has never fetched the stamp it cannot rank it, and the answer is 2
# (undetermined), not 1. "Never a false current" does not license a false STALE — that
# costs a pointless re-vendor and teaches people the gate cries wolf.
#
# CACHE. Upstream HEAD is cached for $TTL seconds in the git common dir (machine-local,
# shared by every worktree, never committed), because this runs in a SessionStart hook
# that blocks session startup and cannot afford a network call every time.
#
# NOT MURDERBOARD-ONLY ANY MORE. The failure it catches — a vendored copy drifting with
# nothing to announce it — is not specific to this repo, and it bit in the other direction
# too: three consumers ran interface2's PRE-FIX SessionStart hook for weeks, including the
# commit written expressly so they would not inherit that outage. One gate, pointed at a
# family with --label/--slug/--clone/--file, serves every vendoring relationship.
#
# Project-neutral: no hardcoded consumer paths. Override anything via the env vars below.

set -u
LC_ALL=C; export LC_ALL

REPO_SLUG="${MURDERBOARD_REPO_SLUG:-syncytium2/murderboard}"
TTL="${MURDERBOARD_TTL:-43200}"          # 12h
NET_CAP="${MURDERBOARD_NET_CAP:-6}"      # max seconds for the upstream lookup

# Where a local clone might live (offline fallback). $MURDERBOARD_REPO wins.
#
# TWO LISTS, and the split is load-bearing. CLONE_CANDIDATES holds paths somebody
# ASSERTED are the upstream for the slug in play — $MURDERBOARD_REPO, or --clone.
# DEFAULT_CLONE_CANDIDATES holds GUESSES, and every guess is a murderboard path.
#
# They must not be merged. --label/--slug generalize this gate to any vendoring
# family, but the guesses never generalized with them: consulted for a slug that is
# not murderboard, they resolve against murderboard's HEAD and the gate returns a
# confident verdict about a repository it never looked at. That is worse than an
# error, because it manufactures the confidence it exists to supply. So the guesses
# are consulted ONLY when the slug actually names this repo; for any other family an
# unreachable upstream stays unreachable, and the caller gets "cannot determine"
# (exit 2), which is true.
DEFAULT_SLUG="syncytium2/murderboard"
CLONE_CANDIDATES="${MURDERBOARD_REPO:-}"
DEFAULT_CLONE_CANDIDATES="
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
tools/murderboard_roster.sh
murderboard_roster.sh
.claude/hooks/require-commit-before-message.sh
tools/require_commit_before_message.sh
require_commit_before_message.sh
.claude/skills/murderboard/SKILL.md
"

if [ -t 1 ]; then RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
else RED=; YEL=; GRN=; RST=; fi

VERBOSE=0; FORCE_UPSTREAM=; ONE_FILE=; REFRESH=0; HOOK=0; DEFER=
STAMP_CONFLICTED=0

# What this run is checking. The tool started life murderboard-only, but the SAME staleness
# failure runs in the other direction too — a consumer's vendored copy of some OTHER
# upstream (a shared lint config or CI template, say) drifts with nothing to announce it.
# --label/--slug/--clone make one gate serve any vendor family; --file scopes it.
LABEL="${MURDERBOARD_LABEL:-murderboard}"
EXPLICIT_FILES=

# Which local clone answered the offline fallback, and what the verdict block learned from
# it. Set by upstream_from_clone / clone_says_stamp_is_newer; empty when upstream came from
# the remote, an explicit sha, or the environment.
ANSWERING_CLONE=
VERDICT_NOTE=

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
  STAMP_CONFLICTED=0
  [ -r "$1" ] || return 1
  while [ $n -lt 5 ] && IFS= read -r line; do
    n=$((n+1))
    # An UNRESOLVED MERGE sitting in the header means this file is not vendored at any
    # commit — it holds two stamps and a pile of markers. Taking the first sha found would
    # pick a side of somebody's conflict at random and then report a confident verdict
    # about it. Seen in the wild: a consumer branch carried committed conflict markers in
    # the top six lines of three vendored files, one stamp per side (729fb06 vs 4e417da),
    # and the vendored fetch_paper.py did not even compile.
    case $line in
      '<<<<<<< '*|'>>>>>>> '*|'=======') STAMP_CONFLICTED=1; STAMP=; return 1 ;;
    esac
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
  local d sha candidates="$CLONE_CANDIDATES"
  # The built-in guesses are murderboard paths and are only admissible when the
  # slug in play is murderboard. See the note at DEFAULT_CLONE_CANDIDATES: for any
  # other family they would answer from the wrong repository.
  [ "$REPO_SLUG" = "$DEFAULT_SLUG" ] && candidates="$candidates
$DEFAULT_CLONE_CANDIDATES"
  for d in $candidates; do
    [ -n "$d" ] && [ -d "$d/.git" ] || continue
    if sha=$(CAP "$NET_CAP" git -C "$d" rev-parse origin/main 2>/dev/null \
             | grep -o '^[0-9a-f]\{40\}$') && [ -n "$sha" ]; then
      # Print WHICH clone answered alongside the sha. The verdict needs this clone's object
      # database to tell "the consumer is behind" from "this clone is behind" — see
      # clone_says_stamp_is_newer(). A global will not do: this runs in a subshell.
      printf '%s %s\n' "$sha" "$d"
      return 0
    fi
  done
  return 1
}

# Did the clone that answered simply not know about the stamped commit yet, or does it
# know it and place it AHEAD of the origin/main it reported? Either way the consumer is
# not stale and must not be accused.
#
# WHY THIS EXISTS. The offline fallback reads a local clone's origin/main, and that clone
# can itself be behind — it only knows what it last fetched. A consumer vendored at the
# TRUE upstream HEAD then disagrees with a stale number, and the verdict block, which only
# asked "are these equal?", called the CONSUMER stale. Backwards, and the expensive
# direction: it costs a pointless re-vendor and teaches people the gate cries wolf.
# Reproduced 2026-08-24: consumer stamped at true HEAD, clone two commits behind -> exit 1
# "IS STALE" where the honest answers are 0 (provably at-or-ahead) or 2 (cannot tell).
#
# Returns 0 = the consumer is at-or-ahead (do not accuse), with VERDICT_NOTE set
#         1 = the clone genuinely places the stamp behind its origin/main -> really stale
#         2 = the clone cannot speak to it at all -> undetermined
clone_says_stamp_is_newer() {
  local d="$ANSWERING_CLONE" stamp="$1" up="$2"
  [ -n "$d" ] && [ -d "$d/.git" ] || return 2
  # A clone that has never heard of the stamped commit cannot rank it. That is the
  # ordinary case when the consumer is NEWER than the clone's last fetch.
  git -C "$d" cat-file -e "${stamp}^{commit}" 2>/dev/null || {
    VERDICT_NOTE="the local clone has never fetched ${stamp%${stamp#???????}}, so it cannot rank it"
    return 2
  }
  if git -C "$d" merge-base --is-ancestor "$up" "$stamp" 2>/dev/null; then
    VERDICT_NOTE="the local clone is behind: ${up%${up#???????}} is an ANCESTOR of the vendored ${stamp%${stamp#???????}}"
    return 0
  fi
  return 1
}

# Split what resolve_upstream printed ("SHA SOURCE [CLONEDIR]") into globals. Must run in
# the CALLER's shell, not a subshell, or ANSWERING_CLONE is lost again.
parse_resolved() {
  local rest
  head_sha=${1%% *}
  rest=${1#* }
  source=${rest%% *}
  if [ "$rest" != "$source" ]; then ANSWERING_CLONE=${rest#* }; else ANSWERING_CLONE=; fi
}

resolve_upstream() {
  local sha
  if [ -n "$FORCE_UPSTREAM" ]; then echo "$FORCE_UPSTREAM explicit"; return 0; fi
  if [ -n "${MURDERBOARD_HEAD:-}" ]; then echo "$MURDERBOARD_HEAD env"; return 0; fi
  if sha=$(upstream_from_gh) && [ -n "$sha" ]; then echo "$sha remote"; return 0; fi
  # The clone's PATH rides along on stdout as a third field. It cannot travel in a global:
  # every caller invokes resolve_upstream in a command substitution, so anything assigned
  # inside dies with the subshell. The verdict block needs that path to tell "the consumer
  # is behind" from "this clone is behind".
  # upstream_from_clone prints "SHA DIR". The clone's PATH must ride along on stdout as a
  # third field: it cannot travel in a global, because every caller invokes resolve_upstream
  # in a command substitution and anything assigned inside dies with the subshell. The
  # verdict block needs that path to tell "the consumer is behind" from "this clone is behind".
  if sha=$(upstream_from_clone) && [ -n "$sha" ]; then
    echo "${sha%% *} local-clone ${sha#* }"
    return 0
  fi
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

  # --defer must print the previous verdict, then refresh it in the background.
  rm -f "$tmp/verdict"
  printf 'PREVIOUS VERDICT\n' > "$tmp/verdict"
  out=$(cd "$tmp" && bash "$SELF" --defer "$tmp/verdict" 2>&1); rc=$?
  if [ "$rc" -eq 0 ] && [ "$out" = "PREVIOUS VERDICT" ]; then
    printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "--defer prints the last verdict"
  else
    printf '  %sFAIL%s  %-34s (rc=%s, out=%s)\n' "$RED" "$RST" "--defer prints the last verdict" "$rc" "$out"
    fails=$((fails+1))
  fi
  # ...and the background writer must actually replace it (here: with a stale-copy report)
  printf '%s\n' "<!-- vendored @ 850bf81 -->" > "$tmp/doc_review_process.md"
  n=0; while [ $n -lt 60 ] && grep -q "PREVIOUS VERDICT" "$tmp/verdict" 2>/dev/null; do
    sleep 0.25; n=$((n+1)); done
  if ! grep -q "PREVIOUS VERDICT" "$tmp/verdict" 2>/dev/null; then
    printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "--defer refreshes the file"
  else
    printf '  %sFAIL%s  %-34s (verdict never replaced)\n' "$RED" "$RST" "--defer refreshes the file"
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

  # --- multi-family use (--label / --slug / --file scoping) --------------------

  # The label must reach the output, or a consumer checking two upstreams gets two
  # identical-looking alerts and cannot tell which one went stale.
  printf 'x @ 1111111 x\n' > "$tmp/other.md"
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_CACHE="$tmp/lbl" MURDERBOARD_HEAD=2222222 \
        bash "$SELF" --label session-protocol --file "$tmp/other.md" --verbose 2>&1); rc=$?
  case "$out" in
    *SESSION-PROTOCOL*) printf '  %sPASS%s  %-34s (rc=%s)\n' "$GRN" "$RST" "--label reaches the alert" "$rc" ;;
    *) printf '  %sFAIL%s  %-34s (out=%s)\n' "$RED" "$RST" "--label reaches the alert" "$out"; fails=$((fails+1)) ;;
  esac

  # --file must SCOPE the cross-stamp notes. Unscoped, a repo vendoring two upstreams
  # reports every file of the OTHER family as wrongly stamped — noise that reads as
  # findings. Run from a repo root that really does carry murderboard-stamped files.
  case "$out" in
    *"doc_review_process.md is stamped"*)
      printf '  %sFAIL%s  %-34s (leaked another family)\n' "$RED" "$RST" "--file scopes cross-stamp notes"; fails=$((fails+1)) ;;
    *) printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "--file scopes cross-stamp notes" ;;
  esac

  # THE BUG THIS FILE SHIPPED WITH until multi-family use existed: the cache was ONE fixed
  # filename in the git common dir, so a second family's cached upstream HEAD was compared
  # against the first family's stamp — a confident, completely wrong verdict in BOTH
  # directions. Prove the cache path is keyed by slug.
  # Asserted on OBSERVABLE behaviour, not on an internal variable: run two families in a
  # throwaway repo (so the cache lands in ITS git dir) and require two distinct cache files.
  # A single shared file is the poisoning bug.
  # NB the head must come from a resolution source that CACHES. --upstream/$MURDERBOARD_HEAD
  # deliberately do not write a cache, so driving this with either proves nothing — the
  # first version of this test did exactly that and found 0 files, looking like the bug.
  # Build a real local upstream and resolve through --clone.
  ( git init -q --bare "$tmp/up.git" 2>/dev/null
    git init -q "$tmp/seed" 2>/dev/null
    cd "$tmp/seed" || exit 1
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed 2>/dev/null
    git branch -M main 2>/dev/null
    git remote add origin "$tmp/up.git" 2>/dev/null
    git push -q origin main 2>/dev/null
    git clone -q "$tmp/up.git" "$tmp/clone" 2>/dev/null

    git init -q "$tmp/repo" 2>/dev/null
    cd "$tmp/repo" || exit 1
    printf 'x @ 1111111 x\n' > v.md
    MURDERBOARD_NO_NET=1 bash "$SELF" --slug fam/one --clone "$tmp/clone" --file v.md >/dev/null 2>&1
    MURDERBOARD_NO_NET=1 bash "$SELF" --slug fam/two --clone "$tmp/clone" --file v.md >/dev/null 2>&1 )
  n=$(ls "$tmp/repo/.git/" 2>/dev/null | grep -c 'murderboard-head\..*\.cache')
  if [ "${n:-0}" -eq 2 ]; then
    printf '  %sPASS%s  %-34s (2 distinct caches)\n' "$GRN" "$RST" "cache is keyed per upstream"
  else
    printf '  %sFAIL%s  %-34s (%s cache file(s); shared cache poisons both verdicts)\n' \
           "$RED" "$RST" "cache is keyed per upstream" "${n:-0}"; fails=$((fails+1))
  fi

  # The built-in clone guesses are murderboard paths. Consulted for another family
  # they answer from the wrong repository — a confident verdict about a repo never
  # looked at. Both directions must hold: admissible for our own slug, inadmissible
  # for anyone else's. HOME is redirected so the guess list is real but hermetic.
  #
  # The stamp used here must be a REAL commit the guessed clone actually has, and an
  # OLDER one — i.e. genuinely stale. A fabricated sha ("1111111") would also produce a
  # non-UNKNOWN verdict for the wrong reason, and since the fallback now refuses to rank
  # a stamp its clone has never fetched, a fabricated stamp reports UNKNOWN and this
  # case would silently stop testing slug-scoping at all.
  ( git init -q --bare "$tmp/mb.git" 2>/dev/null
    git init -q "$tmp/mbseed" 2>/dev/null
    cd "$tmp/mbseed" || exit 1
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m mb 2>/dev/null
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m mb2 2>/dev/null
    git branch -M main 2>/dev/null
    git remote add origin "$tmp/mb.git" 2>/dev/null
    git push -q origin main 2>/dev/null
    mkdir -p "$tmp/fakehome/Developer" 2>/dev/null
    git clone -q "$tmp/mb.git" "$tmp/fakehome/Developer/murderboard" 2>/dev/null ) >/dev/null 2>&1
  mkdir -p "$tmp/consumer" 2>/dev/null
  mb_old=$(git -C "$tmp/mbseed" rev-parse HEAD~1 2>/dev/null)
  printf 'x @ %s x\n' "${mb_old:-1111111}" > "$tmp/consumer/v.md"
  own=$( cd "$tmp/consumer" && HOME="$tmp/fakehome" MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
         bash "$SELF" --slug "$DEFAULT_SLUG" --file v.md 2>&1 | grep -ci 'UNKNOWN\|cannot reach' )
  other=$( cd "$tmp/consumer" && HOME="$tmp/fakehome" MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
           bash "$SELF" --slug other/family --file v.md 2>&1 | grep -ci 'UNKNOWN\|cannot reach' )
  if [ "${own:-0}" -eq 0 ] && [ "${other:-0}" -ge 1 ]; then
    printf '  %sPASS%s  %-34s (guesses used for own slug, refused for others)\n' \
           "$GRN" "$RST" "clone guesses are slug-scoped"
  else
    printf '  %sFAIL%s  %-34s (own=%s other=%s; a foreign slug resolved against murderboard)\n' \
           "$RED" "$RST" "clone guesses are slug-scoped" "${own:-?}" "${other:-?}"; fails=$((fails+1))
  fi

  # A BEHIND CLONE MUST NOT ACCUSE THE CONSUMER. The offline fallback reads a local
  # clone's origin/main, and that clone only knows what it last fetched. Before this case
  # existed, a consumer vendored at the TRUE upstream HEAD was told it was STALE because
  # the clone answering for upstream was two commits behind — the accusation ran backwards,
  # and it is the expensive direction: a pointless re-vendor, and a gate people learn to
  # distrust. Both halves are checked: at-or-ahead must be SILENT (0), and a stamp the
  # clone cannot rank at all must be UNDETERMINED (2), never STALE (1).
  ( git init -q --bare "$tmp/bh.git" 2>/dev/null
    git init -q "$tmp/bhseed" 2>/dev/null
    cd "$tmp/bhseed" || exit 1
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m one 2>/dev/null
    git branch -M main 2>/dev/null
    git remote add origin "$tmp/bh.git" 2>/dev/null
    git push -q origin main 2>/dev/null
    git clone -q "$tmp/bh.git" "$tmp/bhclone" 2>/dev/null
    cd "$tmp/bhseed" || exit 1
    git -c user.email=t@t -c user.name=t commit -q --allow-empty -m two 2>/dev/null
    git push -q origin main 2>/dev/null ) >/dev/null 2>&1
  bh_new=$(git -C "$tmp/bhseed" rev-parse HEAD 2>/dev/null)
  bh_old=$(git -C "$tmp/bhseed" rev-parse HEAD~1 2>/dev/null)
  mkdir -p "$tmp/bhconsumer" 2>/dev/null
  # (a) the clone HAS the stamp and it is a descendant -> at-or-ahead -> silent 0
  git -C "$tmp/bhclone" fetch -q origin 2>/dev/null
  git -C "$tmp/bhclone" update-ref refs/remotes/origin/main "$bh_old" 2>/dev/null
  printf 'x @ %s x\n' "$bh_new" > "$tmp/bhconsumer/v.md"
  ( cd "$tmp/bhconsumer" && MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
    bash "$SELF" --slug bh/fam --clone "$tmp/bhclone" --file v.md >/dev/null 2>&1 ); ahead_rc=$?
  # (b) the clone has NEVER fetched the stamp -> cannot rank -> undetermined 2
  git clone -q "$tmp/bh.git" "$tmp/bhclone2" 2>/dev/null
  git -C "$tmp/bhclone2" update-ref refs/remotes/origin/main "$bh_old" 2>/dev/null
  printf 'x @ %s x\n' "0123456789abcdef0123456789abcdef01234567" > "$tmp/bhconsumer/v.md"
  ( cd "$tmp/bhconsumer" && MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
    bash "$SELF" --slug bh/fam --clone "$tmp/bhclone2" --file v.md >/dev/null 2>&1 ); unrank_rc=$?
  if [ "$ahead_rc" -eq 0 ] && [ "$unrank_rc" -eq 2 ]; then
    printf '  %sPASS%s  %-34s (at-or-ahead=0, unrankable=2)\n' \
           "$GRN" "$RST" "a BEHIND clone does not cry STALE"
  else
    printf '  %sFAIL%s  %-34s (at-or-ahead=%s want 0; unrankable=%s want 2)\n' \
           "$RED" "$RST" "a BEHIND clone does not cry STALE" "$ahead_rc" "$unrank_rc"; fails=$((fails+1))
  fi

  # A COMMITTED MERGE CONFLICT IN THE HEADER IS NOT A STAMP. Two stamps and a pile of
  # markers means the file is vendored at NO commit, and picking the first sha found sides
  # with one half of somebody's unfinished merge and then reports a confident verdict about
  # it. Seen in the wild on a consumer branch: markers in the top six lines of three
  # vendored files, one stamp per side, and the vendored fetch_paper.py did not compile.
  mkdir -p "$tmp/conf" 2>/dev/null
  { printf '<<<<<<< HEAD\n'
    printf '# vendored from o/r @ 1111111 x\n'
    printf '=======\n'
    printf '# vendored from o/r @ 2222222 x\n'
    printf '>>>>>>> origin/main\n'
    printf 'body\n'; } > "$tmp/conf/v.md"
  ( cd "$tmp/conf" && MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
    bash "$SELF" --slug o/r --upstream 2222222 --file v.md >/dev/null 2>&1 ); conf_rc=$?
  conf_says=$( cd "$tmp/conf" && MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= \
    bash "$SELF" --slug o/r --upstream 2222222 --file v.md 2>&1 | grep -ci 'CONFLICT MARKERS' )
  if [ "$conf_rc" -eq 2 ] && [ "${conf_says:-0}" -ge 1 ]; then
    printf '  %sPASS%s  %-34s (rc=2, names the conflict)\n' \
           "$GRN" "$RST" "conflicted header is not a stamp"
  else
    printf '  %sFAIL%s  %-34s (rc=%s want 2; named=%s want >=1)\n' \
           "$RED" "$RST" "conflicted header is not a stamp" "$conf_rc" "${conf_says:-0}"; fails=$((fails+1))
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
    --file)        ONE_FILE="${2:-}"; EXPLICIT_FILES="$EXPLICIT_FILES
${2:-}"; shift ;;
    --label)       LABEL="${2:-}"; shift ;;
    --slug)        REPO_SLUG="${2:-}"; shift ;;
    --clone)       CLONE_CANDIDATES="${2:-}
$CLONE_CANDIDATES"; shift ;;
    --upstream)    FORCE_UPSTREAM="${2:-}"; shift ;;
    --refresh)     REFRESH=1 ;;
    --hook)        HOOK=1 ;;
    --defer)       DEFER="${2:-}"; shift ;;
    --_defer-write) # internal: recompute and atomically replace the verdict file
                   out=$(bash "$SELF" 2>/dev/null); rc=$?
                   printf '%s' "$out" > "${2:-}.tmp" 2>/dev/null \
                     && mv -f "${2:-}.tmp" "${2:-}" 2>/dev/null
                   exit "$rc" ;;
    --selftest)    selftest; exit $? ;;
    --_spawn-probe) spawn_bg touch "${2:-}"; exit 0 ;;   # selftest only
    -h|--help)     sed -n '2,40p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

# --- --defer: zero-work mode for a hot session-start hook ----------------------
# Prints the PREVIOUS verdict (a plain file read) and recomputes in the background. The
# blocking cost is one file read plus one spawn — no git, no stat, no network, ever.
#
# Why this exists: the consumer's SessionStart hook already measured 31-39s against a 45s
# timeout and a hard 60s session abort, with ~8s of run-to-run variance. Even a 3-7s check
# is too much to add to that path, and "the briefing sometimes kills the session" is a far
# worse outcome than "the staleness notice is one session late". Staleness does not change
# minute to minute; a lagging answer costs nothing.
if [ -n "$DEFER" ]; then
  [ -s "$DEFER" ] && cat "$DEFER"
  spawn_bg bash "$SELF" --_defer-write "$DEFER"
  exit 0
fi

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
if [ "${STAMP_CONFLICTED:-0}" -eq 1 ]; then
  echo "${RED}$LABEL: ${target#$root/} has UNRESOLVED CONFLICT MARKERS in its header.${RST}"
  echo "   This file is not vendored at any commit — it holds two stamps and a merge that was"
  echo "   committed unfinished. Freshness is UNDETERMINABLE and the file is probably broken"
  echo "   (a conflicted .py or .sh does not parse). Do NOT resolve toward either side: re-copy"
  echo "   the file fresh from $REPO_SLUG and re-stamp it."
  exit 2
fi
if [ -z "$stamp" ]; then
  echo "${YEL}$LABEL: ${target#$root/} carries NO vendored stamp — cannot tell if it is current.${RST}"
  echo "   Add one:  vendored from $REPO_SLUG @ <short-sha>"
  exit 2
fi

# --- upstream HEAD, cached ----------------------------------------------------
# The cache stores its OWN expiry, so ageing it costs no stat(1). Machine-local (git
# common dir), shared by every worktree of this repo, never committed.
# KEYED BY SLUG, not a fixed name. A repo can vendor from more than one upstream (this
# tool now polices any of them via --slug/--label), and a shared cache file would let one
# family's cached HEAD be compared against another family's stamp — producing a confident,
# completely wrong verdict in BOTH directions. The key is the slug with non-alphanumerics
# folded to '-', so it is a legal filename on every platform.
cache_key=$(printf '%s' "$REPO_SLUG" | tr -c 'A-Za-z0-9' '-')
cache="${MURDERBOARD_CACHE:-$cm/murderboard-head.$cache_key.cache}"
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
    parse_resolved "$ans"; trusted=1
    [ "$source" != "explicit" ] && [ "$source" != "env" ] \
      && printf '%s %s %s %s\n' "$head_sha" "$source" "$((NOW + TTL))" "$NOW" \
         > "$cache" 2>/dev/null
  fi
fi

if [ -z "$head_sha" ]; then
  echo "${YEL}$LABEL: cannot reach upstream ($REPO_SLUG) — freshness UNKNOWN.${RST}"
  echo "   Vendored stamp is $stamp. Check by hand before relying on this copy."
  exit 2
fi

# --- verdict ------------------------------------------------------------------
if same_commit "$stamp" "$head_sha"; then
  [ "$VERBOSE" -eq 1 ] && \
    echo "${GRN}$LABEL: current${RST} (@ $stamp, via $source)"
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
    parse_resolved "$ans"
    [ "$source" != "explicit" ] && [ "$source" != "env" ] \
      && printf '%s %s %s %s\n' "$head_sha" "$source" "$((NOW + TTL))" "$NOW" \
         > "$cache" 2>/dev/null
    if same_commit "$stamp" "$head_sha"; then
      [ "$VERBOSE" -eq 1 ] && \
        echo "${GRN}$LABEL: current${RST} (@ $stamp, via $source — the cache was behind)"
      exit 0
    fi
  fi
fi

# A DISAGREEMENT IS NOT YET AN ACCUSATION — check which way it runs. When the number came
# from a local clone, that clone may simply be behind, in which case the consumer is fine and
# saying otherwise costs a pointless re-vendor. "Never a false current" does not license a
# false STALE: the honest answer when the fallback cannot rank the stamp is 2, not 1.
case "$source" in *local-clone*)
  # The cache records the SOURCE but not which clone answered, so a verdict served from
  # cache arrives with ANSWERING_CLONE empty. Re-derive it; the lookup is local and cheap.
  [ -z "$ANSWERING_CLONE" ] && { reans=$(upstream_from_clone) && ANSWERING_CLONE=${reans#* }; }
  clone_says_stamp_is_newer "$stamp" "$head_sha"; direction=$?
  if [ "$direction" -eq 0 ]; then
    [ "$VERBOSE" -eq 1 ] && \
      echo "${GRN}$LABEL: current${RST} (@ $stamp — $VERDICT_NOTE)"
    exit 0
  elif [ "$direction" -eq 2 ]; then
    echo "${YEL}$LABEL: freshness UNKNOWN${RST} — $VERDICT_NOTE."
    echo "   vendored: $stamp   local-clone origin/main: ${head_sha%${head_sha#???????}}"
    echo "   Fetch that clone, or re-run with network access, before trusting either answer."
    exit 2
  fi
  ;;
esac

echo "${RED}--- !! $(printf '%s' "$LABEL" | tr '[:lower:]' '[:upper:]') IS STALE — re-vendor before relying on it ---${RST}"
echo "   vendored: $stamp   upstream: ${head_sha%${head_sha#???????}}   (via $source)"
echo "   file:     ${target#$root/}"
[ "$LABEL" = murderboard ] && \
echo "   A review run against a stale process silently omits rules already paid for."
echo "   Re-copy from $REPO_SLUG and bump the stamp on EVERY vendored file of this"
echo "   family, then land it on the DEFAULT BRANCH — vendoring onto a leaf branch"
echo "   leaves every new worktree inheriting the old copy."

# Disagreeing stamps across the vendored set are their own defect. SCOPED to the family
# being checked: when the caller named files explicitly, only those are cross-checked.
# Otherwise a repo vendoring two upstreams reports every file of the OTHER family as
# "wrongly stamped" — noise that reads as findings and buries the real line.
for f in ${EXPLICIT_FILES:-$STAMPED_FILES}; do
  ff="$f"; [ -r "$ff" ] || ff="$root/$f"
  [ -r "$ff" ] || continue
  [ "$ff" = "$target" ] && continue
  stamp_of "$ff" || continue
  same_commit "$STAMP" "$stamp" || echo "   note: $f is stamped $STAMP, not $stamp"
done

exit 1
