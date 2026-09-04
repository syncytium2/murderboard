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
#   murderboard_roster.sh --process PATH ...    use this process file (default: autodetect)
#   murderboard_roster.sh --selftest            prove every branch can still fire
#
# EXIT CODES   0 = ok   1 = roles missing, or a mode/execution line is missing or incoherent
#              2 = could not determine
#
# Project-neutral: no hardcoded consumer paths.

set -u
LC_ALL=C; export LC_ALL

PROCESS=
REQUIRE_MODE=0
REQUIRE_EXECUTION=0

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

# ONE PREDICATE, TWO CALLERS: does this line say the fan-out did not happen?
#
# Both functions below needed it and the first version of each answered it separately and
# wrongly. `report_execution` matched substrings with no regard to negation, so
# "subagents unavailable" counted as evidence OF subagents -- a degraded run read as a full
# one, which is the misclassification this whole field exists to prevent. `execution_cause`
# had a list of unavailability idioms, which is a denylist over unbounded English: any
# forced run phrased outside the list fell through to the next branch.
#
# Proximity, not line-global. "Execution: parallel subagents; role 4 could not reach the
# web" says nothing about the fan-out -- the failure is a role's, and a line-global search
# for "could not" would call that degraded. So the two terms must sit within one clause of
# each other, which `[^.;]{0,40}` enforces: commas are inside a clause, a semicolon or a
# full stop ends one. Matched in both directions, since "no subagents" and "subagents
# unavailable" are the same claim written from either end.
#
# The vocabulary is deliberately about the MECHANISM (denied, timed out, errored, hit a
# limit, fell back) rather than about phrasing, because the phrasings are unbounded and the
# mechanisms are not.
FANOUT_WORDS='sub-?agents?|agent tool|task tool|parallel|fan-?out|spawn'
FANOUT_ABSENT='unavailable|not available|[^[:alnum:]]no[^[:alnum:]]|without|denied|blocked|refused|forbidden|disabled|could not|cannot|can.t|fail|error|timed out|timing out|limit|fell back|fall back|fallback|never ran|did not'

fanout_denied() {
  local s
  s=" $(printf '%s' "$1" | tr 'A-Z' 'a-z') "
  printf '%s' "$s" | grep -qE "($FANOUT_ABSENT)[^.;]{0,40}($FANOUT_WORDS)" && return 0
  printf '%s' "$s" | grep -qE "($FANOUT_WORDS)[^.;]{0,40}($FANOUT_ABSENT)" && return 0
  return 1
}

# "inline", "sequentially", "by hand", "myself" are how a degraded run gets written when
# nobody has been handed this vocabulary, and the first version of this list contained none
# of them -- so the commonest honest phrasings landed in `unrecognized` and hard-failed.
EXEC_DEGRADED='single-?pass|single pass|self-review|self review|one-?pass|inline|sequentially|serially|by hand|myself|alone|solo|in turn'

report_execution() {
  local line lower degraded=0 fanout=0
  line=$(execution_line "$1")
  if [ -z "$line" ]; then printf 'undeclared\n'; return; fi
  lower=$(printf '%s' "$line" | tr 'A-Z' 'a-z')

  printf '%s' "$lower" | grep -qE "$EXEC_DEGRADED" && degraded=1
  printf '%s' "$lower" | grep -qE "$FANOUT_WORDS"  && fanout=1

  # A line claiming BOTH, with the fan-out not denied, is not a line to guess at:
  # "11 parallel agents spawned; role 5 also self-reviewed" is a full run, and
  # "spawned in parallel after a one-pass triage" is a full run, while
  # "single-pass, no parallel fan-out" is a degraded one -- and no substring rule
  # separates them. REPORTED, NEVER RESOLVED, which is the discipline the grants gate
  # already applies to a role that declares two verdicts: picking one is how the wrong
  # one gets laundered into the record. The writer says which; the gate does not choose.
  if [ "$degraded" = 1 ] && [ "$fanout" = 1 ] && ! fanout_denied "$line"; then
    printf 'contradictory\n'; return
  fi
  # A denied fan-out IS the degraded case even when the line never says "single-pass":
  # "subagents unavailable, ran inline" names the mode only by its absence.
  if [ "$degraded" = 1 ] || fanout_denied "$line"; then printf 'single-pass\n'; return; fi
  if [ "$fanout" = 1 ]; then printf 'subagents\n'; return; fi
  # A line that EXISTS and names neither is not the same as no line at all. Absence is
  # backward compatibility; an unparseable claim is a live assertion nobody can check, so
  # it fails whether or not enforcement was opted into.
  #
  # THAT STRICTNESS IS SAFE FOR A REASON WORTH WRITING DOWN, because it is the reason and
  # not the posture that makes it safe: `Execution:` is new as of 2026-09-04, so no report
  # anywhere carries one yet. There is no legacy line for this branch to redden -- unlike
  # `Mode:` above, which returns undeclared for anything it does not recognise and so lets
  # a garbled mode line pass in silence. Raised as a backward-compatibility risk in review;
  # it is not one today, and the day it becomes one is the day this comment is wrong.
  printf 'unrecognized\n'
}

# A single-pass run must say WHICH KIND it was, because the two are not the same event:
# CHOSEN is the process working as designed on a one-line deliverable, and FORCED is an
# environment defect that will silently recur on every run until somebody fixes it. A report
# that says only "single-pass" leaves the reader to assume the first, which is the assumption
# that costs nothing to make and everything to be wrong about.
#
# SCOPED TO THE DECLARATION LINE, not the report. Searching the whole document for words
# like "chosen" or "blocked" would pass on essentially every report ever written -- those
# words appear in ordinary finding prose -- and a check that cannot fail is the defect this
# file exists to name. The reason has to be ON the line that makes the claim, which is also
# what the failure message asks for.
#
# THE TWO SIDES ARE NOT SYMMETRICAL, and the first version's bug was assuming they were.
# `forced` was a list of idioms; `chosen` contained `small`, `short`, `caption`, `one-liner`.
# Those describe the DELIVERABLE, and a forced run also has a short deliverable -- so any
# forced run phrased outside the idiom list that mentioned its own brevity was recorded as a
# deliberate judgement call. Four of five constructed forced runs classified as `chosen`,
# including "Task tool errored out, small deliverable". A recurring environment defect filed
# as a choice is the precise outcome this field was added to prevent.
#
# The fix is not a longer forced list -- that is a denylist over unbounded English, which is
# the argument this repo's own reviewer-shell-guard makes against denylists. It is that only
# words describing the DECISION can distinguish a choice from a constraint. So `chosen`
# keeps `chose`/`by choice`/`deliberate` and nothing about the artifact, and `forced` defers
# to the shared mechanism predicate above. A line that says neither is `unstated`, and the
# gate asks rather than guessing.
#
# Reported by murderboard-b1 with constructed inputs, 2026-09-04.
execution_cause() {
  local line
  line=$(execution_line "$1")
  if fanout_denied "$line"; then
    printf 'forced\n'
  elif printf '%s' "$line" | grep -qiE 'chose|chosen|by choice|deliberate|elected|opted|judged'; then
    printf 'chosen\n'
  else
    printf 'unstated\n'
  fi
}

cmd_check() {
  local report="$1" missing=0 total=0 num ttl nick mode execution cause
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
        printf '%smurderboard: execution is single-pass but the report does not say why%s\n' \
               "$RED" "$RST" >&2
        printf '%s  say whether subagents were UNAVAILABLE (an environment defect that will\n' "$RED" >&2
        printf '  recur) or single-pass was CHOSEN for a small deliverable. Unqualified, it\n' >&2
        printf '  reads as the second, which is the reading that costs nothing to assume%s\n' "$RST" >&2
        return 1
      fi
      execution="single-pass ($cause)"
      ;;
    contradictory)
      printf '%smurderboard: the Execution: line claims both a fan-out and a single pass%s\n' "$RED" "$RST" >&2
      printf '%s  and does not say the fan-out failed, so it is not clear which happened.\n' "$RED" >&2
      printf '  This is reported, never resolved: picking one is how the wrong one gets\n' >&2
      printf '  into the record. State the mode the ELEVEN ROLES ran in — a triage pass or\n' >&2
      printf '  one role re-reading its own work does not change it%s\n' "$RST" >&2
      return 1
      ;;
    unrecognized)
      printf '%smurderboard: the Execution: line names neither subagents nor single-pass%s\n' "$RED" "$RST" >&2
      printf '%s  it is a claim nobody can check; write "Execution: parallel subagents" or\n' "$RED" >&2
      printf '  "Execution: single-pass (<why>)"%s\n' "$RST" >&2
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

  printf '%smurderboard: all %s roles accounted for in %s (mode: %s, execution: %s)%s\n' \
         "$GRN" "$total" "$report" "$mode" "$execution" "$RST"
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
  t 'bolded mode line is recognised'    0 cmd_check "$tmp/bold.md"
  printf 'Prove It / DOI or Die / Kill Your Darlings — clean\n> Mode: standard\n' > "$tmp/quoted.md"
  t 'blockquoted mode line recognised'  0 cmd_check "$tmp/quoted.md"

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
  printf '%s\nExecution: parallel subagents, one per role\n' "$roles" > "$tmp/exec_sub.md"
  t 'Execution: subagents passes'       0 cmd_check "$tmp/exec_sub.md"

  # A bare "single-pass" is the failure this exists to catch: it reads as the chosen
  # case, and the forced case is the one that will happen again tomorrow.
  printf '%s\nExecution: single-pass\n' "$roles" > "$tmp/exec_bare.md"
  t 'single-pass with no cause FAILS'   1 cmd_check "$tmp/exec_bare.md"

  printf '%s\nExecution: single-pass — subagents were unavailable in this session\n' "$roles" > "$tmp/exec_forced.md"
  t 'single-pass (forced) passes'       0 cmd_check "$tmp/exec_forced.md"

  printf '%s\nExecution: single-pass — chosen, the deliverable is a one-liner\n' "$roles" > "$tmp/exec_chosen.md"
  t 'single-pass (chosen) passes'       0 cmd_check "$tmp/exec_chosen.md"

  # A line that exists and says nothing checkable is worse than no line: it looks like
  # a declaration. It fails WITHOUT --require-execution, unlike a missing line.
  printf '%s\nExecution: yes\n' "$roles" > "$tmp/exec_junk.md"
  t 'unrecognized execution FAILS'      1 cmd_check "$tmp/exec_junk.md"

  printf '%s\n**Execution:** parallel subagents\n' "$roles" > "$tmp/exec_bold.md"
  t 'bolded execution line recognised'  0 cmd_check "$tmp/exec_bold.md"

  # NEGATIVE CONTROLS for two defects this function shipped with for an hour.
  #
  # A line naming both modes is a confession, not a boast: the honest way to write the
  # degraded case is to name the thing that did not happen. Tested first-match-wins the
  # wrong way round, this passed as "subagents".
  printf '%s\nExecution: single-pass, no parallel fan-out — subagents were unavailable\n' "$roles" > "$tmp/exec_both.md"
  if [ "$(report_execution "$tmp/exec_both.md")" = single-pass ]; then
    pass=$((pass+1)); printf '  ok   a line naming both modes reads as single-pass\n'
  else
    fail=$((fail+1)); printf '  %sFAIL%s a line naming both modes read as subagents\n' "$RED" "$RST"
  fi

  # --- constructed inputs, from murderboard-b1's review, 2026-09-04 ------------
  # A peer defeated both matchers with lines nobody on this branch had thought to write.
  # They are fixtures now, because the way this function fails is by looking correct
  # against the phrasings its author happened to imagine.
  #
  # e() asserts on the CLASSIFICATION rather than the exit code: the exit code collapses
  # "read it wrong" and "refused to guess" into the same 1, and the difference between
  # those is the entire review.
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

  # A forced run whose phrasing sits outside any idiom list, mentioning that the
  # deliverable was short. Four of these five classified as CHOSEN -- an environment
  # defect filed as a judgement call -- because `chosen` held words describing the
  # artifact, and a forced run also has a short artifact.
  e 'forced: "was unavailable"'     single-pass forced 'single-pass — the Agent tool was unavailable; deliverable was short anyway'
  e 'forced: "no subagents"'        single-pass forced 'single-pass — no subagents in this environment, short doc anyway'
  e 'forced: "errored out"'         single-pass forced 'single-pass — Task tool errored out, small deliverable'
  e 'forced: "concurrency limit"'   single-pass forced 'single-pass — spawning hit the concurrency limit; a short caption'
  e 'forced: "kept timing out"'     single-pass forced 'single-pass — subagents kept timing out, so I did it inline (short doc)'

  # The dangerous direction: a degraded run reading as a full one. Neither line contains
  # the words "single-pass", so ordering could not save it -- the fix is that a denied
  # fan-out IS the degraded case.
  e 'degraded: "unavailable, inline"'  single-pass forced 'subagents unavailable, ran inline'
  e 'degraded: "fell back to inline"'  single-pass forced 'fan-out attempted, fell back to inline'

  # A full run that mentions a single pass somewhere inside it. No substring rule
  # separates these from a degraded run, so the gate refuses rather than guessing.
  e 'both, fan-out not denied -> refuse' contradictory unstated '11 parallel agents spawned; role 5 also self-reviewed'
  e 'both, triage pass -> refuse'        contradictory unstated 'spawned in parallel after a one-pass triage'

  # The commonest honest phrasings of a degraded run. These used to be `unrecognized`
  # and hard-fail as unparseable; now they parse, and fail for the right reason instead
  # -- the cause is genuinely unstated and the gate asks for it.
  e 'honest: "myself"'                 single-pass unstated 'ran the eleven roles myself'
  e 'honest: "sequentially, by hand"'  single-pass unstated 'ran the roles sequentially, by hand'

  # PROXIMITY CONTROL. A role's failure is not the fan-out's failure, and a line-global
  # search for "could not" would call this degraded. The clause boundary is what stops it.
  e 'a role failing != the fan-out failing' subagents unstated 'parallel subagents; role 4 could not reach the web'

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
  printf 'Prove It / DOI or Die — clean\nExecution: parallel subagents\n' > "$tmp/short_exec.md"
  t 'declared execution does NOT excuse a missing role' 1 cmd_check "$tmp/short_exec.md"
  printf '%s\nMode: retrospective\nExecution: parallel subagents\n' "$roles" > "$tmp/retro_exec.md"
  t 'a good execution line does NOT excuse a missing stopping reason' 1 cmd_check "$tmp/retro_exec.md"

  # The mode must never rescue a missing role: coverage is checked first and
  # independently, or "Mode: standard" becomes a way to buy a pass.
  printf 'Prove It / DOI or Die — clean\nMode: standard\n' > "$tmp/short_std.md"
  t 'declared mode does NOT excuse a missing role' 1 cmd_check "$tmp/short_std.md"

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
    check)
      CMD=check; shift
      # The flag may sit either side of `check`, because both read naturally and a
      # gate that rejects the order someone typed teaches them to stop running it.
      while [ $# -gt 0 ]; do
        case "$1" in
          --require-mode) REQUIRE_MODE=1; shift ;;
          --require-execution) REQUIRE_EXECUTION=1; shift ;;
          *) break ;;
        esac
      done
      REPORT="${1:-}"
      [ -n "${REPORT:-}" ] || die "usage: murderboard_roster.sh check [--require-mode] [--require-execution] REPORT.md"
      shift ;;
    -h|--help) sed -n '2,30p' "$0"; exit 0 ;;
    *) die "murderboard_roster: unknown argument '$1'" ;;
  esac
done

case "${CMD:-}" in
  list)     cmd_list ;;
  count)    cmd_count ;;
  check)    cmd_check "$REPORT" ;;
  selftest) cmd_selftest ;;
  *)        sed -n '2,30p' "$0"; exit 2 ;;
esac
