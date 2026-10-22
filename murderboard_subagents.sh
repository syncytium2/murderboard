#!/usr/bin/env bash
# murderboard_subagents.sh — name what is blocking subagents in this environment, so a
# review that cannot fan out says so BEFORE it runs instead of degrading in silence.
#
# THE GAP THIS ADDRESSES. `doc_review_process.md` says a substantial deliverable runs the
# roles as parallel subagents, one per role. It also permits a single-pass self-review for a
# small one. Those two sentences leave a hole between them: when the Agent tool is not
# available, a run FALLS BACK into the mode the process already sanctions, and the report it
# produces is textually identical to a report from a run that CHOSE that mode. Eleven roles
# still appear in the ledger; the roster gate still passes. The reader cannot tell that the
# adversary was the author.
#
# It is not hypothetical. `docs/reviews/plugin_adoption_docs_murderboard_2026-08-26.md` is a
# run of exactly that shape, in this repo. It records the deviation only because its author
# volunteered a "Stated deviation" section — and a rule that depends on being remembered is
# not a gate. That is this document's own first principle, turned on its own fan-out.
#
# WHAT THIS SCRIPT IS NOT. It is NOT the gate, and reading it as one is the failure it would
# cause. It reads files. Whether the Agent tool is actually callable is decided by things
# that are not all on disk:
#
#   * a launch flag (--disallowedTools / --allowedTools) that no settings file records;
#   * the session's permission mode;
#   * an instruction injected at runtime by the harness, the IDE, or an output style;
#   * already being inside a subagent — a subagent cannot spawn one, and exports no
#     variable that says so. (Do not infer it from CLAUDE_CODE_CHILD_SESSION, which is set
#     in an ordinary VS Code session, or from CLAUDE_CODE_ENABLE_TASKS, whose subject is
#     not documented to be this.)
#
# The 2026-08-26 block was of the invisible kind: it appeared in no settings file, no hook,
# and no CLAUDE.md. A scan would have returned a clean bill of health for the one case that
# has actually cost this project a degraded run.
#
# SO: EXIT 0 MEANS "NOTHING BLOCKING IN THE FILES I CAN READ". IT DOES NOT MEAN SUBAGENTS
# WORK. The only check that cannot be fooled is spawning one and requiring an answer back,
# which is what the skill's probe step does. This script's job is the other half — once the
# probe has failed, tell the human WHICH KNOB to turn, so "allow subagents" is an action
# rather than a scavenger hunt. Run it early (--hook) for the standing, file-visible cases.
#
# USAGE
#   murderboard_subagents.sh                 scan and report what is readable
#   murderboard_subagents.sh --hook          silent unless a blocker is found; never blocks
#   murderboard_subagents.sh --explain       add the remedy for each finding
#   murderboard_subagents.sh --lookup        scan instead for what stops roles 2 and 6 from
#                                            reaching a source: a WebFetch or curl deny,
#                                            dontAsk with no lookup route allowed, a sandbox
#                                            denying the resolvers (issue #74 is the case on
#                                            record). Same files, same exit codes, same limit:
#                                            the lookup PROBE is the check; this names the knob.
#   murderboard_subagents.sh --root PATH     repo root to scan (default: git root, else cwd)
#   murderboard_subagents.sh --config-dir P  stand in for ~/.claude (default: CLAUDE_CONFIG_DIR)
#   murderboard_subagents.sh --managed PATH  managed-settings.json (default: per platform)
#   murderboard_subagents.sh --selftest      prove every branch can still fire
#
# EXIT CODES
#   0 = no blocker found in the readable files (NOT "subagents work" — see above)
#   1 = a blocker found
#   2 = could not determine — a file exists that could not be read or parsed
#
# Project-neutral: no hardcoded consumer paths, no network, standard library only.

set -u
LC_ALL=C; export LC_ALL

ROOT=
CONFIG_DIR=
MANAGED=
HOOK=0
EXPLAIN=0
SCAN=subagents

BLOCKERS=0
UNDETERMINED=0
OUT=

if [ -t 1 ]; then RED=$'\033[31m'; YEL=$'\033[33m'; GRN=$'\033[32m'; DIM=$'\033[2m'; RST=$'\033[0m'
else RED=; YEL=; GRN=; DIM=; RST=; fi

die() { printf '%s\n' "$*" >&2; exit 2; }
have() { command -v "$1" >/dev/null 2>&1; }

# Findings accumulate into a buffer rather than printing as they are found, because --hook
# must stay SILENT when there is nothing to say. A hook that prints a reassuring paragraph
# at every session start is a hook people learn to scroll past, and then it is not a hook.
say()  { OUT="$OUT$1
"; }
block() {  # block <headline> <remedy>
  BLOCKERS=$((BLOCKERS + 1))
  say "  ${RED}BLOCK${RST}  $1"
  [ "$EXPLAIN" = 1 ] && say "         ${DIM}fix: $2${RST}"
  return 0
}
warn() {   # warn <headline> <remedy> — can block, cannot be shown to
  say "  ${YEL}WARN${RST}   $1"
  [ "$EXPLAIN" = 1 ] && say "         ${DIM}fix: $2${RST}"
  return 0
}
undet() {  # undet <headline> — a surface that exists and could not be read
  UNDETERMINED=$((UNDETERMINED + 1))
  say "  ${YEL}?${RST}      $1"
  return 0
}

repo_root() { git rev-parse --show-toplevel 2>/dev/null || pwd; }

# Where a managed policy file lives, by platform. Absent is the normal case and is not
# "undetermined" — only a file that EXISTS and resists reading is.
default_managed() {
  case "$(uname -s 2>/dev/null)" in
    Darwin) printf '%s\n' "/Library/Application Support/ClaudeCode/managed-settings.json" ;;
    *)      printf '%s\n' "/etc/claude-code/managed-settings.json" ;;
  esac
}

# --- the JSON surfaces -------------------------------------------------------
#
# Parsed with python, never with grep. A permission rule is `"Task(...)"` inside a named
# array, and a grep for the word "Task" cannot tell `permissions.deny` from
# `permissions.allow` — it would report the fix as the fault. With no interpreter this
# reports UNDETERMINED and says so, rather than taking a missing tool for a clean file.
# That fail-open is the exact bug `.claude/hooks/no-heredoc-source.sh` was live-and-broken
# with in three repos, and it is not being repeated here.
PY=
for c in python3 python; do have "$c" && { PY=$c; break; }; done

# Prints one finding per line: "KIND<TAB>text". KIND is BLOCK | WARN.
scan_json() {
  local f="$1"
  [ -e "$f" ] || return 0
  if [ ! -r "$f" ]; then undet "settings exist but are unreadable: $f"; return 0; fi
  if [ -z "$PY" ]; then
    undet "no python on PATH to read $f — cannot say what it denies"
    return 0
  fi
  local out rc
  out=$("$PY" - "$f" "$SCAN" <<'PYEOF'
import json, re, sys

path = sys.argv[1]
scan = sys.argv[2] if len(sys.argv) > 2 else "subagents"
try:
    with open(path, encoding="utf-8") as fh:
        cfg = json.load(fh)
except Exception as exc:                      # malformed is UNDETERMINED, never "clean"
    print("UNDET\t%s could not be parsed as JSON (%s)" % (path, exc.__class__.__name__))
    sys.exit(0)
if not isinstance(cfg, dict):
    print("UNDET\t%s is not a JSON object" % path)
    sys.exit(0)

# The Agent tool is named `Task` in permission rules and hook matchers. `Agent` is what the
# process file and the skill call it in prose. Match either, so a rule written from the
# prose name is still found.
NAMES = re.compile(r"^(task|agent)\b", re.I)
TOOL = "Task"


def entries(*keys):
    node = cfg
    for k in keys[:-1]:
        node = node.get(k) if isinstance(node, dict) else None
        if node is None:
            return []
    val = node.get(keys[-1]) if isinstance(node, dict) else None
    return [v for v in val if isinstance(v, str)] if isinstance(val, list) else []


if scan == "lookup":
    # --lookup: what stops roles 2 and 6 from reaching a source outside the repository.
    # Issue #74's run was stopped by exactly this shape in the project's own settings:
    # deny ["WebFetch", "Bash(curl:*)", "Bash(wget:*)"]. Rule syntax per Claude Code's
    # permissions documentation: a bare tool name or a tool-name glob ("*", "Web*") removes
    # the tool; a scoped rule (`WebFetch(domain:x)`, `Bash(curl -X POST *)`) blocks only the
    # calls it matches, so it BLOCKs here only when it covers a resolver.
    import fnmatch
    # The hosts the lookup probe and roles 2 and 6 depend on -- rfc-editor.org is the probe's
    # documentation page, item 3.
    RESOLVERS = ("doi.org", "dx.doi.org", "api.crossref.org", "crossref.org",
                 "eutils.ncbi.nlm.nih.gov", "pubmed.ncbi.nlm.nih.gov", "ncbi.nlm.nih.gov",
                 "www.rfc-editor.org", "rfc-editor.org")
    FETCHERS = ("curl", "wget", "invoke-webrequest", "iwr", "invoke-restmethod", "irm")

    def covers_resolver(pattern):
        p = pattern.lower().strip()
        return any(fnmatch.fnmatch(h, p) or h == p or h.endswith("." + p) for h in RESOLVERS)

    def lookup_verdict(rule):
        """BLOCK, WARN, or None for one deny/ask rule."""
        r = rule.strip()
        m = re.match(r"^([A-Za-z*?_\[\]-]+)\s*(?:\((.*)\))?$", r, re.S)
        if not m:
            return None
        name, arg = m.group(1), m.group(2)
        if name.lower().startswith("mcp__"):
            return "WARN"                                 # a connector route, removed
        if arg is None:                                   # a whole tool, or a name glob
            if name in ("Bash", "PowerShell"):
                return "BLOCK"                            # the shell route goes with it
            return "BLOCK" if fnmatch.fnmatch("WebFetch", name) else None
        if name == "WebFetch":
            d = re.match(r"^\s*domain:(.+)$", arg)
            return "BLOCK" if (d is None or covers_resolver(d.group(1))) else None
        if name in ("Bash", "PowerShell"):
            if arg.strip() in ("*", ":*", ""):
                return "BLOCK"                            # `Bash(*)` is the whole shell
            # `curl:*` is the prefix form: split only the FIRST word on its colon, so a URL's
            # `https://` in a later word survives to have its host read.
            words = arg.split()
            if not words:
                return None
            head, sep, tail = words[0].partition(":")
            if sep:
                words = [head] + ([tail] if tail else []) + words[1:]
            cmd = words[0].rsplit("/", 1)[-1].rsplit("\\", 1)[-1].lower()
            if cmd not in FETCHERS:
                return None
            rest = [w for w in words[1:] if w != "*"]
            if not rest:
                return "BLOCK"                            # `curl`, `curl:*`, `curl *`
            hosts = [re.sub(r"^[a-z]+://", "", w.lower()).split("/")[0] for w in rest]
            if any(h and covers_resolver(h) for h in hosts):
                return "BLOCK"                            # a fetch aimed at a resolver
            return "WARN"                                 # scoped to something else
        return None
        return None

    for key, kind in (("deny", None), ("ask", "ask")):
        for rule in entries("permissions", key):
            v = lookup_verdict(rule)
            if v is None:
                continue
            if kind == "ask":
                print("WARN\t%s: permissions.ask has %r — every lookup will prompt, and a "
                      "background reviewer cannot answer the prompt" % (path, rule))
            else:
                print("%s\t%s: permissions.deny has %r" % (v, path, rule))

    # dontAsk auto-denies anything not pre-approved, so there an allow list IS restrictive.
    mode = (cfg.get("permissions") or {}).get("defaultMode") if isinstance(cfg.get("permissions"), dict) else None
    if mode == "dontAsk":
        # An allow entry is a route if, read as a deny, it would have BLOCKED one: WebFetch or
        # a resolver domain, the shell, a fetcher or a fetch aimed at a resolver. A connector
        # counts too, since this scan cannot tell a literature connector from any other; the
        # probe settles whether it reaches anything.
        def opens_route(a):
            return lookup_verdict(a) == "BLOCK" or a.strip().lower().startswith("mcp__")
        if not any(opens_route(a) for a in entries("permissions", "allow")):
            print("BLOCK\t%s: permissions.defaultMode is dontAsk and nothing in permissions.allow "
                  "lets a lookup through (WebFetch, curl, or a connector)" % path)

    sandbox = cfg.get("sandbox") if isinstance(cfg.get("sandbox"), dict) else {}
    net = sandbox.get("network") if isinstance(sandbox.get("network"), dict) else {}
    for d in (net.get("deniedDomains") or []):
        if isinstance(d, str) and covers_resolver(d):
            print("BLOCK\t%s: sandbox.network.deniedDomains has %r — a sandboxed shell "
                  "fetch cannot reach the resolvers" % (path, d))

    hooks = cfg.get("hooks")
    if isinstance(hooks, dict):
        for entry in hooks.get("PreToolUse") or []:
            if not isinstance(entry, dict) or not isinstance(entry.get("matcher", ""), str):
                continue
            mt = entry.get("matcher", "")
            try:
                hit = mt.strip() in ("", "*") or bool(re.search(mt, "WebFetch"))
            except re.error:
                continue
            if hit:
                print("WARN\t%s: PreToolUse matcher %r runs on WebFetch" % (path, mt or "(empty)"))
    sys.exit(0)


perm = "permissions"
for rule in entries(perm, "deny"):
    if NAMES.match(rule.strip()):
        print("BLOCK\t%s: permissions.deny has %r" % (path, rule))
for rule in entries(perm, "ask"):
    if NAMES.match(rule.strip()):
        print("WARN\t%s: permissions.ask has %r — every role spawn will prompt" % (path, rule))

# An allow-list is restrictive in a way a deny-list is not: naming any tool excludes the
# rest. Absence of Task here is therefore a finding, where absence from `deny` is not.
# (⚠ Questioned in review, 2026-10-22: Claude Code's permissions documentation describes
# `permissions.allow` as pre-approval, restrictive only under `dontAsk`. Left as it was here;
# the lookup scan above applies the documented reading.)
allow = entries(perm, "allow") + entries("allowedTools")
if allow and not any(NAMES.match(r.strip()) for r in allow):
    print("BLOCK\t%s: an allow-list of %d tools that does not include Task" % (path, len(allow)))

for rule in entries("disallowedTools"):
    if NAMES.match(rule.strip()):
        print("BLOCK\t%s: disallowedTools has %r" % (path, rule))

# A PreToolUse hook can deny the call outright. Whether a given hook WOULD deny it is not
# knowable from here — it is somebody's script — so this is a WARN that names the matcher,
# not a verdict on the hook.
hooks = cfg.get("hooks")
if isinstance(hooks, dict):
    for entry in hooks.get("PreToolUse") or []:
        if not isinstance(entry, dict):
            continue
        m = entry.get("matcher", "")
        if not isinstance(m, str):
            continue
        hit = False
        if m.strip() in ("", "*"):
            hit = True                        # empty/star matcher runs on every tool
        else:
            try:
                hit = bool(re.search(m, TOOL))
            except re.error:
                continue
        if hit:
            print("WARN\t%s: PreToolUse matcher %r runs on %s" % (path, m or "(empty)", TOOL))
PYEOF
  ) ; rc=$?
  if [ "$rc" != 0 ]; then undet "reading $f failed (python exit $rc)"; return 0; fi

  local kind text
  while IFS=$'\t' read -r kind text; do
    [ -n "${kind:-}" ] || continue
    if [ "$SCAN" = lookup ]; then
      case "$kind" in
        BLOCK) block "$text" "lift it for this review, or grant roles 2 and 6 a connector" ;;
        WARN)  warn  "$text" "check it leaves roles 2 and 6 a route; the lookup probe decides" ;;
        UNDET) undet "$text" ;;
      esac
      continue
    fi
    case "$kind" in
      BLOCK) block "$text" "remove the rule, or add \"Task\" to permissions.allow in that file" ;;
      WARN)  warn  "$text" "confirm it lets the Agent tool through before relying on a fan-out" ;;
      UNDET) undet "$text" ;;
    esac
  done <<EOF
$out
EOF
}

# --- the PROSE surface -------------------------------------------------------
#
# This is the one that has actually bitten, so it is not an afterthought. An instruction
# file can forbid subagents in plain English, and no permission system is involved: the
# model simply does not spawn them. Two greps rather than one regex — find the noun, then
# require a negation on the same line — because a single alternation big enough to catch
# the phrasings is also big enough to differ between BSD and GNU grep.
NOUN='sub-?agents?|agent tool|agenttool|task tool|AgentTool'
NEG='do not|don.t|never|avoid|without|refrain|disable|forbid|prohibit|not allowed|unless'
# --lookup reads the same files for a ban on fetching. Reported as WARN, never BLOCK:
# "network" and "curl" turn up in ordinary instructions about everything else ("never block
# startup on the network"), so a hit is a line worth reading, not a verdict.
LOOKUP_NOUN='webfetch|web ?fetch|curl|wget|network access|internet access|fetch(ing)? from the web'

scan_prose() {
  local f="$1"
  [ -f "$f" ] || return 0
  if [ ! -r "$f" ]; then undet "instruction file exists but is unreadable: $f"; return 0; fi
  local hits noun=$NOUN
  [ "$SCAN" = lookup ] && noun=$LOOKUP_NOUN
  hits=$(grep -n -i -E "$noun" "$f" 2>/dev/null | grep -i -E "$NEG" 2>/dev/null | head -3)
  [ -n "$hits" ] || return 0
  local line
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ "$SCAN" = lookup ]; then
      warn "$f:${line%%:*} — may forbid fetching" \
           "if it forbids fetching, lift it for this review"
    else
    block "$f:${line%%:*} — an instruction here reads as forbidding subagents" \
          "no permission system is involved; edit the line, or tell the session to allow subagents for this run"
    fi
    say "         ${DIM}> $(printf '%s' "${line#*:}" | sed -e 's/^[0-9]*://' -e 's/^[[:space:]]*//' | cut -c1-96)${RST}"
  done <<EOF
$hits
EOF
}

# --- main --------------------------------------------------------------------
run_scan() {
  local root cfgdir managed
  root="${ROOT:-$(repo_root)}"
  cfgdir="${CONFIG_DIR:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}}"
  managed="${MANAGED:-$(default_managed)}"

  # Precedence order, weakest last. Reported in the order a human would go looking.
  scan_json "$managed"
  scan_json "$cfgdir/settings.json"
  scan_json "$cfgdir/settings.local.json"
  scan_json "$root/.claude/settings.json"
  scan_json "$root/.claude/settings.local.json"

  scan_prose "$cfgdir/CLAUDE.md"
  scan_prose "$root/CLAUDE.md"
  scan_prose "$root/.claude/CLAUDE.md"
  scan_prose "$root/AGENTS.md"
  local style
  for style in "$cfgdir"/output-styles/*.md; do
    [ -f "$style" ] && scan_prose "$style"
  done
}

report() {
  # --hook: say nothing at all unless there is a blocker. Undetermined is not worth a line
  # at session start — the probe will settle it, and noise here trains people to skip it.
  if [ "$HOOK" = 1 ] && [ "$BLOCKERS" = 0 ]; then return 0; fi

  if [ "$SCAN" = lookup ]; then report_lookup_scan; return 0; fi

  if [ "$BLOCKERS" = 0 ] && [ "$UNDETERMINED" = 0 ]; then
    printf '%smurderboard: no subagent blocker found in the readable settings and instruction files.%s\n' "$GRN" "$RST"
  else
    printf 'murderboard: subagent preflight\n'
    printf '%s' "$OUT"
    if [ "$BLOCKERS" -gt 0 ]; then
      printf '%smurderboard: %s blocker(s) — a fan-out review will degrade to single-pass here.%s\n' "$RED" "$BLOCKERS" "$RST"
    fi
  fi

  # Printed on EVERY path, including the clean one, and deliberately so. The clean line
  # above is the sentence most likely to be quoted back as "subagents are fine", which is
  # not what this script can know.
  printf '%sThis scan reads files. It cannot see the session'\''s tool list, a launch flag, or an\ninstruction injected at runtime — the block that caused this repo'\''s one degraded run\n(2026-08-26) was in none of these files. A clean scan is NOT proof subagents work; only\nspawning one and getting an answer back proves that.%s\n' "$DIM" "$RST"
}

# --lookup prints its WARN lines on the clean path too. Its prose hits are warnings by
# design, and a warning nobody is shown is a scan that found something and said "clean".
report_lookup_scan() {
  if [ "$BLOCKERS" = 0 ] && [ "$UNDETERMINED" = 0 ]; then
    if [ -n "$OUT" ]; then
      printf 'murderboard: no lookup blocker found, but read the warnings below.\n'
    else
      printf '%smurderboard: no lookup blocker found in the readable settings and instruction files.%s\n' "$GRN" "$RST"
    fi
    printf '%s' "$OUT"
  else
    printf 'murderboard: lookup scan — settings that could stop roles 2 and 6\n'
    printf '%s' "$OUT"
    if [ "$BLOCKERS" -gt 0 ]; then
      printf '%smurderboard: %s blocker(s) — roles 2 and 6 may not reach their sources here.%s\n' "$RED" "$BLOCKERS" "$RST"
    fi
  fi
  # Issue #74's cause WAS in a file -- the project's settings denied WebFetch, curl and wget --
  # and this scan finds that shape. What it cannot see is everything outside the files.
  printf '%sThis scan reads files. It cannot see a launch flag, a tool missing for another\nreason, or which literature connectors are attached. A clean scan is NOT proof\na reference can be looked up; only the lookup probe proves that.%s\n' "$DIM" "$RST"
}

cmd_scan() {
  run_scan
  report
  [ "$BLOCKERS" -gt 0 ] && return 1
  [ "$UNDETERMINED" -gt 0 ] && return 2
  return 0
}

# --- selftest ----------------------------------------------------------------
# Every branch must be able to FIRE. A preflight that cannot report a blocker is worse
# than none: it is a standing all-clear.
cmd_selftest() {
  local pass=0 fail=0
  MB_TMP=$(mktemp -d) || die "selftest: mktemp failed"
  trap 'rm -rf "$MB_TMP"' EXIT
  local tmp="$MB_TMP"

  t() { # t <name> <expected-exit> <root> <cfgdir> [scan]
    local name="$1" want="$2" root="$3" cfg="$4" scan="${5:-subagents}"
    local got=0
    ( ROOT="$root" CONFIG_DIR="$cfg" MANAGED=/nonexistent/managed.json HOOK=0 SCAN="$scan" \
      BLOCKERS=0 UNDETERMINED=0 OUT= cmd_scan ) >/dev/null 2>&1 || got=$?
    if [ "$got" = "$want" ]; then pass=$((pass+1)); printf '  ok   %s\n' "$name"
    else fail=$((fail+1)); printf '  %sFAIL%s %s (want exit %s, got %s)\n' "$RED" "$RST" "$name" "$want" "$got"; fi
  }

  # a clean environment
  mkdir -p "$tmp/clean/.claude" "$tmp/cfgclean"
  printf '{"model":"opus"}\n' > "$tmp/cfgclean/settings.json"
  printf '# project\n\nRun the murderboard with parallel subagents.\n' > "$tmp/clean/CLAUDE.md"
  t 'clean environment -> exit 0'          0 "$tmp/clean" "$tmp/cfgclean"

  # permissions.deny
  mkdir -p "$tmp/deny/.claude" "$tmp/cfgnull"
  printf '{}\n' > "$tmp/cfgnull/settings.json"
  printf '{"permissions":{"deny":["Task"]}}\n' > "$tmp/deny/.claude/settings.json"
  t 'permissions.deny Task -> exit 1'      1 "$tmp/deny" "$tmp/cfgnull"

  # an allow-list that omits Task
  mkdir -p "$tmp/allow/.claude"
  printf '{"permissions":{"allow":["Bash","Read","Edit"]}}\n' > "$tmp/allow/.claude/settings.json"
  t 'allow-list without Task -> exit 1'    1 "$tmp/allow" "$tmp/cfgnull"

  # an allow-list that includes it is NOT a finding — the alarm must not ring on the fix
  mkdir -p "$tmp/allowok/.claude"
  printf '{"permissions":{"allow":["Bash","Task"]}}\n' > "$tmp/allowok/.claude/settings.json"
  t 'allow-list with Task -> exit 0'       0 "$tmp/allowok" "$tmp/cfgnull"

  # prose in an instruction file — the case that actually happened
  mkdir -p "$tmp/prose/.claude"
  printf '# repo\n\nDo not call the AgentTool unless the user requested it.\n' > "$tmp/prose/CLAUDE.md"
  t 'prose forbidding subagents -> exit 1' 1 "$tmp/prose" "$tmp/cfgnull"

  # malformed JSON is UNDETERMINED, never clean
  mkdir -p "$tmp/bad/.claude"
  printf '{"permissions":\n' > "$tmp/bad/.claude/settings.json"
  t 'malformed settings -> exit 2'         2 "$tmp/bad" "$tmp/cfgnull"

  # --hook is silent on a clean tree and speaks on a blocked one
  local out
  out=$( ROOT="$tmp/clean" CONFIG_DIR="$tmp/cfgclean" MANAGED=/nonexistent/managed.json \
         HOOK=1 BLOCKERS=0 UNDETERMINED=0 OUT= cmd_scan 2>&1 ); :
  if [ -z "$out" ]; then pass=$((pass+1)); printf '  ok   --hook is silent when clean\n'
  else fail=$((fail+1)); printf '  %sFAIL%s --hook printed on a clean tree: %s\n' "$RED" "$RST" "$out"; fi

  out=$( ROOT="$tmp/deny" CONFIG_DIR="$tmp/cfgnull" MANAGED=/nonexistent/managed.json \
         HOOK=1 BLOCKERS=0 UNDETERMINED=0 OUT= cmd_scan 2>&1 ); :
  case "$out" in
    *BLOCK*) pass=$((pass+1)); printf '  ok   --hook speaks when blocked\n' ;;
    *) fail=$((fail+1)); printf '  %sFAIL%s --hook stayed silent on a deny rule\n' "$RED" "$RST" ;;
  esac

  # the caveat must be on the CLEAN path too, or the clean line becomes an all-clear
  out=$( ROOT="$tmp/clean" CONFIG_DIR="$tmp/cfgclean" MANAGED=/nonexistent/managed.json \
         HOOK=0 BLOCKERS=0 UNDETERMINED=0 OUT= cmd_scan 2>&1 ); :
  case "$out" in
    *"is NOT proof"*) pass=$((pass+1)); printf '  ok   clean report still carries the caveat\n' ;;
    *) fail=$((fail+1)); printf '  %sFAIL%s clean report omitted the caveat\n' "$RED" "$RST" ;;
  esac

  # --- --lookup: the same surfaces, read for what roles 2 and 6 need ------------------
  # Issue #74's cause sat in the project's own settings, which this scan reads; its fixture
  # is below. A launch flag would not have, which is why the probe, not this scan, is the gate.
  t 'lookup: clean environment -> exit 0'      0 "$tmp/clean" "$tmp/cfgclean" lookup
  mkdir -p "$tmp/curl/.claude"
  printf '{"permissions":{"deny":["Bash(curl:*)"]}}\n' > "$tmp/curl/.claude/settings.json"
  t 'lookup: deny Bash(curl:*) -> exit 1'      1 "$tmp/curl" "$tmp/cfgnull" lookup
  mkdir -p "$tmp/wf/.claude"
  printf '{"permissions":{"deny":["WebFetch"]}}\n' > "$tmp/wf/.claude/settings.json"
  t 'lookup: deny WebFetch -> exit 1'          1 "$tmp/wf" "$tmp/cfgnull" lookup
  mkdir -p "$tmp/wfd/.claude"
  printf '{"permissions":{"deny":["WebFetch(domain:doi.org)"]}}\n' > "$tmp/wfd/.claude/settings.json"
  t 'lookup: a domain-scoped WebFetch deny -> exit 1' 1 "$tmp/wfd" "$tmp/cfgnull" lookup
  # The two scans must not bleed into each other: each one's blocker is the other's non-event.
  t 'lookup: deny Task is not a lookup blocker'   0 "$tmp/deny" "$tmp/cfgnull" lookup
  t 'subagents: deny WebFetch is not a subagent blocker' 0 "$tmp/wf" "$tmp/cfgnull"
  # A Bash rule scoped to something other than a fetch leaves the curl route alone.
  mkdir -p "$tmp/bash/.claude"
  printf '{"permissions":{"deny":["Bash(rm:*)"]}}\n' > "$tmp/bash/.claude/settings.json"
  t 'lookup: an unrelated Bash deny -> exit 0' 0 "$tmp/bash" "$tmp/cfgnull" lookup
  # An allow-list only pre-approves (permissions documentation); outside dontAsk it
  # restricts nothing.
  t 'lookup: an allow-list alone -> exit 0'    0 "$tmp/allow" "$tmp/cfgnull" lookup

  lk() { # lk <name> <expected-exit> <settings-json>
    local d="$tmp/lk$((pass + fail))"
    mkdir -p "$d/.claude"; printf '%s\n' "$3" > "$d/.claude/settings.json"
    t "lookup: $1" "$2" "$d" "$tmp/cfgnull" lookup
  }
  # THE #74 SHAPE: the fetch-related entries of the consumer's committed deny list, plus one
  # of its unrelated ones.
  lk 'the issue #74 deny list -> exit 1' 1 \
     '{"permissions":{"deny":["Bash(rm -rf:*)","Bash(curl:*)","Bash(wget:*)","WebFetch"]}}'
  # Scoped rules block only what they match (permissions documentation).
  lk 'WebFetch denied for an unrelated domain -> exit 0' 0 \
     '{"permissions":{"deny":["WebFetch(domain:facebook.com)"]}}'
  lk 'curl denied for POSTs only -> exit 0 (a warning)' 0 \
     '{"permissions":{"deny":["Bash(curl -X POST *)"]}}'
  lk 'curl by absolute path -> exit 1' 1 '{"permissions":{"deny":["Bash(/usr/bin/curl *)"]}}'
  lk 'PowerShell Invoke-WebRequest -> exit 1' 1 \
     '{"permissions":{"deny":["PowerShell(Invoke-WebRequest:*)"]}}'
  # A tool-name glob removes every tool it matches.
  lk 'deny "*" -> exit 1'                1 '{"permissions":{"deny":["*"]}}'
  lk 'deny "Web*" -> exit 1'             1 '{"permissions":{"deny":["Web*"]}}'
  # WebSearch is not a lookup route: a search hit is not a resolution.
  lk 'deny WebSearch alone -> exit 0'    0 '{"permissions":{"deny":["WebSearch"]}}'
  # dontAsk turns "not pre-approved" into "denied".
  lk 'dontAsk with no lookup route allowed -> exit 1' 1 \
     '{"permissions":{"defaultMode":"dontAsk","allow":["Read"]}}'
  lk 'dontAsk with WebFetch allowed -> exit 0' 0 \
     '{"permissions":{"defaultMode":"dontAsk","allow":["WebFetch"]}}'
  lk 'dontAsk with the whole shell allowed -> exit 0' 0 \
     '{"permissions":{"defaultMode":"dontAsk","allow":["Bash"]}}'
  lk 'dontAsk with curl to doi.org allowed -> exit 0' 0 \
     '{"permissions":{"defaultMode":"dontAsk","allow":["Bash(curl https://doi.org/*)"]}}'
  # Denying the whole shell removes the curl route with it.
  lk 'deny the whole shell -> exit 1'    1 '{"permissions":{"deny":["Bash"]}}'
  lk 'deny Bash(*) -> exit 1'            1 '{"permissions":{"deny":["Bash(*)"]}}'
  # A connector named outright is a route removed: worth a warning, not a verdict.
  lk 'deny a connector -> exit 0 (a warning)' 0 \
     '{"permissions":{"deny":["mcp__plugin_bio-research_pubmed"]}}'
  lk 'sandbox denying doi.org -> exit 1' 1 '{"sandbox":{"network":{"deniedDomains":["doi.org"]}}}'
  # The probe's own documentation host, item 3, is a resolver for this purpose.
  lk 'WebFetch denied for rfc-editor.org -> exit 1' 1 \
     '{"permissions":{"deny":["WebFetch(domain:rfc-editor.org)"]}}'
  # A curl rule aimed at a resolver blocks the lookup; one aimed elsewhere does not.
  lk 'curl to doi.org denied -> exit 1' 1 '{"permissions":{"deny":["Bash(curl https://doi.org/*)"]}}'
  # Under dontAsk, a curl allowed only for POSTs is not a lookup route.
  lk 'dontAsk allowing only POST curl -> exit 1' 1 \
     '{"permissions":{"defaultMode":"dontAsk","allow":["Bash(curl -X POST *)"]}}'
  # Prose is a WARN under --lookup, and a WARN must still be SHOWN on the clean path.
  mkdir -p "$tmp/lprose/.claude"
  printf '# repo\n\nNever use WebFetch on this machine.\n' > "$tmp/lprose/CLAUDE.md"
  t 'lookup: prose hit is a warning, exit 0'   0 "$tmp/lprose" "$tmp/cfgnull" lookup
  out=$( ROOT="$tmp/lprose" CONFIG_DIR="$tmp/cfgnull" MANAGED=/nonexistent/managed.json \
         HOOK=0 SCAN=lookup BLOCKERS=0 UNDETERMINED=0 OUT= cmd_scan 2>&1 ); :
  case "$out" in
    *WARN*"is NOT proof"*) pass=$((pass+1)); printf '  ok   lookup: a prose warning is printed, with the caveat\n' ;;
    *) fail=$((fail+1)); printf '  %sFAIL%s lookup: a prose warning was swallowed on the clean path\n' "$RED" "$RST" ;;
  esac

  printf '\n%s passed, %s failed\n' "$pass" "$fail"
  [ "$fail" = 0 ]
}

# --- args --------------------------------------------------------------------
CMD=scan
while [ $# -gt 0 ]; do
  case "$1" in
    --hook)       HOOK=1; shift ;;
    --explain)    EXPLAIN=1; shift ;;
    --lookup)     SCAN=lookup; shift ;;
    --root)       ROOT="${2:-}"; shift 2 ;;
    --config-dir) CONFIG_DIR="${2:-}"; shift 2 ;;
    --managed)    MANAGED="${2:-}"; shift 2 ;;
    --selftest)   CMD=selftest; shift ;;
    -h|--help)    sed -n '2,60p' "$0"; exit 0 ;;
    *)            die "murderboard_subagents: unknown argument '$1'" ;;
  esac
done

case "$CMD" in
  scan)     cmd_scan ;;
  selftest) cmd_selftest ;;
esac
