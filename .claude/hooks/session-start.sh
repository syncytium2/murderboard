#!/usr/bin/env bash
# CANONICAL SOURCE: syncytium2/murderboard .claude/hooks/session-start.sh — edit HERE.
# Generic SessionStart briefing — runs at every session start / resume.
# Its stdout is injected into the session's context.
#
# It is self-configuring (derives the repo name and the sibling worktrees dir), so
# a consumer repo copies it to .claude/hooks/session-start.sh unchanged and wires it
# in .claude/settings.json (see docs/session_protocol.md). A repo may layer its own
# repo-specific checks around this core; keep the core intact so it stays re-copyable.
# Stamp your copy `vendored from syncytium2/murderboard @ <short-sha>` on line 2.
#
# ORIGIN: written in a private repo (interface2) and vendored here at 6e8aff6.
# Murderboard adopted it as canonical on 2026-08-21, when this repo went public --
# a provenance stamp aimed at a repo the reader cannot open is a dead end. Precisely:
# murderboard_freshness.sh --clone resolves a private upstream from a local checkout,
# so on the author's machine the gate answers 0/1 normally. Everywhere else there is
# no checkout and no route, so it answers 2 (unknown), which in --hook mode is SILENT.
# A private upstream does not disable the gate -- it makes the gate answer for one
# person and say nothing to everyone else.
#
# ---------------------------------------------------------------------------------
# HARD CONSTRAINT — this hook BLOCKS session initialization until it exits, and the
# SDK aborts the whole session at 60s ("Subprocess initialization did not complete
# within 60000ms"; the message blames auth/network, which is a red herring). Exiting 0
# is therefore NOT sufficient: "never fails" is not "never blocks". A hook that always
# succeeds but returns too late takes the session down anyway.
#
# This cost ~half a day on 2026-07-30, at 32 worktrees. (The full postmortem lives in the
# private repo this hook came from; the two rules it produced are stated here in full.)
#   * Bound the WHOLE script with a deadline, not each call. Per-call caps MULTIPLY
#     (32 worktrees x 3s = 96s, which is the bug again).
#   * Degrade LOUDLY. A section dropped for budget must say so, or a silent all-clear
#     masquerades as a real one.
# Wire a `"timeout"` into the settings.json hook entry as a second line of defence,
# set ABOVE this budget and below the SDK's 60s.
#
# Tune with env vars if a consumer repo needs to: IF2_HOOK_BUDGET (seconds).
# ---------------------------------------------------------------------------------

set +e

BUDGET="${IF2_HOOK_BUDGET:-20}"   # total wall-clock seconds for git/scan work
started=$SECONDS

# timeout(1) ships with Git for Windows, but Windows also has an incompatible
# System32\timeout.exe that may shadow it. Probe, and degrade to running bare.
if /usr/bin/timeout --version >/dev/null 2>&1; then
  TO() { /usr/bin/timeout "$@"; }
else
  TO() { shift; "$@"; }
fi
left()  { local r=$(( BUDGET - (SECONDS - started) )); [ "$r" -lt 1 ] && r=1; echo "$r"; }
spent() { [ $(( SECONDS - started )) -ge "$BUDGET" ]; }
trunc=""   # accumulated "this section was dropped" notices — always printed

root=$(git rev-parse --show-toplevel 2>/dev/null)
[ -z "$root" ] && { echo "[session-start] not a git repo — skipping briefing."; exit 0; }

# Derive the repo name + worktrees dir from the PRIMARY checkout, not the current
# working tree — in a linked worktree, basename(toplevel) is the worktree slug, not the
# repo. The common-dir points at the primary's .git for every worktree, so its parent is
# the primary checkout and its basename is the repo name.
cm=$(git rev-parse --git-common-dir 2>/dev/null)
cma=$( [ -n "$cm" ] && (CDPATH= cd -- "$cm" 2>/dev/null && pwd -P) )
primary=$( [ -n "$cma" ] && dirname "$cma" )
base="${primary:-$root}"
repo=$(basename "$base")
wt_dir="$(dirname "$base")/${repo}-worktrees"
board="${wt_dir}/SESSIONS.md"

# current worktree's own git-dir, to warn if you're sitting in the primary checkout.
gd=$(git rev-parse --git-dir 2>/dev/null)
gda=$( [ -n "$gd" ] && (CDPATH= cd -- "$gd" 2>/dev/null && pwd -P) )

# --- Keep the TRACKED .claude/settings.json from accreting interactive approvals. ---
# Claude Code appends "always allow" rules to this tracked file (they should land in the
# gitignored settings.local.json but don't), dirtying it and diverging it across machines.
# skip-worktree tells THIS clone's git to ignore working-tree edits to it. Idempotent,
# per-clone, fail-safe. To change the shared baseline:
#   git update-index --no-skip-worktree .claude/settings.json  (then edit, commit, push)
if git -C "$root" ls-files --error-unmatch .claude/settings.json >/dev/null 2>&1; then
  git -C "$root" update-index --skip-worktree .claude/settings.json 2>/dev/null || true
fi

echo "===================== ${repo} — SESSION START ====================="
echo "ASSUME other Claude Code / batch sessions may be running. Coordinate; do not stomp."
echo "You are a stateless instance — you know what other sessions did ONLY from git + the board."
echo
echo "branch: $(git symbolic-ref --short -q HEAD 2>/dev/null || echo '(detached)')    cwd: $(pwd)"

if [ -n "$gda" ] && [ "$gda" = "$cma" ]; then
  echo "!! You are in the PRIMARY checkout. Prefer your OWN worktree — don't share a HEAD:"
  echo "     git worktree add -b <task-slug> ${wt_dir}/<task-slug> main"
fi

# --- unpushed / uncommitted alarm: surface single-copy work so it is never lost.
# A branch is flagged only if it has commits on NO remote at all (safe if those same
# commits live on any other remote branch). Uncommitted = tracked changes only.
#
# `rev-list --count <b> --not --remotes` walks EVERY remote ref on each call, so running
# it per branch is the single most expensive thing here. Pre-filter in one for-each-ref
# pass — but note the trap: a configured upstream does NOT mean the branch is on a
# remote. Once the remote-tracking ref is deleted (any `fetch --prune` after the remote
# branch goes away, e.g. when an MR merges), %(upstream) STILL prints the configured
# name while %(upstream:track) reports "[gone]". Filtering on %(upstream) alone would
# silently skip exactly the branches most likely to hold the only copy of the work —
# in the alarm whose entire job is to prevent that. Skip only a LIVE upstream.
alarm=""
while IFS='|' read -r b up track; do
  [ -n "$up" ] && [ "$track" != "[gone]" ] && continue
  spent && { trunc="${trunc}   (branch scan truncated — budget)\n"; break; }
  n=$(TO 3 git rev-list --count "$b" --not --remotes 2>/dev/null)
  [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null && \
    alarm="${alarm}   ! ${b}: ${n} commit(s) on NO remote — git push -u origin ${b}\n"
done < <(git for-each-ref --format='%(refname:short)|%(upstream)|%(upstream:track)' refs/heads 2>/dev/null)

# One `git status` per worktree. On a slow/scanned filesystem a cold one can take
# seconds, so bound by the remaining DEADLINE rather than capping each call.
while IFS= read -r wt; do
  [ -d "$wt" ] || continue
  spent && { trunc="${trunc}   (worktree scan truncated — budget; run 'git worktree list' manually)\n"; break; }
  m=$(TO "$(left)" git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$m" ] && [ "$m" -gt 0 ] 2>/dev/null && \
    alarm="${alarm}   ! $(basename "$wt"): ${m} uncommitted change(s) — commit + push\n"
done < <(TO 5 git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
if [ -n "$alarm" ] || [ -n "$trunc" ]; then
  echo
  echo "--- !! UNPUSHED / UNCOMMITTED WORK — back it up (feature branches: push freely) ---"
  printf "%b" "$alarm$trunc"
fi

# --- did THIS branch move under you? ---------------------------------------
# Git enforces one CHECKOUT per branch, not one SESSION per worktree: two agents on
# one machine can land in the same worktree, so a feature-branch push is NOT isolated
# the way it is commonly assumed to be. Where the commit-msg convention stamps a
# machine tag ("064: ", "065: "), commits on this branch bearing someone else's tag
# mean another session has been here. Silent no-op where that convention is not used,
# so it is safe in the vendored core.
# Honest limit: this fires at session START; a write that lands mid-session stays
# invisible until the next one.
me=$(hostname 2>/dev/null | sed -n 's/^[Ww][Ss][Mm][Ii][Pp]0*\([0-9][0-9]*\)$/\1/p')
[ -n "$me" ] && me=$(printf '%03d' "$me" 2>/dev/null)
defref=$(git symbolic-ref --short -q refs/remotes/origin/HEAD 2>/dev/null)
[ -z "$defref" ] && defref="origin/main"
foreign=$(git log --format='%s' "${defref}..HEAD" 2>/dev/null \
          | sed -n 's/^\([0-9][0-9][0-9]\):.*/\1/p' | sort -u | grep -vx "${me:-__nomachine__}")
if [ -n "$foreign" ]; then
  echo
  echo "--- !! THIS BRANCH CARRIES ANOTHER MACHINE'S COMMITS ---"
  echo "   machine tag(s): $(printf '%s' "$foreign" | tr '\n' ' ')"
  echo "   Another session has committed to the branch you are on. Read those commits"
  echo "   before building on them; do not assume this worktree is yours alone."
fi

# --- live MATLAB: the resource two sessions on one box actually contend for ---
# Reported ALWAYS, never thresholded on RAM: a long batch can run for hours while
# free RAM never looks tight, so a RAM threshold goes silent exactly when it matters.
# The signal that changes behaviour is "a client WITH pool workers". That is also a
# CORRECTNESS hazard, not merely contention — an already-open pool runs cached
# bytecode, so editing a function that executes inside parfor silently yields wrong
# numbers.
matlab_procs() {
  # Both process listers are capped: tasklist in particular can hang for seconds on a
  # busy or scanned Windows box, and this runs on the blocking path.
  if command -v tasklist >/dev/null 2>&1; then
    # Windows (MSYS/Cygwin bash). CSV: name,pid,session,#,mem ("12,345 K").
    TO 5 tasklist /FI "IMAGENAME eq MATLAB.exe" /FO CSV /NH 2>/dev/null \
      | tr -d '"' | awk -F, 'NF>=5 { gsub(/[^0-9]/,"",$5); print $2, $5*1024 }'
  elif command -v ps >/dev/null 2>&1; then
    TO 5 ps -eo pid=,rss=,comm= 2>/dev/null \
      | awk 'tolower($3) ~ /matlab/ { print $1, $2*1024 }'
  fi
}
mstat=$(matlab_procs | awk '
  { n++; tot += $2; if ($2 > max) { max = $2; pid = $1 } }
  END { if (n) printf "%d %.1f %s %.1f", n, tot/1073741824, pid, max/1073741824 }')
echo
if [ -n "$mstat" ]; then
  # shellcheck disable=SC2086
  set -- $mstat
  echo "--- MATLAB: $1 process(es), $2 GB total; largest PID $3 at $4 GB"
  if [ "$1" -gt 2 ] 2>/dev/null; then
    echo "   -> client + pool workers: another session is mid-batch."
    echo "   -> Do NOT open a parpool. If you must, delete(gcp('nocreate')) first — an"
    echo "      inherited pool runs STALE BYTECODE and silently returns wrong numbers."
    echo "   -> Budget RAM against the above before loading anything large."
  fi
else
  echo "--- MATLAB: none running"
fi

echo
echo "--- worktrees ---";      TO 5 git worktree list 2>/dev/null || echo "(timed out)"
echo "--- recent commits ---"; TO 5 git log --oneline -6 --all 2>/dev/null || echo "(timed out)"

echo "--- session board: ${board} ---"
if [ -f "$board" ]; then cat "$board"; else
  echo "(no board yet — create it and claim your work when you touch shared EXTERNAL outputs)"
fi

echo
echo "RULES: your own worktree; never commit on main; push feature branches promptly;"
echo "claim shared external outputs on the board before writing. Full policy: docs/session_protocol.md"
# Standing canary. BUDGET bounds the scan sections above, NOT this tail, so true wall
# time runs ~10s beyond it. If this number creeps toward the settings.json hook timeout,
# fix it BEFORE it crosses the SDK's 60s and takes the session down.
echo "briefing took $(( SECONDS - started ))s"
echo "==================================================================="
exit 0
