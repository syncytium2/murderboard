#!/usr/bin/env bash
# no_heredoc_hook_test.sh — exercise .claude/hooks/no-heredoc-source.sh in BOTH
# of its modes, and refuse to pass unless it really entered both.
#
# WHY THIS FILE EXISTS AND WHY IT IS NOT IN THE HOOK. The hook is a vendored
# artifact (canonical source: interface2 tools/no-heredoc-source.hook.sh) and
# nobody edits a vendored copy in place, so its --selftest cannot live inside
# it. This file is murderboard's own, and it is what CI runs.
#
# WHAT IT IS FOR. On 2026-08-18 the hook was found failing OPEN wherever
# `python` did not exist -- it exited 0 and allowed every call. The fix added a
# degraded raw-payload path. The verification recipe shipped WITH that fix
# built its python-free PATH by dropping entries matching "python":
#
#   NOPY=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vi python | paste -sd: -)
#
# On a machine whose interpreter lives in /opt/homebrew/bin or /usr/bin, that
# leaves python3 resolvable. The recipe then ran the PARSED path, printed the
# exit code it wanted, and reported success without ever entering the code it
# was written to test. A check that cannot fail is not a check, and the danger
# is that it PASSES -- so this file builds its PATH from an explicit allow-list
# and ASSERTS the interpreter is gone before it trusts a single degraded result.

set -u

HERE=$(cd "$(dirname "$0")" && pwd)
HOOK="${1:-$HERE/../.claude/hooks/no-heredoc-source.sh}"
[ -r "$HOOK" ] || { echo "no_heredoc_hook_test: cannot read hook: $HOOK" >&2; exit 2; }

RED=''; GRN=''; RST=''
if [ -t 1 ]; then RED=$'\033[31m'; GRN=$'\033[32m'; RST=$'\033[0m'; fi

pass=0; fail=0
MB_TMP=$(mktemp -d) || { echo "mktemp failed" >&2; exit 2; }
trap 'rm -rf "$MB_TMP"' EXIT

# Run the hook with a given PATH and payload; echo its exit code.
run_hook() {
  printf '%s' "$2" | PATH="$1" "$BASH_BIN" "$HOOK" >/dev/null 2>&1
  echo $?
}

t() { # t <want> <desc> <path> <payload>
  local want="$1" desc="$2" p="$3" payload="$4" got
  got=$(run_hook "$p" "$payload")
  if [ "$got" = "$want" ]; then
    pass=$((pass+1)); printf '  ok   %s\n' "$desc"
  else
    fail=$((fail+1)); printf '  %sFAIL%s %s (exit=%s, want %s)\n' "$RED" "$RST" "$desc" "$got" "$want"
  fi
}

BASH_BIN=$(command -v bash) || { echo "no bash?" >&2; exit 2; }

# --- payloads ---------------------------------------------------------------
# Real PreToolUse(Bash) shapes. The \n are LITERAL backslash-n, exactly as they
# arrive inside a JSON string -- do not "fix" them into real newlines.
P_DOT_M='{"tool_input":{"command":"cat > x.m <<EOF\ndisp(1)\nEOF"}}'
P_DOT_PY='{"tool_input":{"command":"cat > run.py <<EOF\nprint(1)\nEOF"}}'
P_INLINE_WRITE='{"tool_input":{"command":"python - <<EOF\np.write_text(\"a\")\nEOF"}}'
P_COMMIT_MSG='{"tool_input":{"command":"git commit -F - <<EOF\nmsg\nEOF"}}'
P_NO_HEREDOC='{"tool_input":{"command":"ls -la > out.m"}}'
P_TXT_ONLY='{"tool_input":{"command":"cat <<EOF > README.txt\nhi\nEOF"}}'
P_MALFORMED='not json at all'
P_EMPTY_CMD='{"tool_input":{"command":""}}'

echo "no_heredoc_hook_test: $HOOK"
echo

# --- A. PARSED mode: an interpreter is on PATH ------------------------------
echo "A. parsed mode (interpreter present)"
PARSED_PATH="$PATH"
have_py=""
for c in python3 python py; do
  if PATH="$PARSED_PATH" command -v "$c" >/dev/null 2>&1; then have_py="$c"; break; fi
done
if [ -z "$have_py" ]; then
  # Not a skip. If no interpreter exists anywhere, mode A was never tested and
  # this run proves less than it appears to -- say so and fail.
  fail=$((fail+1))
  printf '  %sFAIL%s no python3/python/py on PATH — parsed mode was NOT exercised\n' "$RED" "$RST"
else
  printf '  (interpreter: %s)\n' "$(PATH="$PARSED_PATH" command -v "$have_py")"
  t 2 'heredoc -> .m is BLOCKED'                "$PARSED_PATH" "$P_DOT_M"
  t 2 'heredoc -> .py is BLOCKED'               "$PARSED_PATH" "$P_DOT_PY"
  t 2 'inline interpreter write_text BLOCKED'   "$PARSED_PATH" "$P_INLINE_WRITE"
  t 0 'git commit -F - heredoc ALLOWED'         "$PARSED_PATH" "$P_COMMIT_MSG"
  t 0 'redirect with no heredoc ALLOWED'        "$PARSED_PATH" "$P_NO_HEREDOC"
  t 0 'heredoc -> .txt ALLOWED'                 "$PARSED_PATH" "$P_TXT_ONLY"
  t 0 'malformed JSON does not crash'           "$PARSED_PATH" "$P_MALFORMED"
  t 0 'empty command ALLOWED'                   "$PARSED_PATH" "$P_EMPTY_CMD"
fi
echo

# --- B. DEGRADED mode: no interpreter anywhere on PATH ----------------------
# Build PATH from an ALLOW-LIST, never by filtering the caller's. The hook still
# needs cat and grep, so a bare PATH=/nonexistent would make every case exit 127
# and every assertion below would be measuring "the harness is broken".
echo "B. degraded mode (no interpreter on PATH)"
MINBIN="$MB_TMP/minbin"; mkdir -p "$MINBIN"
for u in bash cat grep; do
  src=$(command -v "$u" 2>/dev/null)
  # A shell function or alias makes `command -v` echo the bare word, which would
  # produce a self-referential dangling symlink and a silent 127 storm.
  case "$src" in
    /*) ln -sf "$src" "$MINBIN/$u" ;;
    *)  echo "  ${RED}FAIL${RST} cannot resolve '$u' to an absolute path" >&2; fail=$((fail+1)) ;;
  esac
done

# THE ASSERTION THAT MAKES THIS SECTION MEAN ANYTHING.
leaked=""
for c in python3 python py; do
  if PATH="$MINBIN" command -v "$c" >/dev/null 2>&1; then leaked="$c"; break; fi
done
if [ -n "$leaked" ]; then
  fail=$((fail+1))
  printf '  %sFAIL%s %s is still reachable — degraded mode was NOT exercised\n' "$RED" "$RST" "$leaked"
elif ! printf 'abc' | PATH="$MINBIN" grep -q b 2>/dev/null; then
  fail=$((fail+1))
  printf '  %sFAIL%s grep is not usable under the minimal PATH — harness broken, results meaningless\n' "$RED" "$RST"
else
  printf '  (no interpreter reachable; cat+grep usable)\n'
  # Fail CLOSED. These are the cases the gate exists for and it must still stop
  # them with no interpreter to parse the payload.
  t 2 'heredoc -> .m is STILL BLOCKED'          "$MINBIN" "$P_DOT_M"
  t 2 'heredoc -> .py is STILL BLOCKED'         "$MINBIN" "$P_DOT_PY"
  t 2 'inline write_text STILL BLOCKED'         "$MINBIN" "$P_INLINE_WRITE"
  # Must not become a blanket deny: a payload with no heredoc, and a plain
  # commit-message heredoc, still pass on the raw-payload scan.
  t 0 'git commit -F - heredoc STILL ALLOWED'   "$MINBIN" "$P_COMMIT_MSG"
  t 0 'redirect with no heredoc STILL ALLOWED'  "$MINBIN" "$P_NO_HEREDOC"
  t 0 'heredoc -> .txt STILL ALLOWED'           "$MINBIN" "$P_TXT_ONLY"

  # KNOWN IMPRECISION, reported not asserted. The raw payload is one line, so a
  # `>` on one line can pair with a source extension named anywhere later --
  # including in "description", which is not the command at all. These block
  # today. That is the fail-closed trade being paid for, and it is deliberately
  # NOT frozen into an assertion: tightening the degraded scan should not have
  # to fight this file.
  echo "  -- known degraded imprecision (informational, not asserted) --"
  for pair in \
    'heredoc -> .txt naming a .py on a later line|{"tool_input":{"command":"cat <<EOF > notes.txt\nsee analysis.py\nEOF"}}' \
    'benign heredoc, unrelated .py in description|{"tool_input":{"command":"git commit -F - <<EOF\nmsg\nEOF","description":"ran > tools/run.py"}}'
  do
    d=${pair%%|*}; pl=${pair#*|}
    printf '     %-46s parsed=%s degraded=%s\n' "$d" \
      "$(run_hook "$PARSED_PATH" "$pl")" "$(run_hook "$MINBIN" "$pl")"
  done
fi

echo
if [ "$fail" -gt 0 ]; then
  printf '%s%s passed, %s failed%s\n' "$RED" "$pass" "$fail" "$RST"; exit 1
fi
printf '%s%s passed, 0 failed%s\n' "$GRN" "$pass" "$RST"
exit 0
