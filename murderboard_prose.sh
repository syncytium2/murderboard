#!/usr/bin/env bash
# murderboard_prose.sh — run role 5's MECHANICAL half over a document, and print what it found.
#
# THE GAP THIS CLOSES. Role 5 ("Kill Your Darlings") now carries a list of banned
# constructions. That list is greppable -- and it sits inside a role whose other work is
# judgement. The process file names this exact hazard in its own architecture section:
#
#     "a judgment call can be satisfied by thinking and a mechanical one cannot, so when
#      the two share a checklist the prose answer covers for the file nobody opened"
#
# So a reviewer answers "the prose is clean" without ever searching the text, and the
# answer is indistinguishable from one that searched. Same shape as the roster gate: the
# claim of absence rests on an instrument that could not have registered the presence.
#
# This is that instrument. It searches. It cannot judge, and it does not pretend to.
#
# WHAT IT DOES NOT DO -- deliberately. It does not decide whether a block is too long for
# its point, which sentence carries the payload, or whether a hit should stay. Those are
# role 5's judgement and stay with role 5. This prints counts and locations so that
# judgement has something to sit on, and so that "no findings" becomes falsifiable.
#
# A DOCUMENT THAT QUOTES THE LIST TRIPS ON IT. Run this on doc_review_process.md and role 5
# reports seven hits: it is the file that states the words. Same for a style guide, a review
# report quoting its own findings, or this header. The error is a FALSE POSITIVE with a line
# number a human dismisses in a second -- the safe direction. It is not filtered, because
# every filter that could suppress it ("ignore lines inside a list", "ignore quoted text")
# also suppresses a real hit in a real quotation, and this repo has already been bitten by a
# check that laundered a genuine failure out of a report that documented itself.
#
# DERIVED, NEVER RECALLED. The banned WORDS are parsed out of doc_review_process.md at run
# time, exactly as murderboard_roster.sh derives the role list. Edit role 5 and this tool
# follows. A hardcoded copy would drift, and drift here is silent: the tool goes on
# permitting a word the review still fails. The banned FORMS are regexes and live here,
# because a phrase pattern is not a word list; tests/drafting_prompt_test.py checks that
# every form this tool searches for is named in role 5.
#
# USAGE
#   murderboard_prose.sh DOC [DOC...]        scan; table to stdout
#   murderboard_prose.sh --words             print the banned word list and exit
#   murderboard_prose.sh --blocks DOC        block word counts only
#   murderboard_prose.sh --process PATH ...  use this process file (default: autodetect)
#   murderboard_prose.sh --selftest          prove every check can still fire
#
# EXIT  0 = nothing found   1 = hits found   2 = could not read a file / derive the list
#
# Reads .md, .html, .txt. Project-neutral: no hardcoded consumer paths, no dependencies
# beyond POSIX sh + awk + sed.

set -u
LC_ALL=C; export LC_ALL

PROCESS=
BLOCKS_ONLY=0
LONG_BLOCK=120   # words. A convention this project may tune, not a researched optimum.

die() { printf 'murderboard_prose: %s\n' "$*" >&2; exit 2; }

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

resolve_process() {
  [ -n "$PROCESS" ] && { [ -r "$PROCESS" ] || die "cannot read $PROCESS"; return; }
  local root self
  root=$(repo_root); self=$(cd "$(dirname "$0")" && pwd)
  for f in docs/doc_review_process.md doc_review_process.md \
           .claude/skills/murderboard/doc_review_process.md; do
    [ -r "$root/$f" ] && { PROCESS="$root/$f"; return; }
    [ -r "$self/$f" ] && { PROCESS="$self/$f"; return; }
  done
  die "no doc_review_process.md found (use --process PATH)"
}

# Role 5 carries the words as one bold run: **delve, leverage, ... tapestry**
banned_words() {
  resolve_process
  local run
  run=$(tr '\n' ' ' < "$PROCESS" | sed -n 's/.*\*\*delve,\([^*]*\)\*\*.*/delve,\1/p')
  [ -n "$run" ] || die "could not find the banned-word run in $PROCESS (expected \`**delve,\`).
  The list moved or was reworded. This tool derives it rather than keeping a copy, so it
  stops instead of silently searching for the wrong thing."
  printf '%s' "$run" | tr ',' '\n' | sed 's/^ *//; s/ *$//' | grep -v '^$'
}

# Banned FORMS. Each line: <label>::<extended regex>. Every label must appear in role 5 --
# tests/drafting_prompt_test.py enforces that.
#
# The separator is `::` and not `|` because every regex here contains an alternation. With
# `IFS='|' read label re` the pattern `not (just|only) ...` is delivered as `not (just`,
# which is an unbalanced ERE: grep errors to stderr, the `if` reads the error as "no match",
# and the check reports clean on every document forever. It is the fail-open shape this
# whole tool exists to remove, reintroduced in the tool itself.
banned_forms() {
  cat <<'FORMS'
not just X, but Y::not (just|only) [^,.]{1,40}, but
it's not about A, it's about B::(it.s|this is) not about [^,.]{1,40}, (it.s|it is) about
it's worth noting::(it.s|it is) worth noting|worth noting that
In today's ___::[Ii]n today.s [a-z]
FORMS
}

# Strip HTML tags and entities; collapse to plain text, one source line in, one line out,
# so reported line numbers still point at the file the author edits.
to_text() {
  sed -e 's/<[^>]*>/ /g' \
      -e 's/&mdash;/--/g; s/&ndash;/-/g; s/&ldquo;/"/g; s/&rdquo;/"/g' \
      -e "s/&lsquo;/'/g; s/&rsquo;/'/g; s/&amp;/\&/g; s/&nbsp;/ /g" \
      -e 's/&[a-zA-Z]*;/ /g' "$1"
}

scan_hits() {
  local doc="$1" txt="$2" found=0 w label re
  while IFS= read -r w; do
    [ -n "$w" ] || continue
    if grep -nEi -- "\\b${w}(s|ly|ness)?\\b" "$txt" >/dev/null 2>&1; then
      grep -nEi -- "\\b${w}(s|ly|ness)?\\b" "$txt" \
        | awk -F: -v d="$doc" -v w="$w" '{printf "  %-6s %-34s word   %s\n", $1, w, "in: " substr($0, index($0,$2), 60)}'
      found=1
    fi
  done <<EOF
$(banned_words)
EOF

  local line
  while IFS= read -r line; do
    [ -n "${line:-}" ] || continue
    label=${line%%::*}; re=${line#*::}
    # A malformed ERE makes grep exit 2, which the match test below reads as "no match" --
    # clean forever, silently. Prove the pattern compiles before trusting its verdict.
    printf '' | grep -Ei -- "$re" >/dev/null 2>&1
    [ $? -le 1 ] || die "banned form '$label' is not a valid regex; it would report clean on every document"
    if grep -nEi -- "$re" "$txt" >/dev/null 2>&1; then
      grep -nEi -- "$re" "$txt" \
        | awk -F: -v l="$label" '{printf "  %-6s %-34s form   %s\n", $1, l, "in: " substr($0, index($0,$2), 60)}'
      found=1
    fi
  done <<EOF
$(banned_forms)
EOF
  return $((1 - found))
}

# Blocks = runs of non-blank lines. Mechanical: how many words, how many sentences.
# WHICH sentence carries the payload is role 5's call and is deliberately absent here.
scan_blocks() {
  local txt="$1"
  awk -v lim="$LONG_BLOCK" '
    function flush() {
      if (words > 0) {
        n = gsub(/[.!?]["'"'"')]?( |$)/, "&", buf)
        printf "  %-6s %5d words  %3d sentences%s\n", start, words, (n?n:1), (words>lim ? "   << over " lim : "")
        if (words > lim) over++
      }
      words = 0; buf = ""
    }
    /^[[:space:]]*$/ { flush(); next }
    { if (words == 0) start = NR
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if ($0 == "") next
      buf = buf " " $0
      words += NF }
    END { flush(); printf "OVER:%d\n", over+0 }
  ' "$txt"
}

main_scan() {
  local doc="$1" rc=0
  [ -r "$doc" ] || die "cannot read $doc"
  local txt; txt=$(mktemp); trap 'rm -f "$txt"' RETURN
  to_text "$doc" > "$txt"

  printf '\n%s\n' "$doc"

  if [ "$BLOCKS_ONLY" -eq 0 ]; then
    printf '  %-6s %-34s %-6s %s\n' "line" "construction" "kind" "context"
    if scan_hits "$doc" "$txt"; then rc=1; else printf '  %s\n' "— no banned construction found"; fi
    printf '\n'
  fi

  printf '  %s\n' "blocks (word counts are mechanical; WHICH sentence is the payload is role 5's call)"
  local out over
  out=$(scan_blocks "$txt")
  over=$(printf '%s' "$out" | sed -n 's/^OVER:\(.*\)$/\1/p')
  printf '%s\n' "$out" | grep -v '^OVER:'
  [ "${over:-0}" -gt 0 ] && printf '  %s\n' "$over block(s) over $LONG_BLOCK words — for each, name its payload sentence and where it sits"

  rm -f "$txt"; trap - RETURN
  return $rc
}

selftest() {
  local tmp rc=0 pass=0 fail=0 self
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' RETURN

  # Absolute, and re-entered through `bash` explicitly. `"$0" file` looks like it re-runs
  # this script and does not: invoked as `bash murderboard_prose.sh`, $0 is a bare relative
  # name that is not on PATH, so every case exits 127. A 127 is not 0, so the checks that
  # assert a FAILURE pass on it -- the negative controls report green while testing nothing.
  # Caught by this selftest's own positive cases, which is the only reason it was caught.
  self=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
  resolve_process
  run() { bash "$self" --process "$PROCESS" "$@"; }

  ok()  { pass=$((pass+1)); printf '  ok   %s\n' "$1"; }
  bad() { fail=$((fail+1)); printf '  FAIL %s\n' "$1"; }

  printf 'murderboard_prose --selftest\n'

  banned_words > "$tmp/w" 2>/dev/null
  [ "$(wc -l < "$tmp/w")" -ge 5 ] && ok "banned words derive from the process file ($(wc -l < "$tmp/w" | tr -d ' ') found)" \
    || bad "banned words did not derive"

  printf 'This is a robust solution.\n' > "$tmp/a.md"
  run "$tmp/a.md" >/dev/null 2>&1 && bad "a banned WORD did not trip it" || ok "a banned word trips it"

  printf 'It is not just faster, but cheaper too.\n' > "$tmp/b.md"
  run "$tmp/b.md" >/dev/null 2>&1 && bad "a banned FORM did not trip it" || ok "a banned form trips it"

  printf 'A clean sentence about cells.\n' > "$tmp/c.md"
  run "$tmp/c.md" >/dev/null 2>&1 && ok "clean prose passes" || bad "clean prose was flagged"

  printf '<p>A truly robust framework.</p>\n' > "$tmp/d.html"
  run "$tmp/d.html" 2>/dev/null | grep -q robust && ok "HTML is stripped and still searched" \
    || bad "HTML was not searched"

  awk 'BEGIN{for(i=0;i<130;i++) printf "word "}' > "$tmp/e.md"; printf '\n' >> "$tmp/e.md"
  run "$tmp/e.md" 2>/dev/null | grep -q "over $LONG_BLOCK" && ok "a long block is counted and flagged" \
    || bad "long block not flagged"

  run "$tmp/nope.md" >/dev/null 2>&1; [ $? -eq 2 ] && ok "unreadable file -> exit 2" || bad "unreadable file did not exit 2"

  printf '\n%d passed, %d failed\n' "$pass" "$fail"
  [ "$fail" -eq 0 ] || rc=1
  return $rc
}

DOCS=""
while [ $# -gt 0 ]; do
  case "$1" in
    --process) shift; PROCESS="${1:-}"; [ -n "$PROCESS" ] || die "--process needs a path" ;;
    --words)   banned_words; exit 0 ;;
    --blocks)  BLOCKS_ONLY=1 ;;
    --selftest) selftest; exit $? ;;
    -h|--help) sed -n '2,42p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) DOCS="$DOCS $1" ;;
  esac
  shift
done

[ -n "${DOCS# }" ] || die "no document given (try --help)"

RC=0
for d in $DOCS; do main_scan "$d" || RC=1; done
printf '\n'
exit $RC
