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
#   murderboard_roster.sh check --require-reports REPORT.md
#                                               ...and its role reports must be on disk
#   murderboard_roster.sh --process PATH ...    use this process file (default: autodetect)
#   murderboard_roster.sh --selftest            prove every branch can still fire
#
# EXIT CODES   0 = ok   1 = roles missing, the mode line is missing/incoherent, or the
#                         declared role-report archive is absent, incomplete, or empty
#              2 = could not determine
#
# Project-neutral: no hardcoded consumer paths.

set -u
LC_ALL=C; export LC_ALL

PROCESS=
REQUIRE_MODE=0
REQUIRE_REPORTS=0

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

# THE REPORTS LINE. The ledger says a role ran. The record's prose says what the review
# concluded. Neither is what the role actually returned, and until this existed there was
# nowhere in a run record for that difference to show up -- so a review that archived all
# eleven role reports and a review that archived none produced records a reader could not
# tell apart. Observed 2026-09 (appendix): three murderboards in one thread summarised their
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
    printf '%s  a summarised report is not an archived one, and a 0-byte file is not a report%s\n' \
           "$RED" "$RST" >&2
    return 1
  fi
  return 0
}

cmd_check() {
  local report="$1" missing=0 total=0 num ttl nick mode
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
  fi

  printf '%smurderboard: all %s roles accounted for in %s (mode: %s, reports: %s)%s\n' \
         "$GRN" "$total" "$report" "$mode" "$reports" "$RST"
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
  t 'bolded reports line is recognised' 0 cmd_check "$tmp/rep_bold.md"

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
    --require-reports) REQUIRE_REPORTS=1; shift ;;
    check)
      CMD=check; shift
      # The flag may sit either side of `check`, because both read naturally and a
      # gate that rejects the order someone typed teaches them to stop running it.
      while [ $# -gt 0 ]; do
        case "$1" in
          --require-mode) REQUIRE_MODE=1; shift ;;
          --require-reports) REQUIRE_REPORTS=1; shift ;;
          *) break ;;
        esac
      done
      REPORT="${1:-}"
      [ -n "${REPORT:-}" ] || die "usage: murderboard_roster.sh check [--require-mode] [--require-reports] REPORT.md"
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
