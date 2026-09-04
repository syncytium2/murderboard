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
# wrong behaviour, not a threshold needing a tweak.
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
  local raw
  raw=$(execution_line "$1")
  [ -n "$raw" ] || return 1
  raw=${raw#*:}
  raw=${raw%%—*}; raw=${raw%%–*}; raw=${raw%%--*}; raw=${raw%% - *}; raw=${raw%%:*}
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
  head=${raw%%—*}; head=${head%%–*}; head=${head%%--*}; head=${head%% - *}; head=${head%%:*}
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
# judgement call. Four of five constructed forced runs classified as `chosen`, including
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
  t 'bolded execution line recognised'  0 cmd_check "$tmp/exec_bold.md"

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
