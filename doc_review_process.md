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

## The core principle

**Every sentence must be EITHER (a) verifiable against a real source — the data, the
code, a store, a prior result, or a checked citation — OR (b) explicitly flagged as
unverified/assumed (`⚠`).** No unsourced factual or quantitative claim ships unflagged.
No fabricated or approximate citation. No internal contradiction. No filler.

## The process

0. **Preflight — confirm the process itself is current.** This file is usually **vendored** into a
   consumer repo, where it drifts behind its canonical source. Before running, verify THIS copy is up
   to date with upstream — compare its vendored stamp/commit against the canonical repo's HEAD (search
   the known repo locations if the source isn't obvious) and **re-vendor first if it is behind.** A
   review run against a stale process is itself a slop defect: it silently omits rules the process has
   already learned. (This step exists because a consumer shipped a slide-overlap defect using a
   vendored copy that predated the slide-overlap rule.)
1. **Draft** the document.
2. **Review** — run the review team (below). **Every role runs on every deliverable; what
   scales to stakes is how you run them, never which ones you run.**
   - Substantial doc (methods, manuscript, explainer, deck, multi-paragraph report) → **spawn
     the roles as parallel subagents**, one per role, via the Agent tool.
   - Small doc (a caption, a one-liner, a short list) → a **single-pass self-review that still
     walks every role's checklist in turn**, and still produces agent 10's table. Do not burn a
     ten-agent fan-out on one sentence — but do not silently drop a role either: a dropped role
     and a clean role are indistinguishable in the report.
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
     **(a) Legibility.** If the fix deleted, moved, shrank, or recoloured a title, legend, key, or
     label — is the thing it identified **still identifiable**? Removing a colliding label resolves
     the collision by destroying the identification.
     **(b) Relocated, not vanished.** Every element the fix removed must land somewhere **named**:
     the notes pane, an appendix slide, an adjacent legend. "Deleted to resolve the overlap" is a
     finding, not a fix.
     **(c) Prominence.** An element demoted to grey, small, or bottom-of-page must still be findable
     **by the reader who needs it, at the moment they need it**. Presence is not availability.
     **(d) Geometry.** The classic reflow regression — a fix that lengthens text or moves a shape
     pushes something else out of its box or off the page.
     **(e) Scope.** A fix made inside a shared helper changes every artifact that calls it; re-check
     the other consumers, not just the one that prompted it.
     (This exists because a figure-title collision was fixed by deleting the title and moving its
     colour key into grey footer text. The overlap re-check passed — it was the only thing re-run —
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
     - Iterate until a **blind** pass produces no new findings. **Report the number of rounds** — a
       deliverable that needed three is a different object from one that needed none, and the reader
       should know which they are holding.
5. **Deliver** — the corrected document **plus a short review report**: which dimensions
   were checked, how many issues found and fixed, the verify-pass result, and any residual `⚠` flags
   the human must resolve before release. For a generated deliverable, state that the shipped file
   was **rebuilt after the last fix** and verified in that state. A document with unresolved `⚠`
   flags is **not "done."**

## The review team

Spawn these as parallel subagents, each given the draft **and** pointers to the real
sources (the data paths, the code, the companion docs, the handoffs). Each returns a
structured finding list: *location · issue · severity · suggested fix · could-I-verify-it-against-a-source (yes/no)*.

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
   - **A retracted claim stays retracted.** When a source document carries a correction, read the
     **retraction together with the original** — a draft written from the original brief silently
     re-inherits the claim the project already measured and withdrew. And **verify the REPLACEMENT
     as hard as the claim it replaces**: a correction is a new claim, and the first fix is often a
     different unsound mechanism that the same figure's own numbers refute.
2. **Citation & reference validator — "DOI or Die."** For every reference or named attribution, confirm
   the work **exists** and is **correctly attributed** (web search / DOI where needed).
   **Zero tolerance** for fabricated or guessed bibliographic metadata. Flag any
   "representative / placeholder / finalize-later" reference as not-yet-verified. When you
   need the paper itself, follow the **lit-cache protocol** below — check the library
   first, fetch the OA copy, flag what you can't get. Do **not** verify a claim against a
   paper you only half-remember: get the text or flag the paper.
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
     defence** — escalate it to blocking. (Incident: a deck proposed discarding footprint "islands"
     and cleared the risk with "recall unchanged". Recall was already 100% on 2 of 3 slices, and was
     scored by matching 175 tool footprints against 27 human ROIs — so a real cell knocked off its
     ROI is silently covered by a neighbouring footprint and the number cannot move. The slide's own
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
   - **Every panel must be READABLE, not merely present.** With the render open, write one sentence
     per panel saying **what a cold reader sees** ("a bright blob with a red outline inside it").
     If you cannot write that sentence, the panel is a defect — say so. The panel you could not
     explain is the finding, not the one to skip. Watch for renderings that manufacture phantom
     structure: a mask with an interior hole outlines as **two nested contours** and reads as two
     objects; a threshold contour reads as a boundary the data does not have; overlapping
     translucent masks read as a third category. (Boundary with Ship It: agent 10 asks whether the
     panel is present, labeled, and clear of its neighbours; this asks whether, having looked at it,
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
    - **Every line, marker, bracket, shaded span, arrow, and colour is identified** by an on-figure
      label or a legend. No unexplained line, no unlabeled bracket — including a line that is
      labeled in one panel and repeated unlabeled in another.
    - **No vertical lines or bars annotating a histogram** — they read as data height. Mark features
      with a distinct glyph (e.g. a down-diamond).
    - **One glyph per concept**, identical within and across panels; known-answer / ground-truth
      elements carry a **consistent glyph**.
    - **Category colours are clearly contrasting**, not a low-contrast pair.
    - **Every colour is explained by the colorbar or a legend.** A colorbar spans the full range of
      values **actually rendered** — no colour appears in the image that lies outside it. Any colour
      used as an **overlay marker** (not a value on the scale — e.g. a significant-point marker on a
      heatmap) must be in a **legend** and picked to **contrast with the colormap**, or it reads as
      an out-of-range value (a red dot on a parula map topping out at yellow reads as "off the top
      of the scale" unless legended and edge-outlined).
      - **A colour key must render IN its colours, adjacent to what it explains, at body size.** A
        key that names colours in plain grey body text ("magenta = footprint, red = manual ROI"), or
        that sits in the footer / source line beneath a paragraph, technically exists and is
        functionally absent — existence is not the check, identification is. Colour the words (or
        set a swatch), place the key next to the figure, never at source-line size. (Incident: a fix
        that removed a colliding figure title relocated its colour key into grey caption text at the
        bottom of the slide; the overlap re-check passed clean, and the PI's note was "the profiles
        need to be identified clearly — the legend is buried at the bottom of the page and lacks
        colour".)
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
- **Any distance BETWEEN STRUCTURES is edge-to-edge, never centroid-to-centroid.** Applies to prose,
  tables, captions and axis labels, not only to plots. Centroid separation exceeds the gap a reader
  pictures by roughly one structure diameter, so it silently overstates distance — measured on one
  real population, edge-to-edge 8.10 px vs centroid 15.84 px, nearly 2×. Ask of every separation
  claim: **which metric produced this number, and does the text say so?** Three traps:
  - **Overlapping structures have an edge-to-edge distance of 0 by definition.** A distance quoted
    for overlapping objects is a centroid distance wearing a disguise — require **overlap** instead
    (IoU, or intersection over the smaller object).
  - **A distance compared to a size must use the same kind of quantity.** "2–3 cell widths" derived
    by dividing a *centroid distance* by a *diameter* is a category error; it retracted a whole
    slide. Edge-to-edge on the same data gave 1.11 cell widths — adjacent, not remote.
  - **A centroid metric is legitimate as an ALGORITHMIC quantity** (an assignment cost, a
    "is this centroid inside the border" test). Flag only if the text fails to **say so at the point
    of use** and give the edge-to-edge equivalent. The two metrics **rank pairs differently** and are
    not interconvertible: on one dataset, matching by centroid proximity found ~45 % fewer pairs than
    matching by overlap, so swapping the metric changes results, not wording.
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
- Surface residual `⚠` flags **prominently** in the delivery message.

## Output contract

Deliver **(1)** the corrected document and **(2)** a 3–6 line review report: dimensions
checked, issues found / fixed, and any remaining `⚠` flags. If nothing survived review,
say so plainly — do not manufacture findings to look thorough.

---

## Appendix — example incidents (why each rule exists)

These are the concrete failures that motivated the rules above. They come from the
calcium-imaging analysis project the murderboard grew out of; they are **illustrations**,
not part of the process. Keep them because a rule with its scar attached is easier to take
seriously than a rule stated in the abstract.

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
  significant-peak overlay read as an out-of-range colour because the parula colorbar topped out at
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
  retracted ("neighbour centres 7-15 px apart"; the note said *do not re-inherit it*) was reproduced in
  a new draft because the author read the original brief rather than the correction. The first fix then
  replaced it with a *different* unsound mechanism that the same slide's own number refuted. Lesson:
  when a source document carries a retraction, review the retraction and the original together — and
  re-verify the REPLACEMENT claim as hard as the one it replaced.
- **Adversarial reviewer / "Can the alarm ring?"** (a 2026-07 pipeline deck, full team + verify pass)
  — a deck proposed discarding fragmented-footprint "islands" and cleared the obvious risk (that the
  islands are real cells) with "recall unchanged". The review noticed recall was **saturated at 100%
  on 2 of 3 slices** but stopped there. The sharper defect was structural: recall matched **175 tool
  footprints against 27 human ROIs**, so a real cell knocked off its ROI is covered by a neighbouring
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
  correctly flagged, and fixed by **deleting the title** and moving its colour key into grey caption
  text at the bottom of the slide. The verify pass re-ran the overlap check, which passed. Nothing
  checked whether the legend was still legible; the shipped slide identified its colours in
  uncoloured 12 pt grey below a paragraph. The fix created the defect the review then missed.
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

## The core principle

**Every sentence must be EITHER (a) verifiable against a real source — the data, the
code, a store, a prior result, or a checked citation — OR (b) explicitly flagged as
unverified/assumed (`⚠`).** No unsourced factual or quantitative claim ships unflagged.
No fabricated or approximate citation. No internal contradiction. No filler.

## The process

0. **Preflight — confirm the process itself is current.** This file is usually **vendored** into a
   consumer repo, where it drifts behind its canonical source. Before running, verify THIS copy is up
   to date with upstream — compare its vendored stamp/commit against the canonical repo's HEAD (search
   the known repo locations if the source isn't obvious) and **re-vendor first if it is behind.** A
   review run against a stale process is itself a slop defect: it silently omits rules the process has
   already learned. (This step exists because a consumer shipped a slide-overlap defect using a
   vendored copy that predated the slide-overlap rule.)
1. **Draft** the document.
2. **Review** — spawn the review team (below) in parallel via the Agent tool. Scale to
   stakes:
   - Substantial doc (methods, manuscript, explainer, multi-paragraph report) → **full
     team**.
   - Small doc (a caption, a one-liner, a short list) → a **single-pass self-review**
     against the same checklist. Do not burn a 5-agent fan-out on one sentence.
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
5. **Deliver** — the corrected document **plus a short review report**: which dimensions
   were checked, how many issues found and fixed, the verify-pass result, and any residual `⚠` flags
   the human must resolve before release. For a generated deliverable, state that the shipped file
   was **rebuilt after the last fix** and verified in that state. A document with unresolved `⚠`
   flags is **not "done."**

## The review team

Spawn these as parallel subagents, each given the draft **and** pointers to the real
sources (the data paths, the code, the companion docs, the handoffs). Each returns a
structured finding list: *location · issue · severity · suggested fix · could-I-verify-it-against-a-source (yes/no)*.

**Roles are split by what it COSTS to satisfy them, not by which reader they serve.** A judgment
call ("would a cold reader follow this?") can be satisfied by thinking about it; a mechanical check
("is this axis labeled?") can only be satisfied by opening the rendered file. Bundle the two into
one reviewer and its prose answer covers for the file it never opened — so every mechanical check
lives in agent **10**, whose output is a table, and every judgment call lives with the role whose
mode of thought it matches. When a rule could sit in two places, **file it once** and note the
boundary.

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
   - **A retracted claim stays retracted.** When a source document carries a correction, read the
     **retraction together with the original** — a draft written from the original brief silently
     re-inherits the claim the project already measured and withdrew. And **verify the REPLACEMENT
     as hard as the claim it replaces**: a correction is a new claim, and the first fix is often a
     different unsound mechanism that the same figure's own numbers refute.
2. **Citation & reference validator — "DOI or Die."** For every reference or named attribution, confirm
   the work **exists** and is **correctly attributed** (web search / DOI where needed).
   **Zero tolerance** for fabricated or guessed bibliographic metadata. Flag any
   "representative / placeholder / finalize-later" reference as not-yet-verified. When you
   need the paper itself, follow the **lit-cache protocol** below — check the library
   first, fetch the OA copy, flag what you can't get. Do **not** verify a claim against a
   paper you only half-remember: get the text or flag the paper.
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
5. **Line editor — "Kill Your Darlings."** Clarity and precision: undefined jargon, ambiguous sentences,
   redundancy, grammar, logical flow. Every sentence must earn its place and assert
   exactly one true thing.
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
   - **Tone.** Consistent **sentence case**; no scattered Capitals or ALL-CAPS emphasis in prose;
     if the content is a list, **format it as a list** — never smuggle list items into a title or
     legend with separators.

9. **Density & figure-first — "Show, Don't Tell."** *Spawn for any multi-slide or multi-page
   deliverable — a deck, a poster, a report.* A generated document defaults to **prose**: correct,
   complete, sourced, and unreadable at a glance. Every other role checks whether the words are
   TRUE; this one asks the question none of them is empowered to ask — **what here should be a
   picture instead?** A wall of accurate text is still a failed slide.
   - **Count first, then judge.** Report a table, one row per slide/page: **total words · largest
     single text block · carries a figure (y/n)**. The thresholds below are **conventions the
     project may tune, not researched optima** — state the ones you used. Flag: more than **40
     words** on a slide; any single text block over **60 words**; a **results or methods slide
     with no figure**; **two or more consecutive prose-only** slides.
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
    - **Every line, marker, bracket, shaded span, arrow, and colour is identified** by an on-figure
      label or a legend. No unexplained line, no unlabeled bracket — including a line that is
      labeled in one panel and repeated unlabeled in another.
    - **No vertical lines or bars annotating a histogram** — they read as data height. Mark features
      with a distinct glyph (e.g. a down-diamond).
    - **One glyph per concept**, identical within and across panels; known-answer / ground-truth
      elements carry a **consistent glyph**.
    - **Category colours are clearly contrasting**, not a low-contrast pair.
    - **Every colour is explained by the colorbar or a legend.** A colorbar spans the full range of
      values **actually rendered** — no colour appears in the image that lies outside it. Any colour
      used as an **overlay marker** (not a value on the scale — e.g. a significant-point marker on a
      heatmap) must be in a **legend** and picked to **contrast with the colormap**, or it reads as
      an out-of-range value (a red dot on a parula map topping out at yellow reads as "off the top
      of the scale" unless legended and edge-outlined).
    - **Small multiples have real inter-panel spacing.** Panels packed edge-to-edge while the page
      has wide empty margins is a defect — separate them and use the whitespace.

**When new analysis code underlies the deliverable**, add agents **6 (methods expert — RTFM)** and
**7 (reuse auditor — Reinventing the Wheel)** — they review the code path that produced the numbers, not the prose.
Skip them only when no task-specific code was written (pure prose over already-verified data).

**When the deliverable is a deck, poster, or any multi-slide / multi-page document**, add agent
**9 (density & figure-first — Show, Don't Tell)**. No other role has standing to say "this should be
a figure," so without it a deck ships as an essay in twelve parts.

### Spawn matrix

| Deliverable has… | Spawn |
|---|---|
| any document at all | **1, 3, 4, 5** (Prove It · Cross-Examiner · Reviewer 2 · Kill Your Darlings) |
| references or named attributions | **+ 2** (DOI or Die) |
| new analysis code / a specific method or library | **+ 6, 7** (RTFM · Reinventing the Wheel) |
| a non-expert audience | **+ 8** (You Lost Me) |
| multiple slides or pages | **+ 9** (Show, Don't Tell) |
| anything that renders | **+ 10** (Ship It) |

Agent **10 is never dropped for scale.** When step 2 scales a small deliverable down to a
single-pass self-review, the judgment roles collapse into one pass — the mechanical table still
runs. It is the cheapest agent in the team and the only one whose absence leaves no trace in the
output.

**For figures**, agents 1, 3, and 4 (Prove It, Cross-Examiner, Reviewer 2) adapt: does the caption match what is actually
plotted? Does the figure or its caption **overclaim**? Are the plotted numbers consistent
with the underlying data? For an **explainer or any non-expert-facing figure/slide, also add
agent 8 (naive-reader accessibility — You Lost Me)** — the reader-lost class of defect is
invisible to the rest of the team. **Agent 10 (Ship It) owns the mechanical checks**; the rows below
are spelled out in full because each has a trap in it that a one-line checklist entry loses (flag any
violation):
- **Every axis labeled with NAME and UNITS** (e.g. `time (s)`, `signal (a.u.)`). An unlabeled axis
  is a defect — flag it.
- **Any distance BETWEEN STRUCTURES is edge-to-edge, never centroid-to-centroid.** Applies to prose,
  tables, captions and axis labels, not only to plots. Centroid separation exceeds the gap a reader
  pictures by roughly one structure diameter, so it silently overstates distance — measured on one
  real population, edge-to-edge 8.10 px vs centroid 15.84 px, nearly 2×. Ask of every separation
  claim: **which metric produced this number, and does the text say so?** Three traps:
  - **Overlapping structures have an edge-to-edge distance of 0 by definition.** A distance quoted
    for overlapping objects is a centroid distance wearing a disguise — require **overlap** instead
    (IoU, or intersection over the smaller object).
  - **A distance compared to a size must use the same kind of quantity.** "2–3 cell widths" derived
    by dividing a *centroid distance* by a *diameter* is a category error; it retracted a whole
    slide. Edge-to-edge on the same data gave 1.11 cell widths — adjacent, not remote.
  - **A centroid metric is legitimate as an ALGORITHMIC quantity** (an assignment cost, a
    "is this centroid inside the border" test). Flag only if the text fails to **say so at the point
    of use** and give the edge-to-edge equivalent. The two metrics **rank pairs differently** and are
    not interconvertible: on one dataset, matching by centroid proximity found ~45 % fewer pairs than
    matching by overlap, so swapping the metric changes results, not wording.
- **Same data compared across panels → shared y-axis limits.** If panels show the same
  measurement two ways (e.g. condition A vs B), differing y-limits fake a difference via
  autoscaling — a slop bug. Deliberately different limits (full vs zoom vs detail) are allowed
  **only if explicitly marked** (asterisk on the deviating panel + a footnote that the scales
  differ). Unmarked scale changes → flag.
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
- **A label annotating a region must be anchored CLEAR of that region's border, not centred near
  it.** Text centred on a coordinate close to the edge of a patch, box or shaded span puts half its
  glyph height across the line, and renders as a strike-through. Anchor it outside the shape's
  extent (bottom-aligned above, top-aligned below) so the two cannot collide however long the string
  later grows.
- **A borrowed figure imports its owner's defects.** Reusing a panel from another deliverable
  inherits its clipping, contrast and font problems, and "it was already like that" stops being a
  defence the moment you ship it. Hold a borrowed asset to the same bar as one you made; when it
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
- Surface residual `⚠` flags **prominently** in the delivery message.

## Output contract

Deliver **(1)** the corrected document and **(2)** a 3–6 line review report: dimensions
checked, issues found / fixed, and any remaining `⚠` flags. If nothing survived review,
say so plainly — do not manufacture findings to look thorough.

---

## Appendix — example incidents (why each rule exists)

These are the concrete failures that motivated the rules above. They come from the
calcium-imaging analysis project the murderboard grew out of; they are **illustrations**,
not part of the process. Keep them because a rule with its scar attached is easier to take
seriously than a rule stated in the abstract.

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
  significant-peak overlay read as an out-of-range colour because the parula colorbar topped out at
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
  retracted ("neighbour centres 7-15 px apart"; the note said *do not re-inherit it*) was reproduced in
  a new draft because the author read the original brief rather than the correction. The first fix then
  replaced it with a *different* unsound mechanism that the same slide's own number refuted. Lesson:
  when a source document carries a retraction, review the retraction and the original together — and
  re-verify the REPLACEMENT claim as hard as the one it replaced.
- **Figure legibility and figure-vs-text collisions** (a 19-slide generated deck) — embedded plots
  authored ~20 in wide and placed ~8 in wide rendered their 11 pt labels at 5-6 pt, so the deck's own
  ">= 11 pt" rule was met only by the slide text. Raising the source fonts then CLIPPED every long
  supertitle at both ends, which the first render caught and the source did not. Separately, a
  context-window annotation centred just above a shaded patch was struck through by the patch border;
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
