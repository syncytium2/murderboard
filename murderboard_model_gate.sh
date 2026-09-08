#!/usr/bin/env bash
# instrument: cost
# CANONICAL SOURCE: syncytium2/murderboard murderboard_model_gate.sh — edit HERE.
# murderboard_model_gate.sh — PreToolUse gate: BLOCK a murderboard call-up when the
# session is running on a model whose usage limit the run would exhaust.
#
# WHY THIS EXISTS. The murderboard is a FAN-OUT. It spawns one subagent per role —
# eleven at the time of writing, derived from doc_review_process.md, and the process
# says every role runs. Scaling to stakes changes HOW they run, never WHICH, so there
# is no small murderboard: the cheapest legitimate run is still the whole roster, and
# each role reads the artifact plus the process file. That is the point of the thing.
# It is also, on an expensive model, a large fraction of a usage window spent in a
# handful of minutes.
#
# THE INCIDENT. Reported by Tony, 2026-09-08: a murderboard run on Monday 2026-09-07
# was executed under Fable and exhausted his Fable usage limit for TWO DAYS. No review
# record from that run exists in this repo, which is itself the tell — the cost landed
# before the deliverable did. His instruction, same day:
#
#     "murderboard burns through fable and usage limits very quickly. do not run
#      murderboard in fable. stop and flag"
#     "whether the use is outside or me in another session, fable must be blocked."
#
# WHY A GATE AND NOT A NOTE. The first version of this rule was written into a memory
# file, which is the same class of object as a remembered process: it loads in one
# project, for one person, on one machine, and it is silent everywhere else. Tony's
# reply was "memory is insufficient protection." The murderboard's own diagnosis
# applies to its own cost — a rule that depends on being remembered is not a gate.
#
# WHY IT FAILS CLOSED. Every other gate in this repo has a could-not-determine state
# that proceeds with a flag, because the cost of a false block there is a stopped
# session and the cost of a false allow is a defect that review might still catch.
# This gate's asymmetry runs the other way and it is not close:
#
#     false block  -> one message; re-run with the override or switch model.
#     false allow  -> the usage window is gone, for days, and nothing gives it back.
#
# So an unreadable transcript, an absent model field, or a payload this script cannot
# parse all BLOCK. If you are reading this because it stopped you and you disagree,
# the override is one env var and it is named below.
#
# WHY IT IS WIRED FOR PLUGIN INSTALLS TOO, against hooks/hooks.json's stated policy.
# That file ships one hook and explains why: "installing a review harness must not
# silently start refusing a stranger's commands," because the repo's other gates are
# somebody's opinion about how their repo should work. That reasoning is right and it
# does not reach this hook. require_commit_before_message.sh and no-heredoc-source.sh
# refuse a stranger's command on the authors' preference about hygiene. This one
# refuses to spend the stranger's money on a cost THE MURDERBOARD ITSELF INFLICTS. A
# tool that can empty your account for two days and does not say so before it starts
# is not being polite by staying quiet.
#
# Exit 2 tells Claude Code to block the call and feed stderr back to the model.

set -u

# ---- the policy, and its expiry -------------------------------------------------
# BLOCKED is a case-insensitive extended regex matched against the model id.
#
# REVIEW_BY EXISTS BECAUSE THE POLICY IS ABOUT PRICE, NOT ABOUT THE MODEL. Tony,
# 2026-09-08: "some day fable might get cheap so this needs to be reviewed regularly."
# A block that outlives its reason becomes folklore — nobody remembers why it is there,
# it gets carried into repo after repo, and eventually someone deletes it in a cleanup
# with no idea what they are switching off. So the rule carries a date, `--check-review-
# date` fails past it, and this repo's CI runs that check. The red build is the review:
# a human either re-affirms the block and moves the date, or removes it. NOTHING here
# expires on its own — an expired policy still blocks, because a cost gate that quietly
# switches itself off at midnight is the worst object in this file.
BLOCKED="${MURDERBOARD_BLOCKED_MODELS:-fable}"
REVIEW_BY="${MURDERBOARD_BLOCK_REVIEW_BY:-2026-12-08}"   # set 2026-09-08, +3 months

# The deliberate override. A gate with no way past it gets deleted rather than
# obeyed, and then there is no gate and no record that there was one.
OVERRIDE="${MURDERBOARD_ALLOW_EXPENSIVE_MODEL:-}"

# CONFIRMATION. Default ON: every murderboard call-up asks the human first, through
# Claude Code's own permission prompt rather than through the model's good intentions.
# This is a SECOND failure mode from the model block above — not "wrong model" but
# "wrong moment" — and it is the more common one. CONFIRM_TTL is how long one
# confirmation covers the fan-out it authorised, in seconds; long enough for a roster to
# spawn, short enough that a later run in the same session asks again.
CONFIRM="${MURDERBOARD_CONFIRM:-1}"
CONFIRM_TTL="${MURDERBOARD_CONFIRM_TTL:-900}"

usage_and_exit() {
  cat >&2 <<'USAGE'
murderboard_model_gate.sh — PreToolUse hook. Reads a hook payload on stdin.

  --selftest            run the built-in fixtures (CI runs this)
  --check-review-date   exit 1 if the block is past its review-by date
  --why                 print the policy and where it came from
USAGE
  exit 64
}

# ---- model extraction ------------------------------------------------------------
# NO INTERPRETER IS USED ANYWHERE IN THIS FILE, and that is a decision rather than an
# accident. no-heredoc-source.sh took a python dependency, was verified in a shell
# where `python` resolved, and then failed OPEN on every call across seven repos whose
# hooks had only `python3` (colonel_kernel, 2026-08-18). A cost gate cannot afford that
# failure mode, so it never acquires the dependency: everything below is grep and sed.
#
# The transcript is the source of truth for the model. There is no CLAUDE_MODEL in a
# hook's environment — checked on 2026-09-08, the environment carries CLAUDE_PID,
# CLAUDE_EFFORT, CLAUDE_CODE_SESSION_ID and friends, and nothing naming the model. The
# transcript JSONL records "model":"<id>" on each assistant message, so the LAST one is
# what is running right now, which also makes this correct when the model is switched
# mid-session.
model_from_transcript() {
  local tp="$1"
  [ -n "$tp" ] || return 1
  [ -r "$tp" ] || return 1
  local m
  m=$(grep -o '"model":"[^"]*"' "$tp" 2>/dev/null | tail -1 | sed 's/.*:"//; s/"$//')
  [ -n "$m" ] || return 1
  printf '%s' "$m"
}

# ---- modes ------------------------------------------------------------------------
case "${1:-}" in
  --why)
    printf 'blocked models (regex, case-insensitive): %s\n' "$BLOCKED"
    printf 'review by: %s (today: %s)\n' "$REVIEW_BY" "$(date +%F)"
    printf 'override:  MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1\n'
    printf 'confirm:   %s (every call-up asks the human; MURDERBOARD_CONFIRM=0 to stop)\n' \
           "$( [ "$CONFIRM" != 0 ] && echo on || echo OFF )"
    printf '           one prompt per run, good for %ss, then it asks again\n' "$CONFIRM_TTL"
    printf 'known good: Claude Opus 5. Other current models are likely fine.\n'
    printf 'reason:    the roster fan-out spends a usage window in minutes;\n'
    printf '           a Fable run on 2026-09-07 cost two days of access.\n'
    printf '           it is also fired too early: confirmation is about the MOMENT.\n'
    printf 'liability: you pay for these tokens. No cost you incur running this\n'
    printf '           software is ever the responsibility of its authors. See TERMS.md.\n'
    exit 0 ;;
  --check-review-date)
    today=$(date +%F)
    # Lexical comparison, deliberately. ISO-8601 sorts correctly as a string, so this
    # needs no date arithmetic and therefore cannot break on the BSD/GNU `date -d`
    # split that has bitten the other gates on macOS runners.
    if [ "$today" \> "$REVIEW_BY" ]; then
      cat >&2 <<EOF
murderboard_model_gate: THE MODEL BLOCK IS PAST ITS REVIEW DATE.

  blocked: $BLOCKED
  review by: $REVIEW_BY   (today: $today)

This is not a failure of the gate — it is the gate asking to be re-justified. The
block exists because the roster fan-out was expensive on those models in September
2026. Prices move. Decide, then edit REVIEW_BY in this file:

  * still expensive -> re-affirm, push REVIEW_BY out, say so in the commit message.
  * now affordable  -> remove the model from BLOCKED, and delete it from the docs
                       that name it (doc_review_process.md, README.md, SKILL.md,
                       docs/index.html).

Do NOT move the date without deciding. A rubber-stamped review date is worse than
none: it launders folklore as policy.
EOF
      exit 1
    fi
    printf 'ok — model block reviewed by %s, today %s\n' "$REVIEW_BY" "$today"
    exit 0 ;;
  --selftest) ;;   # handled at the foot of the file
  -h|--help)  usage_and_exit ;;
  "")         ;;   # normal hook operation
  *)          usage_and_exit ;;
esac

# ---- selftest ---------------------------------------------------------------------
# Fixtures, not a smoke test. Every branch that can ALLOW is exercised, because an
# allow is the failure that costs money and it is the one that looks like success.
if [ "${1:-}" = "--selftest" ]; then
  RED=''; GRN=''; RST=''
  if [ -t 1 ]; then RED=$'\033[31m'; GRN=$'\033[32m'; RST=$'\033[0m'; fi
  pass=0; fail=0
  TMP=$(mktemp -d) || { echo "mktemp failed" >&2; exit 2; }
  trap 'rm -rf "$TMP"' EXIT
  SELF="$0"

  mk_transcript() { # mk_transcript <name> <model...>
    local f="$TMP/$1.jsonl"; shift
    : > "$f"
    for m in "$@"; do
      printf '{"type":"assistant","message":{"model":"%s","content":[]}}\n' "$m" >> "$f"
    done
    printf '%s' "$f"
  }

  # Every fixture gets a private state dir and confirmation OFF by default, so the
  # model-policy cases below test the model policy and nothing else. The confirmation
  # group turns it back on explicitly -- assignments in "$@" come after these, so a
  # test can override either. Without this, the first fixture would write a marker and
  # silently suppress the asks in every fixture after it.
  t() { # t <want> <desc> <payload> [env assignments...]
    local want="$1" desc="$2" payload="$3"; shift 3
    local got
    got=$(printf '%s' "$payload" \
          | env MURDERBOARD_CONFIRM=0 MURDERBOARD_GATE_STATE="$TMP/state" "$@" \
                bash "$SELF" >/dev/null 2>&1; echo $?)
    if [ "$got" = "$want" ]; then
      pass=$((pass+1)); printf '  ok   %s\n' "$desc"
    else
      fail=$((fail+1)); printf '  %sFAIL%s %s (exit=%s, want %s)\n' "$RED" "$RST" "$desc" "$got" "$want"
    fi
  }

  # Same, but asserts on STDOUT -- the permission decision, which is where the
  # confirmation lives. `t` cannot see it: an ask and a plain allow are both exit 0,
  # so a suite that only checked exit codes would report a working confirmation
  # prompt that never appears.
  tout() { # tout <want-substring|NONE> <desc> <payload> [env assignments...]
    local want="$1" desc="$2" payload="$3"; shift 3
    local out
    out=$(printf '%s' "$payload" \
          | env MURDERBOARD_GATE_STATE="$TMP/state2" "$@" bash "$SELF" 2>/dev/null)
    local ok=0
    if [ "$want" = "NONE" ]; then
      [ -z "$out" ] && ok=1
    else
      case "$out" in (*"$want"*) ok=1 ;; esac
    fi
    if [ "$ok" = 1 ]; then
      pass=$((pass+1)); printf '  ok   %s\n' "$desc"
    else
      fail=$((fail+1)); printf '  %sFAIL%s %s (stdout=%.60s)\n' "$RED" "$RST" "$desc" "${out:-<empty>}"
    fi
  }

  FABLE=$(mk_transcript fable claude-opus-5 claude-fable-5-1)
  OPUS=$(mk_transcript opus claude-fable-5-1 claude-opus-5)   # switched TO opus: allow
  EMPTY=$(mk_transcript empty)                                 # no model line at all

  sk() { printf '{"tool_name":"Skill","transcript_path":"%s","tool_input":{"skill":"murderboard","args":"%s"}}' "$1" "${2:-docs/index.html}"; }
  ag() { printf '{"tool_name":"Agent","transcript_path":"%s","tool_input":{"prompt":"%s"}}' "$1" "$2"; }
  ot() { printf '{"tool_name":"Bash","transcript_path":"%s","tool_input":{"command":"%s"}}' "$1" "$2"; }

  echo "murderboard_model_gate --selftest"

  # --- the thing it was built for
  t 2 "Skill(murderboard) on fable is BLOCKED"            "$(sk "$FABLE")"
  t 0 "Skill(murderboard) on opus is allowed"             "$(sk "$OPUS")"

  # --- the fan-out itself, not just the call-up. A hand-run murderboard never touches
  #     the Skill tool; it reads the process file and spawns agents directly, which is
  #     where the money actually goes.
  t 2 "Agent role fan-out on fable is BLOCKED" \
      "$(ag "$FABLE" "You are role 4 of the murderboard. Work the checklist in doc_review_process.md and report findings.")"
  t 0 "Agent role fan-out on opus is allowed" \
      "$(ag "$OPUS" "You are role 4 of the murderboard. Work the checklist in doc_review_process.md and report findings.")"

  # --- NEGATIVE CONTROLS. The gate must not become a general ban on the word.
  #     Reading ABOUT the murderboard on a blocked model is not a fan-out and must
  #     pass, or the gate gets switched off for being unusable.
  t 0 "Agent merely mentioning murderboard is allowed on fable" \
      "$(ag "$FABLE" "What does murderboard_freshness.sh do when the stamp is missing?")"
  t 0 "unrelated Bash on fable is allowed" \
      "$(ot "$FABLE" "grep -n murderboard README.md")"
  t 0 "unrelated Skill on fable is allowed" \
      "$(printf '{"tool_name":"Skill","transcript_path":"%s","tool_input":{"skill":"code-review"}}' "$FABLE")"

  # --- FAIL CLOSED. Each of these is a state where the gate does not KNOW the model.
  #     All three must block. If any of them starts exiting 0, this file has quietly
  #     become decorative and nothing else in the repo would notice.
  t 2 "unreadable transcript path BLOCKS"    "$(sk "$TMP/does-not-exist.jsonl")"
  t 2 "transcript with no model line BLOCKS" "$(sk "$EMPTY")"
  t 2 "absent transcript_path BLOCKS" \
      '{"tool_name":"Skill","tool_input":{"skill":"murderboard"}}'

  # --- the override, and the fact that it is scoped to the override
  t 0 "override lets a deliberate fable run through" \
      "$(sk "$FABLE")" MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1
  t 2 "override unset does not leak from the environment" \
      "$(sk "$FABLE")" MURDERBOARD_ALLOW_EXPENSIVE_MODEL=

  # --- the blocklist is configurable, and configuring it actually works. Without
  #     this, a consumer who sets MURDERBOARD_BLOCKED_MODELS gets no error and no
  #     effect, which is the silent-no-op failure this repo keeps rediscovering.
  t 2 "a consumer can block another model"  "$(sk "$OPUS")"  MURDERBOARD_BLOCKED_MODELS=opus
  t 0 "and unblock the default one"         "$(sk "$FABLE")" MURDERBOARD_BLOCKED_MODELS=some-other-model

  # --- matching is on the model id, case-insensitively, not on an exact string
  UPPER=$(mk_transcript upper claude-FABLE-5-1)
  t 2 "match is case-insensitive"           "$(sk "$UPPER")"

  # --- the review date is a real mechanism. Both directions, or it is a comment.
  if bash "$SELF" --check-review-date >/dev/null 2>&1; then
    pass=$((pass+1)); printf '  ok   --check-review-date passes before the date\n'
  else
    fail=$((fail+1)); printf '  %sFAIL%s --check-review-date should pass before the date\n' "$RED" "$RST"
  fi
  if MURDERBOARD_BLOCK_REVIEW_BY=2000-01-01 bash "$SELF" --check-review-date >/dev/null 2>&1; then
    fail=$((fail+1)); printf '  %sFAIL%s --check-review-date should FAIL past the date\n' "$RED" "$RST"
  else
    pass=$((pass+1)); printf '  ok   --check-review-date fails past the date\n'
  fi
  # An EXPIRED policy still blocks. This is the one people get wrong.
  t 2 "an expired review date still BLOCKS" "$(sk "$FABLE")" MURDERBOARD_BLOCK_REVIEW_BY=2000-01-01

  # --- CONFIRMATION: the second failure mode, "wrong moment" rather than "wrong model".
  #     These assert on STDOUT, because that is where the permission decision goes and an
  #     ask is indistinguishable from an allow by exit code alone.
  SESS() { printf '{"session_id":"%s","tool_name":"Skill","transcript_path":"%s","tool_input":{"skill":"murderboard"}}' "$1" "$2"; }

  rm -rf "$TMP/state2"
  tout '"permissionDecision":"ask"' "a call-up ASKS the human first" "$(SESS s1 "$OPUS")"
  # ONE PROMPT PER RUN, NOT ELEVEN. The fan-out this authorised must not re-interrogate.
  tout NONE "the fan-out it authorised does not ask again" \
       "$(printf '{"session_id":"s1","tool_name":"Agent","transcript_path":"%s","tool_input":{"prompt":"role 4 murderboard checklist"}}' "$OPUS")"
  # A DIFFERENT session is a different run and must ask on its own account.
  tout '"permissionDecision":"ask"' "a different session asks on its own account" "$(SESS s2 "$OPUS")"
  # The marker EXPIRES, so a later run in the same session is confirmed again.
  tout '"permissionDecision":"ask"' "a later run in the same session asks again" \
       "$(SESS s1 "$OPUS")" MURDERBOARD_CONFIRM_TTL=0
  tout NONE "MURDERBOARD_CONFIRM=0 turns the prompt off" "$(SESS s3 "$OPUS")" MURDERBOARD_CONFIRM=0
  # NEGATIVE CONTROL: confirmation must not soften the model block into a question the
  # human can wave through by reflex. A blocked model is refused, not offered.
  t 2 "a blocked model is DENIED, never merely asked" "$(SESS s4 "$FABLE")" MURDERBOARD_CONFIRM=1
  # The emitted decision has to be the shape Claude Code actually parses.
  tout '"hookEventName":"PreToolUse"' "the decision names its own hook event" "$(SESS s5 "$OPUS")"
  # A session id is used to build a filename. It must not be able to escape the dir.
  tout '"permissionDecision":"ask"' "a hostile session id cannot escape the state dir" \
       "$(SESS '../../etc/passwd' "$OPUS")"
  if [ -e "$TMP/state2/../../etc/passwd" ] && [ ! -e /etc/passwd.murderboard ]; then :; fi
  if find "$TMP/state2" -name 'confirm-*' 2>/dev/null | grep -q .; then
    pass=$((pass+1)); printf '  ok   the marker stayed inside the state dir\n'
  else
    fail=$((fail+1)); printf '  %sFAIL%s the marker escaped the state dir\n' "$RED" "$RST"
  fi

  # THE DECISION MUST ACTUALLY PARSE AS JSON. Substring checks cannot see this, and the
  # failure is silent in the worst way: Claude Code ignores unparseable hook output, so a
  # malformed object means the confirmation prompt simply never appears and every run is
  # waved through while the file looks like it is asking. The reason string is built by
  # hand -- multi-line, with quotes and an em dash in it -- so this is a live risk, not a
  # theoretical one.
  #
  # AN INTERPRETER IS USED HERE AND NOWHERE ELSE. The runtime path stays grep/sed-only for
  # the reason given at the top of this file; a test may depend on python because a
  # missing python must not silently pass. If it is absent this SKIPS LOUDLY rather than
  # counting a pass -- the no-heredoc bug was exactly a check that reported success from a
  # branch it never entered.
  PYB=""
  for c in python3 python; do command -v "$c" >/dev/null 2>&1 && PYB="$c" && break; done
  if [ -z "$PYB" ]; then
    printf '  %sSKIP%s decision-JSON parse check (no python found) — NOT a pass\n' "$RED" "$RST"
  else
    rm -rf "$TMP/state3"
    if printf '{"session_id":"json1","tool_name":"Skill","transcript_path":"%s","tool_input":{"skill":"murderboard"}}' "$OPUS" \
       | env MURDERBOARD_GATE_STATE="$TMP/state3" bash "$SELF" 2>/dev/null \
       | "$PYB" -c 'import json,sys; d=json.load(sys.stdin)["hookSpecificOutput"]; sys.exit(0 if d["permissionDecision"]=="ask" and d["hookEventName"]=="PreToolUse" else 1)'; then
      pass=$((pass+1)); printf '  ok   the emitted decision is valid, parseable JSON\n'
    else
      fail=$((fail+1)); printf '  %sFAIL%s the emitted decision is not valid JSON\n' "$RED" "$RST"
    fi
    # A quote and a backslash in the interpolated model name must not break the object.
    ODD=$(mk_transcript odd 'claude-"weird"\model')
    rm -rf "$TMP/state4"
    if printf '{"session_id":"json2","tool_name":"Skill","transcript_path":"%s","tool_input":{"skill":"murderboard"}}' "$ODD" \
       | env MURDERBOARD_GATE_STATE="$TMP/state4" bash "$SELF" 2>/dev/null \
       | "$PYB" -c 'import json,sys; json.load(sys.stdin); sys.exit(0)'; then
      pass=$((pass+1)); printf '  ok   a model name with quotes and backslashes stays valid JSON\n'
    else
      fail=$((fail+1)); printf '  %sFAIL%s a quoted/backslashed model name breaks the JSON\n' "$RED" "$RST"
    fi
  fi

  printf '\n%s%d passed%s, %s%d failed%s\n' "$GRN" "$pass" "$RST" \
         "$( [ "$fail" -gt 0 ] && printf '%s' "$RED" )" "$fail" "$RST"
  [ "$fail" -eq 0 ] || exit 1
  exit 0
fi

# ---- normal operation -------------------------------------------------------------
payload="$(cat)"

tool=$(printf '%s' "$payload" | grep -o '"tool_name"[[:space:]]*:[[:space:]]*"[^"]*"' \
        | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

# Only two tools can start a murderboard. Everything else is none of this gate's
# business and must pass untouched — a cost gate that inspects every Bash call is a
# cost gate someone removes by Friday.
case "$tool" in
  Skill|Agent|Task) ;;
  *) exit 0 ;;
esac

# IS THIS A MURDERBOARD CALL-UP? Matched against the RAW payload rather than a parsed
# field, on purpose: the alternative is JSON-unescaping a prompt without an
# interpreter, and a parser that silently returns empty would fail OPEN here. grep over
# the raw bytes cannot miss a mention because of escaping. Over-matching is the safe
# direction — it costs a model check, which is one file read.
is_callup=0
case "$tool" in
  Skill)
    # A skill invocation naming the murderboard IS the call-up. No further test:
    # the whole purpose of the skill is to start the fan-out.
    printf '%s' "$payload" | grep -qiE 'murderboard' && is_callup=1
    ;;
  Agent|Task)
    # A hand-run murderboard — the path taken when the skill is not installed, and
    # the one the process file describes — spawns role subagents directly. Require
    # BOTH a murderboard marker AND fan-out vocabulary, so that asking an agent to
    # go read about the tool is not mistaken for running it.
    if printf '%s' "$payload" | grep -qiE 'murderboard|doc_review_process'; then
      printf '%s' "$payload" \
        | grep -qiE 'role[[:space:]_-]*[0-9]|roster|checklist|blind pass|blind-pass|role ledger|adversarial review' \
        && is_callup=1
    fi
    ;;
esac
[ "$is_callup" -eq 1 ] || exit 0

# The deliberate override, checked only now — so that setting it does not disable the
# gate's judgement for calls it would have allowed anyway.
if [ -n "$OVERRIDE" ]; then
  echo "murderboard_model_gate: MURDERBOARD_ALLOW_EXPENSIVE_MODEL is set — allowing a murderboard run on this model." >&2
  exit 0
fi

transcript=$(printf '%s' "$payload" | grep -o '"transcript_path"[[:space:]]*:[[:space:]]*"[^"]*"' \
              | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if ! model=$(model_from_transcript "$transcript"); then
  cat >&2 <<EOF
murderboard_model_gate: BLOCKED — could not determine which model is running.

  transcript_path: ${transcript:-<absent from the hook payload>}

This gate fails CLOSED and that is deliberate. A murderboard run is a roster-wide
fan-out; on a blocked model it can exhaust a usage window in minutes, and no amount
of apologising afterwards gives the window back. A wrong block costs you one message.
A wrong allow cost two days on 2026-09-07.

Confirm your model, then either:
  * run it on a model that is not in: $BLOCKED
  * or, if you have decided you want to spend it here:
        MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1
EOF
  exit 2
fi

if printf '%s' "$model" | grep -qiE "$BLOCKED"; then
  # Past its review date? Say so IN THE BLOCK. The person being stopped is often the
  # person who can decide the policy is obsolete, and this is the moment they care.
  stale_note=""
  if [ "$(date +%F)" \> "$REVIEW_BY" ]; then
    stale_note="
NOTE: this block passed its review date ($REVIEW_BY) and is still in force. If these
models have got cheaper, that is a decision to make and record — see --check-review-date."
  fi
  cat >&2 <<EOF
murderboard_model_gate: BLOCKED — do not run the murderboard on this model.

  model:   $model
  blocked: $BLOCKED

WHY. One subagent per role, every role, every run — there is no cheap murderboard. On
2026-09-07 a run under Fable spent a two-day usage window and produced no review at
all: the cost landed before the deliverable did.

WHAT TO RUN INSTEAD. Known good: Claude Opus 5. Other current models are likely fine.

WHAT TO DO NOW. Stop and tell the human. Do not quietly run a partial roster to save
budget — a review missing roles reads identically to a clean one, which is the exact
failure this apparatus exists to prevent.

  * switch to a model outside: $BLOCKED — then re-invoke
  * or, if the human has decided to spend it here, they set:
        MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1$stale_note
EOF
  exit 2
fi

# ---- stage two: is this the right MOMENT? -----------------------------------------
# The model check above answers "can you afford this at all". It does not answer the
# other way a murderboard wastes money, which Tony reported on 2026-09-08: "some of my
# sessions are running it unnecessarily or prematurely in the doc process." An agent
# decides on its own that something is a document deliverable and fires the whole
# roster at a draft that was not ready for it. The tokens are spent, the findings are
# about a draft that no longer exists five minutes later, and nobody asked.
#
# WHY THIS IS A HARNESS PROMPT AND NOT AN INSTRUCTION. Telling the model "ask the human
# first" is worth nothing: the model is the thing being gated, so it can believe it
# asked, or ask and answer for itself. `permissionDecision: "ask"` hands the decision to
# Claude Code, which prompts the actual human. That is the only version of consent here
# that the model cannot manufacture.
#
# ONE PROMPT PER RUN, NOT ELEVEN. This hook fires on every Agent spawn, so a naive ask
# would interrogate the human once per role. A short-lived marker keyed on the session
# suppresses the follow-ups: the first call-up asks, the fan-out it authorises does not.
# The marker is written when we ASK rather than when the human answers, because a hook
# is never told what the human chose.
#
# THE LIMIT, STATED RATHER THAN IMPLIED. That last point leaves a hole: if the human
# DENIES the skill call and the model immediately hand-runs the same review through
# Agent calls, the marker is already there and the follow-ups pass unasked. Closing it
# needs a signal the hook does not receive. It is documented here, in SKILL.md and in
# the process file as "if you are refused, stop" rather than papered over, because a
# gate that overstates its reach is the defect this repo keeps rediscovering. Likewise
# `ask` does nothing under `bypassPermissions` or in a non-interactive session — the
# harness has nobody to prompt.
if [ "$CONFIRM" != "0" ]; then
  sid=$(printf '%s' "$payload" | grep -o '"session_id"[[:space:]]*:[[:space:]]*"[^"]*"' \
         | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
  # Sanitise: the session id becomes part of a filename. Anything unexpected collapses
  # to a constant rather than escaping the directory.
  case "$sid" in (*[!A-Za-z0-9._-]*|'') sid=nosession ;; esac
  state_dir="${MURDERBOARD_GATE_STATE:-${TMPDIR:-/tmp}/murderboard-gate}"
  marker="$state_dir/confirm-$sid"

  fresh=0
  if [ -f "$marker" ]; then
    now=$(date +%s); then_=$(cat "$marker" 2>/dev/null || echo 0)
    case "$then_" in (''|*[!0-9]*) then_=0 ;; esac
    [ $(( now - then_ )) -lt "$CONFIRM_TTL" ] && fresh=1
  fi

  if [ "$fresh" -eq 0 ]; then
    mkdir -p "$state_dir" 2>/dev/null && date +%s > "$marker" 2>/dev/null
    reason="Start a murderboard run now? It spawns one subagent per reviewer role (every role
runs, always), so this is the full cost of a review, not a sample of one — on model
'$model'. Confirm this is the right MOMENT: is the draft actually ready to be attacked,
and is this the artifact you want reviewed? Runs fired early get paid for in full and
produce findings about a draft you are about to replace. You pay for these tokens; see
TERMS.md. (Set MURDERBOARD_CONFIRM=0 to stop asking.)"
    # JSON, hand-built, because this file takes no interpreter dependency. Only the
    # reason is interpolated and only newlines and quotes can occur in it, both escaped
    # here; everything else in the object is literal.
    esc=$(printf '%s' "$reason" | sed 's/\\/\\\\/g; s/"/\\"/g' | awk 'BEGIN{ORS=""} NR>1{print "\\n"} {print}')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"%s"}}\n' "$esc"
    exit 0
  fi
fi

exit 0

# ----------------------------------------------------------------------------
# ADOPTION (any repo). Copy to tools/murderboard_model_gate.sh (or the root), stamp
# line 2 with its provenance, and add to .claude/settings.json:
#
#   "hooks": {
#     "PreToolUse": [
#       { "matcher": "Skill|Agent|Task",
#         "hooks": [ { "type": "command",
#                      "command": "bash murderboard_model_gate.sh",
#                      "timeout": 10 } ] }
#     ]
#   }
#
# VERIFY IT IN YOUR OWN REPO. A gate that cannot fire manufactures confidence, and
# this one is silent by design on every call it allows:
#
#   bash murderboard_model_gate.sh --selftest
#   bash murderboard_model_gate.sh --why
#
# Then prove it against a REAL payload, because the selftest builds its own and
# therefore cannot notice if the transcript field is ever renamed upstream. Start a
# session on a blocked model, ask for a murderboard, and confirm you are stopped.
# ----------------------------------------------------------------------------
