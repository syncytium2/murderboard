#!/usr/bin/env bash
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
#   bash murderboard_prompt.sh --html          the same prompt as an escaped <pre> block
#   bash murderboard_prompt.sh --sync-page     splice that block into docs/index.html
#   bash murderboard_prompt.sh --sync-md       splice the prompt into PROMPT.md's fence
#   bash murderboard_prompt.sh --selftest      prove it still produces a usable prompt
#
#   bash murderboard_prompt.sh | pbcopy        macOS: straight to the clipboard
#   bash murderboard_prompt.sh | xclip -sel c  Linux
#
#   Both --sync-* rewrite in place (docs/index.html, PROMPT.md); --page <file>
#   aims either one somewhere else. Do NOT regenerate PROMPT.md with a redirect:
#   `... > PROMPT.md` replaces the whole file, fences and all, and CI then fails
#   with a diff that does not say why.
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

# ---------------------------------------------------------------------------
# THE PAGE'S COPY OF THE PROMPT
#
# WHY THE PAGE CARRIES IT INLINE. On 2026-09-01 a first-time user asked an
# assistant what to do with murderboard.tonydefazio.com. It fetched the page,
# summarised it correctly, and offered to fetch PROMPT.md. It then SEARCHED
# instead of fetching, found nothing (the repo is not in the search index),
# reported that it could only fetch "URLs that show up in search results" and
# that it would be "guessing the link" -- while the exact URL sat in an <a href>
# in the nav of the page it had just read twice, and fetches fine. It then
# offered to run a review "in that spirit ... without needing his exact prompt
# text": a role-free imitation, indistinguishable to a novice from the real
# output, carrying this project's name. The user ignored it and fetched the file
# by hand, which is the only reason that run was real.
#
# A prompt one hop from the page is a prompt an assistant can talk itself out of
# reaching. Inline, the fetch that reads the page has already read the prompt.
#
# TWO COPIES DRIFT -- this repo has had that failure -- so neither copy is
# hand-written. PROMPT.md and the page block are both emitted from emit_prompt
# above, and CI diffs both against it.
BEGIN_MARK='BEGIN GENERATED PROMPT'
END_MARK='END GENERATED PROMPT'

# & first, or the later escapes get escaped in turn.
html_escape() { sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

emit_html() {
  local body
  body=$(emit_prompt | html_escape)
  [ -n "$body" ] || die "emit_prompt produced nothing to escape"
  # docs/ is served through Pages, and Jekyll eats anything Liquid-shaped. Fail
  # here, where the message can say why, rather than in the page test downstream.
  case $body in
    *'{{'*|*'{%'*) die "prompt contains a Liquid token — Jekyll would mangle the page" ;;
  esac
  printf '<pre class="promptblock" tabindex="0">\n%s\n</pre>\n' "$body"
}

# PROMPT.md has the same problem from the other direction. Its own header says
#   Regenerate with:  bash murderboard_prompt.sh > PROMPT.md
# and that command DESTROYS the file: the redirect replaces the header comment, the
# title, the "no install, no account" paragraph and both ``` fences with the bare
# prompt, after which CI's fence extraction finds nothing and reports a diff that
# does not explain itself. Followed literally on 2026-09-01; it did exactly that.
# So the markdown gets a splice too, and the instruction gets to be true.
sync_md() {
  local file="${1:-}" nf blk tmp
  [ -n "$file" ] || file="$(repo_root)/PROMPT.md"
  [ -r "$file" ] && [ -w "$file" ] || die "cannot read and write $file"

  nf=$(grep -c '^```$' "$file" || true)
  [ "$nf" = 2 ] || die "expected exactly two \`\`\` fence lines in $file (found $nf)"

  blk=$(mktemp) || die "mktemp failed"
  tmp=$(mktemp) || die "mktemp failed"
  emit_prompt > "$blk" || { rm -f "$blk" "$tmp"; die "could not build the prompt"; }

  awk -v blk="$blk" '
    /^```$/ && !seen { seen=1; print; while ((getline l < blk) > 0) print l; close(blk); skip=1; next }
    /^```$/ &&  skip { skip=0 }
    !skip            { print }
  ' "$file" > "$tmp" || { rm -f "$blk" "$tmp"; die "splice failed"; }

  cat "$tmp" > "$file" || { rm -f "$blk" "$tmp"; die "could not write $file"; }
  rm -f "$blk" "$tmp"
  printf 'murderboard_prompt: synced the fenced block in %s\n' "$file" >&2
}

sync_page() {
  local page="${1:-}" nb ne blk tmp
  [ -n "$page" ] || page="$(repo_root)/docs/index.html"
  [ -r "$page" ] && [ -w "$page" ] || die "cannot read and write $page"

  nb=$(grep -c "$BEGIN_MARK" "$page" || true)
  ne=$(grep -c "$END_MARK" "$page" || true)
  [ "$nb" = 1 ] && [ "$ne" = 1 ] \
    || die "expected exactly one $BEGIN_MARK and one $END_MARK in $page (found $nb and $ne)"

  # Each marker must close its own comment ON ITS OWN LINE. The splice keeps the
  # marker line and discards everything to the end marker, so a BEGIN comment that
  # wrapped onto a second line would lose its "-->" and swallow the whole block into
  # a comment -- the page would still parse, still pass tag balance, and simply stop
  # showing the prompt. That happened once, while this was being written.
  grep "$BEGIN_MARK" "$page" | grep -q -- '-->' \
    || die "the $BEGIN_MARK line must end its own comment with --> (keep it on one line)"
  grep "$END_MARK" "$page" | grep -q -- '-->' \
    || die "the $END_MARK line must end its own comment with --> (keep it on one line)"

  blk=$(mktemp) || die "mktemp failed"
  tmp=$(mktemp) || die "mktemp failed"
  emit_html > "$blk" || { rm -f "$blk" "$tmp"; die "could not build the block"; }

  # index(), not a regex match: the markers are literal and must stay literal.
  awk -v blk="$blk" -v b="$BEGIN_MARK" -v e="$END_MARK" '
    index($0, b) { print; while ((getline l < blk) > 0) print l; close(blk); skip=1; next }
    index($0, e) { skip=0 }
    !skip        { print }
  ' "$page" > "$tmp" || { rm -f "$blk" "$tmp"; die "splice failed"; }

  # Truncate in place rather than mv: keeps the file's mode and inode.
  cat "$tmp" > "$page" || { rm -f "$blk" "$tmp"; die "could not write $page"; }
  rm -f "$blk" "$tmp"
  printf 'murderboard_prompt: synced the generated block in %s\n' "$page" >&2
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

  # THE PAGE COPY. It must be the same prompt, only escaped. If the two diverge the
  # site serves a prompt nobody generated, which is the two-copies failure again.
  local html unescaped
  html=$(emit_html 2>/dev/null)

  if printf '%s' "$html" | grep -q '&lt;n&gt;'; then
    pass=$((pass+1)); printf '  ok   --html escapes angle brackets (raw <n> would parse as a tag)\n'
  else
    fail=$((fail+1)); printf '  FAIL --html did not escape the ROLE <n> placeholder\n'
  fi

  # Strip the <pre> wrapper (first and last lines); nothing between may be raw markup.
  if printf '%s' "$html" | sed '1d;$d' | grep -q '[<>]'; then
    fail=$((fail+1)); printf '  FAIL --html left a raw angle bracket inside the block\n'
  else
    pass=$((pass+1)); printf '  ok   --html leaves no raw angle bracket inside the <pre>\n'
  fi

  # Unescape in the reverse order (& last) and it must be the prompt, byte for byte.
  unescaped=$(printf '%s' "$html" | sed '1d;$d' \
              | sed -e 's/&lt;/</g' -e 's/&gt;/>/g' -e 's/&amp;/\&/g')
  if [ "$unescaped" = "$out" ]; then
    pass=$((pass+1)); printf '  ok   --html round-trips to exactly the prompt\n'
  else
    fail=$((fail+1)); printf '  FAIL --html does not round-trip to the prompt\n'
  fi

  # --sync-page must refuse a file it cannot find both markers in, rather than
  # writing the block somewhere arbitrary or silently doing nothing.
  local mk; mk=$(mktemp -d) || die "mktemp failed"
  printf '<p>no markers here</p>\n' > "$mk/page.html"
  if bash "$SELF_DIR/$(basename "$0")" --sync-page --page "$mk/page.html" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL --sync-page accepted a file with no markers\n'
  else
    pass=$((pass+1)); printf '  ok   --sync-page refuses a file without both markers\n'
  fi
  printf '<!-- %s -->\nstale\n<!-- %s -->\n' "$BEGIN_MARK" "$END_MARK" > "$mk/page.html"
  if bash "$SELF_DIR/$(basename "$0")" --sync-page --page "$mk/page.html" >/dev/null 2>&1 \
     && grep -q 'promptblock' "$mk/page.html" && ! grep -q '^stale$' "$mk/page.html"; then
    pass=$((pass+1)); printf '  ok   --sync-page replaces the marked region\n'
  else
    fail=$((fail+1)); printf '  FAIL --sync-page did not replace the marked region\n'
  fi
  rm -rf "$mk"

  # --sync-md, same two properties: refuse what it cannot splice, and replace what
  # it can. A redirect into PROMPT.md silently ate the wrapper; a splice that
  # quietly ate it too would be no better.
  local md; md=$(mktemp -d) || die "mktemp failed"
  printf 'no fences here\n' > "$md/p.md"
  if bash "$SELF_DIR/$(basename "$0")" --sync-md --page "$md/p.md" >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  FAIL --sync-md accepted a file with no ``` fences\n'
  else
    pass=$((pass+1)); printf '  ok   --sync-md refuses a file without exactly two fences\n'
  fi
  printf '# Title\n\nkeep me\n\n```\nstale\n```\n\nkeep me too\n' > "$md/p.md"
  if bash "$SELF_DIR/$(basename "$0")" --sync-md --page "$md/p.md" >/dev/null 2>&1 \
     && grep -q '^# Title$' "$md/p.md" && grep -q '^keep me too$' "$md/p.md" \
     && ! grep -q '^stale$' "$md/p.md" && grep -q 'MURDERBOARD' "$md/p.md"; then
    pass=$((pass+1)); printf '  ok   --sync-md replaces the fence and keeps the prose around it\n'
  else
    fail=$((fail+1)); printf '  FAIL --sync-md did not preserve the wrapper around the fence\n'
  fi
  rm -rf "$md"

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
PAGE_FILE=""
while [ $# -gt 0 ]; do
  case "$1" in
    --full)      MODE=full ;;
    --roles)     MODE=roles ;;
    --html)      MODE=html ;;
    --sync-page) MODE=sync ;;
    --sync-md)   MODE=syncmd ;;
    --selftest)  MODE=selftest ;;
    --process)   shift; PROCESS="${1:-}" ;;
    --page)      shift; PAGE_FILE="${1:-}" ;;
    -h|--help)   sed -n '/^# USAGE/,/^# EXIT/p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *)           die "unknown argument '$1' (try --help)" ;;
  esac
  shift
done

case "$MODE" in
  selftest) selftest; exit $? ;;
  roles)    resolve; roles ;;
  full)     resolve; cmd_full ;;
  html)     resolve; emit_html ;;
  sync)     resolve; sync_page "$PAGE_FILE" ;;
  syncmd)   resolve; sync_md "$PAGE_FILE" ;;
  prompt)   resolve; emit_prompt ;;
esac
