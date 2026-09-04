#!/usr/bin/env bash
# instrument: retrieval
# CANONICAL SOURCE: syncytium2/murderboard .claude/hooks/no-heredoc-source.sh — edit HERE.
# no-heredoc-source.hook.sh — PreToolUse(Bash) gate: BLOCK writing source files
# through a shell heredoc.
#
# VENDOR IT ELSEWHERE. Project-neutral by design: no dataset, no domain, no MATLAB
# specifics beyond the extension list. Copy it UNCHANGED into a consumer repo's
# .claude/hooks/ and wire the PreToolUse block shown at the foot of this file.
# Consumers stamp `vendored from syncytium2/murderboard @ <short-sha>` on line 2,
# and nobody edits a vendored copy in place.
#
# ORIGIN: written in a private repo (interface2) and vendored here at a33c8ea9.
# Murderboard adopted it as canonical on 2026-08-21, when this repo went public.
#
# Staleness is checkable IN YOUR COPY — the freshness gate is generic, not
# murderboard-specific. Run this in the CONSUMER repo, not here: this file is the
# original, so it carries no vendored stamp and the gate correctly says so.
#   bash murderboard_freshness.sh --label no-heredoc --slug syncytium2/murderboard \
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

# ---- interpreter resolution -------------------------------------------------
# ⚠ FIXED 2026-08-18, reported by colonel_kernel: this hardcoded `python`, which
# does not exist on a system that ships only `python3` (most Linux, Homebrew
# macOS). The failure was not "the hook errors" — it was far worse:
#
#     cmd="$(... | python -c '...' 2>/dev/null)"   -> python not found
#     [ -z "$cmd" ] && exit 0                      -> EXIT 0, ALLOW EVERYTHING
#
# A GATE THAT FAILS OPEN IS WORSE THAN NO GATE, because it is installed, it is
# in the settings file, and it reports nothing — so it manufactures exactly the
# confidence it was built to earn. It was live in seven repos.
PYBIN=""
for c in python3 python py; do
  if command -v "$c" >/dev/null 2>&1; then
    if [ "$c" = "py" ]; then PYBIN="py -3"; else PYBIN="$c"; fi
    break
  fi
done

cmd=""
if [ -n "$PYBIN" ]; then
  cmd="$(printf '%s' "$payload" | $PYBIN -c '
import json,sys
try:
    d = json.load(sys.stdin)
except Exception:
    sys.exit(0)
print((d.get("tool_input") or {}).get("command", ""))
' 2>/dev/null)"
fi

# NO INTERPRETER, OR PARSE FAILED -> DEGRADE, DO NOT SURRENDER. Scan the raw
# payload instead. It is JSON, so the command text is in there with its quoting
# escaped; the heredoc and source-file patterns still show through. Cruder, and
# that is the point: a gate may lose precision when its tools are missing, but
# it may not silently stop gating.
DEGRADED=0
if [ -z "$cmd" ]; then
  DEGRADED=1
  cmd="$payload"
fi

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
  if [ "$DEGRADED" = "1" ]; then
    printf '%s\n' "" \
      "(NOTE: no python3/python/py found, so this matched the RAW payload rather" \
      " than the parsed command. Precision is reduced — if this is a false" \
      " positive, install python3 or report it.)" >&2
  fi
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
#
# AND RUN THEM AGAIN WITH NO PYTHON ON PATH. This is not paranoia — it is the
# bug colonel_kernel found on 2026-08-18: the hook was verified passing in a
# shell where `python` happened to resolve, then shipped to seven repos where a
# hook's plain login PATH had only `python3`, and it exited 0 for every call.
# The original two checks CANNOT detect that; only this third one can.
#
#   NOPY=$(printf '%s' "$PATH" | tr ':' '\n' | grep -vi "python" | paste -sd: -)
#   printf '%s' '{"tool_input":{"command":"cat > x.m <<EOF\ndisp(1)\nEOF"}}' \
#     | PATH="$NOPY" bash .claude/hooks/no-heredoc-source.sh ; echo "exit=$? (want 2)"
# ----------------------------------------------------------------------------
