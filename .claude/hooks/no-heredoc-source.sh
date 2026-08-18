#!/usr/bin/env bash
# vendored from interface2 @ eb2536a6 — do NOT edit here; edit the canonical original (interface2 tools/no-heredoc-source.hook.sh) and re-copy.
# no-heredoc-source.hook.sh — PreToolUse(Bash) gate: BLOCK writing source files
# through a shell heredoc.
#
# CANONICAL SOURCE: interface2 tools/no-heredoc-source.hook.sh — VENDOR IT ELSEWHERE.
# Project-neutral by design: no dataset, no domain, no MATLAB specifics beyond the
# extension list. Copy it UNCHANGED into a consumer repo's .claude/hooks/ and wire
# the PreToolUse block shown at the foot of this file. Same distribution rule as
# tools/session-start.hook.sh (decisions/0014-session-protocol-vendorable-artifact.md):
# interface2 is the source, consumers stamp `vendored from interface2 @ <short-sha>`
# on line 1, and nobody edits a vendored copy in place.
#
# Staleness is checkable — the freshness gate is generic, not murderboard-specific:
#   bash tools/murderboard_freshness.sh --label no-heredoc --slug <owner>/interface2 \
#        --file .claude/hooks/no-heredoc-source.sh --verbose
#
# WHY THIS EXISTS. Writing MATLAB (or Python, or R) through a shell heredoc
# corrupts string escapes, silently, and the corruption survives into a file
# that still looks correct in a diff. It has cost real time repeatedly. On
# 2026-08-18 alone, in one session:
#
#   sprintf('(%s) %6.1f \rightarrow %6.1f', ...)
#       heredoc collapsed the escape, MATLAB's sprintf then read \r as a
#       CARRIAGE RETURN and printed "ightarrow". The figure shipped once with
#       a mangled arrow before it was caught by looking at the raster.
#
#   warning('... STALE ON DISK: %s\n   %s', ...)
#       the \n became a LITERAL newline inside the quoted string, so the string
#       terminated early and the whole script stopped parsing. Every figure in
#       that run silently failed to render.
#
# Both were invisible in the command that produced them and obvious only in the
# written file. Tony, 2026-08-18: "the heredoc mangling is well documented. i'm
# sad that our tools did not help you avoid that ... make sure this gets flagged
# in the future ... we know this is a standing problem for months."
#
# THE POINT: sapper cannot catch this. Sapper greps the lines a COMMIT ADDS, so
# it only ever sees the wreckage, and only if the wreckage reaches a commit.
# This hook sees the ATTEMPT and stops it before a file is written.
#
# THE FIX IS ALWAYS THE SAME: use the Write / Edit tools for source files. They
# take the content literally — no shell, no escape processing, no surprises.
#
# Exit 2 tells Claude Code to block the call and feed stderr back to the model.

payload="$(cat)"

cmd="$(printf '%s' "$payload" | python -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("tool_input") or {}).get("command", ""))
' 2>/dev/null)"

[ -z "$cmd" ] && exit 0

# A heredoc at all?  ( << or <<- , quoted or not )
printf '%s' "$cmd" | grep -qE '<<-?[[:space:]]*'"'"'?[A-Za-z_]' || exit 0

# ...aimed at a source file?  Either a redirect to one, or an inline
# interpreter that writes one (python - <<EOF ... p.write_text(...)).
if printf '%s' "$cmd" | grep -qiE '>[[:space:]]*[^|;&]*\.(m|py|R|jl|sh)\b' \
   || printf '%s' "$cmd" | grep -qiE "(write_text|writelines|\.write\()" ; then

  cat >&2 <<'MSG'
BLOCKED: writing a source file through a shell heredoc.

Shell heredocs corrupt string escapes on the way to disk, silently, and the
result still looks right in a diff. This has cost this project real time
repeatedly -- most recently two MATLAB files in one session:

  sprintf('... \rightarrow ...')  -> sprintf read \r as a CARRIAGE RETURN
  warning('... %s\n   %s', ...)   -> \n became a literal newline, string
                                     terminated early, the script stopped
                                     parsing and every figure silently failed

USE THE Write OR Edit TOOL INSTEAD. They take content literally: no shell, no
escape processing. For a small change, Edit; for a new file, Write.

If you genuinely need a heredoc here (a throwaway shell script with no escapes,
data rather than source), say so explicitly and re-run with the intent stated --
but for .m / .py / .R source, the answer is the file tools.
MSG
  exit 2
fi

exit 0

# ----------------------------------------------------------------------------
# ADOPTION (any repo). Copy this file to .claude/hooks/no-heredoc-source.sh,
# stamp line 1 with its provenance, and add to .claude/settings.json:
#
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Bash",
#         "hooks": [ { "type": "command",
#                      "command": "bash .claude/hooks/no-heredoc-source.sh",
#                      "timeout": 10 } ] }
#     ]
#   }
#
# Verify it works in the consumer repo before trusting it — a gate that cannot
# fire manufactures confidence:
#
#   printf '%s' '{"tool_input":{"command":"cat > x.m <<EOF\ndisp(1)\nEOF"}}' \
#     | bash .claude/hooks/no-heredoc-source.sh ; echo "exit=$? (want 2)"
#   printf '%s' '{"tool_input":{"command":"git commit -F - <<EOF\nmsg\nEOF"}}' \
#     | bash .claude/hooks/no-heredoc-source.sh ; echo "exit=$? (want 0)"
# ----------------------------------------------------------------------------
