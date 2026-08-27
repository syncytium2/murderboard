---
# canonical: syncytium2/murderboard skills/murderboard/SKILL.md
# When vendoring, INSERT a line just below the --- above: vendored from https://github.com/syncytium2/murderboard @ <short-sha> — do NOT edit here; update by re-copying. (murderboard_revendor.py does this, and keeps it in the right place.)
name: murderboard
description: Run the murderboard — the adversarial critical-review process — on a document deliverable before it ships. Use whenever the deliverable is an explainer, methods section, manuscript/abstract/cover-letter text, a figure or its caption/labels, a report, a slide deck, or a human-facing handoff. Also use when asked to "murderboard", "critically review", or "check this before I send it". Not for source code (that is the code-review path), quick conversational answers, or throwaway diagnostics.
---

# Murderboard — call-up

This skill is the **entry point**. It owns the mechanics of *invoking* the review correctly.
It does **not** restate the review itself — the roles, their checklists, and every rule live
in `doc_review_process.md`, which you will load in step 2 and follow.

> **Why a skill exists at all.** The process file already carried the diagnosis — *"a rule
> that depends on being remembered is not a gate"* — and applied it only to its own preflight.
> Invocation stayed prose, so a review could be summoned late, run against a stale copy, fire
> 7 of 11 roles, or target the generator instead of the built file, and every one of those
> outcomes looked exactly like success. The steps below are the parts that must not depend on
> anyone remembering them.

## 0. Resolve the paths — do not assume a layout

There are two ways these files get onto a machine, and they land in different places:
**vendored** (copied into the repo, at whatever paths that project chose) or **installed**
(a Claude Code plugin, under `~/.claude/plugins/cache/…`). Find them before anything else:

```bash
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
MODE=vendored; MB=

# VENDORED WINS when the repo has its own copy, even if a plugin is also installed.
# That copy is the project's declared version — possibly pinned on purpose, and it is the
# one its CI and its SessionStart hook police. Silently preferring the newer installed
# copy would review against a process the repo never agreed to, and the run record would
# name a commit that appears nowhere in it.
for p in docs/doc_review_process.md doc_review_process.md; do
  [ -r "$root/$p" ] && PROCESS="$root/$p" && break
done
for p in tools/murderboard_freshness.sh murderboard_freshness.sh; do
  [ -r "$root/$p" ] && FRESH="$root/$p" && break
done
for p in tools/murderboard_roster.sh murderboard_roster.sh; do
  [ -r "$root/$p" ] && ROSTER="$root/$p" && break
done
for p in tools/murderboard_agents.py murderboard_agents.py; do
  [ -r "$root/$p" ] && COMPILER="$root/$p" && break
done
# Where the compiled agent files belong in THIS repo. Claude Code loads `.claude/agents/`;
# the murderboard's own checkout is a plugin, so its copies live at `agents/` and ship.
AGENTDIR="$root/.claude/agents"; [ -d "$root/.claude-plugin" ] && AGENTDIR="$root/agents"

# Nothing vendored here — fall back to the plugin install. $CLAUDE_PLUGIN_ROOT is set when
# this skill came from a plugin, but do not rely on it reaching the shell: glob the install
# cache as a fallback, newest version last.
if [ -z "${PROCESS:-}" ]; then
  MB="${CLAUDE_PLUGIN_ROOT:-}"
  if [ -z "$MB" ] || [ ! -r "$MB/doc_review_process.md" ]; then
    for d in "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"/plugins/cache/*/murderboard/*/; do
      [ -r "$d/doc_review_process.md" ] && MB="${d%/}"
    done
  fi
  if [ -n "$MB" ] && [ -r "$MB/doc_review_process.md" ]; then
    MODE=installed
    PROCESS="$MB/doc_review_process.md"
    FRESH="$MB/murderboard_freshness.sh"
    ROSTER="$MB/murderboard_roster.sh"
    COMPILER="$MB/murderboard_agents.py"
    AGENTDIR="$MB/agents"      # the plugin ships them already compiled
  fi
fi
echo "mode=$MODE process=${PROCESS:-NONE} agents=${AGENTDIR:-NONE}"
```

If `$PROCESS` is missing, **stop** and say the repo has neither vendored the murderboard nor
got it installed — do not reconstruct the process from memory. A remembered murderboard is
the thing this whole apparatus exists to prevent.

## 1. Freshness — a HARD GATE, here, now

```bash
if [ "$MODE" = installed ]; then
  bash "$FRESH" --refresh --verbose --plugin "$MB" ; echo "exit=$?"
else
  bash "$FRESH" --refresh --verbose ; echo "exit=$?"
fi
```

The two modes ask the same question — *is this copy behind upstream?* — of different
evidence. A vendored copy is judged by the stamp written into it; an installed one by the
commit the installer recorded for it. Both answer 0/1/2 and both are hard gates. **An
install is not exempt:** `/plugin update` exists but nothing fires it, so an installed copy
goes stale exactly the way a vendored one does.

- **exit 0** — current. Proceed.
- **exit 1 — STALE. STOP.** Update first, then start over — re-vendor if `MODE=vendored`,
  `/plugin update murderboard` if `MODE=installed`. Do not "note it and continue": a review
  run against a stale process silently omits rules the process has already learned, and the
  report will claim coverage it did not have.
- **exit 2** — could not determine. Proceed, but the run record's `freshness:` field says
  `UNDETERMINED`, and you say so in the delivered summary.

This is deliberately **not** the same as the SessionStart freshness check. That one is an
early warning: it serves a *cached* verdict, once, at startup, for whichever worktree the
session began in. This one fires in the worktree you are actually reviewing in, at the moment
you review, with `--refresh` so it cannot serve a stale cache. Keep both.

## 2. Load the process

Read `$PROCESS` **in full** before spawning anything. It is the authority on what each role
does; this skill is only the harness around it.

## 3. Resolve the ARTIFACT — the built file, never its generator

Ask what is actually shipping, and review *that*:

- A generated deliverable is **the built file**, not the script that builds it. If handed a
  `.py` / `.m` / builder, ask for (or build) the artifact it produces, and review both — the
  builder under roles 6–7, the built file under everything else.
- A deck / poster / PDF must be **rendered to images** and inspected page by page. A caption
  that overflows onto the figure below is invisible in the component figure, in the extracted
  text, and in a bounding-box check.
- Record the artifact's path and a fingerprint now:
  `git hash-object <artifact>` (or `sha256sum`). Step 6 needs it to prove the *corrected* file
  was re-checked rather than merely claimed to be.

## 4. Derive the roster — never recall it

```bash
bash "$ROSTER" list     # N<TAB>title, parsed out of $PROCESS
bash "$ROSTER" count
```

Spawn **one subagent per row returned**, no fewer. The roster is derived from the process
file, so when upstream adds role 12 every consumer picks it up without editing this skill.

### 4a. Compile the specialists, then spawn them BY NAME

Each role has its own agent file — frontmatter, its own checklist, and the tool grant the
process file gives it — compiled out of `$PROCESS`. Bring them up to date first; a stale
agent file is a reviewer running last month's checklist:

```bash
if [ -n "${COMPILER:-}" ]; then
  python3 "$COMPILER" --process "$PROCESS" --dir "$AGENTDIR" check \
    || python3 "$COMPILER" --process "$PROCESS" --dir "$AGENTDIR" write
  python3 "$COMPILER" --process "$PROCESS" --dir "$AGENTDIR" list   # N<TAB>agent-name<TAB>path
fi
```

Then spawn each row's `agent-name` as the subagent type. **If the named agent does not
resolve** — freshly written files are not picked up until Claude Code rescans, and a consumer
may have vendored the process file without the compiler — fall back to spawning a generic
subagent whose prompt is **the contents of that role's agent file**, and if there is no agent
file either, the role's block from `$PROCESS`. All three paths run the same eleven roles.

**Say which path you used in the run record.** The fallback loses the tool grant — a role that
should hold `WebSearch` gets whatever the generic subagent has — and a review whose citation
validator could not reach a DOI is not the same review as one whose could. `roles:` in the
header takes a suffix: `11 of 11 run (named agents)` or `11 of 11 run (inline fallback)`.

Scale to stakes in *how* you run them, never in *which* ones:

- **Substantial deliverable** (methods, manuscript, explainer, deck, multi-paragraph report)
  → parallel subagents, one per role, via the Agent tool.
- **Small deliverable** (a caption, a one-liner) → a single-pass self-review that still walks
  every role's checklist in turn and still produces role 10's table.

A role with genuinely nothing to check returns **"no findings, and here is what I checked."**
Silence is not a result.

## 5. Synthesize and apply

Consolidate, dedupe, rank by severity, adjudicate each finding (fix / flag-inline `⚠` /
no-change), and **apply** the fixes. Rebuild the artifact if it is generated.

## 6. Blind verify pass — until it comes back empty

Re-check the **corrected, rebuilt** artifact per the process file's step 4: a fresh pass that
did not do the original review, a blind pass before any finding-list-driven pass, role 10
re-run in full against the NEW render, and iterate until a blind pass produces no new
findings. **Report the number of rounds.** Confirm the artifact's fingerprint changed from
step 3 — if it did not, the fixes are not in the file you are about to ship.

## 7. Emit the run record, then let it be checked

**Lead with the problem, not the ledger.** The record is a document deliverable like any
other: open with what was at stake and — where the subject is visual — a figure showing
it, then what was found, then what would validate it and how it generalises. The header
and role ledger below are an **appendix**: required, checkable, and not the first thing a
reader meets. A record ordered by process proves the roles ran and tells nobody what was
learned (see *The run record is a deliverable* in the process file).

Write the report to `docs/reviews/<artifact-stem>_<YYYY-MM-DD>.md`, carrying this header:

```markdown
# Murderboard run — <artifact>
- upstream:  syncytium2/murderboard @ <sha>      # from step 1
- copy:      vendored | installed @ <sha>        # from step 0/1 — say WHICH, and at what
- freshness: current | UNDETERMINED
- artifact:  <path> (<hash before> -> <hash after>)
- roles:     <n> of <n> run (named agents | inline fallback)   # from step 4a
- rounds:    <n> blind verify rounds to clean
```

Then the **role ledger** — one row per role, all of them, each with its finding count or its
"nothing to check, here is what I checked" line — followed by the findings and their
adjudications, and any residual `⚠` the human must resolve.

Finally, gate your own output:

```bash
bash "$ROSTER" check docs/reviews/<artifact-stem>_<YYYY-MM-DD>.md ; echo "exit=$?"
```

**exit 1 means a role is missing from the ledger — the run is not finished.** Either that role
never ran (run it) or it ran and left no trace (record it). Do not deliver past a failing
check; a report that cannot show all its roles is the failure mode this skill was built for.

## What to hand the human

The corrected deliverable, the path to the run record, and a short plain summary: what was
checked, what was found and fixed, how many verify rounds, and every residual `⚠`. A
deliverable with unresolved `⚠` flags is **not "done."**
