#!/usr/bin/env bash
# instrument: verification
# murderboard_prompt.sh — print a paste-ready murderboard prompt for ANY chat assistant.
#
# WHY THIS EXISTS. The murderboard is a process, not a product. Most of this repo already
# runs without Claude -- the process file is prose, and all three gates plus fetch_paper.py
# are plain shell and Python that never touch a model. Only the skill and the hooks are
# Claude Code specific. But someone arriving with ChatGPT, Gemini, a local model, or nothing
# but a text box had no obvious way in: the process file is ~975 lines, and "read this and
# apply it" is not an on-ramp.
#
# So this prints something you can paste. One command, no install, no account, no agent.
#
# DERIVED, NEVER RECALLED. The role list comes from murderboard_roster.sh, which parses it
# out of doc_review_process.md -- the same source the coverage gate uses. Add a role upstream
# and this prompt gains it for free. A hand-maintained copy of the roster would drift, and a
# prompt that quietly reviews with 9 of 11 roles is exactly the failure the roster gate exists
# to catch.
#
# USAGE
#   bash murderboard_prompt.sh                 compact prompt (fits any chat window)
#   bash murderboard_prompt.sh --full          compact prompt + the whole process file
#   bash murderboard_prompt.sh --roles         just the role list, one per line
#   bash murderboard_prompt.sh --selftest      prove it still produces a usable prompt
#
#   bash murderboard_prompt.sh | pbcopy        macOS: straight to the clipboard
#   bash murderboard_prompt.sh | xclip -sel c  Linux
#
# EXIT  0 ok   2 could not find the process file or the roster tool

set -u

SELF_DIR=$(cd "$(dirname "$0")" && pwd)
PROCESS="${MURDERBOARD_PROCESS:-}"
ROSTER=""

die() { printf '%s\n' "murderboard_prompt: $*" >&2; exit 2; }

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

resolve() {
  local root; root=$(repo_root)
  if [ -z "$PROCESS" ]; then
    for f in docs/doc_review_process.md doc_review_process.md; do
      [ -r "$root/$f" ] && { PROCESS="$root/$f"; break; }
      [ -r "$SELF_DIR/$f" ] && { PROCESS="$SELF_DIR/$f"; break; }
    done
  fi
  [ -n "$PROCESS" ] && [ -r "$PROCESS" ] || die "no doc_review_process.md found (set MURDERBOARD_PROCESS)"

  for f in "$SELF_DIR/murderboard_roster.sh" "$root/murderboard_roster.sh" \
           "$root/tools/murderboard_roster.sh"; do
    [ -r "$f" ] && { ROSTER="$f"; break; }
  done
  [ -n "$ROSTER" ] || die "cannot find murderboard_roster.sh (the role list is derived from it)"
}

# --process, NOT an env var. murderboard_roster.sh takes the path as a flag; an
# unrecognised environment variable is silently ignored, and it would autodetect the
# repo's OWN process file instead -- which looks like success and tests nothing.
roles() { bash "$ROSTER" --process "$PROCESS" list; }

emit_prompt() {
  local n; n=$(roles | grep -c .)
  [ "$n" -gt 0 ] || die "parsed 0 roles from $PROCESS — refusing to emit an empty prompt"

  cat <<'HEAD'
You are running a MURDERBOARD on the document I am about to give you: an adversarial
review that tries to tear the draft apart before it ships, so that what survives is
trustworthy.

Run EVERY role below. Not a sample, not the ones that seem relevant -- every one. A role
with genuinely nothing to check says so explicitly and states what it checked; that is a
valid result, and silently skipping it is not.

THE ROLES
HEAD

  roles | while IFS="$(printf '\t')" read -r num ttl; do
    printf '  %2s. %s\n' "$num" "$ttl"
  done

  cat <<'TAIL'

HOW TO RUN THEM

1. Work role by role. For each one, output a short block:
      ROLE <n> — <name>
      findings: <each with location · what is wrong · severity · suggested fix>
                · could I verify this against a source I was actually given? (yes/no)
      or: "no findings — here is what I checked: ..."

2. SEVERITY is blocking / major / minor. Be honest; inflating severity is its own defect.

3. THE MOST IMPORTANT RULE: check claims against SOURCES, not against your impression of
   the text. If I have not given you the underlying data, code, or references, you CANNOT
   verify a claim that rests on them -- say so and mark it unverified. Do not guess, and
   do not treat a confident sentence as evidence for itself. A review that silently
   assumes the sources agree is worse than no review, because it manufactures confidence.

4. Do not invent findings to look thorough. "This section is clean" is a real result.

5. A null result needs a check that could have failed. If the document says "we tested for
   X and it did not occur", ask whether the test could ever have detected X.

THEN

- List the findings ordered by severity, most severe first.
- State plainly which findings you could NOT verify, and what you would need to verify them.
- Do not rewrite the document unless I ask. Report first.

Finally, confirm you ran all the roles by listing them with their finding counts, so I can
see at a glance that none was dropped.

I will paste the document in my next message. Acknowledge with a single line, then wait.
TAIL
}

cmd_full() {
  emit_prompt
  cat <<'SEP'

================================================================================
REFERENCE — the full process, including what each role checks and the incidents
behind each rule. Consult it while running the roles above.
================================================================================

SEP
  cat "$PROCESS"
}

selftest() {
  local pass=0 fail=0 out n
  printf 'murderboard_prompt selftest\n'
  resolve

  out=$(emit_prompt 2>/dev/null); n=$(roles | grep -c .)

  if [ "$n" -gt 0 ]; then pass=$((pass+1)); printf '  ok   derived %s roles from the process file\n' "$n"
  else fail=$((fail+1)); printf '  FAIL derived 0 roles\n'; fi

  # Every derived role must actually appear in the emitted prompt. A prompt that lists 9
  # of 11 roles reviews with 9 of 11 roles, and nothing downstream would notice.
  local missing=0 num ttl
  while IFS="$(printf '\t')" read -r num ttl; do
    printf '%s' "$out" | grep -qF "$ttl" || { missing=$((missing+1)); printf '  FAIL role %s missing from prompt: %s\n' "$num" "$ttl"; }
  done <<EOF
$(roles)
EOF
  if [ "$missing" = 0 ]; then pass=$((pass+1)); printf '  ok   every derived role appears in the prompt\n'
  else fail=$((fail+1)); fi

  if printf '%s' "$out" | grep -q 'could I verify this against a source'; then
    pass=$((pass+1)); printf '  ok   prompt keeps the verify-against-sources instruction\n'
  else fail=$((fail+1)); printf '  FAIL prompt lost the verify-against-sources instruction\n'; fi

  # An empty roster must refuse loudly rather than emit a confident, role-free prompt.
  local tmp; tmp=$(mktemp -d) || die "mktemp failed"
  printf '# Nothing\n\n## The review team\n\n(no roles)\n' > "$tmp/empty.md"
  if bash "$SELF_DIR/$(basename "$0")" --process "$tmp/empty.md" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL emitted a prompt from a process file with 0 roles\n'
  else
    pass=$((pass+1)); printf '  ok   0 roles -> refuses to emit (exit 2)\n'
  fi
  rm -rf "$tmp"

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

MODE=prompt
while [ $# -gt 0 ]; do
  case "$1" in
    --full)     MODE=full ;;
    --roles)    MODE=roles ;;
    --selftest) MODE=selftest ;;
    --process)  shift; PROCESS="${1:-}" ;;
    -h|--help)  sed -n '/^# USAGE/,/^# EXIT/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)          die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

case "$MODE" in
  selftest) selftest; exit $? ;;
  roles)    resolve; roles ;;
  full)     resolve; cmd_full ;;
  prompt)   resolve; emit_prompt ;;
esac
