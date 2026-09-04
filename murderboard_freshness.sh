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
#   murderboard_freshness.sh --plugin DIR    the copy is an INSTALLED Claude Code plugin:
#                                            take the commit the installer recorded for it
#   murderboard_freshness.sh --from-git DIR  the copy is a plain CHECKOUT: take its HEAD
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
# TWO WAYS A COPY CAN CARRY ITS VERSION. A VENDORED copy is loose files, so its version has
# to be written down — that is the stamp, and the whole cache/trust apparatus above exists
# because a written-down version can be edited, forgotten, or corrupted. An INSTALLED copy
# did not come from a human with a text editor, so its version was recorded by whatever
# installed it: `--plugin DIR` reads the commit Claude Code stored for that install, and
# `--from-git DIR` reads a plain checkout's HEAD. Everything downstream is unchanged,
# because all three paths produce a sha.
#
# The plugin install path must NOT be exempted from this gate. It is tempting — `/plugin
# update` exists, so staleness is "handled" — but nothing FIRES it, which makes it exactly
# the class of rule this gate was written to replace. An installed copy goes stale the same
# way a vendored one does; it just cannot lie about which commit it is at.
#
# --from-git DEMANDS THE CHECKOUT PROVE ITS IDENTITY. A sha is a sha: pointed at some
# unrelated repository, the comparison below would run to completion and report a confident
# STALE about a repo it never looked at — the manufactured-confidence failure that
# DEFAULT_CLONE_CANDIDATES is split in two to avoid. So the checkout's remotes must name
# $REPO_SLUG. No match is exit 2, not a verdict.
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
tools/murderboard_prose.sh
murderboard_prose.sh
tools/murderboard_revendor.py
murderboard_revendor.py
tools/murderboard_agents.py
murderboard_agents.py
.claude/hooks/require-commit-before-message.sh
tools/require_commit_before_message.sh
require_commit_before_message.sh
.claude/skills/murderboard/SKILL.md
"

if [ -t 1 ]; then RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; RST=$'\033[0m'
else RED=; YEL=; GRN=; RST=; fi

VERBOSE=0; FORCE_UPSTREAM=; ONE_FILE=; REFRESH=0; HOOK=0; DEFER=
STAMP_CONFLICTED=0
FROM_GIT=          # --from-git DIR: read the version from a checkout's HEAD, not a stamp
PLUGIN_DIR=        # --plugin DIR:   read it from the Claude Code plugin install registry
PLUGIN_NAME="${MURDERBOARD_PLUGIN_NAME:-murderboard}"   # name inside marketplace.json
INSTALLED_VERSION=; INSTALLED_SHA=
INSTALLED=0        # set for --from-git: the copy is INSTALLED, not vendored

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

# --from-git: an INSTALLED copy's version is its own HEAD. Sets $STAMP, or fails with a
# reason on stderr. See the "TWO WAYS A COPY CAN CARRY ITS VERSION" note in the header.
#
# The identity check is not ceremony. Without it this function happily returns the HEAD of
# whatever checkout it was handed, and the verdict block downstream — which only compares
# shas — announces STALE about an unrelated repository. Remote URLs vary in form
# (https://host/O/R, https://host/O/R.git, git@host:O/R.git, and a file:// path in tests),
# so match on the O/R substring rather than parsing, and accept ANY remote: a plugin
# install's remote is not guaranteed to be named `origin`.
CHECKOUT_WHY=
# --plugin: an INSTALLED Claude Code plugin. Sets $STAMP, or fails with a reason.
#
# MEASURED, not assumed (2026-08-26, by installing this plugin and looking): the install is
# a PLAIN COPY at ~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/. It has no .git,
# so there is no HEAD in it to read. What it does have is a registry entry — the installer
# records the commit it took under `gitCommitSha` in installed_plugins.json, keyed by the
# same installPath. That is the identity, and it is a sha, so every comparison below is
# unchanged. A version string would not have done: it is hand-maintained, and a forgotten
# bump would read as "current" — the one verdict this gate promises never to invent.
#
# Falls back to the directory's own HEAD when it is a checkout, which covers developing the
# plugin against a live clone.
#
# JSON needs a parser. Rather than scrape a machine-written file with grep and inherit a
# silent break the next time its formatting changes, this asks for python and returns 2
# without one. Undetermined is honest; a guess here would be the fail-open the no-heredoc
# hook already taught this project about.
stamp_from_install() {
  local dir="$1" py= out
  STAMP=; STAMP_CONFLICTED=0; CHECKOUT_WHY=
  if [ ! -d "$dir" ]; then CHECKOUT_WHY="no such directory: $dir"; return 1; fi
  # A real checkout answers for itself, and more precisely than the registry can.
  if git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    stamp_from_checkout "$dir" && return 0
    return 1
  fi
  for c in python3 python; do have "$c" && { py=$c; break; }; done
  if [ -z "$py" ]; then
    CHECKOUT_WHY="no python on PATH to read the plugin registry, so the installed commit cannot be determined"
    return 1
  fi
  # Prints "VERSION SHA SOURCEREPO"; SHA and SOURCEREPO may be "-" (a local/directory
  # marketplace names no repo). Empty output means no entry for that path.
  out=$("$py" - "$dir" "${CLAUDE_CONFIG_DIR:-$HOME/.claude}" <<'PYEOF' 2>/dev/null
import json, os, sys
want, cfg = os.path.realpath(sys.argv[1]), sys.argv[2]
base = os.path.join(cfg, "plugins")
try:
    inst = json.load(open(os.path.join(base, "installed_plugins.json")))
except Exception:
    sys.exit(0)
try:
    mkts = json.load(open(os.path.join(base, "known_marketplaces.json")))
except Exception:
    mkts = {}
for key, entries in (inst.get("plugins") or {}).items():
    for e in entries or []:
        if os.path.realpath(e.get("installPath", "")) != want:
            continue
        mkt = key.split("@")[-1] if "@" in key else ""
        src = (mkts.get(mkt) or {}).get("source") or {}
        repo = (src.get("repo") or "") if src.get("source") == "github" else ""
        print(e.get("version") or "-", e.get("gitCommitSha") or "-", repo or "-")
        sys.exit(0)
PYEOF
)
  if [ -z "$out" ]; then
    CHECKOUT_WHY="$dir is not a registered plugin install (no installed_plugins.json entry for that path)"
    return 1
  fi
  local ver sha repo
  read -r ver sha repo <<EOF
$out
EOF
  [ "$repo" = "-" ] && repo=
  [ "$sha" = "-" ] && sha=
  INSTALLED_VERSION="$ver"
  INSTALLED_SHA="$sha"
  if [ "$ver" = "-" ] || [ -z "$ver" ]; then
    CHECKOUT_WHY="the plugin registry records no version for $dir, so there is nothing to compare"
    return 1
  fi
  # Same identity rule as --from-git, and for the same reason: a sha compared against the
  # wrong upstream yields a confident verdict about a repository never looked at. A
  # DIRECTORY-source marketplace names no repo and cannot be checked this way; that is the
  # developer's own clone, and refusing it would disable the gate in the one case where the
  # person can actually act on it. Accepted, and labelled as unverified in the source.
  if [ -n "$repo" ] && [ "$repo" != "$REPO_SLUG" ]; then
    CHECKOUT_WHY="that plugin came from $repo, not $REPO_SLUG — refusing to judge one repository against another"
    return 1
  fi
  [ -z "$repo" ] && VERDICT_NOTE="installed from a local marketplace, so its origin repo is unverified"
  STAMP="$sha"
  return 0
}

# Upstream's ADVERTISED plugin version — the number the installer compares against.
# Fetched from the marketplace manifest on the upstream default branch. Public raw URL: no
# auth, so this works for a stranger with no gh CLI configured.
upstream_plugin_version() {
  # The explicit answer comes FIRST: it needs no network, so the offline flag must not
  # suppress it. (It did, and every version case in the selftest returned "cannot reach".)
  [ -n "${MURDERBOARD_PLUGIN_VERSION:-}" ] && { printf '%s\n' "$MURDERBOARD_PLUGIN_VERSION"; return 0; }
  [ -n "${MURDERBOARD_NO_NET:-}" ] && return 1
  local py=
  for c in python3 python; do have "$c" && { py=$c; break; }; done
  [ -z "$py" ] && return 1
  CAP "$NET_CAP" "$py" - "$REPO_SLUG" "$PLUGIN_NAME" <<'PYEOF' 2>/dev/null
import json, sys, urllib.request
slug, name = sys.argv[1], sys.argv[2]
RAW = f"https://raw.githubusercontent.com/{slug}/HEAD"


def get(path):
    try:
        with urllib.request.urlopen(f"{RAW}/{path}", timeout=10) as r:
            return json.load(r)
    except Exception:
        return None


doc = get(".claude-plugin/marketplace.json")
if doc is None:
    sys.exit(1)
entry = next((p for p in (doc.get("plugins") or [])
              if isinstance(p, dict) and p.get("name") == name), None)
if entry is None:
    sys.exit(1)
if entry.get("version"):
    print(entry["version"])
    sys.exit(0)
# A marketplace entry MAY omit the version and leave it in the plugin's own manifest --
# 289 of the 289 entries in anthropics/claude-plugins-official do exactly that. Follow the
# entry's source to find it, rather than reporting "cannot reach" for a repo just answered.
src = entry.get("source")
sub = ""
if isinstance(src, str) and not src.startswith(("http", "git@")):
    # Trim exactly the leading "./" and any trailing "/" -- NOT str.strip("./"), which
    # strips those characters as a SET from both ends and would eat a real path segment
    # (a source of "./plugins/v1.0/" comes back as "plugins/v1", silently wrong).
    sub = src[2:] if src.startswith("./") else src
    sub = sub.strip("/")
path = "/".join(x for x in (sub, ".claude-plugin/plugin.json") if x)
man = get(path)
if isinstance(man, dict) and man.get("version"):
    print(man["version"])
    sys.exit(0)
sys.exit(1)
PYEOF
}

# Compare two dotted versions. 0 = same, 1 = $1 older than $2, 2 = $1 newer.
# Numeric per component, so 0.10.0 ranks above 0.9.0 — a string compare gets that backwards,
# and getting it backwards here means telling a current install it is stale.
version_cmp() {
  local a="$1" b="$2" ia ib i n
  local -a A B
  IFS=. read -r -a A <<EOF
$a
EOF
  IFS=. read -r -a B <<EOF
$b
EOF
  n=${#A[@]}; [ ${#B[@]} -gt "$n" ] && n=${#B[@]}
  # RANKABILITY IS CHECKED FIRST, over every component of both versions, not inside the
  # comparison loop. Checked inline, an earlier difference short-circuits and returns a
  # confident verdict before the unrankable component is ever looked at: 0.10.0 vs
  # 0.11.0-rc1 answered "STALE" on the strength of 10 < 11, having silently not understood
  # the version it was ranking against.
  for ((i = 0; i < n; i++)); do
    case "${A[i]:-0}${B[i]:-0}" in *[!0-9]*) return 3 ;; esac
  done
  for ((i = 0; i < n; i++)); do
    ia=${A[i]:-0}; ib=${B[i]:-0}
    [ "$ia" -lt "$ib" ] && return 1
    [ "$ia" -gt "$ib" ] && return 2
  done
  return 0
}

stamp_from_checkout() {
  local dir="$1" sha urls
  STAMP=; STAMP_CONFLICTED=0; CHECKOUT_WHY=
  if [ ! -d "$dir" ]; then CHECKOUT_WHY="no such directory: $dir"; return 1; fi
  if ! git -C "$dir" rev-parse --git-dir >/dev/null 2>&1; then
    CHECKOUT_WHY="$dir is not a git checkout, so it carries no HEAD to read"
    return 1
  fi
  urls=$(git -C "$dir" remote -v 2>/dev/null)
  if [ -z "$urls" ]; then
    CHECKOUT_WHY="$dir has no remotes, so it cannot prove it is a copy of $REPO_SLUG"
    return 1
  fi
  case "$urls" in
    *"$REPO_SLUG"*) : ;;
    *) CHECKOUT_WHY="no remote in $dir names $REPO_SLUG — refusing to judge a checkout of some other repository"
       return 1 ;;
  esac
  # An unborn HEAD (freshly `git init`ed, nothing committed) has no sha. Ask for a commit
  # explicitly so that case fails here rather than yielding the literal string "HEAD".
  sha=$(git -C "$dir" rev-parse --verify --quiet HEAD^{commit} 2>/dev/null) || sha=
  case "$sha" in
    [0-9a-f]*) STAMP="$sha"; return 0 ;;
  esac
  CHECKOUT_WHY="$dir has no commit at HEAD"
  return 1
}

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
# that cannot fire manufactures confidence. No network, in any case.
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

  # --- --from-git: an INSTALLED copy carries its version in HEAD ----------------
  # Five cases. The two that matter most are the NEGATIVE CONTROLS at the end: a checkout
  # of the wrong repository, and a checkout that is not a repository at all. Both must be
  # 2. If either ever returns 1, this mode has become a confident-verdict generator
  # pointed at whatever directory it was handed.
  mkdir -p "$tmp/inst" 2>/dev/null
  ( cd "$tmp/inst" && git init -q . && git config user.email s@t && git config user.name s \
    && git remote add origin "https://github.com/fam/plug.git" \
    && echo one > a && git add a && git commit -qm one \
    && echo two > a && git commit -qam two ) >/dev/null 2>&1
  inst_head=$(git -C "$tmp/inst" rev-parse HEAD 2>/dev/null)
  inst_prev=$(git -C "$tmp/inst" rev-parse HEAD~1 2>/dev/null)

  fg() { # name expected_rc dir upstream
    local name="$1" want="$2" dir="$3" up="$4" got
    out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-fg" \
          bash "$SELF" --slug fam/plug --from-git "$dir" --upstream "$up" --verbose 2>&1); got=$?
    if [ "$got" -eq "$want" ]; then
      printf '  %sPASS%s  %-34s (rc=%s)\n' "$GRN" "$RST" "$name" "$got"
    else
      printf '  %sFAIL%s  %-34s (rc=%s, want %s)\n%s\n' \
             "$RED" "$RST" "$name" "$got" "$want" "$out"
      fails=$((fails+1))
    fi
  }

  fg "install at HEAD is SILENT"    0 "$tmp/inst" "$inst_head"
  fg "install behind HEAD FIRES"    1 "$tmp/inst" "0123456789abcdef0123456789abcdef01234567"

  # A stale INSTALL must be told to update the install, and told the RIGHT WAY for how it
  # got here. "Re-copy the files and bump the stamp on every vendored file" has no referent
  # for either kind, and an alert nobody can act on is an alert that gets tuned out. The two
  # kinds differ: a checkout is pulled, a plugin install has no checkout to pull and is
  # replaced wholesale by the installer. Asserted per mode so neither can inherit the
  # other's instruction unnoticed. (The --plugin half is in the registry block below.)
  fg_says=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-fg" \
    bash "$SELF" --slug fam/plug --from-git "$tmp/inst" \
    --upstream 0123456789abcdef0123456789abcdef01234567 2>&1 \
    | grep -ci 'pull the checkout')
  fg_notplug=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-fg" \
    bash "$SELF" --slug fam/plug --from-git "$tmp/inst" \
    --upstream 0123456789abcdef0123456789abcdef01234567 2>&1 | grep -ci 'plugin update')
  if [ "${fg_says:-0}" -ge 1 ] && [ "${fg_notplug:-0}" -eq 0 ]; then
    printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "stale checkout says: pull it"
  else
    printf '  %sFAIL%s  %-34s (pull=%s want >=1; plugin=%s want 0)\n' \
           "$RED" "$RST" "stale checkout says: pull it" "${fg_says:-0}" "${fg_notplug:-0}"
    fails=$((fails+1))
  fi

  # NEGATIVE CONTROL 1 — the wrong repository. The checkout is real and its HEAD is a
  # real sha, so every comparison downstream runs to completion; only the identity check
  # stands between that and a confident STALE about a repo this gate never looked at.
  # (fg() always passes a slug that matches, so this case is spelled out rather than
  # routed through it: the whole point is a slug the checkout's remotes do NOT name.)
  out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-fg" \
        bash "$SELF" --slug someone/else --from-git "$tmp/inst" --upstream "$inst_prev" 2>&1); wrong_rc=$?
  if [ "$wrong_rc" -eq 2 ]; then
    printf '  %sPASS%s  %-34s (rc=2)\n' "$GRN" "$RST" "wrong-repo checkout is undetermined"
  else
    printf '  %sFAIL%s  %-34s (rc=%s, want 2)\n' \
           "$RED" "$RST" "wrong-repo checkout is undetermined" "$wrong_rc"; fails=$((fails+1))
  fi

  # NEGATIVE CONTROL 2 — not a checkout at all, and a checkout with nothing committed.
  mkdir -p "$tmp/notgit" 2>/dev/null; echo x > "$tmp/notgit/a"
  fg "a non-git dir is undetermined" 2 "$tmp/notgit" "$inst_head"
  mkdir -p "$tmp/unborn" 2>/dev/null
  ( cd "$tmp/unborn" && git init -q . && git remote add origin https://github.com/fam/plug.git ) >/dev/null 2>&1
  fg "an unborn HEAD is undetermined" 2 "$tmp/unborn" "$inst_head"

  # --- --plugin: judged on the VERSION, because that is what the updater acts on ---
  # An installed plugin is a plain copy with a registry entry (verified 2026-08-26 by
  # installing this one and looking), so the fixture is a fake CLAUDE_CONFIG_DIR.
  #
  # The comparison under test is installed version vs upstream's advertised version, NOT
  # the commit: `claude plugin update` keys on the version string, so a sha-based verdict
  # sends the user to a command that reports success and changes nothing.
  mkdir -p "$tmp/cfg/plugins" "$tmp/pluginst" 2>/dev/null
  echo body > "$tmp/pluginst/a"
  reg="$tmp/cfg/plugins/installed_plugins.json"
  mkt="$tmp/cfg/plugins/known_marketplaces.json"
  writereg() { # version [sha]
    printf '{"version":2,"plugins":{"murderboard@m":[{"scope":"user","installPath":"%s","version":"%s"%s}]}}\n' \
           "$tmp/pluginst" "$1" "${2:+,\"gitCommitSha\":\"$2\"}" > "$reg"
  }
  writereg 0.2.0 "$inst_head"
  printf '{"m":{"source":{"source":"github","repo":"fam/plug"}}}\n' > "$mkt"

  pl() { # name expected_rc dir upstream_version
    local name="$1" want="$2" dir="$3" upv="$4" got
    out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-pl" \
          CLAUDE_CONFIG_DIR="$tmp/cfg" MURDERBOARD_PLUGIN_VERSION="$upv" \
          bash "$SELF" --slug fam/plug --plugin "$dir" --verbose 2>&1); got=$?
    if [ "$got" -eq "$want" ]; then
      printf '  %sPASS%s  %-34s (rc=%s)\n' "$GRN" "$RST" "$name" "$got"
    else
      printf '  %sFAIL%s  %-34s (rc=%s, want %s)\n%s\n' \
             "$RED" "$RST" "$name" "$got" "$want" "$out"
      fails=$((fails+1))
    fi
  }

  if have python3 || have python; then
    pl "same version is SILENT"         0 "$tmp/pluginst" "0.2.0"
    pl "an older install FIRES"         1 "$tmp/pluginst" "0.3.0"
    # A developer running a build newer than upstream is not stale. Accusing them costs a
    # pointless reinstall and teaches them the gate cries wolf.
    pl "an AHEAD install is silent"     0 "$tmp/pluginst" "0.1.0"
    # NUMERIC, not lexical. "0.10.0" > "0.9.0" as versions and < as strings; a string
    # compare here tells a current install it is stale, every time, forever.
    writereg 0.10.0 "$inst_head"
    pl "0.10.0 outranks 0.9.0"          0 "$tmp/pluginst" "0.9.0"
    pl "0.10.0 is behind 0.11.0"        1 "$tmp/pluginst" "0.11.0"
    # Unrankable is undetermined, never "current".
    pl "a prerelease tag is 2"          2 "$tmp/pluginst" "0.11.0-rc1"
    writereg 0.2.0 "$inst_head"
    # A directory not in the registry must not be guessed at.
    pl "unregistered dir is 2"          2 "$tmp/notgit"   "0.2.0"

    # A stale PLUGIN must name the installer, and must NOT tell the user to pull a
    # checkout that does not exist. (The --from-git half is asserted above.)
    pl_says=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-pl" \
      CLAUDE_CONFIG_DIR="$tmp/cfg" MURDERBOARD_PLUGIN_VERSION=9.9.9 \
      bash "$SELF" --slug fam/plug --plugin "$tmp/pluginst" 2>&1 | grep -ci 'plugin update')
    pl_nopull=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-pl" \
      CLAUDE_CONFIG_DIR="$tmp/cfg" MURDERBOARD_PLUGIN_VERSION=9.9.9 \
      bash "$SELF" --slug fam/plug --plugin "$tmp/pluginst" 2>&1 | grep -ci 'pull the checkout')
    if [ "${pl_says:-0}" -ge 1 ] && [ "${pl_nopull:-0}" -eq 0 ]; then
      printf '  %sPASS%s  %-34s\n' "$GRN" "$RST" "stale plugin says: update it"
    else
      printf '  %sFAIL%s  %-34s (update=%s want >=1; pull=%s want 0)\n' \
             "$RED" "$RST" "stale plugin says: update it" "${pl_says:-0}" "${pl_nopull:-0}"
      fails=$((fails+1))
    fi

    # NEGATIVE CONTROL — the entry exists but its marketplace is a DIFFERENT github repo.
    # Every comparison downstream would run to completion; only the identity check stops a
    # confident verdict about a repository never looked at.
    printf '{"m":{"source":{"source":"github","repo":"someone/else"}}}\n' > "$mkt"
    out=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/nocache-pl2" \
          CLAUDE_CONFIG_DIR="$tmp/cfg" MURDERBOARD_PLUGIN_VERSION=0.2.0 \
          bash "$SELF" --slug fam/plug --plugin "$tmp/pluginst" 2>&1); pwrong=$?
    if [ "$pwrong" -eq 2 ]; then
      printf '  %sPASS%s  %-34s (rc=2)\n' "$GRN" "$RST" "wrong-marketplace plugin is 2"
    else
      printf '  %sFAIL%s  %-34s (rc=%s, want 2)\n' \
             "$RED" "$RST" "wrong-marketplace plugin is 2" "$pwrong"; fails=$((fails+1))
    fi

    # An entry with no version cannot be ranked -> undetermined, never "current".
    printf '{"m":{"source":{"source":"github","repo":"fam/plug"}}}\n' > "$mkt"
    printf '{"version":2,"plugins":{"murderboard@m":[{"scope":"user","installPath":"%s"}]}}\n' \
           "$tmp/pluginst" > "$reg"
    pl "a versionless entry is 2"       2 "$tmp/pluginst" "0.2.0"

    # --hook must NEVER block on the network, even with a cold cache: silent, rc 0.
    writereg 0.2.0 "$inst_head"
    hookout=$(MURDERBOARD_NO_NET=1 MURDERBOARD_REPO= MURDERBOARD_CACHE="$tmp/coldplug" \
              CLAUDE_CONFIG_DIR="$tmp/cfg" \
              bash "$SELF" --hook --plugin "$tmp/pluginst" --slug fam/plug 2>&1); hrc=$?
    if [ "$hrc" -eq 0 ] && [ -z "$hookout" ]; then
      printf '  %sPASS%s  %-34s (rc=0, silent)\n' "$GRN" "$RST" "--hook cold plugin cache silent"
    else
      printf '  %sFAIL%s  %-34s (rc=%s, out=%s)\n' \
             "$RED" "$RST" "--hook cold plugin cache silent" "$hrc" "$hookout"; fails=$((fails+1))
    fi
  else
    printf '  %sSKIP%s  %-34s (no python on PATH)\n' "$YEL" "$RST" "--plugin registry cases"
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
    --from-git)    FROM_GIT="${2:-}"; shift ;;
    --plugin)      PLUGIN_DIR="${2:-}"; shift ;;
    --plugin-name) PLUGIN_NAME="${2:-}"; shift ;;
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

# --- --plugin: judge an install by the number its updater acts on ----------------
#
# MEASURED 2026-08-26, and it overturned the obvious design. This first compared the
# install's recorded gitCommitSha against upstream HEAD — precise, tamper-proof, and
# USELESS, because `claude plugin update` keys on the VERSION STRING: with plugin.json
# unchanged it answers "already at the latest version (0.1.0)" and does nothing, no matter
# how far the commit has moved. A gate that reports STALE and then hands over a remedy that
# exits successfully without updating anything is worse than no gate — it burns the user's
# trust once and is ignored forever after.
#
# So the comparison is the one the installer will actually make: installed version vs the
# version upstream advertises in .claude-plugin/marketplace.json. The sha is still printed,
# because it says WHICH commit is on disk, but it is not the verdict.
#
# THE COST, stated plainly: this makes freshness depend on a hand-maintained number, which
# is the weakness the sha did not have. A release that forgets to bump the version is
# invisible here. That is not a reason to compare shas instead — it is the same discipline
# the installer already requires of the maintainer, since without a bump nobody's `/plugin
# update` does anything either. So the bump is gated rather than remembered: the
# "plugin version was bumped if the plugin changed" step in .github/workflows/ci.yml fails
# a PR that edits the plugin payload without moving the number.
if [ -n "$PLUGIN_DIR" ]; then
  if ! stamp_from_install "$PLUGIN_DIR"; then
    echo "${YEL}$LABEL: freshness UNKNOWN — $CHECKOUT_WHY.${RST}"
    exit 2
  fi

  # CACHED, and for the same reason the sha path is: this runs in a SessionStart hook. The
  # cache lives beside the plugin registry rather than in a git common dir — a plugin user
  # need not be inside a repository at all, and the sha path's cache location assumes one.
  now
  pv_key=$(printf '%s' "$REPO_SLUG/$PLUGIN_NAME" | tr -c 'A-Za-z0-9' '-')
  pv_cache="${MURDERBOARD_CACHE:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/plugins/.murderboard-plugver.$pv_key}"
  up_ver=; pv_expires=0
  if [ "$REFRESH" -eq 0 ] && [ -z "${MURDERBOARD_PLUGIN_VERSION:-}" ]; then
    read -r up_ver pv_expires 2>/dev/null < "$pv_cache" || { up_ver=; pv_expires=0; }
    [ "${pv_expires:-0}" -gt "$NOW" ] 2>/dev/null || up_ver=
  fi
  if [ -z "$up_ver" ]; then
    if [ "$HOOK" -eq 1 ]; then
      # Never block session startup on a lookup. Refresh detached and say nothing now; the
      # next session judges on a warm cache. One silent session beats a slow one.
      spawn_bg bash "$SELF" --refresh --plugin "$PLUGIN_DIR" --slug "$REPO_SLUG" \
                            --plugin-name "$PLUGIN_NAME" --label "$LABEL"
      exit 0
    fi
    up_ver=$(upstream_plugin_version) || up_ver=
    [ -n "$up_ver" ] && [ -z "${MURDERBOARD_PLUGIN_VERSION:-}" ] && \
      printf '%s %s\n' "$up_ver" "$((NOW + TTL))" > "$pv_cache" 2>/dev/null
  fi
  if [ -z "$up_ver" ]; then
    echo "${YEL}$LABEL: cannot reach $REPO_SLUG to ask what version it publishes — freshness UNKNOWN.${RST}"
    echo "   installed: $INSTALLED_VERSION${INSTALLED_SHA:+ (commit ${INSTALLED_SHA%${INSTALLED_SHA#???????}})}"
    exit 2
  fi
  version_cmp "$INSTALLED_VERSION" "$up_ver"; vc=$?
  case $vc in
    0|2)  # same, or the install is AHEAD (a developer running their own build)
      [ "$VERBOSE" -eq 1 ] && {
        echo "${GRN}$LABEL: current${RST} (installed $INSTALLED_VERSION, upstream $up_ver)"
        [ -n "$VERDICT_NOTE" ] && echo "   note: $VERDICT_NOTE"; }
      exit 0 ;;
    3)
      echo "${YEL}$LABEL: freshness UNKNOWN — cannot rank version '$INSTALLED_VERSION' against '$up_ver'.${RST}"
      exit 2 ;;
  esac
  echo "${RED}--- !! $(printf '%s' "$LABEL" | tr '[:lower:]' '[:upper:]') IS STALE — update before relying on it ---${RST}"
  echo "   installed: $INSTALLED_VERSION   upstream: $up_ver"
  echo "   install:   $PLUGIN_DIR${INSTALLED_SHA:+   (commit ${INSTALLED_SHA%${INSTALLED_SHA#???????}})}"
  [ -n "$VERDICT_NOTE" ] && echo "   note:      $VERDICT_NOTE"
  [ "$LABEL" = murderboard ] && \
  echo "   A review run against a stale process silently omits rules already paid for."
  echo "   This copy is an INSTALL, not a vendored set: update it in place, do not re-vendor."
  echo "   Run  /plugin update $LABEL  (or: claude plugin update $LABEL). Do not hand-edit"
  echo "   files under that path; the next update replaces the whole tree."
  exit 1
fi

target=; stamp=; TRUST_FILE=
if [ -n "$FROM_GIT" ]; then
  INSTALLED=1
  # An INSTALLED copy. Its version is HEAD, so none of the stamp-shaped failures below
  # (conflict markers in a header, a missing stamp, disagreeing stamps across the set) can
  # occur here — they are properties of a version somebody wrote down by hand. Skipped,
  # not reported as absent.
  if ! stamp_from_checkout "$FROM_GIT"; then
    echo "${YEL}$LABEL: freshness UNKNOWN — $CHECKOUT_WHY.${RST}"
    exit 2
  fi
  target="$FROM_GIT"; stamp=$STAMP
  # The cache trust test asks whether the cached HEAD was resolved AFTER this copy last
  # changed. For a checkout, what moves on update is the HEAD file, not the directory's
  # mtime — an update that lands the same tree would not touch the directory at all.
  gd=$(git -C "$FROM_GIT" rev-parse --git-dir 2>/dev/null)
  case "$gd" in
    /*) TRUST_FILE="$gd/HEAD" ;;
    "") TRUST_FILE="$FROM_GIT" ;;
    *)  TRUST_FILE="$FROM_GIT/$gd/HEAD" ;;
  esac
  [ -r "$TRUST_FILE" ] || TRUST_FILE="$FROM_GIT"
elif [ -n "$ONE_FILE" ]; then
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
TRUST_FILE="${TRUST_FILE:-$target}"
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
    [ "${resolved:-0}" -ge "$(mtime "$TRUST_FILE")" ] 2>/dev/null || trusted=0
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

# THE REMEDY DEPENDS ON HOW THE COPY GOT HERE, and telling a plugin user to "re-copy the
# files and bump the stamp on every vendored file" sends them to do something that has no
# meaning for their install — at which point the gate has correctly detected staleness and
# then handed over an instruction that cannot be followed. An unactionable alert is a
# tuned-out alert.
echo "${RED}--- !! $(printf '%s' "$LABEL" | tr '[:lower:]' '[:upper:]') IS STALE — update before relying on it ---${RST}"
if [ "$INSTALLED" -eq 1 ]; then
  echo "   installed: $stamp   upstream: ${head_sha%${head_sha#???????}}   (via $source)"
  echo "   install:   $target"
  [ -n "$VERDICT_NOTE" ] && echo "   note:      $VERDICT_NOTE"
else
  echo "   vendored: $stamp   upstream: ${head_sha%${head_sha#???????}}   (via $source)"
  echo "   file:     ${target#$root/}"
fi
[ "$LABEL" = murderboard ] && \
echo "   A review run against a stale process silently omits rules already paid for."
if [ "$INSTALLED" -eq 1 ]; then
  # Reached only for --from-git; --plugin has its own verdict block and exits before here.
  echo "   This copy is a CHECKOUT, not a vendored set: pull the checkout, do not re-vendor."
  echo "   Do not hand-edit files there; the next pull conflicts."
else
  echo "   Re-copy from $REPO_SLUG and bump the stamp on EVERY vendored file of this"
  echo "   family, then land it on the DEFAULT BRANCH — vendoring onto a leaf branch"
  echo "   leaves every new worktree inheriting the old copy."
fi

# Disagreeing stamps across the vendored set are their own defect. SCOPED to the family
# being checked: when the caller named files explicitly, only those are cross-checked.
# Otherwise a repo vendoring two upstreams reports every file of the OTHER family as
# "wrongly stamped" — noise that reads as findings and buries the real line.
#
# An INSTALLED copy has no stamps to disagree — every file in it is at the checkout's one
# HEAD by construction. Walking the list there would read the CONSUMER's own vendored files
# (a repo may do both) and report them against the plugin's HEAD: two different families,
# compared, with the mismatch printed as a defect in the wrong one.
if [ "$INSTALLED" -eq 0 ]; then
  for f in ${EXPLICIT_FILES:-$STAMPED_FILES}; do
    ff="$f"; [ -r "$ff" ] || ff="$root/$f"
    [ -r "$ff" ] || continue
    [ "$ff" = "$target" ] && continue
    stamp_of "$ff" || continue
    same_commit "$STAMP" "$stamp" || echo "   note: $f is stamped $STAMP, not $stamp"
  done
fi

exit 1
