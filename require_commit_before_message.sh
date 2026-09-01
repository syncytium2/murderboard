#!/usr/bin/env bash
# instrument: concurrency
# require_commit_before_message.sh — a session may tell another session something
# once that something exists in git.
#
# THE GAP THIS CLOSES. Messages between Claude Code sessions are socket traffic.
# Nothing persists them, nothing versions them, and when a session exits its half of
# every conversation is gone. Sessions have repeatedly worked a real finding out in
# conversation and lost it, because a conversation is not a repository.
#
# The rule that covers this — "the repo on origin is the only durable channel;
# anything not pushed does not exist to the next session or the next machine" — was
# prose, and prose does not enforce itself. One estate lost a finding that had taken
# four sessions to establish, and only noticed because someone asked whether the
# messages were committed. This is that rule, mechanized.
#
# WHAT IT DOES. Refuses the send while the working tree is dirty.
#
# Note where the friction lands. A session holding nothing uncommitted passes
# freely, so asking a question costs nothing. It bites only when you are sitting on
# uncommitted work — which is exactly when what you are about to say is most likely
# to be the thing that evaporates.
#
# It gates on *a* commit, not on the message matching one. That is deliberate: a
# check that tried to prove the message and the commit were about the same thing
# would need to read both and would be wrong often enough to be turned off. The
# friction lands where the carelessness is, and that is enough.
#
# USAGE — wire as a PreToolUse hook matched to the message-sending tool:
#
#   "hooks": { "PreToolUse": [ { "matcher": "SendMessage", "hooks": [
#     { "type": "command", "command": "bash .claude/hooks/require-commit-before-message.sh",
#       "timeout": 10 } ] } ] }
#
#   require_commit_before_message.sh --selftest   prove every branch can fire
#
# EXIT CODES  0 = allow   2 = block (stderr is shown to the model)
#
# Outside a git repository it allows: there is nothing to commit. Untracked files
# count as dirty — an uncommitted finding is exactly the case this exists for — but
# anything gitignored is invisible to `git status --porcelain` and so costs nothing.

set -uo pipefail

# --- the gate ----------------------------------------------------------------
gate() {
  local root="${CLAUDE_PROJECT_DIR:-$PWD}" dirty count branch
  cd "$root" 2>/dev/null || return 0
  git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0

  dirty="$(git status --porcelain 2>/dev/null)"
  [ -z "$dirty" ] && return 0

  count="$(printf '%s\n' "$dirty" | grep -c '^')"
  branch="$(git branch --show-current 2>/dev/null || echo 'detached HEAD')"

  {
    echo "BLOCKED: commit before messaging another session."
    echo
    echo "The working tree has ${count} uncommitted change(s) on '${branch}'."
    echo "Messages between sessions are socket traffic — nothing persists them, and"
    echo "when this session exits anything said in one is gone. A finding worth"
    echo "telling another session is worth committing first, or it reaches exactly"
    echo "one process and dies there."
    echo
    echo "Commit — and push, so it survives this machine — then send the message."
    echo "If what you are holding is not worth committing, say so in the message"
    echo "rather than working around this: a claim nobody can look up later is a"
    echo "claim the next session has to re-derive."
    echo
    printf '%s\n' "$dirty" | head -20
    [ "$count" -gt 20 ] && echo "  ... and $((count - 20)) more"
  } >&2
  return 2
}

# --- selftest ----------------------------------------------------------------
# A gate that cannot fire is worse than no gate. Every branch proves itself here.
selftest() {
  local fails=0 rc SELF="${BASH_SOURCE[0]}"
  if [ -t 1 ]; then local RED=$'\033[31m' GRN=$'\033[32m' RST=$'\033[0m'
  else local RED= GRN= RST=; fi
  # NOT local: the EXIT trap runs after this function has returned, so a local
  # would be out of scope by then and `set -u` would abort during cleanup —
  # after the verdict has printed, which is the most confusing place to fail.
  SELFTEST_TMP="$(mktemp -d)" || return 2
  trap 'rm -rf "${SELFTEST_TMP:-}"' EXIT
  local tmp="$SELFTEST_TMP"

  check() { # name expected_rc dir
    CLAUDE_PROJECT_DIR="$3" bash "$SELF" >/dev/null 2>&1; rc=$?
    if [ "$rc" -eq "$2" ]; then
      printf '  %sPASS%s  %-30s (rc=%s)\n' "$GRN" "$RST" "$1" "$rc"
    else
      printf '  %sFAIL%s  %-30s (rc=%s, expected %s)\n' "$RED" "$RST" "$1" "$rc" "$2"
      fails=$((fails+1))
    fi
  }

  mkdir -p "$tmp/plain"
  check "outside a repo: allow" 0 "$tmp/plain"

  git init -q "$tmp/repo" 2>/dev/null
  ( cd "$tmp/repo" && git -c user.email=t@t -c user.name=t commit -q --allow-empty -m seed 2>/dev/null )
  check "clean tree: allow" 0 "$tmp/repo"

  printf 'x\n' > "$tmp/repo/untracked.txt"
  check "untracked file: BLOCK" 2 "$tmp/repo"

  ( cd "$tmp/repo" && git add -A && git -c user.email=t@t -c user.name=t commit -q -m add 2>/dev/null )
  check "after committing: allow" 0 "$tmp/repo"

  printf 'y\n' >> "$tmp/repo/untracked.txt"
  check "modified tracked file: BLOCK" 2 "$tmp/repo"

  ( cd "$tmp/repo" && git checkout -q -- . 2>/dev/null )
  printf 'z\n' > "$tmp/repo/ignored.log"
  printf 'ignored.log\n' > "$tmp/repo/.gitignore"
  ( cd "$tmp/repo" && git add .gitignore && git -c user.email=t@t -c user.name=t commit -q -m ignore 2>/dev/null )
  check "gitignored file: allow" 0 "$tmp/repo"

  echo
  if [ "$fails" -eq 0 ]; then echo "all checks pass"; return 0; fi
  echo "$fails FAILED"; return 1
}

case "${1:-}" in
  --selftest) selftest; exit $? ;;
  -h|--help)  sed -n '2,40p' "$0"; exit 0 ;;
  "")         gate; exit $? ;;
  *)          echo "unknown option: $1" >&2; exit 2 ;;
esac
