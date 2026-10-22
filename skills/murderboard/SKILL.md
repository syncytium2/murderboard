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

## Preflight — what this costs, before it costs it

**Deliberately before step 0**, and unnumbered, because it gates whether the run happens at
all rather than how it is done. A murderboard is a fan-out: one subagent per role, every role,
always. **Known good: Claude Opus 5**; other current models are likely fine. On a model you
cannot afford to exhaust you get **no review and the full bill** — which is what happened on
2026-09-07 under Fable.

**A `PreToolUse` hook should already have handled this** — `murderboard_model_gate.sh`, wired
in the plugin and in consumers that vendored it. It blocks a run on a blocked model, and it
**asks the human before every run**, because the other way this wastes money is being fired
too early, at a draft that was not ready. If you are reading this line it either allowed the
call or is not installed here; do not assume the second case means no policy:

```bash
GATE=; for p in tools/murderboard_model_gate.sh murderboard_model_gate.sh \
                "${MB:-/nonexistent}/murderboard_model_gate.sh"; do
  [ -r "$p" ] && GATE="$p" && break
done
[ -n "$GATE" ] && bash "$GATE" --why || echo "no model gate present — check the model yourself"
```

**If the gate is absent, say which model you are running on and confirm the human wants to
spend it here** before spawning anything. One line before the fan-out, rather than an apology
after it.

**If you are blocked or the human declines, that is the end of it.** Do not re-invoke, do not
reach for the hand-run path through the process file, and do not trim the roster to fit a
budget — a report missing roles is indistinguishable from a clean one, which is the failure
this entire skill exists to prevent. Their options are to switch model or to set
`MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1`; both are theirs to pick, not yours.

**Be straight about whose bill it is.** No cost incurred running the murderboard is ever the
responsibility of its authors, and the gate is a safeguard, **not a spending cap** — never
imply it protects anyone from a bill.
<https://github.com/syncytium2/murderboard/blob/main/TERMS.md>

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
  `subagents`. Carry on.

  ⚠ **That does not mean the ROLE fan-out will be allowed.** The cost gate above is a
  `PreToolUse` hook on `Skill|Agent|Task` that reads the prompt, and it blocks a murderboard
  role spawn while letting an unrelated Agent call through. Verified against it: on a blocked
  model this probe returns **0** and a role spawn returns **2**. So a green probe answers *can
  I spawn a subagent*, never *can I spawn eleven of these* — the cost preflight is what answers
  the second, which is why it runs first and why skipping it is not a shortcut. If the fan-out
  is refused after a green probe, that is a **cost** refusal, not an availability one: stop and
  hand it back, do not record `single-pass (forced)` and carry on.
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

### 4a. Compile the specialists, probe the lookup, then spawn them BY NAME

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

Each role is spawned by its row's `agent-name` as the subagent type. **If the named agent does
not resolve**, fall back to spawning a generic subagent whose prompt is **the contents of that
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
else. **The one exception is roles 2 and 6 losing their sources:** that is not a mismatch to
record but a stop, and the lookup probe below is where it stops.

**Before the fan-out: probe the lookup.** Roles 2 and 6 are the only roles whose sources live
outside the repository, and a role that cannot reach them still returns a full report about
them (issue #74 in this repository's tracker; the process file's appendix tells it).

- **Skip it only when there is nothing to look up:** no references, no named attribution, and no
  outside method or tool. Record `Lookup: not needed` and go on to the fan-out. A probe that
  ran and failed cannot be followed by `not needed`.
- **Otherwise spawn role 2's `agent-name` once, by the path the roles will use** — by name, or
  the fallback above if the name does not resolve — so it holds what role 2 will hold. In a
  single-pass run, which has no role 2 to spawn, the main thread answers the probe itself.

Fill the prompt in fresh for each run. Pick one row of the table below at random, and make the
fake DOI from `10.1000/` plus twelve random hex characters (`openssl rand -hex 6`). Both are
there so that the answers cannot come from memory:

> Lookup probe, not a review. Use only a resolver, a registry, or a literature database —
> doi.org, Crossref, PubMed, or similar. A search-engine result does not count.
>
> 1. `<real DOI>` — reply `FOUND <title>` plus the PMID or HTTP status your route returned,
>    or `NOT FOUND`.
> 2. `<fake DOI>` — the same.
> 3. Fetch `https://api.crossref.org/works/<real DOI>` as a web page and quote the value of
>    `created.date-time`, or reply `CANNOT FETCH`.
>
> Then one line naming each route you used.

| real DOI | title | `created.date-time` |
|---|---|---|
| `10.1016/j.jnutbio.2017.08.013` | Protein malnutrition after weaning disrupts peripheral clock and daily insulin secretion in mice | `2017-09-04T03:45:43Z` |
| `10.1016/j.mimet.2018.03.010` | Real-time PCR-based method for rapid detection of Aspergillus niger and Aspergillus welwitschiae isolated from coffee | `2018-03-23T19:17:01Z` |
| `10.1155/2016/7920631` | Small Interfering RNA Targeted to ASPP2 Promotes Progression of Experimental Proliferative Vitreoretinopathy | `2016-06-09T22:05:54Z` |
| `10.1186/s12938-016-0298-3` | Pressure ulcer image segmentation technique through synthetic frequencies generation and contrast variation using toroidal geometry | `2017-01-13T09:21:33Z` |
| `10.1016/j.ultsonch.2011.12.010` | Characterisation and improvement of a reference cylindrical sonoreactor | `2011-12-21T13:14:18Z` |
| `10.4088/pcc.15l01844` | Resolution of Pathological Skin Picking With Fluvoxamine in a 74-Year-Old Dementia Patient | `2016-01-27T18:57:07Z` |

Every row was checked live on 2026-10-22: each DOI redirects at `doi.org`, is indexed in
PubMed, and is little-cited enough that its title is not common knowledge. `10.1000` is the DOI
Foundation's own prefix, and `doi.org` answers a suffix nobody registered with a 404.

**What each answer proves:**

| answer | proves | role it clears |
|---|---|---|
| real DOI `FOUND` with the table's title | the route resolves identifiers | 2 |
| fake DOI `NOT FOUND` | the route does not answer *something* to everything | 2 |
| the `created.date-time` matches the table | the role can read an arbitrary web page, not only a database | 6 |

A literature connector can pass the first two and not the third. That is enough for a
deliverable whose only outside sources are papers. It is not enough for one that rests on a
tool's or library's documentation, which role 6 has to read. Require the halves the deliverable
needs. Do not run the probe through `fetch_paper.py`: it fetches open-access papers rather than
resolving DOIs, and the fake DOI would land on the human's `_NEEDED.md` list.

- **Every half it needs comes back right** → record `Lookup: live — <route>` (step 7). Keep the
  probe's reply, verbatim: it goes into the role-report archive (step 4b) as
  `00-lookup-probe.md`, and the roster gate looks for it whenever a record says `live` and
  names its archive. Then fan out.
- **Anything else** → **STOP before spawning any reviewer.** This is not a `MISMATCH` to carry
  into the ledger. It is a stop. Tell the human which route was tried and what came back, then
  look for the knob:
  ```bash
  [ -n "${SUBAGENTS:-}" ] && bash "$SUBAGENTS" --lookup --explain ; echo "exit=$?"
  ```
  It reads the settings files for a rule that blocks a lookup: a `WebFetch` or `curl` deny, a
  `dontAsk` mode with nothing allowed, a sandbox that denies the resolver hosts. That is the
  shape behind #74, where the project's own settings denied `WebFetch`, `curl` and `wget`.
  **Its exit 0 is not an all-clear.** A launch flag, or a tool missing for some other reason,
  is in no file.

  The remedies are the human's: lift the rule for the review, run where the web is reachable,
  or grant roles 2 and 6 a literature connector (see *A connector reaches a role only through
  its grant* in `$PROCESS`). Then ask, and wait. **"Go ahead anyway" cannot buy a passing
  record**: the roster gate fails `Lookup: unavailable` however it is written.

The cost gate does not count the probe as a call-up, because it carries none of the fan-out's
vocabulary. That is harmless: it runs after the cost preflight, which has already stopped a
blocked model.

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

### 4b. Write each report to disk AS IT ARRIVES — not at the end

The moment a role returns, write its output verbatim to a file, before you read it and
before you synthesize anything:

```bash
REPORTS=docs/reviews/<artifact-stem>_<YYYY-MM-DD>-roles
mkdir -p "$REPORTS"
# one file per role, named after that role's agent file: 01-prove-it.md, 02-doi-or-die.md, …
```

Three reasons this is a step and not a nicety, in the order they bite:

1. **The window.** Between the first role returning and the run record being written sits the
   whole synthesis — the longest, most interruptible stretch of the run. Everything eleven
   roles said lives in the session for all of it. Sessions end, and the record you were about
   to write is the only thing anyone would have looked for.
2. **The record is a summary, and summaries drop things.** A finding you merged, softened, or
   judged out of scope is gone from the record by construction, and so is the evidence that a
   role reporting "nothing to check" checked anything. Later, nobody can tell which.
3. **Do not trust the harness's own per-agent output files.** Observed 2026-09: a run's agent
   outputs were each written to a file by the tooling, and **every one of those files was
   0 bytes**. The archive existed, nobody opened it, and it held nothing. `[ -s "$f" ]` before
   you rely on it.

**If a report cannot be preserved, say `reports: not preserved` in the record and mean it** —
do not reconstruct one from memory and file it as an archive. A paraphrase written after the
fact is a second summary, not evidence, and it is worse than an admitted gap because it cannot
be told apart from the real thing.

## 5. Synthesize and apply

Consolidate, dedupe, rank by severity, adjudicate each finding (fix / flag-inline `⚠` /
no-change), and **apply** the fixes. Rebuild the artifact if it is generated.

**First, read roles 2 and 6 for sources they could not reach.** A probe that passed says the
route worked once, before the fan-out. It does not say it kept working for every citation. If
either role reports sources left unchecked *because no route reached them*, rather than because
a paper is paywalled, stop here, as you would at a failed probe.

## 6. Blind verify pass — until it comes back empty

Re-check the **corrected, rebuilt** artifact per the process file's step 4: a fresh pass that
did not do the original review, a blind pass before any finding-list-driven pass, role 10
re-run in full against the NEW render, and iterate until a blind pass produces no new
findings. **Report the number of rounds.** Confirm the artifact's fingerprint changed from
step 3 — if it did not, the fixes are not in the file you are about to ship.

## 7. Emit the run record, then let it be checked

**Lead with the problem, not the ledger.** The record is a document deliverable like any
other: open with what was at stake and — where the subject is visual — a figure showing
it, then what was found, then what would validate it and how it generalizes. The header
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
- reports:   <artifact-stem>_<YYYY-MM-DD>-roles/ | not preserved   # from step 4b
- rounds:    <n> blind verify rounds to clean

Execution: subagents | single-pass (forced) | single-pass (chosen)   # from step 1a
Lookup: live | not needed            # step 4a: the probe passed, or there was nothing to look up
```

The token before the dash is parsed and must be exact; everything after it is yours and is
**never read**:

```markdown
Execution: subagents — one per role, all eleven spawned
Execution: single-pass (forced) — the Agent tool was unavailable; step 1a's probe failed
Execution: single-pass (chosen) — a one-line caption, not worth an eleven-agent fan-out
Lookup: live — curl to doi.org and Crossref; all three probe answers right
Lookup: live — PubMed connector granted to role 2; a deliverable citing papers only
Lookup: not needed — a caption that cites nothing and names no outside method
```

A third token, `unavailable`, always fails the gate. If you find yourself about to write it,
the run should have stopped at the lookup probe, and a finished record is not where that goes.

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
bash "$ROSTER" check --require-execution --require-reports --require-lookup "$REPORT" ; echo "roster=$?"
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

Write the token about the **eleven roles**, not about everything that happened — a triage pass
before the fan-out, or one role re-reading its own work, does not change the mode the team ran
in. A `subagents` token whose prose then describes an inline run is **reported, never
resolved**: the gate refuses it rather than picking, on the same grounds the grants gate
refuses a role that declares two verdicts.

**The token is not decoration, and it replaced two parsers that tried to do without it.** Both
inferred the verdict from the sentence and both got it wrong in the direction that costs most —
reading a degraded run as a full one. The second was defeated by a comma:
*"parallel subagents; role 4 could not reach the web"* and the same line with a comma
classified opposite ways. Distance cannot tell whether a failure attaches to the fan-out or to
one role, so the author says which and the gate stops guessing. A line with no token is refused
with the grammar printed — a failure that teaches rather than one that misclassifies.

⚠ **Which means the token has to be true, and nothing here can check that.** A `subagents`
token above prose describing a total fan-out failure records as a full run: the gate compares
the prose against *mode* words only, for the reason set out in the process file. This is the
same limit the grants gate states about itself. Write the token from what step 1a actually
returned, not from what the run was meant to be.
**It also reads the `reports:` line.** With `--require-reports` the run must name an archive
that resolves and holds a non-empty file for every role, or say `not preserved` and be refused
for it. A named archive that does not exist fails whether the flag is set or not — that is the
"cited but missing" shape, and it reads to anyone downstream as the complete run. **Do not make
it green by deleting the line**; write the reports, or declare the gap and tell the human.

**And it reads the `Lookup:` line.** Under `--require-lookup` a missing line fails. A `live`
line whose archive has no `00-lookup-probe.md` fails too, which is what makes "the probe ran"
something the gate can check rather than take on trust. It still cannot check that the probe's
answers were right. Write the token from what the probe returned.

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
not perform its check (for roles 2 and 6, step 4a's lookup probe covers that). It proves that
every role said what it held and that what it said matches the grant it was issued — not that
the tools were there. Containment and equipment are enforced where the agent is spawned.

## What to hand the human

The corrected deliverable, the path to the run record, **the path to the role-report
archive**, and a short plain summary: what was checked, what was found and fixed, how many
verify rounds, and every residual `⚠`. A deliverable with unresolved `⚠` flags is
**not "done."** If the reports were not preserved, say that out loud here too — it is the
one thing the record cannot make up for later.
