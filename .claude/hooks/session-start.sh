#!/usr/bin/env bash
# vendored from interface2 @ 46da2c3 — do NOT edit here; update interface2 tools/session-start.hook.sh and re-copy
# Generic SessionStart briefing — runs at every session start / resume.
# Its stdout is injected into the session's context. NON-blocking: it must never
# fail a session, so every command is guarded and the script always exits 0.
#
# CANONICAL SOURCE: interface2 tools/session-start.hook.sh (vendored elsewhere).
# It is self-configuring (derives the repo name and the sibling worktrees dir), so
# a consumer repo copies it to .claude/hooks/session-start.sh unchanged and wires it
# in .claude/settings.json (see docs/session_protocol.md). A repo may layer its own
# repo-specific checks around this core; keep the core intact so it stays re-copyable.

set +e

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
alarm=""
for b in $(git for-each-ref --format='%(refname:short)' refs/heads 2>/dev/null); do
  n=$(git rev-list --count "$b" --not --remotes 2>/dev/null)
  [ -n "$n" ] && [ "$n" -gt 0 ] 2>/dev/null && \
    alarm="${alarm}   ! ${b}: ${n} commit(s) on NO remote — git push -u origin ${b}\n"
done
while IFS= read -r wt; do
  [ -d "$wt" ] || continue
  m=$(git -C "$wt" status --porcelain --untracked-files=no 2>/dev/null | wc -l | tr -d ' ')
  [ -n "$m" ] && [ "$m" -gt 0 ] 2>/dev/null && \
    alarm="${alarm}   ! $(basename "$wt"): ${m} uncommitted change(s) — commit + push\n"
done < <(git worktree list --porcelain 2>/dev/null | sed -n 's/^worktree //p')
if [ -n "$alarm" ]; then
  echo
  echo "--- !! UNPUSHED / UNCOMMITTED WORK — back it up (feature branches: push freely) ---"
  printf "%b" "$alarm"
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
  if command -v tasklist >/dev/null 2>&1; then
    # Windows (MSYS/Cygwin bash). CSV: name,pid,session,#,mem ("12,345 K").
    tasklist /FI "IMAGENAME eq MATLAB.exe" /FO CSV /NH 2>/dev/null \
      | tr -d '"' | awk -F, 'NF>=5 { gsub(/[^0-9]/,"",$5); print $2, $5*1024 }'
  elif command -v ps >/dev/null 2>&1; then
    ps -eo pid=,rss=,comm= 2>/dev/null \
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
echo "--- worktrees ---";      git worktree list 2>/dev/null
echo "--- recent commits ---"; git log --oneline -6 --all 2>/dev/null

echo "--- session board: ${board} ---"
if [ -f "$board" ]; then cat "$board"; else
  echo "(no board yet — create it and claim your work when you touch shared EXTERNAL outputs)"
fi

echo
echo "RULES: your own worktree; never commit on main; push feature branches promptly;"
echo "claim shared external outputs on the board before writing. Full policy: docs/session_protocol.md"
echo "==================================================================="
exit 0
