#!/usr/bin/env bash
# murderboard_roster.sh — derive the review-team roster FROM the process file, and check
# that a review report actually accounts for every role.
#
# THE GAP THIS CLOSES. `doc_review_process.md` says "every role runs on every deliverable"
# and "a role with genuinely nothing to check returns 'no findings, and here is what I
# checked'". Both are prose addressed to the reviewer. Nothing reads the finished report
# and asks whether all of them are actually in it — so a run that fired 7 of 11 roles and a
# run that fired all 11 cleanly produce reports that are indistinguishable to the reader.
#
# That is the same defect the process itself names as a rule ("can the alarm ring?"): a
# claim of absence resting on an instrument that could not have registered the presence.
# "No findings from role 9" is worthless if role 9 was never spawned.
#
# Two jobs, both cheap:
#   list   — parse the roles out of the process file. The roster is DERIVED, never recalled,
#            so adding role 12 upstream propagates to every consumer's check for free.
#   check  — verify a review report names every role in the roster. Exit 1 if any is missing.
#
# USAGE
#   murderboard_roster.sh list                  print "N<TAB>title" for each role
#   murderboard_roster.sh count                 print how many roles the process defines
#   murderboard_roster.sh check REPORT.md       every role accounted for? (0 yes / 1 no)
#   murderboard_roster.sh check --require-mode REPORT.md
#                                               ...and the report must declare its Mode:
#   murderboard_roster.sh check --require-execution REPORT.md
#                                               ...and the report must declare its Execution:
#   murderboard_roster.sh check --require-reports REPORT.md
#                                               ...and its role reports must be on disk
#   murderboard_roster.sh check --require-lookup REPORT.md
#                                               ...and the report must declare its Lookup:
#   murderboard_roster.sh --process PATH ...    use this process file (default: autodetect)
#   murderboard_roster.sh --selftest            prove every branch can still fire
#
# EXIT CODES   0 = ok   1 = roles missing, a mode/execution/lookup line is missing or
#                         incoherent, Lookup: is `unavailable`, or the declared
#                         role-report archive is absent, incomplete, or empty
#              2 = could not determine
#
# Project-neutral: no hardcoded consumer paths.

set -u
LC_ALL=C; export LC_ALL

PROCESS=
REQUIRE_MODE=0
REQUIRE_EXECUTION=0
REQUIRE_REPORTS=0
REQUIRE_LOOKUP=0

# Where the process file lives in a consumer, relative to the repo root. First hit wins.
PROCESS_CANDIDATES="
docs/doc_review_process.md
doc_review_process.md
.claude/skills/murderboard/doc_review_process.md
"

if [ -t 1 ]; then RED=$'\033[31m'; GRN=$'\033[32m'; RST=$'\033[0m'
else RED=; GRN=; RST=; fi

die() { printf '%s\n' "$*" >&2; exit 2; }

repo_root() {
  git rev-parse --show-toplevel 2>/dev/null || pwd
}

resolve_process() {
  [ -n "$PROCESS" ] && { [ -r "$PROCESS" ] || die "murderboard_roster: cannot read $PROCESS"; return; }
  local root f
  root=$(repo_root)
  for f in $PROCESS_CANDIDATES; do
    if [ -r "$root/$f" ]; then PROCESS="$root/$f"; return; fi
  done
  die "murderboard_roster: no doc_review_process.md found under $root (use --process PATH)"
}

# Print "N<TAB>title" for every numbered role.
#
# SCOPED ON PURPOSE. The file has other top-level numbered bold lists — the 5 process
# steps ("1. **Draft** the document.") and the 3 literature rules ("1. **Check the library
# FIRST.**"). An unscoped grep counts 19 "roles" and the check then demands rows that do
# not exist. So: only lines between "## The review team" and the next "## " heading, and
# only at column 0 (sub-bullets are indented).
roster() {
  awk '
    /^## The review team/ { inteam = 1; next }
    inteam && /^## /      { inteam = 0 }
    inteam && /^[0-9]+\. \*\*/ {
      line = $0
      num  = line; sub(/\..*$/, "", num)
      ttl  = line
      sub(/^[0-9]+\. \*\*/, "", ttl)
      sub(/\*\*.*$/, "", ttl)
      printf "%s\t%s\n", num, ttl
    }
  ' "$PROCESS"
}

cmd_list()  { resolve_process; roster; }
cmd_count() { resolve_process; roster | grep -c . ; }

# Does the report account for every role? A role counts as present if the report contains
# its number in a leading/table position OR its nickname. Deliberately generous about
# FORMAT and strict about PRESENCE: the point is to catch a silently dropped role, not to
# dictate markdown.
# THE MODE LINE. An eleven-of-eleven ledger says every role ran; it does not say the
# LOOP finished. A run against a published or submitted artifact cannot repair and cannot
# re-review, so it stops after round 1 -- and produces a report indistinguishable from a
# complete one, because the thing that was lost is not counted anywhere. Observed: a full
# 11-role run against a published paper, correct in every role, stopping silently at round
# 1 of 3.
#
# Reported, never assumed. Absent a declaration the answer is UNDECLARED, not "standard" --
# the discipline the freshness gate already uses, where the one verdict it may never produce
# is a false "current". Undeclared exits 0 so every report written before this existed keeps
# passing; --require-mode is how a project opts into enforcement.
report_mode() {
  local report="$1"
  if grep -qiE '^[[:space:]]*[*_|>[:space:]]*Mode:[[:space:]]*retrospective' "$report" 2>/dev/null; then
    printf 'retrospective\n'
  elif grep -qiE '^[[:space:]]*[*_|>[:space:]]*Mode:[[:space:]]*standard' "$report" 2>/dev/null; then
    printf 'standard\n'
  else
    printf 'undeclared\n'
  fi
}

# Generous about wording, strict about presence -- same posture as the role check. A
# retrospective run that does not say WHY it stopped is the failure this is here to catch:
# it reads as a complete run to everyone downstream.
has_stopping_reason() {
  grep -qiE 'round[[:space:]]+[0-9]+[[:space:]]+of[[:space:]]+[0-9]+|stopping reason|repair (and re-review )?(is |are )?unavailable|cannot be (changed|repaired)|already (published|submitted)' \
       "$1" 2>/dev/null
}

# THE EXECUTION LINE. The mode line above records whether the LOOP finished. This one
# records whether there was ever more than one reviewer, which the ledger also cannot show.
#
# The process runs a substantial deliverable as parallel subagents and permits a single-pass
# self-review for a small one. Between those two sentences is a hole: when the Agent tool is
# unavailable -- denied by a permission rule, withheld by a launch flag, forbidden by an
# instruction, or absent because the session is already inside a subagent -- a run FALLS BACK
# into the mode the process already sanctions. Eleven roles still appear, each with real
# findings; this gate and the grants gate both still pass. What is lost is the independence,
# and nothing counts independence.
#
# Observed here: docs/reviews/plugin_adoption_docs_murderboard_2026-08-26.md, a full 11-role
# run in which one reviewer played all eleven parts. It says so only because its author chose
# to write a "Stated deviation" section. A disclosure that depends on being volunteered is
# the prose this repo keeps converting into gates.
#
# Same posture as the mode line, for the same reason: undeclared exits 0 so every report
# written before this existed keeps passing, and --require-execution is how a project opts in.
execution_line() {
  grep -iE '^[[:space:]]*[*_|>[:space:]]*Execution:' "$1" 2>/dev/null | head -1
}

# A CONTROLLED TOKEN, AND THE PROSE IS LEFT ALONE. The grammar is:
#
#     Execution: subagents
#     Execution: subagents — 11 spawned, role 4 could not reach the web
#     Execution: single-pass (forced) — the Agent tool was unavailable
#     Execution: single-pass (chosen) — a one-line caption
#
# Everything before the separator is parsed and must be a token exactly. Everything after
# it is never parsed at all.
#
# TWO PARSERS DIED TO GET HERE, and both died the same way -- inferring a verdict the author
# could simply have stated. The first matched substrings with no regard for negation, so
# "subagents unavailable" counted as evidence OF subagents. The second added a negation
# predicate bounded to one clause by `[^.;]{0,40}`, on the reasoning that "parallel
# subagents; role 4 could not reach the web" is a role's failure and not the fan-out's.
#
# That bound was defeated four ways in review, and the first case is the one that settles it:
#
#     "parallel subagents; role 4 could not reach the web"   -> subagents
#     "parallel subagents, role 4 could not reach the web"   -> single-pass
#
# The same sentence, one character apart, classified opposite ways. And:
#
#     "spawned the eleven. Every one of them failed to start"   a full stop blocks the denial
#     "subagents were, after three attempts and a timeout, unavailable"   44 chars: too long
#     "parallel fan-out; nothing came back"    no vocabulary word at all, and no bound on
#                                              how many such phrasings exist
#
# The second is the one worth staring at: it defeats the bound BY BEING MORE DETAILED, so a
# terser and less honest line passes where a fuller one fails. That is a gate rewarding the
# wrong behavior, not a threshold needing a tweak.
#
# THE DIAGNOSIS, which is why no setting of the bound would have worked: proximity is
# standing in for GRAMMATICAL ATTACHMENT -- does the denial attach to the fan-out or to one
# role? -- and those two are not distinguishable by distance.
#
#     "parallel subagents could not start"           the fan-out
#     "parallel subagents, role 4 could not start"   a role
#
# Nearly the same span, opposite meanings. Widen the bound and false positives rise; narrow
# it and real denials are missed. A cheap measurable quantity standing in for the property
# that actually matters is the defect this repo names everywhere else; it had been built
# into a gate here.
#
# So: stop parsing the sentence. An unbounded natural-language problem becomes a bounded
# one, every case above becomes unambiguous, and the author states the verdict instead of
# the gate guessing at it. A line that does not fit is `unrecognized` -- refused, with the
# grammar printed -- which is a failure that TEACHES rather than one that misclassifies.
#
# The window for imposing a format is open exactly now: `Execution:` is new as of
# 2026-09-04 and no report anywhere carries one, so this costs no consumer anything. It
# closes the moment the first one does. Diagnosis and design from murderboard-b1.

# Everything up to the first separator, lowercased and squeezed. Separators are authoring
# marks a writer puts in deliberately: an em/en dash, a double hyphen, a spaced hyphen, or
# a second colon. NOT a comma or a semicolon -- "subagents, none of which started" would
# hand back "subagents", which is the misread this design exists to end.
execution_head() {
  token_head "$(execution_line "$1")"
}

# Cut a declaration's value at its first separator. The ONE copy of the separator rules,
# used by token_head and execution_tail alike, so a head and a tail can never be split in
# different places.
token_cut() {
  local raw="$1"
  raw=${raw%%—*}; raw=${raw%%–*}; raw=${raw%%--*}; raw=${raw%% - *}; raw=${raw%%:*}
  printf '%s' "$raw"
}

# The head of any `Label: token — prose` declaration line. Shared by Execution: and Lookup:
# so the two cannot drift into separator rules that disagree.
token_head() {
  local raw="$1"
  [ -n "$raw" ] || return 1
  raw=${raw#*:}
  raw=$(token_cut "$raw")
  # Strip markdown decoration left over on the far side of the label. `**Execution:**
  # subagents` keeps its closing `**` after the colon is cut, and the head would be
  # `** subagents` -- a token match away from being refused for its formatting rather
  # than its content, which is the thing the mode line is careful not to do.
  printf '%s' "$raw" | tr 'A-Z' 'a-z' | tr -s '[:space:]' ' ' \
    | sed -e 's/^[]['"'"'*_|>#[:space:]]*//' -e 's/ *$//'
}

# Everything AFTER the separator. Read for exactly one purpose -- see report_execution.
execution_tail() {
  local raw head
  raw=$(execution_line "$1"); raw=${raw#*:}
  head=$(token_cut "$raw")
  [ "$head" = "$raw" ] && return 1
  printf '%s' "${raw#"$head"}" | tr 'A-Z' 'a-z'
}

report_execution() {
  local head mode
  head=$(execution_head "$1") || { printf 'undeclared\n'; return; }
  mode=${head%%(*}                       # drop a "(forced)" / "(chosen)" qualifier
  mode=$(printf '%s' "$mode" | sed -e 's/ *$//')
  case "$mode" in
    subagents|parallel\ subagents|parallel-subagents) mode=subagents ;;
    single-pass|single\ pass)                          mode=single-pass ;;
    *) printf 'unrecognized\n'; return ;;
  esac

  # ONE DIRECTION ONLY, and the asymmetry is deliberate. A `subagents` head whose prose
  # says the run went inline is a visible self-contradiction worth refusing. A
  # `single-pass` head whose prose mentions a fan-out is almost always saying the fan-out
  # did NOT happen -- "no parallel fan-out" -- and checking it would resurrect the
  # negation problem this design exists to retire.
  #
  # MODE WORDS ONLY, which is what keeps attachment out of this check. "inline", "by hand",
  # "single-pass" can only describe how the RUN went. "could not", "failed", "unavailable"
  # describe a run OR a role, and that ambiguity is the whole attachment problem.
  #
  # ⚠ WHAT THIS GATE THEREFORE DOES NOT CATCH, stated because understating a gate is the
  # same defect as overstating one. A `subagents` head whose prose denies the fan-out in
  # NON-MODE words passes unchecked:
  #
  #     Execution: subagents — spawned the eleven. Every one failed to start
  #     Execution: subagents — parallel fan-out; nothing came back
  #
  # Both record as a full run. A mislabelled head buys exactly that, and this gate cannot
  # take it back: it reads a declaration, and a declaration that is simply false is not
  # something a report-reading check can detect -- the same limit murderboard_agents.py
  # states about a role that types its granted tools back without holding them.
  #
  # DO NOT "FIX" IT BY ADDING DENIAL VOCABULARY TO THE TAIL. The fixture two lines below --
  # "subagents — 11 spawned, role 4 could not reach the web" -- is a role-level failure in
  # a genuinely full run, and it false-positives on precisely that vocabulary. That is the
  # attachment problem again, one layer in, and the argument that killed the proximity
  # bound kills this too: it would trade a stated limit for an unstated false positive.
  # The reasoning is in doc_review_process.md so the next person does not rediscover it.
  # (Boundary identified by murderboard-b1, 2026-09-04, who also argued against fixing it.)
  if [ "$mode" = subagents ] && execution_tail "$1" 2>/dev/null \
     | grep -qE 'single-?pass|single pass|self-review|one-?pass|inline|by hand|myself'; then
    printf 'contradictory\n'; return
  fi
  printf '%s\n' "$mode"
}

# A single-pass run must say WHICH KIND it was, because the two are not the same event:
# CHOSEN is the process working as designed on a one-line deliverable, and FORCED is an
# environment defect that will silently recur on every run until somebody fixes it. A report
# that says only "single-pass" leaves the reader to assume the first, which is the assumption
# that costs nothing to make and everything to be wrong about.
#
# A TOKEN, in the head's parenthetical, for the same reason and after the same failure.
#
# The first version searched the whole report and would have passed on any document
# containing the word "chosen" in ordinary finding prose. The second scoped to the
# declaration line and read the two sides as symmetrical, which they are not: `forced` was
# a list of idioms while `chosen` held `small`, `short`, `caption`, `one-liner` -- words
# describing the DELIVERABLE. A forced run also has a short deliverable, so any forced run
# phrased outside the idiom list that mentioned its own brevity was filed as a deliberate
# judgment call. Four of five constructed forced runs classified as `chosen`, including
# "Task tool errored out, small deliverable" -- a recurring environment defect recorded as
# a choice, which is the single outcome this field exists to prevent.
#
# Both failures were the gate inferring an answer only the author has. So it is stated:
# `single-pass (forced)` or `single-pass (chosen)`, and the prose after the separator says
# forced by WHAT or chosen WHY without being parsed for it.
execution_cause() {
  local head
  head=$(execution_head "$1") || { printf 'unstated\n'; return; }
  case "$head" in
    *\(forced\)*) printf 'forced\n' ;;
    *\(chosen\)*) printf 'chosen\n' ;;
    *)            printf 'unstated\n' ;;
  esac
}

# THE LOOKUP LINE. Execution: records whether there was more than one reviewer. This one
# records whether the two roles whose sources live OUTSIDE the repository -- 2 (DOI or Die)
# and 6 (RTFM) -- could actually reach them. The ledger cannot show it and neither can the
# grants gate: a role missing WebFetch declares `GRANT 2 MISMATCH`, which is honest and
# deliberately not fatal (a fallback run is a real run), and then returns prose about
# citations it could not resolve. Observed 2026-10-14 (issue #74): the project's settings
# denied WebFetch, curl and wget; role 2 matched each DOI against the paper's own saved text
# instead of resolving it, and this gate and the grants gate both passed.
#
# What stops the run is the PROBE in the skill, before the fan-out. This line is the record
# of that probe, and the gate holds the record to it:
#
#     Lookup: live — curl to doi.org and Crossref; all three probe answers right
#     Lookup: live — PubMed connector granted to role 2; a deliverable citing papers only
#     Lookup: not needed — the deliverable cites nothing and rests on no outside method
#
# `live` names no tool on purpose: any route that passes the probe is a route, and a gate
# demanding WebFetch would fail a role 2 granted a working connector. The tool's name is not
# the capability. What `live` must have is the probe's reply, `00-lookup-probe.md`, in the
# archive the record names -- the one part of "the probe ran" a report-reading gate can check.
#
# `unavailable` FAILS, always, flag or no flag. A run that could not look anything up did
# not do role 2's job, and the probe exists so that it stops there; a finished record that
# says `unavailable` is a record of the stop being skipped.
#
# Same token parser as Execution: -- token stated, prose after the separator never read -- for
# the reasons written at execution_head. The LINE match is wider, because here a missed line
# is a missed failure: a list bullet (`- Lookup:`), a numbered item, a heading mark and a
# bolded key (`**Lookup**:`) all count. And ANY Lookup: line saying `unavailable` decides it,
# wherever it sits, so a quoted `live` earlier in the report cannot mask a real `unavailable`.
# The reverse -- a quoted `unavailable` above a real `live` -- fails closed, and the message
# says which line it read. Undeclared exits 0 so older records keep passing, and
# --require-lookup is how a project opts in.
lookup_grammar() {
  printf '%s  The token is parsed; everything after the dash is yours and never read:\n' "$RED" >&2
  printf '      Lookup: live — curl to doi.org and Crossref; probe answers right\n' >&2
  printf '      Lookup: live — PubMed connector granted to role 2\n' >&2
  printf '      Lookup: not needed — no references, attribution or outside method%s\n' "$RST" >&2
}

lookup_lines() {
  grep -iE '^[[:space:]]*([-+*_|>#[:space:]]|[0-9]+\.)*Lookup[*_]*:' "$1" 2>/dev/null
}

report_lookup() {
  local line head first=
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    head=$(token_head "$line") || continue
    [ "$head" = unavailable ] && { printf 'unavailable\n'; return; }
    [ -n "$first" ] || first=$head
  done <<EOF
$(lookup_lines "$1")
EOF
  [ -n "$first" ] || { printf 'undeclared\n'; return; }
  case "$first" in
    live)                              printf 'live\n' ;;
    not\ needed|not-needed)            printf 'not needed\n' ;;
    *)                                 printf 'unrecognized\n' ;;
  esac
}

# THE REPORTS LINE. The ledger says a role ran. The record's prose says what the review
# concluded. Neither is what the role actually returned, and until this existed there was
# nowhere in a run record for that difference to show up -- so a review that archived all
# eleven role reports and a review that archived none produced records a reader could not
# tell apart. Observed 2026-09 (appendix): three murderboards in one thread summarized their
# role reports into the record and kept none, one round is gone for good, and for one run the
# harness DID write a file per agent and every one of them was 0 bytes. An archive that exists
# and an archive with content in it are different facts.
#
# Same posture as the mode line, with one deliberate asymmetry:
#   undeclared            -> reported as undeclared, exits 0 (every older report keeps passing)
#   not preserved         -> warned about, exits 0; --require-reports makes it a failure
#   a path that resolves  -> every role must have a non-empty file, ALWAYS
#   a path that does not  -> FAILURE, always, flag or no flag
# The last one is the "cited but missing" case: a record pointing at an archive that is not
# there is worse than one admitting it has none, because it reads as the complete run.
reports_decl() {
  awk '{
    line = $0
    gsub(/[*`_|>]/, "", line)
    sub(/^[ \t]+/, "", line)
    sub(/^-[ \t]+/, "", line)
    if (tolower(substr(line, 1, 8)) == "reports:") {
      v = substr(line, 9)
      sub(/^[ \t]+/, "", v); sub(/[ \t]+$/, "", v)
      print v
      exit
    }
  }' "$1" 2>/dev/null
}

# The archive directory, resolved the way a reader would: beside the report first, then from
# the repo root. A record names its archive relative to whichever of those it was written from.
resolve_reports_dir() {
  local decl="$1" report="$2" base root
  case "$decl" in
    /*) [ -d "$decl" ] && { printf '%s\n' "$decl"; return 0; } ;;
  esac
  base=$(dirname "$report")
  [ -d "$base/$decl" ] && { printf '%s\n' "$base/$decl"; return 0; }
  root=$(repo_root)
  [ -d "$root/$decl" ] && { printf '%s\n' "$root/$decl"; return 0; }
  [ -d "$decl" ] && { printf '%s\n' "$decl"; return 0; }
  return 1
}

# Match a file to a role by its LEADING NUMBER -- "01-prove-it.md", "1-prove-it.md", "11_x.md".
# By number and not by nickname on purpose: the nickname already appears inside every role's
# report (each one quotes its own checklist), so a name match would pair role 3's file with
# role 4 as readily as with role 3.
role_report_file() {
  local dir="$1" num="$2" f base n
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    base=${f##*/}
    case "$base" in [0-9]*) ;; *) continue ;; esac
    n=${base%%[!0-9]*}
    [ -n "$n" ] || continue
    if [ "$((10#$n))" = "$num" ]; then printf '%s\n' "$f"; return 0; fi
  done
  return 1
}

# 0 = every role has a non-empty file, 1 = one does not.
check_reports_dir() {
  local dir="$1" missing=0 empty=0 total=0 num ttl f
  while IFS=$'\t' read -r num ttl; do
    [ -n "$num" ] || continue
    total=$((total + 1))
    if f=$(role_report_file "$dir" "$num"); then
      if [ ! -s "$f" ]; then
        printf '%s  EMPTY role %s — %s is 0 bytes%s\n' "$RED" "$num" "$f" "$RST" >&2
        empty=$((empty + 1))
      fi
    else
      printf '%s  NO REPORT for role %s — %s (nothing in %s starts with %s)%s\n' \
             "$RED" "$num" "$ttl" "$dir" "$num" "$RST" >&2
      missing=$((missing + 1))
    fi
  done <<EOF
$(roster)
EOF
  [ "$total" -gt 0 ] || return 1
  if [ "$((missing + empty))" -gt 0 ]; then
    printf '%smurderboard: %s of %s role reports usable in %s — %s missing, %s empty%s\n' \
           "$RED" "$((total - missing - empty))" "$total" "$dir" "$missing" "$empty" "$RST" >&2
    printf '%s  a summarized report is not an archived one, and a 0-byte file is not a report%s\n' \
           "$RED" "$RST" >&2
    return 1
  fi
  return 0
}

cmd_check() {
  local report="$1" missing=0 total=0 num ttl nick mode execution cause lookup
  local decl dir reports
  resolve_process
  [ -r "$report" ] || die "murderboard_roster: cannot read report $report"

  while IFS=$'\t' read -r num ttl; do
    [ -n "$num" ] || continue
    total=$((total + 1))
    # nickname = the quoted name inside the title, if present
    nick=$(printf '%s' "$ttl" | sed -n 's/.*"\(.*\)\.".*/\1/p')
    if [ -n "$nick" ] && grep -qiF "$nick" "$report" 2>/dev/null; then continue; fi
    # fall back to the role NUMBER used as a ROW LABEL: "| 3 |", "3. ", "role 3 |".
    # ANCHORED at line start on purpose. An unanchored number match is a vacuous pass:
    # a report saying "11 findings" would satisfy role 11 without ever running it.
    if grep -qiE "^\|?[[:space:]]*(role|agent)?[[:space:]]*$num[[:space:]]*[|.):]" "$report" 2>/dev/null; then continue; fi
    printf '%s  MISSING role %s — %s%s\n' "$RED" "$num" "$ttl" "$RST" >&2
    missing=$((missing + 1))
  done <<EOF
$(roster)
EOF

  [ "$total" -gt 0 ] || die "murderboard_roster: parsed 0 roles from $PROCESS — refusing to pass vacuously"

  if [ "$missing" -gt 0 ]; then
    printf '%smurderboard: report accounts for %s of %s roles — %s MISSING%s\n' \
           "$RED" "$((total - missing))" "$total" "$missing" "$RST" >&2
    return 1
  fi

  mode=$(report_mode "$report")
  case "$mode" in
    retrospective)
      if ! has_stopping_reason "$report"; then
        printf '%smurderboard: mode is retrospective but the report states no stopping reason%s\n' \
               "$RED" "$RST" >&2
        printf '%s  say which round it stopped at and why repair was unavailable — otherwise\n' "$RED" >&2
        printf '  a truncated run is indistinguishable from a complete one%s\n' "$RST" >&2
        return 1
      fi
      ;;
    undeclared)
      if [ "$REQUIRE_MODE" = 1 ]; then
        printf '%smurderboard: report declares no Mode: line (--require-mode)%s\n' "$RED" "$RST" >&2
        printf '%s  add "Mode: standard" or "Mode: retrospective"; all %s roles ran, but nothing\n' "$RED" "$total" >&2
        printf '  in the report says whether the LOOP finished%s\n' "$RST" >&2
        return 1
      fi
      ;;
  esac

  execution=$(report_execution "$report")
  case "$execution" in
    single-pass)
      cause=$(execution_cause "$report")
      if [ "$cause" = unstated ]; then
        printf '%smurderboard: execution is single-pass but does not say which kind%s\n' \
               "$RED" "$RST" >&2
        printf '%s  write "single-pass (forced)" if subagents were unavailable — an\n' "$RED" >&2
        printf '  environment defect that will recur on every run until it is fixed — or\n' >&2
        printf '  "single-pass (chosen)" if the deliverable did not warrant a fan-out.\n' >&2
        printf '  Unqualified it reads as chosen, which is the assumption that costs\n' >&2
        printf '  nothing to make and everything to be wrong about%s\n' "$RST" >&2
        return 1
      fi
      execution="single-pass ($cause)"
      ;;
    contradictory)
      printf '%smurderboard: the Execution: line declares subagents and then describes a%s\n' "$RED" "$RST" >&2
      printf '%s  single pass. Reported, never resolved: picking one is how the wrong one\n' "$RED" >&2
      printf '  reaches the record. State the mode the ELEVEN ROLES ran in — a triage pass,\n' >&2
      printf '  or one role re-reading its own work, does not change it%s\n' "$RST" >&2
      return 1
      ;;
    unrecognized)
      printf '%smurderboard: the Execution: line does not start with a known token%s\n' "$RED" "$RST" >&2
      printf '%s  The token is parsed; everything after the dash is yours and is never read:\n' "$RED" >&2
      printf '      Execution: subagents — 11 spawned, role 4 could not reach the web\n' >&2
      printf '      Execution: single-pass (forced) — the Agent tool was unavailable\n' >&2
      printf '      Execution: single-pass (chosen) — a one-line caption\n' >&2
      printf '  Earlier versions inferred this from the prose and got it wrong in both\n' >&2
      printf '  directions, so the verdict is stated rather than guessed at%s\n' "$RST" >&2
      return 1
      ;;
    undeclared)
      if [ "$REQUIRE_EXECUTION" = 1 ]; then
        printf '%smurderboard: report declares no Execution: line (--require-execution)%s\n' "$RED" "$RST" >&2
        printf '%s  all %s roles ran, but nothing says whether there was ever more than one\n' "$RED" "$total" >&2
        printf '  reviewer. Eleven roles played by one agent is a real review and a weaker\n' >&2
        printf '  adversary, and the report cannot currently tell them apart%s\n' "$RST" >&2
        return 1
      fi
      ;;
  esac

  lookup=$(report_lookup "$report")
  case "$lookup" in
    unavailable)
      # ALWAYS, flag or no flag -- see lookup_lines.
      printf '%smurderboard: a Lookup: line says unavailable — this always fails%s\n' "$RED" "$RST" >&2
      printf '%s  Roles 2 and 6 could not reach any source outside the repository, so their\n' "$RED" >&2
      printf '  checks did not happen; a reference never looked up is not a checked one.\n' >&2
      printf '  To fix it:\n' >&2
      printf '    1. murderboard_subagents.sh --lookup --explain   (finds a blocking rule)\n' >&2
      printf '    2. give roles 2 and 6 a working route: web access, or a literature\n' >&2
      printf '       connector added to their grant (see doc_review_process.md)\n' >&2
      printf '    3. run the lookup probe again, then the whole review\n' >&2
      printf '  If the deliverable cites nothing and uses no outside method or tool, write\n' >&2
      printf '  "Lookup: not needed" instead.%s\n' "$RST" >&2
      return 1
      ;;
    unrecognized)
      printf '%smurderboard: the Lookup: line does not start with a known token%s\n' "$RED" "$RST" >&2
      lookup_grammar
      return 1
      ;;
    undeclared)
      if [ "$REQUIRE_LOOKUP" = 1 ]; then
        printf '%smurderboard: report declares no Lookup: line (--require-lookup)%s\n' "$RED" "$RST" >&2
        printf '%s  Roles 2 and 6 ran, but nothing says whether they could reach a source\n' "$RED" >&2
        printf '  outside the repository; a role that could not still writes about one.%s\n' "$RST" >&2
        lookup_grammar
        return 1
      fi
      ;;
  esac

  # --- the role reports -----------------------------------------------------
  decl=$(reports_decl "$report")
  if [ -z "$decl" ]; then
    reports=undeclared
    if [ "$REQUIRE_REPORTS" = 1 ]; then
      printf '%smurderboard: report declares no reports: line (--require-reports)%s\n' "$RED" "$RST" >&2
      printf '%s  add "reports: <dir>/" or "reports: not preserved"; all %s roles are in the\n' "$RED" "$total" >&2
      printf '  ledger, but nothing says whether what they SAID still exists%s\n' "$RST" >&2
      return 1
    fi
  elif printf '%s' "$decl" | grep -qiE '^(not[ -]?(preserved|archived|kept)|none|unpreserved|lost)'; then
    reports='not preserved'
    printf '%smurderboard: role reports declared NOT PRESERVED — the record is the only copy%s\n' \
           "$RED" "$RST" >&2
    if [ "$REQUIRE_REPORTS" = 1 ]; then return 1; fi
  else
    decl=$(printf '%s' "$decl" | awk '{print $1}')
    if ! dir=$(resolve_reports_dir "$decl" "$report"); then
      # ALWAYS a failure, flag or no flag: a record pointing at an archive that is not
      # there reads as the complete run, which is worse than one admitting it kept none.
      printf '%smurderboard: report names a role-report archive that does not exist: %s%s\n' \
             "$RED" "$decl" "$RST" >&2
      return 1
    fi
    check_reports_dir "$dir" || return 1
    reports="$dir"
    # `live` claims the probe ran. Its reply is the evidence, filed beside the role reports
    # as 00-lookup-probe.md, and an archive without it holds the claim and not the proof.
    if [ "$lookup" = live ]; then
      local probe
      if ! probe=$(role_report_file "$dir" 0) || [ ! -s "$probe" ]; then
        printf '%smurderboard: Lookup: live, but %s holds no 00-lookup-probe.md%s\n' "$RED" "$dir" "$RST" >&2
        printf '%s  Save the lookup probe'\''s reply there, verbatim, as the role reports are;\n' "$RED" >&2
        printf '  without it, nothing shows that the probe ran.%s\n' "$RST" >&2
        return 1
      fi
    fi
  fi

  printf '%smurderboard: all %s roles accounted for in %s (mode: %s, execution: %s, lookup: %s, reports: %s)%s\n' \
         "$GRN" "$total" "$report" "$mode" "$execution" "$lookup" "$reports" "$RST"
  return 0
}

# --- selftest ----------------------------------------------------------------
# Every branch must be able to FIRE. A check that cannot fail is worse than no check.
cmd_selftest() {
  local pass=0 fail=0
  # NOT `local`: the EXIT trap runs after this function's scope is gone, and under
  # `set -u` a local would make the trap itself die with "tmp: unbound variable".
  MB_TMP=$(mktemp -d) || die "selftest: mktemp failed"
  local tmp="$MB_TMP"
  trap 'rm -rf "$MB_TMP"' EXIT

  t() { # t <name> <expected-exit> <command...>
    local name="$1" want="$2"; shift 2
    local got=0
    # SUBSHELL, not a bare call: die() exits, and a bare call would take the whole
    # selftest with it — the "unreadable report" case killed the run at test 5 of 7
    # and the summary line never printed. A harness that dies mid-suite reports a
    # PASS for every test it never reached.
    ( "$@" ) >/dev/null 2>&1 || got=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); printf '  ok   %s\n' "$name"
    else fail=$((fail+1)); printf '  %sFAIL%s %s (want exit %s, got %s)\n' "$RED" "$RST" "$name" "$want" "$got"; fi
  }

  # a miniature process file with 3 roles, plus the decoys that broke the naive grep
  cat > "$tmp/doc_review_process.md" <<'MB'
# process
## The process
1. **Draft** the document.
2. **Review** — run the team.
## The review team
1. **Claim & data verifier — "Prove It."** blah
2. **Citation validator — "DOI or Die."** blah
   1. **Not a role** — indented sub-item
3. **Line editor — "Kill Your Darlings."** blah
## Literature handling
1. **Check the library FIRST.** blah
MB

  PROCESS="$tmp/doc_review_process.md"
  local n; n=$(roster | grep -c .)
  if [ "$n" = 3 ]; then pass=$((pass+1)); printf '  ok   roster parses 3 roles, ignores decoys\n'
  else fail=$((fail+1)); printf '  %sFAIL%s roster parsed %s roles, want 3\n' "$RED" "$RST" "$n"; fi

  printf 'Prove It / DOI or Die / Kill Your Darlings — all clean\n' > "$tmp/full.md"
  t 'complete report passes'            0 cmd_check "$tmp/full.md"

  printf 'Prove It / DOI or Die — clean\n' > "$tmp/short.md"
  t 'report missing a role FAILS'       1 cmd_check "$tmp/short.md"

  printf '| 1 | ok |\n| 2 | ok |\n| 3 | ok |\n' > "$tmp/numeric.md"
  t 'numeric table form passes'         0 cmd_check "$tmp/numeric.md"

  printf 'nothing to see here\n' > "$tmp/empty.md"
  t 'empty report FAILS'                1 cmd_check "$tmp/empty.md"

  t 'unreadable report -> exit 2'       2 cmd_check "$tmp/nope.md"

  # --- the mode line ---------------------------------------------------------
  # BACKWARD COMPATIBILITY IS THE FIRST TEST. This gate is vendored; every report
  # written before the mode line existed must keep passing, or the change lands as
  # a wall of red in projects that did nothing wrong.
  t 'undeclared mode still passes'      0 cmd_check "$tmp/full.md"

  printf 'Prove It / DOI or Die / Kill Your Darlings — all clean\nMode: standard\n' > "$tmp/std.md"
  t 'Mode: standard passes'             0 cmd_check "$tmp/std.md"

  # Retrospective WITHOUT a stopping reason is the exact failure this exists to catch:
  # a truncated run that reads as a complete one.
  printf 'Prove It / DOI or Die / Kill Your Darlings — all clean\nMode: retrospective\n' > "$tmp/retro_bad.md"
  t 'retrospective without a reason FAILS' 1 cmd_check "$tmp/retro_bad.md"

  printf 'Prove It / DOI or Die / Kill Your Darlings — all clean\nMode: retrospective\nStopped at round 1 of 3; the artifact is published.\n' > "$tmp/retro_ok.md"
  t 'retrospective with a reason passes' 0 cmd_check "$tmp/retro_ok.md"

  # Formatting is generous on purpose -- bold, table cell, blockquote all count --
  # because a gate that only accepts one markdown dialect gets satisfied by
  # reformatting rather than by declaring.
  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\n**Mode:** standard\n' > "$tmp/bold.md"
  t 'bolded mode line is recognized'    0 cmd_check "$tmp/bold.md"
  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\n> Mode: standard\n' > "$tmp/quoted.md"
  t 'blockquoted mode line recognized'  0 cmd_check "$tmp/quoted.md"

  REQUIRE_MODE=1
  t '--require-mode: undeclared FAILS'  1 cmd_check "$tmp/full.md"
  t '--require-mode: standard passes'   0 cmd_check "$tmp/std.md"
  t '--require-mode: retrospective ok'  0 cmd_check "$tmp/retro_ok.md"
  REQUIRE_MODE=0

  # --- the execution line ----------------------------------------------------
  # Backward compatibility first, for the same reason as the mode line: this file is
  # vendored, and a change that reddens every existing report in a consumer that did
  # nothing wrong gets the gate removed rather than the reports fixed.
  t 'undeclared execution still passes' 0 cmd_check "$tmp/full.md"

  local roles='Prove It / DOI or Die / Kill Your Darlings — all clean'
  printf '%s\nExecution: subagents — one per role, all eleven spawned\n' "$roles" > "$tmp/exec_sub.md"
  t 'Execution: subagents passes'       0 cmd_check "$tmp/exec_sub.md"

  # A bare "single-pass" is the failure this exists to catch: it reads as the chosen
  # case, and the forced case is the one that will happen again tomorrow.
  printf '%s\nExecution: single-pass\n' "$roles" > "$tmp/exec_bare.md"
  t 'single-pass with no cause FAILS'   1 cmd_check "$tmp/exec_bare.md"

  printf '%s\nExecution: single-pass (forced) — the Agent tool was unavailable\n' "$roles" > "$tmp/exec_forced.md"
  t 'single-pass (forced) passes'       0 cmd_check "$tmp/exec_forced.md"

  printf '%s\nExecution: single-pass (chosen) — the deliverable is a one-liner\n' "$roles" > "$tmp/exec_chosen.md"
  t 'single-pass (chosen) passes'       0 cmd_check "$tmp/exec_chosen.md"

  # A line that exists and says nothing checkable is worse than no line: it looks like
  # a declaration. It fails WITHOUT --require-execution, unlike a missing line.
  printf '%s\nExecution: yes\n' "$roles" > "$tmp/exec_junk.md"
  t 'unrecognized execution FAILS'      1 cmd_check "$tmp/exec_junk.md"

  printf '%s\n**Execution:** subagents\n' "$roles" > "$tmp/exec_bold.md"
  t 'bolded execution line recognized'  0 cmd_check "$tmp/exec_bold.md"

  # --- constructed inputs, from murderboard-b1's review, 2026-09-04 ------------
  # A peer defeated two successive matchers with lines nobody on this branch had thought
  # to write. They are fixtures because the way this function fails is by looking correct
  # against the phrasings its author happened to imagine.
  #
  # e() asserts on the CLASSIFICATION rather than the exit code: the exit code collapses
  # "read it wrong" and "refused to guess" into the same 1, and the difference between
  # those is the entire design.
  e() { # e <name> <expected-mode> <expected-cause> <line>
    local name="$1" wm="$2" wc="$3" ln="$4" gm gc
    printf '%s\nExecution: %s\n' "$roles" "$ln" > "$tmp/e.md"
    gm=$(report_execution "$tmp/e.md"); gc=$(execution_cause "$tmp/e.md")
    if [ "$gm" = "$wm" ] && [ "$gc" = "$wc" ]; then
      pass=$((pass+1)); printf '  ok   %s\n' "$name"
    else
      fail=$((fail+1)); printf '  %sFAIL%s %s (want %s/%s, got %s/%s)\n' \
        "$RED" "$RST" "$name" "$wm" "$wc" "$gm" "$gc"
    fi
  }

  # THE PAIR THAT SETTLED THE DESIGN. One character apart, classified opposite ways by
  # the proximity parser. Under the token grammar the first is read from its token and
  # the second is refused for having no token -- neither is guessed at.
  e 'semicolon form reads its token'  subagents unstated 'subagents — 11 spawned; role 4 could not reach the web'
  e 'comma form is refused, not read' unrecognized unstated 'parallel subagents, role 4 could not reach the web'

  # Three degraded runs that the proximity parser read as FULL -- the direction that
  # costs the most. A full stop blocked the denial in the first; the second defeated the
  # 40-character bound BY BEING MORE DETAILED, so a terser and less honest line passed
  # where a fuller one failed; the third used a phrasing in no vocabulary at all, and
  # there is no bound on how many such phrasings exist.
  e 'denial in a second sentence'   unrecognized unstated 'spawned the eleven. Every one of them failed to start'
  e 'denial past the length bound'  unrecognized unstated 'subagents were, after three separate attempts and a timeout, unavailable'
  e 'denial in no vocabulary'       unrecognized unstated 'parallel fan-out; nothing came back'

  # The five forced runs that classified as CHOSEN when `chosen` held words describing
  # the DELIVERABLE -- a forced run also has a short deliverable. The cause is a token
  # now, so the artifact prose cannot reach it.
  e 'forced token, prose mentions brevity' single-pass forced 'single-pass (forced) — the Agent tool was unavailable; deliverable was short anyway'
  e 'forced token, "errored out"'          single-pass forced 'single-pass (forced) — Task tool errored out, small deliverable'
  e 'forced token, "concurrency limit"'    single-pass forced 'single-pass (forced) — spawning hit the concurrency limit; a short caption'
  e 'chosen token, prose mentions failure'  single-pass chosen 'single-pass (chosen) — a caption; the fan-out would have worked fine'
  e 'no token -> cause is unstated'         single-pass unstated 'single-pass — subagents were unavailable'

  # THE PROSE IS NOT READ, and that is the whole point. A `subagents` token followed by
  # any description of role-level trouble stays `subagents`.
  e 'prose about a role never demotes the token' subagents unstated 'subagents — every one of them was slow and role 4 could not reach the web'

  # ONE DIRECTION OF CONTRADICTION. A subagents token whose prose says the run went
  # inline is a visible self-contradiction and is refused, never resolved.
  e 'token says subagents, prose says inline' contradictory unstated 'subagents — fell back to inline after the first failure'

  # THE DOCUMENTED LIMIT, PINNED. These three are NOT bugs and must not be "fixed": a
  # mislabelled head whose prose denies the fan-out in non-mode words records as a full
  # run, because catching it needs denial vocabulary in the tail and the fourth case here
  # is a role-level failure in a genuinely full run that false-positives on exactly that.
  # If someone later makes any of these `contradictory`, the fourth will go red and say so
  # -- which is the point of asserting a limit rather than only writing it down.
  e 'LIMIT: total failure under a subagents head'  subagents unstated 'subagents — spawned the eleven. Every one failed to start'
  e 'LIMIT: denial past the head'                  subagents unstated 'subagents — were, after three attempts and a timeout, unavailable'
  e 'LIMIT: denial in no vocabulary'               subagents unstated 'subagents — parallel fan-out; nothing came back'
  e 'and why it cannot be fixed in the tail'       subagents unstated 'subagents — 11 spawned, role 4 could not reach the web'
  # ...and the reverse is NOT a contradiction: a single-pass line mentioning a fan-out is
  # almost always saying the fan-out did not happen.
  e 'single-pass may mention the fan-out'  single-pass forced 'single-pass (forced) — no parallel fan-out was available'

  # The cause must come from the DECLARATION, not from anywhere in the report. Searching
  # the whole file for "chosen" passes on ordinary finding prose, and a bare declaration
  # then buys a pass off a word it never said.
  printf '%s\nExecution: single-pass\n\nF1: the wording chosen here overstates the result.\n' "$roles" > "$tmp/exec_leak.md"
  t 'a bare declaration cannot borrow a cause from the body' 1 cmd_check "$tmp/exec_leak.md"

  REQUIRE_EXECUTION=1
  t '--require-execution: undeclared FAILS' 1 cmd_check "$tmp/full.md"
  t '--require-execution: subagents ok'     0 cmd_check "$tmp/exec_sub.md"
  t '--require-execution: forced ok'        0 cmd_check "$tmp/exec_forced.md"
  REQUIRE_EXECUTION=0

  # Neither declaration may rescue a missing role, and the two must not rescue each
  # other: coverage is checked first, then mode, then execution, independently.
  printf 'Prove It / DOI or Die — clean\nExecution: subagents\n' > "$tmp/short_exec.md"
  t 'declared execution does NOT excuse a missing role' 1 cmd_check "$tmp/short_exec.md"
  printf '%s\nMode: retrospective\nExecution: subagents\n' "$roles" > "$tmp/retro_exec.md"
  t 'a good execution line does NOT excuse a missing stopping reason' 1 cmd_check "$tmp/retro_exec.md"

  # The mode must never rescue a missing role: coverage is checked first and
  # independently, or "Mode: standard" becomes a way to buy a pass.
  printf 'Prove It / DOI or Die — clean\nMode: standard\n' > "$tmp/short_std.md"
  t 'declared mode does NOT excuse a missing role' 1 cmd_check "$tmp/short_std.md"

  # --- the reports line ------------------------------------------------------
  # BACKWARD COMPATIBILITY FIRST, for the same reason the mode line tests it first:
  # this gate is vendored, and every record written before an archive was asked for
  # must keep passing or the change lands as red in projects that did nothing wrong.
  t 'undeclared reports still passes'   0 cmd_check "$tmp/full.md"

  mkdir -p "$tmp/roles"
  printf 'role 1 said things\n' > "$tmp/roles/01-prove-it.md"
  printf 'role 2 said things\n' > "$tmp/roles/02-doi-or-die.md"
  printf 'role 3 said things\n' > "$tmp/roles/03-kill-your-darlings.md"
  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\nreports: roles/\n' > "$tmp/rep_ok.md"
  t 'reports: a full archive passes'    0 cmd_check "$tmp/rep_ok.md"

  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\n**reports:** roles/\n' > "$tmp/rep_bold.md"
  t 'bolded reports line is recognized' 0 cmd_check "$tmp/rep_bold.md"

  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\nreports: roles/ (3 files)\n' > "$tmp/rep_count.md"
  t 'trailing count after the path is ignored' 0 cmd_check "$tmp/rep_count.md"

  # THE HEADLINE CASE. The harness wrote a file per agent and every one was 0 bytes.
  # A check that only asks whether the file exists passes that run.
  : > "$tmp/roles/02-doi-or-die.md"
  t 'a 0-byte role report FAILS'        1 cmd_check "$tmp/rep_ok.md"
  printf 'role 2 said things\n' > "$tmp/roles/02-doi-or-die.md"

  mv "$tmp/roles/03-kill-your-darlings.md" "$tmp/roles/.hidden-away"
  t 'a role with no report at all FAILS' 1 cmd_check "$tmp/rep_ok.md"
  mv "$tmp/roles/.hidden-away" "$tmp/roles/03-kill-your-darlings.md"

  # "Cited but missing" -- a record naming an archive that is not there. This fails
  # WITHOUT the flag, unlike every other reports verdict, because it reads to a reader
  # as the complete run: worse than a record admitting it kept nothing.
  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\nreports: nowhere-at-all/\n' > "$tmp/rep_gone.md"
  t 'archive named but absent FAILS without the flag' 1 cmd_check "$tmp/rep_gone.md"

  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\nreports: not preserved\n' > "$tmp/rep_none.md"
  t 'reports: not preserved passes (declared)' 0 cmd_check "$tmp/rep_none.md"

  # A declared archive must never rescue a missing role, for the same reason the mode
  # line must not: otherwise the declaration becomes a way to buy a pass.
  printf 'Prove It / DOI or Die — clean\nreports: roles/\n' > "$tmp/rep_short.md"
  t 'declared reports do NOT excuse a missing role' 1 cmd_check "$tmp/rep_short.md"

  REQUIRE_REPORTS=1
  t '--require-reports: undeclared FAILS'    1 cmd_check "$tmp/full.md"
  t '--require-reports: not preserved FAILS' 1 cmd_check "$tmp/rep_none.md"
  t '--require-reports: full archive passes' 0 cmd_check "$tmp/rep_ok.md"
  REQUIRE_REPORTS=0

  # --- the lookup line -------------------------------------------------------
  # Backward compatibility first, as for every other declaration line.
  t 'undeclared lookup still passes'    0 cmd_check "$tmp/full.md"

  L='Prove It / DOI or Die / Kill Your Darlings — clean\n'
  printf '%b' "${L}Lookup: live — curl to doi.org and Crossref; probe answers right\n" > "$tmp/lk_live.md"
  t 'Lookup: live passes'               0 cmd_check "$tmp/lk_live.md"
  # THE ROUTE IS NOT THE TOOL. A role 2 granted a working connector, with no WebFetch, is a
  # live lookup; a gate demanding WebFetch would fail it.
  printf '%b' "${L}Lookup: live — PubMed connector granted to role 2; WebFetch denied\n" > "$tmp/lk_mcp.md"
  t 'live through a connector passes'   0 cmd_check "$tmp/lk_mcp.md"
  printf '%b' "${L}**Lookup:** live — WebFetch\n" > "$tmp/lk_bold.md"
  t 'bolded lookup line recognized'     0 cmd_check "$tmp/lk_bold.md"
  printf '%b' "${L}Lookup: not needed — no references, attribution or outside method\n" > "$tmp/lk_nn.md"
  t 'Lookup: not needed passes'         0 cmd_check "$tmp/lk_nn.md"

  # THE HEADLINE CASE (issue #74): the run continued past a role that could not reach a
  # source, and every gate stayed green. `unavailable` fails WITHOUT the flag -- in every
  # form a record actually writes it, since a missed line here is a missed failure. The #74
  # record wrote its declaration lines as list bullets.
  printf '%b' "${L}Lookup: unavailable — no WebFetch, curl denied\n" > "$tmp/lk_un.md"
  t 'Lookup: unavailable FAILS without the flag' 1 cmd_check "$tmp/lk_un.md"
  printf '%b' "${L}- Lookup: unavailable — no WebFetch\n" > "$tmp/lk_un_li.md"
  t 'a bulleted unavailable FAILS'      1 cmd_check "$tmp/lk_un_li.md"
  printf '%b' "${L}- **Lookup**: unavailable\n" > "$tmp/lk_un_bk.md"
  t 'a bold-key bulleted unavailable FAILS' 1 cmd_check "$tmp/lk_un_bk.md"
  printf '%b' "${L}3. Lookup: unavailable\n" > "$tmp/lk_un_no.md"
  t 'a numbered unavailable FAILS'      1 cmd_check "$tmp/lk_un_no.md"
  printf '%b' "${L}## Lookup: unavailable\n" > "$tmp/lk_un_h.md"
  t 'a heading unavailable FAILS'       1 cmd_check "$tmp/lk_un_h.md"
  # A quoted `live` earlier in the report must not mask the real `unavailable` below it.
  printf '%b' "${L}\`\`\`\nLookup: live — an example\n\`\`\`\nLookup: unavailable — the real one\n" > "$tmp/lk_mask.md"
  t 'a quoted live cannot mask a real unavailable' 1 cmd_check "$tmp/lk_mask.md"
  # And a bulleted live is a declaration too, under the flag.
  printf '%b' "${L}- Lookup: live — WebFetch\n" > "$tmp/lk_li.md"
  t 'a bulleted live is recognized'     0 cmd_check "$tmp/lk_li.md"

  # `live` with an archive must carry the probe's reply: the claim and its evidence.
  mkdir -p "$tmp/lkroles"
  cp "$tmp/roles/"*.md "$tmp/lkroles/"
  printf '%b' "${L}Lookup: live — WebFetch\nreports: lkroles/\n" > "$tmp/lk_arch.md"
  t 'live + archive without 00-lookup-probe FAILS' 1 cmd_check "$tmp/lk_arch.md"
  : > "$tmp/lkroles/00-lookup-probe.md"
  t 'live + an EMPTY 00-lookup-probe FAILS' 1 cmd_check "$tmp/lk_arch.md"
  printf 'FOUND …\nNOT FOUND\n' > "$tmp/lkroles/00-lookup-probe.md"
  t 'live + archive with the probe reply passes' 0 cmd_check "$tmp/lk_arch.md"
  # not needed claims no probe, so it needs no reply on file.
  printf '%b' "${L}Lookup: not needed — nothing cited\nreports: roles/\n" > "$tmp/lk_nn_arch.md"
  t 'not needed + archive needs no probe reply' 0 cmd_check "$tmp/lk_nn_arch.md"
  # Prose after the separator is never read, in either direction: "unavailable" in the tail
  # of a `live` line is a role-level remark, not a verdict, and does not fail it.
  printf "%b" "${L}Lookup: live — PubMed connector; WebFetch unavailable\n" > "$tmp/lk_tail.md"
  t 'unavailable in the prose does not override live' 0 cmd_check "$tmp/lk_tail.md"
  # A token the gate does not know is refused, never guessed at.
  printf "${L}Lookup: offline matching against saved full text\n" > "$tmp/lk_junk.md"
  t 'unrecognized lookup FAILS'         1 cmd_check "$tmp/lk_junk.md"
  printf "${L}Lookup: partially — some DOIs resolved\n" > "$tmp/lk_part.md"
  t 'a hedge is not a token'            1 cmd_check "$tmp/lk_part.md"

  REQUIRE_LOOKUP=1
  t '--require-lookup: undeclared FAILS'  1 cmd_check "$tmp/full.md"
  t '--require-lookup: live passes'       0 cmd_check "$tmp/lk_live.md"
  t '--require-lookup: not needed passes' 0 cmd_check "$tmp/lk_nn.md"
  REQUIRE_LOOKUP=0

  # A declared lookup must never rescue a missing role.
  printf 'Prove It / DOI or Die — clean\nLookup: live — WebFetch\n' > "$tmp/lk_short.md"
  t 'declared lookup does NOT excuse a missing role' 1 cmd_check "$tmp/lk_short.md"

  # a process file with no team section must NOT pass vacuously
  printf '# nothing\n' > "$tmp/noteam.md"
  PROCESS="$tmp/noteam.md"
  t 'zero parsed roles -> exit 2'       2 cmd_check "$tmp/full.md"

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

# --- args --------------------------------------------------------------------
CMD=
while [ $# -gt 0 ]; do
  case "$1" in
    --process) PROCESS="${2:-}"; shift 2 ;;
    --selftest) CMD=selftest; shift ;;
    list|count) CMD="$1"; shift ;;
    --require-mode) REQUIRE_MODE=1; shift ;;
    --require-execution) REQUIRE_EXECUTION=1; shift ;;
    --require-reports) REQUIRE_REPORTS=1; shift ;;
    --require-lookup) REQUIRE_LOOKUP=1; shift ;;
    check)
      CMD=check; shift
      # The flag may sit either side of `check`, because both read naturally and a
      # gate that rejects the order someone typed teaches them to stop running it.
      while [ $# -gt 0 ]; do
        case "$1" in
          --require-mode) REQUIRE_MODE=1; shift ;;
          --require-execution) REQUIRE_EXECUTION=1; shift ;;
          --require-reports) REQUIRE_REPORTS=1; shift ;;
          --require-lookup) REQUIRE_LOOKUP=1; shift ;;
          *) break ;;
        esac
      done
      REPORT="${1:-}"
      [ -n "${REPORT:-}" ] || die "usage: murderboard_roster.sh check [--require-mode] [--require-execution] [--require-reports] [--require-lookup] REPORT.md"
      shift ;;
    -h|--help) sed -n '2,/^# Project-neutral/p' "$0"; exit 0 ;;
    *) die "murderboard_roster: unknown argument '$1'" ;;
  esac
done

case "${CMD:-}" in
  list)     cmd_list ;;
  count)    cmd_count ;;
  check)    cmd_check "$REPORT" ;;
  selftest) cmd_selftest ;;
  *)        sed -n '2,/^# Project-neutral/p' "$0"; exit 2 ;;
esac
