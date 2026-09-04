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
for p in tools/murderboard_subagents.sh murderboard_subagents.sh; do
  [ -r "$root/$p" ] && SUBAGENTS="$root/$p" && break
done
# Where the compiled agent files belong in the repo BEING REVIEWED. Claude Code scans
# `.claude/agents/` recursively, so the eleven go in a subdirectory this tool owns — writing
# them loose into the shared directory is how an earlier version deleted a consumer's own
# subagents. Ask the compiler rather than reproducing its rule here; it detects the
# murderboard's own checkout by plugin NAME, since any consumer may publish a plugin too.
AGENTDIR=$(python3 "$COMPILER" --print-dir 2>/dev/null) \
  || AGENTDIR="$root/.claude/agents/murderboard"

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
    SUBAGENTS="$MB/murderboard_subagents.sh"
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

### 1a. Subagents — PROBE, do not infer

**Ask now, while a "no" is still cheap.** The review runs eleven roles as independent
subagents. When the Agent tool is not available this run does not fail — it *degrades*, into
the single-pass self-review the process already permits for small deliverables, and the report
it produces is indistinguishable from one where eleven independent reviewers agreed. That has
happened here: `docs/reviews/plugin_adoption_docs_murderboard_2026-08-26.md` is a full
eleven-role run in which one agent played every part. It is legible as such only because its
author volunteered a "Stated deviation" section.

**Spawn one throwaway subagent and require an answer back.** Not a settings check — an actual
spawn:

> Reply with exactly this and nothing else: `MB-PROBE-OK`

Nothing else proves it. Availability is decided by the session's tool list, a launch flag, the
permission mode, an instruction injected by the harness or the IDE, or by already being inside
a subagent — and a subagent cannot spawn one. Several of those appear in no file on the
machine. **The 2026-08-26 block was of exactly that kind**, so any amount of config-reading
would have returned a clean bill of health for the one case that has actually cost this project
a degraded run.

Then act on the answer:

- **Token comes back** → subagents work. The run record's `Execution:` line says
  `parallel subagents`. Carry on.
- **It does not** → **STOP, before role 1.** Say so plainly, and name the knob, which is what
  the scanner is for:
  ```bash
  [ -n "${SUBAGENTS:-}" ] && bash "$SUBAGENTS" --explain ; echo "exit=$?"
  ```
  It reports the blockers it can see — a `permissions.deny` rule, an allow-list without
  `Task`, a `PreToolUse` hook that runs on the Agent tool, an instruction file that forbids
  subagents in plain English. **Its exit 0 is not an all-clear** and it says so on every run:
  it reads files, and the answer is not always in a file. A clean scan under a failed probe
  means the block is in the session, not on disk — which is still actionable, and is the case
  the human can usually fix in one sentence.

  Then ask, and wait. Do not start the roles on the assumption that a weaker review now beats
  a real one shortly.

**Two things the human's "go ahead anyway" cannot buy:**

- **A single-pass run must be declared as forced**, on the `Execution:` line, in those terms —
  never left to read as the chosen case. The roster gate rejects a bare `single-pass`.
- **A deliverable that attributes a method, claims novelty, or says something is "ours" may not
  run single-pass at all**, whatever its length. The process file makes role 2 a separate agent
  in that case specifically because a single pass inherits the drafter's search history and so
  stops searching in the same place for the same reason. Blindness is the mechanism, and one
  pass cannot supply it. If subagents are unavailable and the deliverable makes an attribution
  claim, the run does not proceed.

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
resolve**, fall back to spawning a generic subagent whose prompt is **the contents of that
role's agent file**, and if there is no agent file either, the role's block from `$PROCESS`.

**Expect the fallback on a repo's FIRST run, always.** Claude Code watches the agent
directories and picks up edits within seconds with no restart — but only for directories that
existed when the session started. Compiling the first time creates that directory, so nothing
watches it yet and the named agents cannot resolve until the session restarts. That is not a
failure; it is the first run. Say so in the record, and tell the human a restart converts
subsequent runs to named agents.

⚠ **Path 3 cannot satisfy the grants gate.** A role's block in `$PROCESS` carries its checklist
but not the grant-declaration instruction, which the compiler injects. A role spawned that way
emits no `GRANT` line and step 7's `verify` will report it as undeclared — correctly. Prefer
path 2 whenever an agent file exists.

**Say which path you used in the run record.** The fallback does not merely lose a grant — a
generic subagent inherits whatever the harness hands it, which is sometimes *more* than the
process file allows, including the editing tools no reviewer may have. So `roles:` in the
header takes a suffix: `11 of 11 run (named agents)` or `11 of 11 run (inline fallback)`.

**You do not have to take that on trust, and neither does the reader.** Every agent file tells
its role to open with `GRANT <n> ok — <tools held>` or `GRANT <n> MISMATCH — …`. Carry those
lines into the role ledger verbatim; step 7 gates the header against them. A `MISMATCH` is not
a failed run — a fallback review is a real review — it just may not be written up as something
else.

Scale to stakes in *how* you run them, never in *which* ones:

- **Substantial deliverable** (methods, manuscript, explainer, deck, multi-paragraph report)
  → parallel subagents, one per role, via the Agent tool.
- **Small deliverable** (a caption, a one-liner) → a single-pass self-review that still walks
  every role's checklist in turn and still produces role 10's table.

**This is a choice about stakes, and step 1a has already established whether it is available
to make.** The two bullets above used to be the only thing said about fan-out, which left the
degraded case with somewhere to hide: a run that *could not* spawn landed in the second bullet
and looked like a run that had *judged* its way there. If the probe failed, you are in the
second bullet by constraint — write it down as such.

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

Execution: parallel subagents | single-pass (<forced by what, or chosen why>)   # from step 1a
```

`roles:` and `Execution:` answer different questions and neither implies the other. `roles:`
says which **prompt** each reviewer got — its compiled agent file, or the role's block inlined.
`Execution:` says whether there was ever **more than one reviewer**. A run can spawn eleven
named agents, or play eleven parts alone from those same eleven files; the ledger looks the
same either way. `Execution:` goes on a line of its own, beside `Mode:`, because that is where
the gate looks for it.

Then the **role ledger** — one row per role, all of them, each with its finding count or its
"nothing to check, here is what I checked" line — followed by the findings and their
adjudications, and any residual `⚠` the human must resolve.

Finally, gate your own output:

```bash
REPORT=docs/reviews/<artifact-stem>_<YYYY-MM-DD>.md
bash "$ROSTER" check --require-execution "$REPORT" ; echo "roster=$?"
[ -n "${COMPILER:-}" ] && python3 "$COMPILER" --process "$PROCESS" verify "$REPORT" ; echo "grants=$?"
```

**roster exit 1 means a role is missing from the ledger — the run is not finished.** Either that
role never ran (run it) or it ran and left no trace (record it). Do not deliver past a failing
check; a report that cannot show all its roles is the failure mode this skill was built for.

It also fails, under `--require-execution`, on a missing or unqualified `Execution:` line — a
bare `single-pass` is rejected until it says whether subagents were **unavailable** or
single-pass was **chosen**. Those are not the same event: one is the process working as
designed on a one-line deliverable, the other an environment defect that will recur silently on
every run until somebody fixes it. Do not satisfy this by picking whichever word makes it
green; step 1a already knows which it was.

**grants exit 1 means the report does not account for what its reviewers said they held.** Four
shapes fail: a role never declared its grant; a role declared `ok` while naming tools that are
not the ones the process file grants it (naming none at all is this case, not a lesser one); a
role declared **both** `ok` and `MISMATCH`; or the header claims `named agents` while a role
reported `MISMATCH`. The two gates ask different questions and neither substitutes for the
other: the roster asks *did every role leave a trace*, this asks *did every role state what it
held*. Fix the header or re-run with the grants in place; do not delete the `GRANT` lines to
make it green.

**A contradiction is reported, never resolved.** If one role declared both verdicts the gate
will not pick one — last-wins is how an honest `MISMATCH` used to launder into `ok`, since every
agent file carries the literal string `GRANT n ok — <its tools>` and a report that quotes its own
agent files is the most thorough one anyone would write. If a quotation supplied the second
verdict, break the quotation. Otherwise state, once, what the reviewer actually reached.

⚠ **What this gate still does NOT do, stated because the wording here has twice claimed more
than was true.** It reads a report. It cannot tell you a declaration is *honest*: a reviewer
that types its granted tools back without ever holding them passes, and so does one that could
not perform its check. It proves that every role said what it held and that what it said matches
the grant it was issued — not that the tools were there. Containment and equipment are enforced
where the agent is spawned, not here.

## What to hand the human

The corrected deliverable, the path to the run record, and a short plain summary: what was
checked, what was found and fixed, how many verify rounds, and every residual `⚠`. A
deliverable with unresolved `⚠` flags is **not "done."**
