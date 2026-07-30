#!/usr/bin/env bash
# vendored from interface2 @ 7065f5e — do NOT edit here; update interface2 tools/session-start.hook.sh and re-copy
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
