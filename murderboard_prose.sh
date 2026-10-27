#!/usr/bin/env bash
# murderboard_prose.sh — run role 5's MECHANICAL half over a document, and print what it found.
#
# THE GAP THIS CLOSES. Role 5 ("Kill Your Darlings") now carries a list of banned
# constructions. That list is greppable -- and it sits inside a role whose other work is
# judgment. The process file names this exact hazard in its own architecture section:
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
# role 5's judgment and stay with role 5. This prints counts and locations so that
# judgment has something to sit on, and so that "no findings" becomes falsifiable.
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
#   murderboard_prose.sh --spelling us|uk DOC  check spelling against the named reader
#                                            (default $MURDERBOARD_SPELLING; unset = both ways)
#   murderboard_prose.sh --spelling-only ... spelling section only (this repo's CI uses it)
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
SPELLING_ONLY=0
SPELLING="${MURDERBOARD_SPELLING:-}"
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
the data is::\b(the|this|that|these|our|their|its|your|my|his|her|raw|real|input|source|new|more|less|much|enough|all|any|same|such|which|whose|no|observed|recorded|simulated|synthetic) data (is|was|has|does|doesn.t|isn.t|wasn.t|hasn.t|shows|says|suggests|indicates|contains|supports|refutes|means|needs|makes|gives|exists|remains|seems|appears|requires|proves|confirms|reveals|lives|sits|comes|looks|reads|tells|agrees|matches|fits|lacks|holds|itself)\b
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

# SPELLING. Flags words from the other variety than the reader's (process step 2, "Name the
# reader in the brief"; role 5, "Spelling and conventions match the reader").
#
# PATTERNS, NOT A WORD LIST, for the British forms. This repo swept British spellings out
# twice (#12, #70), both times by searching for a list of known words, and both times the words
# nobody thought of survived: a CI scan on 2026-10-27 found twelve that #70's list had missed.
# So -our, -ise/-isation, -yse, -tre/-bre, -ll-, and the ae/oe medical spellings are matched
# by SHAPE, and the American words of the same shape (hour, raise, promise, lyse, macabre...)
# are an allowlist. An unknown word therefore FAILS LOUDLY and a human decides, instead of
# passing silently because nobody listed it. The fixed forms (licence, grey, whilst...) are
# a list because they have no shared shape.
#
# The American forms (for a UK reader) ARE a list: -or, -er and -ize are all ordinary British
# shapes too (doctor, water, and Oxford's -ize), so no pattern separates them.
#
# With no variety declared it runs BOTH directions. A document that hits both is MIXED, which
# is a defect whatever the reader (exit 1). A document that hits only one is reported as
# reading that way, with a reminder that nobody declared a reader -- not a failure, because
# the tool cannot know which reader was wanted, and guessing is the defect it exists to catch.
#
# A line containing the text  spelling-ok  is skipped: for a quotation, an identifier, or a
# file that names the words (like this one). Say why on the same line.
scan_spelling() {
  local doc="$1" txt="$2" variety="$3"
  awk -v variety="$variety" -v skipfile="$doc" '
    BEGIN {
      while ((getline l < skipfile) > 0) { n++; if (l ~ /spelling-ok/) skip[n] = 1 }
      close(skipfile)
      split("our your four hour tour pour flour sour scour dour detour contour devour glamour amour paramour velour troubadour", a, " ")
      for (i in a) ourok[a[i]] = 1
      split("rais ris nois otherwis precis imprecis promis exercis expertis advis advertis surpris premis aris franchis merchandis enterpris compromis concis disguis despis devis revis supervis televis improvis paradis prais apprais chastis circumcis excis incis demis pois porpois treatis tortois cruis bruis anis mortis appris compris repris vis upris sunris liais cheris chemis valis", a, " ")
      for (i in a) iseok[a[i]] = 1
      split("analyses paralyses lyse lysed lyses lysing", a, " ")
      for (i in a) yseok[a[i]] = 1
      split("macabre timbre timbres ombre", a, " ")
      for (i in a) treok[a[i]] = 1
      split("licence licences licenced defence defences offence offences pretence grey greys greyed greying greyer greyish greyness judgement judgements ageing sceptic sceptics sceptical sceptically scepticism programme programmes whilst amongst learnt spelt enquiry enquiries enquire enquired enquiring artefact artefacts aluminium manoeuvre manoeuvres cheque cheques tyre tyres plough mould moulds mouldy draught draughts kerb storey storeys cosy pyjamas aeroplane moustache sulphur sulphate catalogue catalogues catalogued analogue analogues fulfil fulfils fulfilment enrol enrols enrolment instil distil skilful wilful instalment focussed focussing practise practised practising advert adverts maths", a, " ")
      for (i in a) ukword[a[i]] = 1
      split("color colors colored coloring colorful behavior behaviors behavioral favor favors favorite favorites favored honor honors honored labor labored neighbor neighbors neighboring neighborhood humor rumor armor vapor odor endeavor harbor savior flavor flavors center centers centered centering liter liters fiber fibers theater caliber gray grays defense offense pretense catalog catalogs skeptic skeptical skepticism aging labeled labeling modeled modeling traveled traveling traveler canceled canceling signaled fueled leveled totaled counseled channeled fulfill fulfills fulfillment enroll enrollment skillful willful installment mold molds plow pajamas airplane mustache sulfur fetus fetal hemoglobin anemia pediatric anesthesia edema esophagus estrogen leukemia diarrhea gynecology analyze analyzed analyzing paralyze catalyze", a, " ")
      for (i in a) usword[a[i]] = 1
    }
    function british(w,   s) {
      if (w in ukword) return 1
      if (w ~ /^[a-z]+our(s|ed|ing|ite|ites|able|ably|ful|less|er|ers)?$/) {
        s = w; sub(/(s|ed|ing|ite|ites|able|ably|ful|less|er|ers)$/, "", s)
        if (!(s in ourok) && s ~ /our$/) return 1
      }
      if (w ~ /^[a-z]+is(e|es|ed|ing|ation|ations|er|ers)$/) {
        s = w; sub(/(e|es|ed|ing|ation|ations|er|ers)$/, "", s)
        if (!(s in iseok) && s !~ /wis$/) return 1
      }
      if (w ~ /^[a-z]+ys(e|es|ed|ing|er|ers)$/ && !(w in yseok)) return 1
      if (w ~ /^[a-z]+(tre|bre)(s|d)?$/ && !(w in treok)) return 1
      if (w ~ /^(label|model|travel|cancel|signal|fuel|level|total|counsel|channel|tunnel|marshal|dial|duel|equal|jewel|libel|marvel|panel|pedal|quarrel|shovel|snorkel|swivel|towel|bevel|chisel|enamel|funnel|grovel|kennel|refuel|rival|spiral|stencil|pencil|yodel)l(ed|ing|er|ers)$/) return 1
      if (w ~ /(haem|anaem|anaesth|paed|oedem|oesoph|oestr|foet|leukaem|diarrhoe|gynaec|ischaem)/) return 1
      return 0
    }
    function report(kind, w) {
      printf "  %-6s %-34s %-6s %s\n", NR, w, kind, "in: " substr(line, 1, 60)
    }
    {
      if (NR in skip) next
      line = $0; gsub(/^[[:space:]]+/, "", line)
      t = tolower($0)
      if (t ~ /(^|[^a-z])per cent([^a-z]|$)/) { ukhits++; if (variety != "uk") report("uk", "per cent") }
      gsub(/[^a-z]+/, " ", t)
      m = split(t, w, " ")
      for (i = 1; i <= m; i++) {
        if (british(w[i]))  { ukhits++; if (variety != "uk") report("uk", w[i]) }
        if (w[i] in usword) { ushits++; if (variety != "us") report("us", w[i]) }
      }
    }
    END {
      if (variety == "us") { print "VERDICT:" (ukhits ? "fail" : "ok") }
      else if (variety == "uk") { print "VERDICT:" (ushits ? "fail" : "ok") }
      else if (ukhits && ushits) print "VERDICT:mixed"
      else if (ukhits) print "VERDICT:reads-uk"
      else if (ushits) print "VERDICT:reads-us"
      else print "VERDICT:ok"
    }
  ' "$txt"
}

scan_spelling_section() {
  local doc="$1" txt="$2" out verdict label
  case "$SPELLING" in us) label="US reader";; uk) label="UK reader";; *) label="no reader declared";; esac
  printf '  spelling (%s)\n' "$label"
  out=$(scan_spelling "$doc" "$txt" "$SPELLING")
  verdict=$(printf '%s\n' "$out" | sed -n 's/^VERDICT://p')
  printf '%s\n' "$out" | grep -v '^VERDICT:'
  case "$verdict" in
    ok)    printf '  %s\n' "— no spelling from the other variety found"; return 0 ;;
    fail)  return 1 ;;
    mixed) printf '  %s\n' "MIXED: both US and UK spellings above. A defect whatever the reader."; return 1 ;;
    reads-uk|reads-us)
      printf '  %s\n' "reads as ${verdict#reads-} English, and no reader was declared. Name the reader"
      printf '  %s\n' "(--spelling us|uk, or MURDERBOARD_SPELLING); never adopt the draft's variety."
      return 0 ;;
    *) die "spelling scan returned no verdict for $doc; it would report clean on every document" ;;
  esac
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

  if [ "$SPELLING_ONLY" -eq 1 ]; then
    scan_spelling_section "$doc" "$txt" || rc=1
    rm -f "$txt"; trap - RETURN
    return $rc
  fi

  if [ "$BLOCKS_ONLY" -eq 0 ]; then
    printf '  %-6s %-34s %-6s %s\n' "line" "construction" "kind" "context"
    if scan_hits "$doc" "$txt"; then rc=1; else printf '  %s\n' "— no banned construction found"; fi
    printf '\n'
    scan_spelling_section "$doc" "$txt" || rc=1
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

  printf 'The data is noisy.\n' > "$tmp/p.md"
  run "$tmp/p.md" 2>/dev/null | grep -q 'the data is' && ok "a singular verb after \"data\" trips it" \
    || bad "\"the data is\" did not trip it"

  printf 'The data are noisy, and these data show a gap.\nif data is None: return\n' > "$tmp/q.md"
  run "$tmp/q.md" >/dev/null 2>&1 && ok "plural \"data\" and code without a determiner pass" \
    || bad "plural \"data\" or code without a determiner was flagged"

  printf 'A clean sentence about cells.\n' > "$tmp/c.md"
  run "$tmp/c.md" >/dev/null 2>&1 && ok "clean prose passes" || bad "clean prose was flagged"

  printf '<p>A truly robust framework.</p>\n' > "$tmp/d.html"
  run "$tmp/d.html" 2>/dev/null | grep -q robust && ok "HTML is stripped and still searched" \
    || bad "HTML was not searched"

  awk 'BEGIN{for(i=0;i<130;i++) printf "word "}' > "$tmp/e.md"; printf '\n' >> "$tmp/e.md"
  run "$tmp/e.md" 2>/dev/null | grep -q "over $LONG_BLOCK" && ok "a long block is counted and flagged" \
    || bad "long block not flagged"

  run "$tmp/nope.md" >/dev/null 2>&1; [ $? -eq 2 ] && ok "unreadable file -> exit 2" || bad "unreadable file did not exit 2"

  # Spelling. Each British form below is one NO list names -- matched by shape -- so this
  # fails if the patterns are ever swapped back for a word list.
  printf 'The data were theorised, then organisation of haemoglobin centres was labelled.\n' > "$tmp/s.md"
  for w in theorised organisation haemoglobin centres labelled; do
    run --spelling us --spelling-only "$tmp/s.md" 2>/dev/null | grep -qw "$w" \
      && ok "US reader: \"$w\" trips it by shape" || bad "US reader: \"$w\" did not trip it"
  done

  printf 'Raise the noise; I promise the lysed cells, macabre hour and spelled travel are otherwise fine.\n' > "$tmp/t.md"
  run --spelling us --spelling-only "$tmp/t.md" >/dev/null 2>&1 && ok "US reader: American words of the same shape pass" \
    || bad "US reader: an American word was flagged as British"

  printf 'The colour of the centre.\n' > "$tmp/u.md"
  run --spelling uk --spelling-only "$tmp/u.md" >/dev/null 2>&1 && ok "UK reader: British spelling passes" \
    || bad "UK reader: British spelling was flagged"
  printf 'The color of the center.\n' > "$tmp/v.md"
  run --spelling uk --spelling-only "$tmp/v.md" >/dev/null 2>&1 && bad "UK reader: American spelling did not trip it" \
    || ok "UK reader: American spelling trips it"

  printf 'Use judgment here and judgement there; the colour is gray.\n' > "$tmp/x.md"
  run --spelling-only "$tmp/x.md" 2>/dev/null | grep -q MIXED && ok "no reader: a mix of both is reported MIXED" \
    || bad "no reader: a mix was not reported"
  printf 'The colour of the centre.\n' > "$tmp/y.md"
  run --spelling-only "$tmp/y.md" > "$tmp/y.out" 2>/dev/null; yrc=$?
  [ "$yrc" -eq 0 ] && grep -q 'no reader was declared' "$tmp/y.out" && ok "no reader: one variety is reported, not failed" \
    || bad "no reader: one variety was not reported as undeclared (exit $yrc)"

  printf 'The colour (spelling-ok: quoted) stays.\n' > "$tmp/z.md"
  run --spelling us --spelling-only "$tmp/z.md" >/dev/null 2>&1 && ok "a spelling-ok line is skipped" \
    || bad "a spelling-ok line was still flagged"

  run --spelling us-ish "$tmp/c.md" >/dev/null 2>&1; [ $? -eq 2 ] && ok "an unknown --spelling value -> exit 2" \
    || bad "an unknown --spelling value was accepted"

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
    --spelling) shift; SPELLING="${1:-}" ;;
    --spelling-only) SPELLING_ONLY=1 ;;
    --selftest) selftest; exit $? ;;
    -h|--help) sed -n '2,50p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) DOCS="$DOCS $1" ;;
  esac
  shift
done

case "$SPELLING" in us|uk|"") ;; *) die "--spelling must be us or uk (got '$SPELLING')" ;; esac
[ -n "${DOCS# }" ] || die "no document given (try --help)"

RC=0
for d in $DOCS; do main_scan "$d" || RC=1; done
printf '\n'
exit $RC
