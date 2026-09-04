# The murderboard — critical review process for document deliverables (anti-slop)

A standing, project-neutral review process. Its purpose is to stop **slop** — unsourced
claims, wrong numbers, fabricated citations, internal contradictions, and overreach — from
reaching a document you asked for. It exists because slop ships when nobody adversarially
checks a draft against its real sources: a statistic that disagrees with the run it claims
to summarize, a reference list written from memory, a count that contradicts itself across
sections, an identifier copied wrong, a figure whose caption overclaims what the data show.

A newer, subtler class hides in **analysis code**: a plotted number can be exactly
consistent with its caption and still be wrong because the code that produced it misused a
library or re-derived a method the project already implements correctly. A figure is only
as sound as the code and method behind it; the review must reach that far. (Concrete
incidents that motivated each rule are collected in the appendix — they are examples, not
part of the neutral process.)

## When it triggers

Any time you request a **document deliverable**: an explainer, a methods section,
manuscript / abstract / cover-letter text, a figure **or its caption / labels**, a
report, or a human-facing handoff or slide. **Not** for: source code, quick
conversational answers, throwaway diagnostics, or internal scratch notes.

**When the deliverable rests on NEW analysis code** (a figure or number produced by a
script written for this task), the review extends to that code — not just the prose.
Agents 6–7 (RTFM, Reinventing the Wheel) below cover this.

### Run it before the artifact leaves your hands

The value of a finding and the cost of acting on one move in **opposite** directions, and they
cross at submission:

| The artifact is | A finding is | Declining to look is |
|---|---|---|
| a draft you still control | cheap, and fully actionable | pure loss — there is nothing yet to protect |
| submitted, under review | expensive, and only partly actionable | reasonable |
| published | maximally expensive, and unactionable | reasonable |

This is **guidance and cannot be a gate** — nothing can know an artifact's submission state, and
a rule that depends on being remembered is not a gate. It is written down anyway so that
declining a late run has a stated basis: the right-hand column is a cost, not a lapse. A reviewer
who skips a run on something already published is reading the table correctly, and one who skips
it on a draft is giving up the column where a finding is free.

A murderboard is a **pre-mortem**. The same eleven roles run after the fact produce an autopsy:
identical findings, no patient.

### When the artifact can no longer change — retrospective mode

The loop below assumes you can repair. *"The deliverable is not done until this pass is clean"*
is unsatisfiable for a paper already submitted or published, and so is *"a repaired deliverable
has not been reviewed — re-review it."* Point the process at one anyway — which people do, because
someone else's published paper is the safest thing to try this on — and it **truncates silently**:
roles 1–11 run, the ledger comes out complete and correct, rounds 2 and 3 never happen, and
nothing in the output says so. The role tally is not what was lost. The loop is, and nothing
counts loops.

So a run against an artifact that cannot change is a **different mode**, and says so:

- **Declare it.** The run record carries `Mode: retrospective` and states the stopping reason —
  *"round 1 of 3; repair and re-review unavailable, the artifact is published."* A report that
  does not distinguish itself from a complete run will be read as one.
- **Point it forward.** Ask *what would the next document's murderboard catch that this one's
  review did not*, rather than *what is wrong with this one*. Same roles, same findings; the
  output becomes a checklist for the next artifact instead of a list of regrets, which is the
  only form in which it is still actionable.
- **Triage findings by what it now costs to act.** On a submitted artifact some findings stay
  cheap — a citation that does not say what it is cited for, a typo, a mislabelled panel are all
  correctable at proof. Others are not: a statistical error, an overstated abstract.
  **This governs which findings you ACT ON, never which roles you RUN.** Every role still runs;
  see *The team is not optional*. A reviewer that skips the roles it expects to produce expensive
  findings has inverted this process into a machine for confirming what it hoped.

## The core principle

**Every sentence must be EITHER (a) verifiable against a real source — the data, the
code, a store, a prior result, or a checked citation — OR (b) explicitly flagged as
unverified/assumed (`⚠`).** No unsourced factual or quantitative claim ships unflagged.
No fabricated or approximate citation. No internal contradiction. No filler.

## The process

> **Call-up.** Where the consumer has installed the skill (`.claude/skills/murderboard/`, vendored
> from `skills/murderboard/SKILL.md` upstream), **invoke it — `/murderboard <artifact>` — rather than
> working from this file by hand.** The skill owns only the mechanics that must not depend on being
> remembered: the freshness gate fires at the moment of review instead of at session start, the
> roster is *derived* from this file instead of recalled, the artifact is resolved to the built file
> rather than its generator, and the run leaves a record that can be checked. This file remains the
> authority on *what* each role does — the skill loads it and follows it. Reading this file directly
> still works and is the fallback for a consumer without the skill installed; it is simply the mode
> in which each of those four steps can be silently skipped.

0. **Preflight — confirm the process itself is current.** This file is usually **vendored** into a
   consumer repo, where it drifts behind its canonical source. Before running, verify THIS copy is up
   to date with upstream — compare its vendored stamp/commit against the canonical repo's HEAD (search
   the known repo locations if the source isn't obvious) and **re-vendor first if it is behind.** A
   review run against a stale process is itself a slop defect: it silently omits rules the process has
   already learned. (This step exists because a consumer shipped a slide-overlap defect using a
   vendored copy that predated the slide-overlap rule.)
   - **Do not do this by hand — run `murderboard_freshness.sh`.** It compares the vendored stamp
     against upstream HEAD and exits **0 current · 1 STALE · 2 could-not-determine** (never a false
     "current"). It is silent when current, so it can run unattended. **Wire it into your
     session-start hook** with `--hook`, which serves a cached answer and refreshes detached, so it
     never blocks startup on the network:
     ```
     bash tools/murderboard_freshness.sh --hook      # session-start: silent unless stale
     bash tools/murderboard_freshness.sh --verbose   # on demand: always prints the verdict
     bash tools/murderboard_freshness.sh --selftest  # prove every branch can still fire
     ```
     This step was prose for its whole life and got skipped exactly when it mattered. A rule that
     depends on being remembered is not a gate. The reason it now fires by itself: the consumer it
     was written for went 10 commits and 11 days stale while ~17 of its worktrees branched from the
     stale copy, and nothing said a word.
1. **Draft** the document.
2. **Review** — run the review team (below). **Every role runs on every deliverable; what
   scales to stakes is how you run them, never which ones you run.**
   - Substantial doc (methods, manuscript, explainer, deck, multi-paragraph report) → **spawn
     the roles as parallel subagents**, one per role, via the Agent tool.
   - Small doc (a caption, a one-liner, a short list) → a **single-pass self-review that still
     walks every role's checklist in turn**, and still produces agent 10's table. Do not burn a
     ten-agent fan-out on one sentence — but do not silently drop a role either: a dropped role
     and a clean role are indistinguishable in the report.
   - **Scale by size, EXCEPT for attribution: any deliverable that attributes a method, or claims
     something is novel, unattributed, or "ours", runs role 2 as a SEPARATE agent — whatever its
     length.** The defect role 2 is catching there is *a search that stopped too early*, and a
     single-pass self-review inherits the drafter's search history, so it stops in the same place
     for the same reason. Blindness is the mechanism; one pass cannot supply it. This is the only
     role the size rule may not collapse.
   - **Confirm the fan-out is available BEFORE you use size to decide — probe, do not infer.**
     Spawn one throwaway subagent and require an answer back. Where the Agent tool is missing,
     denied, or forbidden, this choice is not yours to make and the run lands in the second
     bullet by constraint; done silently, that is indistinguishable from having judged its way
     there. **The record then says `Execution: single-pass (subagents unavailable)`** — see
     *Output contract*. Two consequences follow immediately: the attribution exception above
     cannot be satisfied at all, so a deliverable making an attribution claim does not proceed;
     and the block will recur on every run in that environment until somebody changes it, which
     is why it is worth surfacing before a review rather than after.
   A role with genuinely nothing to check returns **"no findings, and here is what I checked."**
   See **"The team is not optional"** below.
3. **Synthesize** (main thread) — consolidate findings, dedupe, rank by severity,
   adjudicate each (fix / flag-inline / no-change), and **apply** the fixes.
4. **Verify the fixes (a fresh follow-up pass).** After applying, re-check the **corrected** artifact —
   ideally with a subagent that did NOT do the original review — against the finding list: (a) every
   finding is **actually resolved in the deliverable**, not merely claimed; (b) nothing was silently
   dropped or quietly downgraded; (c) **no NEW defect was introduced by the edits** — re-run the
   craft/overlap pass on the corrected RENDER, because a fix that lengthens text or moves a shape is a
   classic regression. The deliverable is **not done** until this pass is clean. (This step exists
   because a fix that lengthened captions pushed them onto the figure, and nothing re-checked the
   applied edit.)
   - **A fix may not degrade what it was not aimed at — re-review the SLIDE, not the finding.** Every
     fix is a new draft of the thing it touched, so re-run that slide's **full** craft row, not only
     the cell that failed. The named sub-checks, in the order they bite:
     **(a) Legibility.** If the fix deleted, moved, shrank, or recolored a title, legend, key, or
     label — is the thing it identified **still identifiable**? Removing a colliding label resolves
     the collision by destroying the identification.
     **(b) Relocated, not vanished.** Every element the fix removed must land somewhere **named**:
     the notes pane, an appendix slide, an adjacent legend. "Deleted to resolve the overlap" is a
     finding, not a fix.
     **(c) Prominence.** An element demoted to gray, small, or bottom-of-page must still be findable
     **by the reader who needs it, at the moment they need it**. Presence is not availability.
     **(d) Geometry.** The classic reflow regression — a fix that lengthens text or moves a shape
     pushes something else out of its box or off the page.
     **(e) Scope.** A fix made inside a shared helper changes every artifact that calls it; re-check
     the other consumers, not just the one that prompted it.
     (This exists because a figure-title collision was fixed by deleting the title and moving its
     color key into gray footer text. The overlap re-check passed — it was the only thing re-run —
     and the deliverable shipped with an unreadable legend that the fix itself created.)
   - **A generated deliverable is the BUILT FILE, not its generator.** When a script produces the
     document (a slide-deck builder, a LaTeX/Quarto/Typst source, a plotting script), editing the
     source does **not** resolve a finding — **rebuild, then run this pass on the rebuilt file.**
     There are two artifacts and only one of them ships; the one you verified must be the one you
     hand over. Before delivering, confirm the built file is **newer than the last fix and newer
     than every input it embeds** (figures, tables, data files) — if it is older, it predates a
     correction and must be rebuilt. **The last action before delivery is the build, not the fix.**
     (This step exists because a deck's figure-overlap fix was written into its builder and never
     run: the corrected source was clean while the shipped `.pptx`, one build behind, still ran
     every caption through its figure.)
   - **A repaired deliverable has not been reviewed. Re-review it — BLIND FIRST, then follow up.**
     Every fix is a new edit with no review behind it, and layout fixes in particular are *moves*:
     the defect leaves one place and lands in another. Measured incidents from one run — a figure
     resized to stop it overlapping text landed on a different text block; a list re-flowed to fix
     an overflow pushed its last line onto the source footer. **Two passes, in this order, and the
     order is the point.**
     - **PASS 1 — BLIND.** Re-run the roles against the repaired artifact **with no knowledge of the
       previous findings, the fixes, or which parts were touched.** Give the reviewer the artifact
       and its sources, nothing else. A reviewer told "we fixed the overlap on slide 12" looks at
       slide 12, confirms it, and stops — the fix is *verified* and everything the fix broke
       elsewhere is invisible. Blindness is what keeps the second look a look, rather than a
       signature. Its findings are recorded as first-class findings, indistinguishable in the
       report from round-one findings.
     - **PASS 2 — FOLLOW-UP, driven by the initial findings.** Only now, with the blind pass banked,
       walk the original finding list and rule on each one: **fixed · not fixed · moved** (the
       defect now exists somewhere else) · **superseded** (the surrounding content changed so the
       finding no longer applies). "Moved" is the verdict this pass exists to produce, and a
       reviewer holding the original list is the one placed to spot it — which is exactly why it
       must come *after* the blind pass, not instead of it.
     - A finding may only be closed by the pass that can see it: a *blind* pass cannot close a
       finding it was never shown, and a *follow-up* pass cannot open the ground it was never asked
       to walk.
     - Role **10 re-runs in full in the blind pass**, always — it is the cheapest role, and every
       repair to a rendering deliverable changes the file it inspects. Its table must name the NEW
       render.
     - **Stop on SEVERITY, not on silence, and cap the rounds.** Stop when a blind round produces
       **no blocking and no major** findings, **or after 3 blind rounds**, whichever comes first.
       Minors surviving the final round are **recorded as residual `⚠`, not fixed** — fixing them
       starts a round you have already decided not to run.
     - **"Iterate until a blind pass produces no new findings" was the rule here until 2026-08-18,
       and it does not terminate.** This process states two things that together make it
       unbounded: *"a repaired deliverable has not been reviewed"*, and every fix is new text. So
       each round manufactures the surface the next round reviews, and on a complex artifact the
       generation rate can exceed the retirement rate indefinitely. A reviewer told to find
       problems in unreviewed text will find some; that is the role working, not the artifact
       failing. Measured on the run that produced this rule — a cross-project reply resting on new
       code and a generated data folder — findings ran ~60 / 10 / 20 / 15 across four rounds while
       blocking findings ran 6 / 0 / 3 / 0. It was stopped by a human at round 3, still producing.
     - **Report findings by severity per round, as a table.** That table is the convergence
       evidence and it replaces the bare round count: a run whose blocking findings go 6 → 0 → 3 → 0
       has converged in the way that matters even if minors keep arriving. State the stopping
       reason explicitly — *severity floor reached* or *round cap reached* — and never present a
       capped run as a clean one.
     - **If severity is NOT falling across rounds, stop and escalate to the human.** A flat or
       rising blocking count after two rounds does not mean review harder; it means the artifact
       has a structural problem that patching will not retire, and continuing to patch converts a
       fixable draft into a long tail of edits nobody has reviewed together.
5. **Deliver** — the corrected document **plus a short review report**: which dimensions
   were checked, the **per-round findings-by-severity table** and the stopping reason (severity
   floor, or round cap), the verify-pass result, and any residual `⚠` flags the human must resolve
   before release. **A run stopped at the cap is delivered as unconverged**, with the open items
   named — a capped run and a clean run must not read alike. For a generated deliverable, state that the shipped file
   was **rebuilt after the last fix** and verified in that state. A document with unresolved `⚠`
   flags is **not "done."**

### The run record is a deliverable, and this process applies to it

The record this process produces is a document, and it is the one document nobody
reviews. Its prescribed shape — header, role ledger, finding list — is ordered by
**process** rather than by **argument**: it can prove every role ran and cannot tell a
reader what was found out. Roles 9 and 11 would catch that in any other document and are
never pointed at this one.

So the record **opens with the problem**, shown as a figure wherever the subject is
visual, then places the work — where it fits and why it was worth doing — then states
what would validate it and how it generalises beyond the project that produced it. The
ledger and the finding list move to an appendix, where a reader who wants to audit
coverage can still find every role.

This is not a style preference. A record organised by process is read once by its author
and never again, so the findings it contains stop being available to the next person —
which is the same failure the murderboard exists to prevent, one level up.

### What a clean run does NOT warrant — state it in the record

**A clean run is evidence the roles ran. It is not evidence the artifact is correct.** Say so, in
the delivered summary, in these terms or equivalent:

> This review found and fixed N defects. It is not a correctness proof. The convergence table
> measures how quickly reviewers stopped finding things, not whether anything remains.

The report must not be presentable as a warrant, because that is exactly how it will be used —
the run record is the most quotable thing the process emits, and "11/11 roles, severity floor
reached" reads to any human as a clean bill of health.

This is the **"can the alarm ring?"** rule turned on this process a second time. The role ledger
fixed *"7 of 11" and "11 of 11" look alike*. It did not fix the next one up: **"11 of 11 and
clean" and "11 of 11 and correct" look alike**, and the second is what a reader takes away. A
convergence table cannot distinguish a document with nothing left to find from one whose
reviewers were all looking in the same wrong place.

## The review team

Spawn these as parallel subagents, each given the draft **and** pointers to the real
sources (the data paths, the code, the companion docs, the handoffs).

**Each role returns a structured finding list**, one row per finding: *location · issue · severity ·
suggested fix · could-I-verify-it-against-a-source (yes/no)*.

Those are two paragraphs on purpose. The first is addressed to **whoever spawns the team**, the
second to **each reviewer**, and `murderboard_agents.py` compiles only the second into the agent
files — a single paragraph mixing the two would hand every reviewer an instruction to spawn the
team it is already a member of.

**Roles are split by what it COSTS to satisfy them, not by which reader they serve.** A judgment
call ("would a cold reader follow this?") can be satisfied by thinking about it; a mechanical check
("is this axis labeled?") can only be satisfied by opening the rendered file. Bundle the two into
one reviewer and its prose answer covers for the file it never opened — so every mechanical check
lives in agent **10**, whose output is a table, and every judgment call lives with the role whose
mode of thought it matches. When a rule could sit in two places, **file it once** and note the
boundary.

A second axis matters as much: **the unit of analysis.** Most roles read one slide/panel at a time,
and a defect whose unit is the WHOLE SEQUENCE (argument order) or the WHOLE PAGE (how much canvas
the figure was given) is invisible to all of them — each slide passes on its own. Give any such
defect a role whose unit matches it (11, 9), or it will be found by the reader instead.

1. **Claim & data verifier — "Prove It."** Extract **every** factual and quantitative claim — numbers,
   statistics, sample / record IDs, parameter values, and "X does Y" statements — and
   verify each against the actual data, code, store, or prior result. Flag any claim not
   verifiable from a real source, **especially numbers and attributions**.
   - **Return a claim ledger, not an impression.** One row per quantity: *quoted value · cited
     source · recomputed value · match / mismatch / unverifiable*. **Recompute — do not eyeball.**
     A number that "looks about right" against a file has not been checked.
   - **A cited source must actually CONTAIN the quantity.** Check the source holds the field being
     quoted before comparing values — a footer can point at a real file that has no such column,
     and a reviewer reading only the prose will accept the citation as provenance.
   - **Self-describing names and labels are claims too.** "X-free", "matched", "controlled",
     "independent" assert something checkable — verify each against what the code actually did.
   - **Count the MISSING, not just the present — and compare against an older artifact.** A
     table, figure or export can be complete in shape and empty in meaning: right columns,
     right row count, plausible numbers, and a category column that is silently blank. Check
     the count of empty / `NA` / `<missing>` values in every labeled column, and check that
     the label vocabulary matches its source of truth (the workbook, the dictionary, the
     other stack). *Incident:* a treatment dictionary ported between two stacks was missing
     two rules the source had; **67% of rows in a published export carried no treatment
     label** and the downstream stack dropped them as NA. Every summary statistic still
     computed. It was caught only because an OLDER export of the same data disagreed — so
     when a deliverable is a REGENERATION, diff it against what it replaces and account for
     every difference, including a changed row count.
   - **The sources a deliverable did NOT consult are part of the check.** Verifying every
     claim against the sources a document *names* still passes a document that never opened
     the one it should have. Most projects keep a **record of experimental design and unit
     membership** separately from the measurements: which condition, group, or subject each
     unit belongs to, which units share a subject, and which units have been withdrawn.
     Locate that record before reviewing, then check the deliverable against it — were
     withdrawn units included, does the unit count reconcile, and are units sharing a subject
     counted as independent? If the project appears to have **no** such record, report that
     as a finding: *"there is no source of record for group membership"* is a serious claim
     about a project, not a default. (Incident: a corpus result was reviewed by eleven roles
     and shipped including a recording its own lab had marked excluded, in a column no role
     knew existed. The same review reported a pooled across-group number as unavoidable
     while the grouping sat in a column of the file the analysis had already loaded.)
   - **A retracted claim stays retracted.** When a source document carries a correction, read the
     **retraction together with the original** — a draft written from the original brief silently
     re-inherits the claim the project already measured and withdrew. And **verify the REPLACEMENT
     as hard as the claim it replaces**: a correction is a new claim, and the first fix is often a
     different unsound mechanism that the same figure's own numbers refute.
2. **Citation & reference validator — "DOI or Die."** For every reference or named attribution, confirm
   the work **exists**, **says what is quoted**, and **is the origin** — traced back until the
   citations stop, and forward to what the same authors did next (web search / DOI where needed).
   Existence and correct attribution are half the check.
   **Zero tolerance** for fabricated or guessed bibliographic metadata. Flag any
   "representative / placeholder / finalize-later" reference as not-yet-verified. When you
   need the paper itself, follow the **lit-cache protocol** below — check the library
   first, fetch the OA copy, flag what you can't get. Do **not** verify a claim against a
   paper you only half-remember: get the text or flag the paper.
   - **How to establish the origin.** Open the cited work's own references for the claim and follow
     them backwards until they stop. **Report where you stopped and why** — "the root is paywalled,
     verified to one step short" is a finding; silence is not. Prefer the root and cite later work
     as the modern restatement. Verifying everything *present* while never asking what is *absent*
     is how a reference list can be entirely correct and still credit the wrong paper.
     - **A shared author is not a shared laboratory.** "Which lab" is the **last author plus the
       affiliation**, not name overlap — a first author is often a trainee in someone else's
       group, and the same person appearing on both papers is exactly what a method being
       *carried* from one lab to another looks like. Look the affiliation up; do not infer it.
       Crediting the wrong laboratory is a research-integrity problem, not a citation-style
       nitpick, and it survives every check that only asks whether the reference resolves.
   - **Name the literatures you searched.** A construction general enough to have been invented in
     another field will not be cleared by searching one. When a deliverable claims something is
     novel, unattributed, or "ours", the reportable finding is never "looks fine" — it is
     *"searched X and Y; did not search Z"*. **An unsearched field is a residual `⚠`, not an
     absence of prior art.**
   - **Trace FORWARD as well as backward — the origin is not the only place the answer hides.**
     Following citations back finds where a method came from. It does not find where its authors
     took it *next*, and when a deliverable wraps someone's tool or measure, that is usually where
     the closest prior art for the **wrapping** lives. So for any third-party tool, measure or
     library the deliverable builds on, **the authors' own later applied papers are a required
     search target, not an optional field** — read the tool's publication page, not only the paper
     it was introduced in. A citation set can be complete back to 1968 and still miss the paper
     the same author published last year doing exactly what the deliverable claims as its own.
   - **Ask what the humans hold. Correspondence is a source.** Before reporting that a claim is
     unattributed, or that prior art could not be found, ask the people involved whether anyone
     **has already asked someone** — an email to a tool's author, a reviewer exchange, a
     conference conversation, an enquiry that was answered months ago and never written down.
     That evidence is real, it is frequently decisive, and it is invisible to every literature
     search that will ever be run. It is also the **cheapest check in this document**: one
     question, no database, no paywall. **"Nobody was asked" is a residual `⚠`**, recorded exactly
     like an unsearched field. Where correspondence exists, quote it and date it — a personal
     communication is citable, and an undated one is not checkable.
3. **Consistency auditor — "Cross-Examiner."** Cross-check **within** the document and **against companion
   docs**: counts, totals, terminology, cross-references, and figure↔text agreement. Flag
   every contradiction. **Watch for one population counted on different bases** (per-detector flags vs
   a deduped roster; observations vs unique units; active-subset vs all): pin ONE canonical counting
   basis and reconcile every figure/number to it, or the same "N" silently changes between slides.
   - **Any count named in prose must be visible in the figure.** Text says "two" → the figure shows
     two. Text says "n = 2 vs 2" → the figure's axis does not still say 3 vs 2.
   - **Consistent category order across figures.** When more than one figure/panel shares a
     categorical grouping (experimental groups, conditions, timepoints), every one lists the
     categories in the **same order** — the project's canonical order (check the glossary). Two
     figures that disagree on category order are a defect: the reader cannot line them up.
   - **Terminology / reserved words.** Check every term against the project glossary; a reserved
     word may not be reused for a different concept; any new term is added to the glossary **in
     the same change**.
4. **Adversarial reviewer — "Reviewer 2."** Read as a **hostile peer reviewer**. Attack every claim:
   overreach, unsupported leaps, conclusions the evidence does not support, missing
   caveats, and vague hand-waving. Demand the caveat wherever one is due. Also attack for
   **rigor**, not just craft — a labeled-and-consistent figure can still be soft:
   - **Undefined quantities.** Is every plotted/quoted quantity *defined*? (E.g. "how is
     'mean rate' defined?" — count ÷ window duration, say it.)
   - **Unjustified constants.** Every magic number (a bin width, a cutoff, a time
     constant, a threshold) must be **defined AND justified** on-figure/in-text. An
     unexplained constant is a defect. (Boundary with RTFM: Reviewer 2 asks whether the
     *reader* is told why; RTFM asks whether it's the *right* value for the method — same
     number, two lenses. File it once.)
   - **Fragile statistics.** A claim resting on a single **max / extreme** is suspect —
     "we saw it happen once; how often?" Demand the **frequency / distribution**, not the
     bare maximum; a one-off must be visible as a one-off.
   - **Significance in titles.** A panel title/caption should state **why the result
     matters** (its inferential purpose), not merely name the quantity plotted.
   - **Enrichment must be a rate, not a raw count.** "More X in group G" / "G-enriched" claims must be
     shown as a **rate normalized to G's denominator**, never a raw count — a big count in the largest
     group is not enrichment. Demand the denominator and the per-group rate.
   - **"Independent methods agree" — is it really independence?** When two methods are said to
     corroborate, check they do not **share upstream data or derivation** (correlated errors make
     agreement partly guaranteed). Validating one method on cases **selected by the other** is
     circular — call it a consistency check, not independent validation.
   - **A group difference asserted is a group difference tested.** "Opposite profiles", "highest in
     G", "structured" imply a comparison — demand the actual test (effect size / CI / model), or the
     claim is softened to "described, not tested".
   - **Show the evidence the claim rests on, not only examples.** A validation / methods claim that
     says "tested on synthetic signals / ground truth" must **show that ground-truth set** — the
     actual synthetic cases with their known answers vs the tool's call — not merely a couple of
     hand-picked near-threshold examples. Examples-of-the-margin belong on their own slide; they are
     not the ground-truth test.
   - **Break a result down by the experimental design variables.** A result pooled across the
     factors the study manipulates (group, condition, timepoint, region) **hides the structure** and
     invites "…in which condition?". Demand the breakdown (e.g. one panel per condition, bars by
     group) — a single pooled headline number is a defect for a results claim.
   - **"The breakdown is unavailable" is a claim, and it is checked like any other.** When a
     deliverable pools across a design factor and explains that the factor is not available in
     the data, do not accept it and file a caveat — that is how a pooled result ships with a
     flag nobody can act on. Establish whether a source of record exists *before* the caveat
     is written. Unverified unavailability is the most comfortable finding in a review and the
     least often true. (Boundary with Prove It: that role locates the record and reconciles
     against it; this one refuses to let its absence be assumed.)
   - **A check that cannot fail is not a check — and the danger is that it PASSES.** Distinct
     from the alarm-ring rule below, which is about a null *result*: this is about a
     *verification step* the deliverable performed. When a document says a quantity was
     validated against a reference, establish that the reference is independent of the thing
     being validated. A check comparing a value against the same value obtained by a second
     route reports agreement forever and cannot detect the error it was written to catch.
     (Incident: an analysis verified its time windows against a lab workbook and reported
     agreement on every recording. Both sides were the raw recording period; the defect was
     that the analysis should have used a *different* column — the producer's analysis window
     — and the check had no visibility of it at all.)
   - **A PASSING check can be asserting the defect. When a defect is found, read the tests that
     did not fail.** The two rules above are about a check with no power; this is about a check
     with full power, aimed at the wrong outcome. A test written beside a bug encodes the bug as
     the specification, goes green, and then *defends* it: the next person to fix the behaviour
     sees a red suite and reads it as their own mistake. So for any defect, ask which assertion
     should have caught it and did not — and if an assertion covered that exact behaviour and
     passed, **the fix must flip it, not add a sibling beside it.** A repair that leaves the old
     assertion standing has written the defect down twice. State in the record which assertions
     flipped; that count is evidence about how the defect survived, and it is the one number a
     reader cannot reconstruct afterwards. (Incident: a compiler that wrote into a *shared*
     directory deleted every file it had not itself produced. Two selftest assertions — "an
     orphaned agent file FAILS check" and "write removes the orphan" — had been green since the
     tool was written, and both were describing a consumer's own subagent on its way to being
     unlinked. The suite was not silent about the behaviour; it was vouching for it.)
   - **"Can the alarm ring?" — a null result needs a test with the power to fail.** The most
     dangerous sentence in an analysis deliverable is *"we checked for X and it did not happen"*: it
     reads as evidence while resting on nothing if the check could never have registered X. For
     every such claim ask the operational question — **construct the failure the claim denies, walk
     that one concrete instance through the exact metric as computed, and say whether the number
     moves.** If you cannot name an instance that would move it, the test has **no power**, and the
     result is not absence of harm — it is silence. Demand the claim be restated as *"not detectable
     by this test"*, and demand the test that WOULD have power. Four cheap diagnostics find most
     cases:
     - **Ceiling / saturation.** A metric already at its bound before the manipulation (100% recall,
       zero errors) has spent its dynamic range and cannot register a loss.
     - **Many-to-one scoring.** When the metric matches MANY candidates onto FEW references, losing
       one true candidate is absorbed by a sibling and never scored. Ask the matching cardinality,
       then ask what the number does when exactly one correct item is deleted.
     - **The harm lives in the other set.** A metric defined over set A cannot adjudicate a claim
       about set B — recall scores coverage of the reference set, so it is mute about damage to
       items never in it. Name the set the harm lives in; check the metric is scored over that set.
     - **Aggregate rate vs per-item harm.** A claimed per-item harm needs a **paired per-item check**
       ("did THIS item survive?"), never an aggregate rate that averages it away.

     **When the draft itself explains why the number did not move, that is the confession, not the
     defense** — escalate it to blocking. (Incident: a deck proposed discarding footprint "islands"
     and cleared the risk with "recall unchanged". Recall was already 100% on 2 of 3 slices, and was
     scored by matching 175 tool footprints against 27 human ROIs — so a real cell knocked off its
     ROI is silently covered by a neighboring footprint and the number cannot move. The slide's own
     caption said "another covers it". Boundary with RTFM: RTFM asks whether the metric was
     **computed correctly**; this asks whether a correctly computed metric could ever have
     **answered the question** — same number, two lenses, file it once. Boundary with Prove It:
     Prove It verifies the number is real; this asks whether a real number is responsive.)
   - **Read the picture, not the caption.** Open the rendered figure and ask what the IMAGE says
     about the claim above it: does it support it, undermine it, or show structure the text never
     mentions? A figure can refute the slide it illustrates, and that refutation is invisible to a
     reviewer who read the caption, the source table, and the code. (Incident: the panels
     illustrating "fragmented footprints" showed the discarded islands sitting on what look like
     **adjacent cells**, each with its own bright core — i.e. the deck's central proposal may have
     been deleting real cells. Every role had read *about* the figure; the PI looked at it.)
5. **Line editor — "Kill Your Darlings."** Clarity and precision: undefined jargon, ambiguous sentences,
   redundancy, grammar, logical flow. Every sentence must earn its place and assert
   exactly one true thing.
   - **The house voice.** Short sentences, concrete nouns, active verbs. Cut every word that does
     not change the meaning. Prefer the specific example to the general claim. Name what the
     document does not know instead of hedging around it. No throat-clearing, no preview of what
     a section is about to say, no closing paragraph that recaps. Dry humour is fine where it is
     also true; cut it where it is decoration.
   - **Count first, then judge — and run the tool, do not describe it.** Role 5 owns both a
     judgement (is this block longer than its point?) and a search (does this word appear?). The
     architecture note above says what happens when one role holds both: *the prose answer covers
     for the file nobody opened.* So the search is a script and its **output is pasted, not
     summarised** — `murderboard_prose.sh <artifact>`, one row per hit and one row per block:
     **line · construction · kind**, then **block · words · sentences**. **"Not run" is a failure,
     not a clean result.** The tool cannot judge and does not try: it reports that a block is 220
     words, never that the block is too long. The columns it cannot fill — *which sentence is the
     payload, where it sits, what the other words buy* — are this role's, and a table returned
     without them is a tool receipt, not a review.
   - **The banned constructions — check these first, mechanically.** They are forms, not topics,
     so they are searchable and either present or absent: *not just X, but Y* · *it's not about A,
     it's about B* · *it's worth noting* · **delve, leverage, robust, seamless, crucial,
     landscape, tapestry** · a three-item list built for rhythm rather than because there are
     three things · an em-dash pivot into an uplifting close · an opener of the form *"In today's
     ___"*. Report each hit with its location. A hit is a defect unless the author states why it
     stays. **This list is a house convention, not a finding about English** — a consuming
     project should edit it, and a role that cites it must say which list it ran.
   - **The passage test — what does this block assert that its last sentence does not?** A block
     can be true, correctly placed, and clean line by line, and still spend four hundred words
     arriving at one. **Every other role passes it**: role 4 finds the claim supported, role 11
     finds the section in its right position, role 8 finds a stranger able to follow it, role 9
     wants a picture rather than a cut. Nobody is left holding the question *did this need to be
     this long* — which is why it reaches a reader as the first thing they say about the draft.
     So, per block: write the one sentence it exists to deliver, then name what the remaining
     words buy — evidence a sceptic would actually demand, or the author's satisfaction at having
     been thorough. Cut the second kind. **The payload is usually at the end**, because the block
     was written in the order it was thought; promoting it is the fix more often than trimming is.
     (Boundary with Start With the Problem: role 11 owns the order of the sections and may not
     reach inside one; this owns the paragraph — a block in exactly the right place, three times
     longer than its point.)
   - **Why this role gets a list where the others get judgement.** An instruction to write with
     more wit, or in the voice of some admired author, cannot fail: nothing in the draft can
     contradict it, so it yields a different voice on every run and no reviewer can dispute the
     result. Worse, a long stack of such instructions averages out — the traits blend instead of
     stacking, and the output lands on the same neutral register the instruction was meant to
     escape. A named construction is either in the text or it is not. Prefer the check that can
     fail; this is *"Can the alarm ring?"* (role 4) applied to prose.
6. **Methods / domain expert — "RTFM."** *Spawn whenever the deliverable rests on a specific
   method, tool, or library* (a statistical model, a signal-processing routine, an
   inference algorithm, a numerical library). **Before** reviewing, ground in the actual
   method — the source paper(s) and the tool/API documentation the analysis depends on
   (read them; don't reason from memory — get the source papers via the **lit-cache
   protocol** below: `--have` first, fetch the OA copy, `--need` what you can't reach).
   Then check that the analysis **obeys the method's invariants and uses the tool
   correctly**: input conventions (shape, orientation, units), the baseline/normalization
   a routine assumes, what each parameter actually controls, and known traps (e.g. a
   correction applied twice, a filter run along the wrong axis). This is the reviewer that
   catches a misused library call — the kind of error invisible to someone reading only
   the prose. **Also: a validation/benchmark must exercise the SHIPPED parameters.** A test run at
   looser or specially-tuned settings validates a *different* tool than the one that produced the
   results; re-run at the production settings and report the true score. And confirm a reported
   metric counts what the prose says it counts (e.g. "9/10 real bursts flagged" vs "9/10 mixed cases
   classified" are different claims).
7. **Reuse auditor — "Reinventing the Wheel."** When the analysis code **re-implements something the project already
   does in tested production code**, flag it and check two things: (a) should the new code
   just **call the existing code** instead of duplicating it? and (b) where it does
   re-implement, does it **match the reference exactly** — same parameters, orientation,
   unit conversions, and guard clauses? Point to the canonical implementation by path/line.
   The project's own working code is the reference; the default is to reuse it, not
   re-derive it.

8. **Naive-reader accessibility — "You Lost Me."** *Spawn for any deliverable meant to be understood by a
   reader NOT already steeped in the work — an explainer, a slide deck, a figure a colleague
   must read cold.* Read each slide/panel with ZERO prior context and flag every place such a
   reader is lost. It exists because a deliverable can be every-number-correct, honest, and
   craft-clean and still be **unreadable to the audience it is for** — a gap the rest of the
   team does not cover. This role holds only the checks that require **reading as a stranger**;
   its mechanical figure rules moved to agent 10, its cross-figure rules to agent 3, and its
   evidence-adequacy rules to agent 4. Checklist:
   - **Output contract: a per-slide verdict, not a deck-wide list of terms.** One row per
     slide/panel: *terms and identifiers first used here · which are defined on the slide · can a
     cold reader follow it (yes / no / blocking)*. A pooled list of undefined terms lets the worst
     slide hide inside the average — the finding is technically present, nobody can act on it, and
     it dies in synthesis. Any slide introducing **three or more** undefined terms is a **blocking
     row, named by slide number**, not a line in a list. (Incident: a reviewer correctly listed six
     undefined terms scattered across a deck and the fix never happened; the PI's first note was
     "slide 2 has a bunch of undefined terms" — the same defect, but *located*, and therefore
     fixable.)
   - **Self-contained.** Each slide/panel stands alone; **define every named method, term, and
     relative word the first time it appears there** — a relative word must name its referent
     ("secondary *to what*", "soft *relative to what*"). Define every non-obvious **unit** on the
     slide it first appears. Keep **internal code identifiers** (variable, function, field, and
     parameter names) OUT of audience-facing text — use the plain-language concept.
   - **Illustrate, don't name-drop.** Any non-trivial mechanism (a transform, a shuffle, a null
     model) is introduced **graphically**; reuse an existing illustration if the project has one.
   - **Label each panel by what it demonstrates.** Beyond the letter (agent 10 checks the letter is
     there), a validation / example-grid panel must name **the archetype or category it shows**
     ("sustained", "non-oscillator control", "rejected: noise") so the reader knows why it is there
     without hunting in the body text.
   - **Name the chart type the image RESEMBLES before reading its axis labels.** Every
     field has a few dominant visual idioms — a raster, a heatmap, a spectrogram, a
     Manhattan plot, a volcano plot, a phylogeny, a piano roll — and each carries fixed
     axis conventions its readers apply automatically. A plot that borrows an idiom's
     visual grammar while assigning **different meaning to its axes** is a false friend:
     it is misread by exactly the expert audience it was drawn for, and the more fluent
     the reader, the more confidently they misread it. Labels do not save it, because the
     idiom is recognised before a label is read.
     Ask three questions, in this order, with the render open and the caption covered:
     *what does this resemble · in that idiom what do the axes mean · do they mean the
     same thing here?* If the answer to the third is no, the finding is **not** "clarify
     the label". Redraw it so it cannot be confused — gridded tiles rather than scattered
     marks, explicit cell borders, a different mark shape, transposed axes — or show the
     familiar chart beside it so the reader can see the correspondence instead of
     assuming it.
     **This defect is invisible to everyone who already knows what the figure is**, which
     is every reviewer by the time they have read the caption and the generator. It is
     the one figure check that must be made from ignorance, and it is why this role holds
     it. (Boundary with Ship It: that role asks whether the panel is present, labeled and
     legible — a false friend passes every one of those rows. Boundary with the
     phantom-structure rule below: that one is about spurious structure *inside* a
     correctly-read chart; this one is about the chart being read as the wrong kind of
     chart entirely.)
     *Incident:* a report on which cells participate in which events drew its membership
     matrix as square marks scattered on continuous axes — horizontal axis a cell,
     vertical axis an event ordinal. That is the visual grammar of a spike raster, where
     the horizontal axis is **time** and each row is a **cell**. Eleven roles reviewed the
     figure, wrote per-panel "what a cold reader sees" sentences, and passed it. The PI's
     first reaction: *"the first figure is very confusing. showing something that looks
     like a raster when it is not a raster is really mind blowing"* — followed by the fix
     this rule prescribes: *"i think you should show a proper raster (or two if you need).
     something simple to illustrate your point."*
   - **Every panel must be READABLE, not merely present.** With the render open, write one sentence
     per panel saying **what a cold reader sees** ("a bright blob with a red outline inside it").
     If you cannot write that sentence, the panel is a defect — say so. The panel you could not
     explain is the finding, not the one to skip. Watch for renderings that manufacture phantom
     structure: a mask with an interior hole outlines as **two nested contours** and reads as two
     objects; a threshold contour reads as a boundary the data does not have; overlapping
     translucent masks read as a third category. (Boundary with Ship It: agent 10 asks whether the
     panel is present, labeled, and clear of its neighbors; this asks whether, having looked at it,
     a stranger can say what it IS. Incident: an annular footprint that rendered as two concentric
     outlines passed every mechanical row, and was the one panel the PI singled out as
     uninterpretable.)
   - **Tone.** Consistent **sentence case**; no scattered Capitals or ALL-CAPS emphasis in prose;
     if the content is a list, **format it as a list** — never smuggle list items into a title or
     legend with separators.

9. **Density & figure-first — "Show, Don't Tell."** *Spawn for any multi-slide or multi-page
   deliverable — a deck, a poster, a report.* A generated document defaults to **prose**: correct,
   complete, sourced, and unreadable at a glance. Every other role checks whether the words are
   TRUE; this one asks the question none of them is empowered to ask — **what here should be a
   picture instead?** A wall of accurate text is still a failed slide.
   - **Count first, then judge.** Report a table, one row per slide/page: **total words · largest
     single text block · carries a figure (y/n) · figure share of the canvas (%)**. The thresholds
     below are **conventions the project may tune, not researched optima** — state the ones you
     used. Flag: more than **40 words** on a slide; any single text block over **60 words**; a
     **results or methods slide with no figure**; **two or more consecutive prose-only** slides; and
     any figure-bearing slide whose figure occupies **less than half the canvas** (next bullet).
   - **The figure is the payload — measure its share of the ink.** "Carries a figure" is the wrong
     question; **how much of the page the figure was given** is the right one. Measure the
     **rendered** figure's bounding box as a percentage of the page area — never its requested width
     in the source — and flag any figure slide under **~50%**, or any slide with more than **20% of
     its width as empty margin on both sides** while the text above runs full width. The remedy is a
     **reflow, not a crop**, and you must name it: *move the standfirst into a narrow left column
     and give the figure the remaining width*; *drop the full-width caption to a two-line footer*.
     An auto-shrinking layout helper is the usual cause, which is why the render is the only valid
     measurement. (Incident: a 13.3 in slide carried its key figure at 5.8 in wide — **29% of the
     canvas, 3.7 in of empty margin on each side** — because a fit-to-height helper traded width
     away to respect a bottom limit. A reviewer noticed the white margins and filed them as a minor
     flag; the PI's first instruction on seeing the deck was to move the text into a narrow column
     and let the figure fill the space. Boundary with Ship It: agent 10 reports empty margins as
     evidence of a **geometry/build bug**; this role judges them as a **layout policy** failure and
     owns the reflow prescription.)
   - **Every flag must name a replacement figure.** "Condense the wording" is not a finding — that
     is the line editor's job, and an agent that returns it has not done this one. Name the
     artifact: *this typed 3×2 table → grouped bars, value by category*; *this paragraph of
     sequence → a timeline*; *this mechanism → a schematic*. Or state plainly that prose is right
     here, and why.
   - **Relocate, don't delete.** Caveats, hedges, provenance, and competing readings are precisely
     what a review earns — cutting them to hit a word count trades a craft defect for a rigor
     defect, which is a worse trade. Move them to the **notes / speaker-notes pane**, an appendix
     slide, or a companion doc, where the presenter keeps every word. Only the assertion and the
     evidence for it stay on the face of the slide.
   - **A caption is a caption.** It states **what the figure shows and why it matters** — not the
     slide's whole argument. Anything past that moves to notes or its own slide.

10. **Build & craft gate — "Ship It."** *Spawn for every deliverable that renders — a figure, a
    slide deck, a poster, a PDF.* Owns every check whose answer is decided by **looking at a
    rendered file or running a script**, never by reasoning about the source. It is a separate role
    for one reason: a judgment call can be satisfied by thinking and a mechanical one cannot, so
    when the two share a checklist the prose answer covers for the file nobody opened.
    - **Output contract: a table, not findings.** One row per slide / page / panel, each row naming
      **the render it was checked against**. Prose in place of the table is a failed run, and
      **"not run" is a failure, not a clean result** — an empty finding list from this agent means
      nothing unless the renders exist.
    - **The build is current.** For a generated deliverable, the built file is **newer than the last
      fix and newer than every input it embeds** (see step 4). A stale build fails every row below,
      because the rows describe a file that is not the one shipping.
    - **Nothing overlaps; nothing runs off the page.** Run the render/zoom-crop pass specified
      below — within each figure AND shape-vs-shape across the whole slide.
    - **Everything the source implies is actually THERE.** Walk the generator's element list against
      the render: a dropped element leaves its caption and source line behind and reads as
      deliberate. Absence is invisible in the source — only the image shows it. (Spec below.)
    - **Document properties name THIS file, not the template it was built from.** Generated files
      inherit their blank template's creation date and author verbatim. Check and stamp
      created / modified / author / title on the final artifact. (Spec below.)
    - **Every axis is labeled with NAME and UNITS**, never a placeholder like "value".
    - **Same measurement across panels → shared y-limits**, or the deviation is explicitly marked.
    - **Panels are lettered (A/B)** — never referred to by spatial words ("left/right",
      "top/bottom"), in the figure or in the text that describes it.
    - **Every line, marker, bracket, shaded span, arrow, and color is identified** by an on-figure
      label or a legend. No unexplained line, no unlabeled bracket — including a line that is
      labeled in one panel and repeated unlabeled in another.
    - **No vertical lines or bars annotating a histogram** — they read as data height. Mark features
      with a distinct glyph (e.g. a down-diamond).
    - **One glyph per concept**, identical within and across panels; known-answer / ground-truth
      elements carry a **consistent glyph**.
    - **Category colors are clearly contrasting**, not a low-contrast pair.
    - **Every color is explained by the colorbar or a legend.** A colorbar spans the full range of
      values **actually rendered** — no color appears in the image that lies outside it. Any color
      used as an **overlay marker** (not a value on the scale — e.g. a significant-point marker on a
      heatmap) must be in a **legend** and picked to **contrast with the colormap**, or it reads as
      an out-of-range value (a red dot on a parula map topping out at yellow reads as "off the top
      of the scale" unless legended and edge-outlined).
      - **A color key must render IN its colors, adjacent to what it explains, at body size.** A
        key that names colors in plain gray body text ("magenta = footprint, red = manual ROI"), or
        that sits in the footer / source line beneath a paragraph, technically exists and is
        functionally absent — existence is not the check, identification is. Color the words (or
        set a swatch), place the key next to the figure, never at source-line size. (Incident: a fix
        that removed a colliding figure title relocated its color key into gray caption text at the
        bottom of the slide; the overlap re-check passed clean, and the PI's note was "the profiles
        need to be identified clearly — the legend is buried at the bottom of the page and lacks
        color".)
    - **Small multiples have real inter-panel spacing.** Panels packed edge-to-edge while the page
      has wide empty margins is a defect — separate them and use the whitespace.
    - **Report every figure's RENDERED box, not its requested size.** A fit-to-box / bottom-limit
      helper silently trades width for height and raises no error, so the placed figure can be far
      smaller than the code appears to ask for and the source reads as correct. Give each figure row
      the box measured off the render, in page units and as a % of the page. Wide empty margins
      beside a figure are reported here as a geometry defect; whether the layout *should* have given
      the figure more room is agent 9's call.

11. **Argument order — "Start With the Problem."** *Spawn for any deliverable that makes a case in
    sequence — a deck, an explainer, a report with sections.* Every other role reads the document a
    slide at a time; this one reads **only the order**. A deliverable can be true on every slide,
    readable on every slide, craft-clean on every slide, and still fail because it presents the fix
    before the reader knows there is a problem. No other role has standing to say *"slide 6 should
    be slide 1"*, and without it a deck ships in the order it was written rather than the order it
    argues.
    - **Reduce the document to its spine first.** Return a numbered outline, **one sentence per
      slide/section stating that slide's CLAIM** — not its title, not its topic. Judge the order
      from that list. A reviewer who reasons from the slides themselves ends up reviewing slides
      again, which is already covered twice.
    - **Check the spine against a defensible arc, and name the arc you used.** The default for an
      analysis deliverable is: **the problem → what it costs → the method applied to it → what the
      method gets wrong → the fix → the evidence for the fix → the residual risk.** Deviations are
      allowed; an *unstated* deviation is a defect.
    - **The cold open.** State what the audience sees **first**, and whether that is the problem. A
      deliverable that opens on history, scope, definitions, or a summary of the work asks the
      reader to hold everything in suspense until the motivation finally arrives. (Incident: the one
      slide that showed what the problem actually LOOKS LIKE was slide 6 of 12; the PI's instruction
      was to make it the first thing the reader sees — "they need to see the problem first".)
    - **Nothing arrives before the reader can evaluate it.** For each slide, name the earliest
      position at which its claim is intelligible. A slide that motivates something must precede
      what it motivates; evidence follows the claim it supports rather than leading it.
    - **Every slide earns its position or moves.** State the one job each slide does in the argument.
      A slide with no job in the spine belongs in an appendix, not in the middle of the case.
      (Boundary with You Lost Me: agent 8 asks whether a stranger can read **this slide**; this asks
      whether the **order of the slides** makes the case. Boundary with Reviewer 2: agent 4 attacks
      whether a claim is supported; this attacks whether it arrives somewhere the reader can judge
      it.)

**Where the weight falls.** No role is optional (see below), but each exists for a reason and does
the real work on the deliverables that need it. **When new analysis code underlies the deliverable**,
agents **6 (methods expert — RTFM)** and **7 (reuse auditor — Reinventing the Wheel)** carry it —
they review the code path that produced the numbers, not the prose. **When the deliverable is a
deck, poster, or any multi-slide / multi-page document**, agents **9 (density & figure-first — Show,
Don't Tell)** and **11 (argument order — Start With the Problem)** carry it: no other role has
standing to say "this should be a figure," so without 9 a deck ships as an essay in twelve parts; no
other role reads the sequence, so without 11 it ships in the order it was written rather than the
order it argues.

### What each role must be able to reach

A role that cannot perform its check still returns prose, and prose describing a check is
indistinguishable in the report from the check. *DOI or Die* with no way to reach a DOI reports on
citations it never resolved; *Ship It* with no way to open a render reports on a figure it never
saw. That is this document's own **"can the alarm ring?"** rule turned on the reviewers themselves,
so what a role may reach is part of the role's definition and belongs here, beside its checklist —
not in whichever harness happens to spawn it.

**No reviewer may edit the artifact.** Findings go to the main thread, which adjudicates and applies
them (steps 3 and 5). A reviewer able to repair what it finds can also make a finding *disappear*
before it reaches the record, and the record is the only thing a reader can check. No role is
granted `Edit`, `Write` or `NotebookEdit`.

**For some roles that is a boundary; for the rest it is a request, and the difference is `Bash`.**
Withholding the three editing tools confines a role that holds none of them — the judgment roles,
granted only `Read`, `Grep` and `Glob`, genuinely cannot alter anything. Every role granted a shell
can: `rm`, `>` and `sed -i` are writes, and a shell subsumes all three withheld tools. For those
roles the no-edit rule is a **discipline the reviewer is asked to keep**, not a boundary the grant
imposes. This document will not pretend otherwise. A review harness whose own documentation
overstates what it confines is worse than one that says nothing, because a consumer vendors on the
strength of the sentence — and overstating a guarantee is the exact defect this document sends
eleven roles to look for.

⚠ **Open gap, stated as one.** The shell is not removable: role 1 must recompute, role 10 must
render, and both must write intermediates somewhere. The repair is a declared writable scratch
path plus a harness-level restriction on everything outside it, and **it is not built yet**. Until
it is: run the murderboard on a checkout you would let a colleague run a script in, and treat a
reviewer that reports touching anything outside the scratch path as a finding about the run.

**Every reviewer declares its grant before it reviews.** A grant written down and a grant that
arrived are different facts, and nothing downstream can tell them apart. A role spawned through a
fallback path — because the named agent was not registered, or the harness never loaded it —
inherits whatever tools that harness happened to hand it: sometimes fewer than its grant allows,
sometimes *more*, including the editing tools the paragraph above forbids. So each role's
**first output line** states what it actually holds: `GRANT <n> ok — <tools held>`, or
`GRANT <n> MISMATCH — missing <tools>; holds <forbidden tools>`. Both are acceptable outcomes and
only silence is not. A mismatch is a finding **about the run**, not about the artifact: it belongs
in the ledger, and the run record's `roles:` line must then say the review took a fallback path
rather than claiming named agents. `murderboard_agents.py verify <report>` refuses a report that
claims grants its own reviewers said they did not have — because a rule that depends on the
reviewer remembering to mention it is the same non-gate this document was written about.

**Bash goes to the roles that must RUN something to answer.** 1 recomputes quantities and counts
what is missing; 4 walks a constructed failure through the metric to see whether the number moves;
7 locates the canonical implementation and compares it line for line; 9 measures a rendered
bounding box; 10 renders, crops and zooms; and **2 and 6 run the lit tool** to fetch the papers
this document forbids them to remember. **Web access also goes to 2 and 6** — the only two roles
whose sources live outside the repository. The rest are judgment roles reading the artifact and its
companions; handing them a shell would not make their answers more checkable, and a role that could
have gone looking for evidence but reasoned instead is worse than one that plainly could not.
**The table below is the authority and this paragraph is a gloss on it** — where they disagree the
table is right, because the table is what the compiler reads and this paragraph is what drifted.

`model` is `inherit` for every role: which model to spend on which reviewer is a property of the
consumer's environment, not of the process, and this document declines to guess. Tune it here if you
have a reason — that keeps the grant and the checklist in the same place, which is the point.

| # | role | may reach | model |
|---|---|---|---|
| 1 | Prove It | Read, Grep, Glob, Bash | inherit |
| 2 | DOI or Die | Read, Grep, Glob, Bash, WebSearch, WebFetch | inherit |
| 3 | Cross-Examiner | Read, Grep, Glob | inherit |
| 4 | Reviewer 2 | Read, Grep, Glob, Bash | inherit |
| 5 | Kill Your Darlings | Read, Grep, Glob | inherit |
| 6 | RTFM | Read, Grep, Glob, Bash, WebSearch, WebFetch | inherit |
| 7 | Reinventing the Wheel | Read, Grep, Glob, Bash | inherit |
| 8 | You Lost Me | Read, Grep, Glob | inherit |
| 9 | Show, Don't Tell | Read, Grep, Glob, Bash | inherit |
| 10 | Ship It | Read, Grep, Glob, Bash | inherit |
| 11 | Start With the Problem | Read, Grep, Glob | inherit |

`murderboard_agents.py` compiles this table together with the role blocks above into one agent file
per role, under `agents/`. **The table and the blocks are the authority; the agent files are their
output** — edit a role here and regenerate, never the other way round. A hand-edited agent file is a
second copy of a rule, which is how a roster stops describing the review that actually ran.

### The team is not optional

**Every role runs on every deliverable.** The matrix below records what each role is *for*, not a
menu to choose from. A reviewer may not drop a role because it judges the role inapplicable — that
judgement is made with the same context that produced the draft, and it fails in one direction:
toward less scrutiny of the thing the author was already comfortable with.

A role with genuinely nothing to check returns **"no findings, and here is what I checked"** — a
one-line statement of the surface it examined. That is cheap, and it leaves a trace. Silently not
running leaves none, and is indistinguishable in the report from running clean.

**Where a role looks inapplicable, read its checklist rather than its title.** Role 8 is filed
under "a non-expert audience", but its content — self-contained slides, define terms where they
first appear, no internal code identifiers in audience-facing text — applies to an expert reader
too. An expert who wrote the code still cannot read `§4 statistic` on a slide and recover what
decision is pending. Titles route; checklists govern.

| Deliverable has… | Role emphasis (all roles still run) |
|---|---|
| any document at all | **1, 3, 4, 5** carry the weight (Prove It · Cross-Examiner · Reviewer 2 · Kill Your Darlings) |
| references or named attributions | **2** carries the weight (DOI or Die) |
| new analysis code / a specific method or library | **6, 7** carry the weight (RTFM · Reinventing the Wheel) |
| a non-expert audience *(or any audience-facing text)* | **8** carries the weight (You Lost Me) |
| multiple slides or pages | **9** carries the weight (Show, Don't Tell) |
| an argument made in sequence (deck, explainer, sectioned report) | **11** carries the weight (Start With the Problem) |
| anything that renders | **10** carries the weight (Ship It) |

Agent **10 is never dropped for scale.** When step 2 scales a small deliverable down to a
single-pass self-review, the judgment roles collapse into one pass — the mechanical table still
runs. It is the cheapest agent in the team and the only one whose absence leaves no trace in the
output.

**For figures**, agents 1, 3, and 4 (Prove It, Cross-Examiner, Reviewer 2) adapt: does the caption match what is actually
plotted? Does the figure or its caption **overclaim**? Are the plotted numbers consistent
with the underlying data? For an **explainer or any non-expert-facing figure/slide, agent 8
(naive-reader accessibility — You Lost Me) carries the weight** — the reader-lost class of defect is
invisible to the rest of the team. **Agent 10 (Ship It) owns the mechanical checks**; the rows below
are spelled out in full because each has a trap in it that a one-line checklist entry loses (flag any
violation):
- **Every axis labeled with NAME and UNITS** (e.g. `time (s)`, `signal (a.u.)`). An unlabeled axis
  is a defect — flag it.
- **Any distance BETWEEN STRUCTURES states its convention — edge-to-edge (gap) or center-to-center
  (centroid).** Applies to prose, tables, captions and axis labels, not only to plots. **Neither is
  universally correct**; they answer different questions. The defect is leaving it *unstated*,
  because the two are not interconvertible and a reader will assume whichever suits the claim. Ask
  of every separation claim: **which metric produced this number, and does the text say so?**
  - **Choose the one that matches the question.** *Edge-to-edge* when the claim is about proximity
    or contact — is there a gap, how far must something cross, are these adjacent. *Center-to-center*
    when the claim is about position or arrangement independent of size — nearest-neighbor spacing,
    spatial regularity, drift or registration offsets, assignment costs — and when structures may
    overlap, since edge-to-edge saturates at 0 there and can no longer discriminate.
  - **An unstated convention is not a rounding difference.** The two differ by roughly one structure
    diameter: measured on one real population, edge-to-edge 8.10 px vs centroid 15.84 px, nearly 2×.
    A reader told "8 px apart" pictures a gap; if the number was centroid, the gap is about half it.
  - **Never mix conventions inside one comparison.** "2–3 cell widths" obtained by dividing a
    *centroid distance* by a *diameter* is a category error; it retracted a whole slide. Edge-to-edge
    on the same data gave 1.11 cell widths — adjacent, not remote.
  - **Overlapping structures have an edge-to-edge distance of 0 by definition.** If the point is to
    tell overlapping objects apart, edge-to-edge cannot do it — use **overlap** (IoU, or intersection
    over the smaller object), or center-to-center with the choice stated.
  - **They rank pairs differently and do not convert by a constant.** On one dataset, matching by
    centroid proximity found ~45 % fewer pairs than matching by overlap. Swapping the metric changes
    results, not wording — so a change of convention mid-analysis is itself a finding.
- **Same data compared across plots → shared axis limits (x and y).** If plots show the same
  measurement more than one way (condition A vs B, or the same series across panels), differing
  limits fake a difference via autoscaling — a slop bug. Deliberately different limits (full vs
  zoom vs detail, or naturally different ranges) are allowed **only if explicitly marked**
  (asterisk on the deviating panel + a footnote that the scales differ). Unmarked scale changes →
  flag. **When different limits are genuinely justified, prefer showing BOTH views** — the
  fixed / shared-limit one (the honest comparison) **and** the free / per-panel one (the internal
  detail) — rather than picking one: the shared view alone can hide each panel's structure, the
  free view alone can hide the difference between panels.
- **Show the actual data, not only a summary or a schematic — humans need to see the data.**
  When a deliverable rests on a dataset (real or synthetic), include a view of the **real
  underlying records** — a sample of rows, a trace, a raster of events — so a human can *see* what
  an aggregate or a schematic hides. A diagram of how the data *should* look, or a bar of summary
  statistics, is **not a substitute** for the data itself: a summary can be exactly right while the
  data is wrong (a spacing, a density, a jitter, an outlier, an artifact) in a way visible only
  when a person looks at the records. Flag any data-driven figure/deliverable that shows only
  schematics or aggregates and never lets the reader see the data.
- **Overlap check covers the whole page/slide, not only inside a figure.** The zoom-crop overlap
  pass (slice the render into bands) catches label-on-tick collisions *within* a figure — but also
  check **shape-vs-shape on the slide**: a figure overlapping body text, a caption overflowing its
  box, a picture pushed off the page edge, or body text that grew past its box into the figure below
  (a common regression after an edit lengthens the text). Verify every figure's box sits clear of
  every text box, and nothing runs past the page bounds.
  - **An automated overlap gate has blind spots — know which.** A checker that compares text boxes
    against IMAGES will pass a caption sitting on a TABLE, and text overrunning a footer or another
    text box, because neither is an image. Tables are the worst case: they GROW to fit their content,
    so a table's rendered height is not the height the code asked for, and the gap you left below it
    may not exist. Treat a clean automated pass as necessary, never sufficient, and say in the report
    which classes the gate cannot see.
  - **This pass requires a render of the FINAL COMPOSITED deliverable — you cannot skip it.** When the
    deliverable is not already an image (a slide deck, a poster, a PDF), **render each slide/page to an
    image first**, then run the zoom-crop bands on *that*. Inspecting the component figures, or the
    source/extracted text, is NOT sufficient: a caption that overflows onto the figure is invisible in
    both, and a shape bounding-box check misses it because text overflows its fixed-height box
    **silently** (no reflow, no error). If the deliverable is generated by code, also **gate the build**
    on an estimated-text-height check (lines = chars ÷ chars-per-line; fail if any text's estimated
    bottom crosses a figure's top) — belt-and-suspenders for the render pass. **"Final composited"
    means the freshly rebuilt file** (step 4): a render of a build that predates the last fix proves
    nothing about what ships.
- **Text inside an embedded figure is sized by its PLACED size, not by the figure.** The size a
  reader sees is roughly `source_pt × (placed width ÷ the figure's own nominal width)`. A figure
  authored 20 in wide and placed 8 in wide renders its 11 pt labels at about 4.5 pt — perfectly
  legible while you are making it, unreadable in the deliverable. Compute that ratio and check the
  SMALLEST text in every embedded figure against the deliverable's own minimum type size. A house
  rule like "all fonts ≥ 11 pt" is otherwise satisfied only by the text the document set itself,
  and silently exempts every figure — which is most of what the reader is trying to read.
- **A figure collides with ITSELF, not only with the page — and the causes are different.** The
  slide-level checks above assume a composited document; a single multi-panel figure fails the same
  way for reasons no bounding-box or slide render reaches. Check each explicitly: a **supertitle or
  subtitle is one line that does not wrap**, so a string built by interpolation (an id, a list, a
  value printed to 3 s.f.) runs off *both* page edges; **per-panel titles collide sideways**, because
  each panel is only `width ÷ ncols` wide while the title font is usually larger than the axis font;
  and a plotting library's **layout padding may not survive export** (a tight-crop export discards
  it, putting ink against the page edge with no headroom for any later font change). Report the ink
  bounding box against the page — ink touching the edge is text off the page, ink within a few px is
  a clip waiting for the next edit. This is decidable mechanically and belongs in agent 10's table.
- **Publishing IS delivery. Render to a private path, inspect, and only then write where the reader
  looks.** Reviewing a render you have already dropped into the shared folder — the review directory,
  the synced drive, the channel — is inspection *after* publication: the reader can have seen the
  defect before you looked, and every intermediate iteration is visible as if it were a draft you
  chose to show. State the deliverable's publication boundary and keep unvetted renders on the other
  side of it. (Incident: every render of a figure was opened and checked, and the author still shipped
  two defective versions — a supertitle off both page edges, then panel titles colliding after a
  review fix lengthened them — because each render was written straight into the folder the reviewer
  reads from. The inspection was real; it was one step too late. The reviewer's note was that this
  class had been raised with them "many times".)
- **Raising a figure's fonts CLIPS its long strings. Any font change is a layout change.** Titles
  and supertitles are laid out against the axes or the figure width, so enlarging the type makes an
  already-long string overflow, and it is cut off at BOTH ends with no error and no warning. After
  any font or size change, re-render and re-read every string end to end — do not assume a fix to
  legibility left the content intact.
- **Explanatory prose belongs in the caption, not inside the figure.** A definition, key or legend
  embedded in a supertitle is the first thing to become illegible when the figure is scaled down and
  the first thing to be clipped when its fonts are raised. Keep figure-internal text to labels that
  name what they sit next to; put the sentence beside the figure, where it is set in the document's
  own type size and can be read.
- **A label annotating a region must be anchored CLEAR of that region's border, not centered near
  it.** Text centered on a coordinate close to the edge of a patch, box or shaded span puts half its
  glyph height across the line, and renders as a strike-through. Anchor it outside the shape's
  extent (bottom-aligned above, top-aligned below) so the two cannot collide however long the string
  later grows.
- **A borrowed figure imports its owner's defects.** Reusing a panel from another deliverable
  inherits its clipping, contrast and font problems, and "it was already like that" stops being a
  defense the moment you ship it. Hold a borrowed asset to the same bar as one you made; when it
  fails, fix it **at its source** rather than cropping around it, and record where the fix belongs
  so the other consumer gets it too.
- **If the point of the page is "how does this work", the figure must show the MECHANISM, not the
  output.** A figure of finished results cannot answer a process question: the reader substitutes
  their own model of the algorithm, and a wrong model can survive many readings without anyone
  noticing, because nothing on the page contradicts it. When a reader says they do not understand a
  method the deliverable supposedly covers, check whether any figure actually shows the intermediate
  steps — usually none does. Prefer a purpose-built figure that computes its annotated numbers from
  the same code path it is explaining, so the illustration cannot drift from the implementation.
- **Presence check: the render must contain everything the source implies.** Overlap is not the only
  render defect — a generated element can be **silently dropped**. Adding a table to the wrong kind of
  placeholder, an unsupported object in a container, a missing asset path: the library emits no error,
  the build succeeds, and the artifact simply lacks the element while its caption and source line
  remain, which reads as deliberate. Walk the generator's element list against the render and confirm
  each one is actually visible. Absence is invisible in the source; it is only detectable in the image.
- **Provenance / document properties of a GENERATED deliverable.** Libraries that build files from a
  bundled blank template (python-pptx, MATLAB Report Generator, docx/LaTeX templates) copy that
  template's metadata verbatim and never rewrite it. The finished artifact then advertises the
  **template's** birthday and the **template author's** name — e.g. decks created today reporting
  `created 2013-01-27, lastModifiedBy "Steve Canny"` (the author of python-pptx) or `created 2014,
  modified 2019` (Report Generator). Check created/modified/author/title on the FINAL file and stamp
  them. Also check any derived field the generator does not refresh when code changes geometry (e.g.
  `PresentationFormat` still reading "4:3" for a widescreen deck). This matters most for anything
  leaving the group: a shared deliverable that shows a decade-old creation date and a stranger as its
  last editor discredits itself before it is read.

## Literature handling — check the lit cache, keep the keepers, flag the gaps

The murderboard reads papers (agents 2 and 6 especially). Reading a paper means **getting
its actual text**, never reasoning from memory — a half-remembered paper is exactly how a
from-memory reference list or a method misattribution ships. Two goals: stop re-downloading
what you already have, and flag what you can't reach so a human can fetch it. All fetching
goes through **`fetch_paper.py`** (open-access hosts only; it caches fetched papers under
`<lit>/_autofetch/` so a URL is never pulled twice). Point it at your literature library
with the `MURDERBOARD_LIT` environment variable (see the tool's header). Three standing steps:

1. **Check the library FIRST.** Your curated library likely already holds the PDF. Before
   fetching, search it — a hit means Read the PDF, do not download:
   ```
   python3 fetch_paper.py --have <author> <keyword> <keyword>
   ```
   This is the step that "prevents many downloads" — the `_autofetch` cache only dedupes by
   URL, but `--have` finds a paper already filed under a human name.
2. **Promote the keepers.** When a fetched paper actually earns its place in the review
   (verified a citation, grounded a method), copy it into the curated library so the next
   session finds it via `--have` instead of re-fetching:
   ```
   python3 fetch_paper.py --promote <url> "Author Year short title.pdf"
   ```
3. **Flag what you can't get.** Every failed or paywalled fetch is auto-appended to
   **`<lit>/_NEEDED.md`** (a `--need "<citation>"` also flags a citation with no reachable
   URL). **Surface that want-list in the delivery message** — a human can get any PDF; a
   paper you couldn't reach becomes a residual `⚠`, never a guess about its contents.

## Adjudication (main thread)

- **Confirmed factual error** → fix it.
- **Unverifiable claim** that cannot be checked right now → **flag inline** (`⚠ VERIFY …`),
  never delete-and-hope or guess a plausible number.
- **Style / clarity** → apply when it improves precision; do not pad.
- **A named construction or an over-length block** (role 5, with a line number) → **not covered by
  the line above.** "Apply when it improves precision" is a disposition for taste, and taste is
  what a style finding usually is. A hit from `murderboard_prose.sh` is not taste: it has a
  location, it was found by a search that could have come back empty, and waving it off returns
  the run to the state the search existed to end. Fix it, or record *why it stays* next to its
  line number. Neither of those is "do not pad".
- Surface residual `⚠` flags **prominently** in the delivery message.

## Output contract

Deliver **(1)** the corrected document, **(2)** a short plain-language summary — dimensions
checked, issues found / fixed, verify rounds, any remaining `⚠` flags — and **(3)** a **role
ledger: one row per role in the roster, all of them**, each carrying either its findings or
its "no findings, and here is what I checked" line. If nothing survived review, say so
plainly — do not manufacture findings to look thorough.

The summary **must carry the calibration line** from *"What a clean run does NOT warrant"* above:
the review is evidence the roles ran, not a correctness proof. A report that omits it is a report
that will be quoted as a warrant.

**The ledger is not bureaucracy; it is the only evidence the team ran.** This contract used to
ask for "a 3–6 line review report", which cannot physically carry a trace from eleven roles —
so the document demanded that every role run, then specified an output too small to show
whether they had. A run that fired 7 of 11 roles and a run that fired all 11 cleanly produced
reports a reader could not tell apart. That is this process's own "can the alarm ring?" rule
turned on itself: *"no findings from role 9"* is worth nothing if role 9 was never spawned.

**Check the ledger mechanically rather than by eye** — `murderboard_roster.sh` parses the
roster out of this file and verifies the report accounts for every role:

```
murderboard_roster.sh list            # the roster, derived from this file (never recalled)
murderboard_roster.sh check REPORT.md # 0 = every role accounted for, 1 = one is missing
```

**The record declares its mode**, on a line of its own: `Mode: standard` (the full loop ran, or
was available to run) or `Mode: retrospective` (the artifact cannot change — see *When the
artifact can no longer change*, which also requires a stated stopping reason). The gate reports
the mode it found, and an undeclared mode is reported as **undeclared** rather than assumed
complete — the same discipline the freshness gate uses, where the one verdict it may never
produce is a false "current". Undeclared still exits 0, so existing reports keep passing; a
project that wants the declaration enforced opts in:

```
murderboard_roster.sh check --require-mode REPORT.md   # undeclared mode is a failure
```

An eleven-of-eleven ledger says every role ran. It does not say the loop finished, and until the
mode line existed there was nowhere for that difference to be recorded.

**The record also declares how the roles were executed**, on a line of its own, as a
**controlled token** followed by prose the gate never reads:

```
Execution: subagents — one per role, all eleven spawned
Execution: single-pass (forced) — the Agent tool was unavailable
Execution: single-pass (chosen) — a one-line caption
```

The ledger cannot carry this either. Eleven roles spawned as eleven independent reviewers, and
eleven roles played in turn by the one agent that wrote the draft, produce the same eleven rows
— and the second is a materially weaker adversary, most of all at role 4, where the attacker is
also the author.

**The token is stated rather than inferred, and the reason generalises past this gate.** Two
earlier versions read the verdict out of the sentence, and both failed in the expensive
direction — recording a degraded run as a full one. The second was defeated by a comma:
*"parallel subagents; role 4 could not reach the web"* and the same sentence with a comma
classified opposite ways. The diagnosis is worth carrying: textual distance was standing in for
**grammatical attachment** — does a failure attach to the fan-out or to one role? — and
*"parallel subagents could not start"* and *"parallel subagents, role 4 could not start"* have
nearly the same span and opposite meanings. No threshold separates them, because distance is
not what distinguishes them. A cheap measurable quantity standing in for the property that
actually matters is a defect this process hunts in other people's work; it had been built into
one of its own gates.

A single-pass declaration must say **which kind** it was, and the gate rejects a bare one:

- **chosen** — the deliverable is a caption or a one-liner, and a ten-agent fan-out on one
  sentence is waste. The process working as designed.
- **forced** — the Agent tool was unavailable: denied by a permission rule, withheld by a
  launch flag, forbidden by an instruction, or absent because the session was already inside a
  subagent. An environment defect, which will recur on every run until someone changes the
  environment, and which the reader must be able to tell from the first.

Unqualified, it reads as *chosen*, because that is the reading that costs nothing to assume.
`docs/reviews/plugin_adoption_docs_murderboard_2026-08-26.md` is the forced case, and it is
legible only because its author wrote a "Stated deviation" section nothing asked for.

```
murderboard_roster.sh check --require-execution REPORT.md   # undeclared execution is a failure
```

Undeclared exits 0 by default, on the same terms as the mode line: this file is vendored, and a
change that reddens every report a consumer has already written gets the gate deleted rather
than the reports fixed.

**Establish it before the run, not after.** A run that discovers mid-flight that it cannot fan
out has already spent the roles. Probe first — spawn one throwaway subagent and require an
answer back — and if it fails, stop and say so while a "no" is still cheap.
`murderboard_subagents.sh` then names the blockers that are visible in files, so *"allow
subagents"* is one edit rather than a scavenger hunt. **It cannot answer the question on its
own**, and reports that limitation on every run including its clean one: availability is
settled by the session's tool list, a launch flag, or an instruction injected at runtime, and
the 2026-08-26 block was in none of the files any scan can read. The spawn is the check; the
scan is the hint.

Because the roster is derived, adding a role here propagates to every consumer's check with no
edit anywhere else. A failing check does not mean "write more" — it means a role either never
ran or left no trace, and both are defects.

---

## Appendix — example incidents (why each rule exists)

These are the concrete failures that motivated the rules above. They come from the
calcium-imaging analysis project the murderboard grew out of; they are **illustrations**,
not part of the process. Keep them because a rule with its scar attached is easier to take
seriously than a rule stated in the abstract.

- **Claim/data verifier** — a regenerated export was complete in shape and empty in meaning:
  a ported treatment dictionary was missing two rules its source stack had, so **67% of rows
  carried no treatment label** while every summary statistic still computed. Found only by
  diffing against an older export of the same data. Hence: count the missing, check the label
  vocabulary against its source, and account for every difference when a deliverable replaces
  an earlier one.
- **Claim/data verifier** — a manuscript misattributed a method to the wrong tool; a slice
  ID was copied wrong; per-detector z-values disagreed with the run they summarized.
- **Citation validator** — a "representative" reference list was written from memory, with
  bibliographic details that did not survive a lookup.
- **Consistency auditor** — a document said "five detectors" in one place and "four" in
  another.
- **Methods expert** — a figure fed a spike-inference tool (MLspike) a trace at baseline
  ≈ 2 when the method requires F/F₀ with **baseline = 1**; another passed a **column**
  vector to `prctfilt`, which filters along the *last* dimension, so the baseline came back
  all-zeros. Both are invisible to a prose-only read.
- **Reuse auditor** — that same analysis re-implemented a normalization the project already
  did correctly in tested production code (`MLspikeWrapper3`), and flipped the vector
  orientation in the process. The fix was to call the existing code, not re-derive it.
- **Figure-craft** — panels comparing the same measurement two ways were autoscaled
  independently, faking a difference that shared y-limits dissolved.
- **Naive-reader / figure-craft** (a 2026-07 slide-deck review) — a "validation" slide claimed a
  synthetic ground-truth test but showed only two near-threshold real examples (not the synthetic
  set); a "result" slide reported one pooled prevalence number instead of the group×condition
  breakdown that actually carried the finding; a small-multiples grid was crammed edge-to-edge beside
  wide empty margins; validation panels were unlabeled as to which archetype each showed; and an edit
  that lengthened a slide's text pushed it into the figure below — a slide-level overlap the
  within-figure zoom-crop pass never sees; two bar charts on one slide ordered their experimental
  groups differently, so the reader could not line them up; and a spectrogram's red
  significant-peak overlay read as an out-of-range color because the parula colorbar topped out at
  yellow and the marker was never legended.
- **Methods expert** (same review) — a detector's synthetic benchmark ran at *looser* gates than the
  shipped detector, so "9/10" validated a different tool than the one that made the results (at
  production settings it was 8/10); and "9/10 real bursts flagged" actually meant "9/10 mixed cases
  classified" — the metric counted something other than the prose said.
- **Adversarial reviewer** (same review) — "group-G-enriched" was printed as a raw count in the
  largest group (true as a rate, but the rate was never shown); "two independent methods agree"
  described two lenses computed from the *same* recording (and one was "validated" on cases the other
  had selected — circular); and a "treatment amplifies the effect" headline rested on a single example
  cell while the group-level rate moved the other way.
- **Consistency auditor** (same review) — the same "TTX-oscillator" population appeared as 21+26, as
  35, and as 25+14 on adjacent slides because three different counting bases (per-detector flags,
  unique cells, deduped-roster primary type) were never reconciled to one.
- **Verify pass / generated deliverables** (a 2026-07 slide-deck review, script-built `.pptx`) — the
  murderboard ran **twice** and against a **current** vendored copy, and every prose correction
  shipped, because both passes ended in a rebuild. The figure-overlap fix did not: the builder was
  corrected to compute each figure's height against a bottom limit instead of letting the aspect
  ratio set it, but the deck was never regenerated. The delivered file was one build old and ran all
  four captions through their figures — a defect the process, the project's own hard rule, and the
  fix in the source tree all covered. The gap was that "re-check the corrected artifact" never said
  **which** artifact when a script and its output are both on disk.
- **Density & figure-first** (same deck) — 1,646 words over 12 slides (**137 per slide**), **8 of 12
  slides carrying no figure at all**, a largest single text block of **139 words**, and figure
  "captions" running 42–76 words. Its central comparison — three slices × two sampling rules — was
  typed as a text table on a slide, in a deck that already shipped four plotted figures. The review
  ran twice and raised none of it, because every rule in the process asked whether the words were
  true and no rule asked whether they should have been a picture. The verbosity was also
  **load-bearing** (the caveats and competing readings are what the review earned), which is why the
  rule that came out of it relocates prose to the notes pane rather than cutting it.
- **Render presence** (a 2026-07 status-deck build) — a slide's table was added to a placeholder type
  that silently discards tables. The build succeeded, the caption and source line rendered normally,
  and the slide simply had no data on it. Nothing in the source or the logs showed this; it was found
  only by exporting the slide to an image and looking at it.
- **Provenance / document properties** (same build) — decks generated that day reported creation dates
  of 2013 and 2014 and named the author of a Python library as their last editor, because both
  generators copy their bundled blank template's metadata and never rewrite it. One of the affected
  files was the copy most likely to be shared outside the group.
- **Correction discipline** (same build) — a claim the project had already measured and explicitly
  retracted ("neighbor centers 7-15 px apart"; the note said *do not re-inherit it*) was reproduced in
  a new draft because the author read the original brief rather than the correction. The first fix then
  replaced it with a *different* unsound mechanism that the same slide's own number refuted. Lesson:
  when a source document carries a retraction, review the retraction and the original together — and
  re-verify the REPLACEMENT claim as hard as the one it replaced.
- **Adversarial reviewer / "Can the alarm ring?"** (a 2026-07 pipeline deck, full team + verify pass)
  — a deck proposed discarding fragmented-footprint "islands" and cleared the obvious risk (that the
  islands are real cells) with "recall unchanged". The review noticed recall was **saturated at 100%
  on 2 of 3 slices** but stopped there. The sharper defect was structural: recall matched **175 tool
  footprints against 27 human ROIs**, so a real cell knocked off its ROI is covered by a neighboring
  footprint and the metric cannot move — the control had **no power to detect the harm the claim
  denied**, and the slide's own caption said so ("another covers it"). The PI got it from the picture
  in under a minute: the discarded islands were visibly **adjacent cells with their own bright
  cores**. Two lessons: a null needs a demonstrated ability to fail, and a figure must be *looked at*,
  not read about.
- **Naive reader / panel readability** (same deck) — a footprint panel showing an annular mask
  rendered as **two nested contours** (the outline of a mask with an interior hole) and was simply
  uninterpretable. Every mechanical row passed: it was present, lettered, labeled, and overlapped
  nothing. Nobody had been asked to say **what the panel shows**.
- **Located vs pooled findings** (same deck) — the accessibility reviewer listed six undefined terms
  spread across the deck; none were fixed. The PI's note was "slide 2 has a bunch of undefined
  terms". The finding existed and did not survive synthesis because it was never attached to a slide.
- **Figure share of the canvas** (same deck) — the key figure sat at **5.8 in wide on a 13.3 in
  slide, 29% of the page, with 3.7 in of blank margin on each side**, because a fit-to-height helper
  scaled width down to respect a bottom limit. It was seen and filed as a minor flag: the word-count
  table asked how many words were on the slide and nothing asked how much of the slide the figure
  got.
- **Regression from a fix** (same deck) — a two-line figure title colliding with panel titles was
  correctly flagged, and fixed by **deleting the title** and moving its color key into gray caption
  text at the bottom of the slide. The verify pass re-ran the overlap check, which passed. Nothing
  checked whether the legend was still legible; the shipped slide identified its colors in
  uncolored 12 pt gray below a paragraph. The fix created the defect the review then missed.
- **Argument order** (same deck) — twelve slides, every one true and individually readable, in an
  order that reached the fix before the reader had seen the problem. The slide showing what the
  problem looks like was **slide 6**; the PI moved it to the front. No role in the team read the
  sequence.
- **The team is not optional** (a 2026-07 15-slide status deck) — the reviewer **dropped two roles on
  its own judgement**, including role 8 because "the audience is the project owner, who is an
  expert". Role 8's actual content is *self-contained slides*, *define every term where it first
  appears*, and *keep internal code identifiers out of audience-facing text* — none of which is about
  expertise. The deck passed review with 13 findings fixed and shipped a "Remaining issues" slide
  listing items as `ADR-0017 §4 statistic`, `Per-footprint vs per-island edge rule`, and `the
  bridge's one knob`. The project owner read it and replied *"2. no clue what this is about. 3. no
  clue. 4. no clue. what bridge? 6. repeats 1?"* — four of six items unreadable and one a duplicate.
  The role that would have caught it had been reasoned away from its title instead of its checklist.
- **Blind re-review** (same run) — the same review repaired 13 findings and **re-ran no role
  afterwards**. Two repairs introduced new defects that only the next render caught: resizing a
  figure to stop it overlapping text moved it onto a *different* text block, and re-flowing a list to
  fix an overflow pushed its last line onto the source footer. Neither would have been found by a
  follow-up pass driven by the original findings, because neither was on that list — which is why the
  blind pass must come first.
- **Figure legibility and figure-vs-text collisions** (a 19-slide generated deck) — embedded plots
  authored ~20 in wide and placed ~8 in wide rendered their 11 pt labels at 5-6 pt, so the deck's own
  ">= 11 pt" rule was met only by the slide text. Raising the source fonts then CLIPPED every long
  supertitle at both ends, which the first render caught and the source did not. Separately, a
  context-window annotation centered just above a shaded patch was struck through by the patch border;
  a borrowed panel arrived with its own titles already clipped and a low-contrast label; and a caption
  landed on a TABLE twice, invisible to a text-vs-picture overlap checker because a table is not a
  picture and had grown past its requested height. Lesson: figure text is sized by where it LANDS,
  every font change is a layout change, and only the render of the composited page shows any of it.
- **Mechanism vs output** (same deck) — a reader reported not understanding a method the deck
  "explained", saying they kept expecting a sliding window where the algorithm actually uses fixed
  non-overlapping bins. The deck had borrowed a figure showing two FINISHED episodes and never showed
  the binning, so nothing on the page could have corrected the wrong model. The fix was a purpose-built
  figure of the intermediate steps that recomputes its annotated numbers from the same logic it
  illustrates. Lesson: a results figure cannot answer a process question, and a plausible wrong model
  is invisible until someone says it out loud.
- **A verified citation that was the wrong citation** (an attribution report, 2026-08) — a run
  reported 11/11 roles, a blind verify round, blocking findings 5 → 0, stopping reason "severity
  floor reached", and a clean `murderboard_roster.sh check`. Every signal green. The document
  credited a 2022 paper for a synchronous-event detection rule introduced nineteen years earlier
  in Cossart, Aronov & Yuste 2003 (*Nature* 423:283–288, doi:10.1038/nature01614), which in turn
  credits Mao et al. 2001 (*Neuron* 32:883–898). **The misattribution was both nineteen years late
  and one laboratory upstream**, and the second half is the more serious one: the rule was
  published from **Yuste's lab at Columbia** (PMID 12748641 — Cossart first author, Yuste last,
  "Department of Biological Sciences, Columbia University, New York"), and was credited to the
  **Cossart lab** through a 2022 INMED paper (PMID 35856497 — Dard first author, Picardo last,
  Cossart second-to-last, "Aix-Marseille University, INSERM, INMED U1249, Marseille"). Rosa
  Cossart is first author on the 2003 work and carried the method to her own lab in Marseille, so
  the lineage runs Yuste → Cossart. A nineteen-year gap is a curiosity; crediting the wrong
  laboratory is a research-integrity problem. The PI caught it from the delivered summary in one
  sentence. Every citation in the document resolved — nine PMIDs and a DataCite DOI — and an
  author-list error in the same reference had been caught and fixed by role 2 on an earlier pass.
  **Sequel, 2026-08-25.** The fix was filed as a sub-bullet under role 2 and the role's opening
  sentence still read "confirm the work exists and is correctly attributed". Every summary written
  from that sentence — including this project's own briefing document and its public explainer —
  reproduced the pre-fix rule, because a summariser reads the headline and stops. A rule filed
  below the line a reader actually reads has not been filed. **When a role gains a check, the
  role's first sentence is part of the change.**
  The reviewer verified everything present and never asked what was absent; one backward step,
  named in a single line of the 2003 paper's own Methods, would have found it. In the same run a
  suite of detectors was cleared against the spike-train literature and reported as "ours as far as
  we know" — all of it is CFAR, a radar literature dating to Finn & Johnson 1968 (*RCA Review* 29).
  Lesson: **existence and correct attribution are not origin**, and a single-field search cannot
  clear a construction general enough to have been invented in another field. Confound recorded
  honestly: that run was executed single-pass on a substantial report where the process prescribes
  parallel subagents, so conformance was also short — which is why the size rule may no longer
  collapse role 2 on an attribution deliverable.
- **The rule fired; the class did not close** (the same attribution report, re-reviewed 2026-08-24)
  — the fix above was tested by re-running the repaired process **blind** on the same report at
  the commit before its correction, in two independent arms that could not see each other and were
  not told a defect had been missed. **Both caught the wrong laboratory**, independently, from
  PubMed affiliations; a third delivery caught it again. So the origin rule works on the defect it
  was written for.
  Then the tool's author supplied ground truth nobody in the estate had: an email answering the
  exact question, sent **2026-04-23, four months before the report was written** — naming his own
  applied papers (Cecchini et al. 2022; Kreuz et al. 2024) doing the very construction the report
  claimed as "ours", and pointing at Mainen & Sejnowski 1995 for a second claim, closing *"I was
  kind of hoping you'd find it on your own."* **Every arm missed all of it.** Both had written, in
  nearly identical words, that the report *"verified everything present and never asked what was
  absent"* — and then did the same thing one level down: they reached for radar, seismology,
  astronomy and econometrics while never checking the measure author's *later* work, and never
  asking whether anyone had simply written to him. Someone had. The reply was in an inbox the
  whole time. Hence the two rules above: **trace forward, and ask what the humans hold.** Lesson:
  a rule patched to catch one instance of a defect class does not close the class, and the
  cheapest source in the room is the one no search strategy will ever return.
  > ⚠ **This appendix is an answer key.** These entries name the defects, the papers and the
  > laboratories, so a blind re-run against a case recorded here is contaminated by the process
  > document itself — the 2026-08-24 arms had this bullet's predecessor withheld for exactly that
  > reason. When re-testing on a recorded case, redact its entry and say that you did; when
  > choosing a case, prefer one that is **not** written down here.
- **A green check that had stopped measuring what its name claimed** (the freshness gate's own
  selftest, 2026-08) — the case named `clone guesses are slug-scoped` existed to prove the gate's
  built-in clone guesses are admissible for its own upstream and refused for anyone else's. It
  stamped its fixture with a *fabricated* sha and used "the run did not say UNKNOWN" as its proxy
  for "the guess was used". When the gate later learned to refuse to rank a stamp its clone has
  never fetched, a fabricated stamp became correctly unrankable — so the case would have gone on
  reporting PASS or FAIL for a reason having nothing to do with slug scoping, and the tempting fix
  was to re-baseline it to agree with the new code. It was repaired instead, to stamp a real older
  commit, which is what it always meant to test. Lesson: **a passing check earns its authority from
  the thing it measures, and a proxy can quietly detach from that thing while the name and the
  green stay exactly the same.** When a change makes a test go red, ask first whether the test had
  stopped testing — re-baselining is how a suite becomes a row of green lights that assert nothing.
- **A committed merge conflict wearing a stamp** (a consumer branch, 2026-08) — a consumer's branch
  tip carried unresolved `<<<<<<<` / `=======` / `>>>>>>>` markers in the **top six lines** of three
  vendored files, one vendor stamp on each side of the conflict (`729fb06` vs `4e417da`). The
  vendored `fetch_paper.py` did not compile. The freshness gate, asked about it, read the first sha
  it found, sided with one half of somebody's unfinished merge, and returned a confident verdict.
  A file in that state is vendored at **no** commit. The gate now refuses it: unresolved markers in
  the header mean freshness is *undeterminable* (exit 2), and the repair is to re-copy the file
  fresh from upstream rather than resolve toward either side, because both sides are stamps and
  neither is the content. Lesson: **the thing that makes a check trustworthy is that it can say
  "I cannot tell"**, and a stamp is metadata about a file, not evidence the file is intact.
- **Adversarial reviewer / a passing test defending the defect** (2026-08-28, `murderboard_agents.py`)
  — the tool that compiles this file's roles into agent files writes them into `.claude/agents`,
  which is the harness's **shared** project agent directory, not the tool's own. Its refresh deleted
  every `*.md` there it had not itself produced, and its `check` reported those files as *orphans* —
  which is what made the skill's unattended `check || write` fire the delete. A consumer with their
  own subagents lost them on their first review. **Two selftest assertions had been green since the
  tool was written** — "an orphaned agent file FAILS check" and "write removes the orphan" — and
  both described a consumer's own agent on its way to being unlinked. The suite was not silent about
  the behaviour; it was **vouching** for it, and a later maintainer fixing this would have met a red
  suite and read it as their own error. The repair had to **flip** those two assertions rather than
  add safe ones beside them. Three lessons, and the second is the one that generalises: a tool
  writing into a directory it does not own may remove **only what it can prove it wrote** (here, a
  generated banner in the file's own content — not its name, not its location); when a defect is
  found, the tests that *passed* are evidence and must be read; and an unreadable file is never
  evidence that it is yours to delete. Reported by the review team's own role 6 and role 3 running
  against the branch that introduced it, and reproduced before repair: two files in, zero out.
