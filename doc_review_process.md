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
Agents 6–7 below cover this.

## The core principle

**Every sentence must be EITHER (a) verifiable against a real source — the data, the
code, a store, a prior result, or a checked citation — OR (b) explicitly flagged as
unverified/assumed (`⚠`).** No unsourced factual or quantitative claim ships unflagged.
No fabricated or approximate citation. No internal contradiction. No filler.

## The process

1. **Draft** the document.
2. **Review** — spawn the review team (below) in parallel via the Agent tool. Scale to
   stakes:
   - Substantial doc (methods, manuscript, explainer, multi-paragraph report) → **full
     team**.
   - Small doc (a caption, a one-liner, a short list) → a **single-pass self-review**
     against the same checklist. Do not burn a 5-agent fan-out on one sentence.
3. **Synthesize** (main thread) — consolidate findings, dedupe, rank by severity,
   adjudicate each (fix / flag-inline / no-change), and **apply** the fixes.
4. **Deliver** — the corrected document **plus a short review report**: which dimensions
   were checked, how many issues found and fixed, and any residual `⚠` flags the human
   must resolve before release. A document with unresolved `⚠` flags is **not "done."**

## The review team

Spawn these as parallel subagents, each given the draft **and** pointers to the real
sources (the data paths, the code, the companion docs, the handoffs). Each returns a
structured finding list: *location · issue · severity · suggested fix · could-I-verify-it-against-a-source (yes/no)*.

1. **Claim & data verifier.** Extract **every** factual and quantitative claim — numbers,
   statistics, sample / record IDs, parameter values, and "X does Y" statements — and
   verify each against the actual data, code, store, or prior result. Flag any claim not
   verifiable from a real source, **especially numbers and attributions**.
2. **Citation & reference validator.** For every reference or named attribution, confirm
   the work **exists** and is **correctly attributed** (web search / DOI where needed).
   **Zero tolerance** for fabricated or guessed bibliographic metadata. Flag any
   "representative / placeholder / finalize-later" reference as not-yet-verified. When you
   need the paper itself, follow the **lit-cache protocol** below — check the library
   first, fetch the OA copy, flag what you can't get. Do **not** verify a claim against a
   paper you only half-remember: get the text or flag the paper.
3. **Consistency auditor.** Cross-check **within** the document and **against companion
   docs**: counts, totals, terminology, cross-references, and figure↔text agreement. Flag
   every contradiction.
4. **Adversarial reviewer.** Read as a **hostile peer reviewer**. Attack every claim:
   overreach, unsupported leaps, conclusions the evidence does not support, missing
   caveats, and vague hand-waving. Demand the caveat wherever one is due. Also attack for
   **rigor**, not just craft — a labeled-and-consistent figure can still be soft:
   - **Undefined quantities.** Is every plotted/quoted quantity *defined*? (E.g. "how is
     mean firing rate defined?" — events ÷ window duration, say it.)
   - **Unjustified constants.** Every magic number (a bin width, a cutoff, a time
     constant, a threshold) must be **defined AND justified** on-figure/in-text. An
     unexplained constant is a defect.
   - **Fragile statistics.** A claim resting on a single **max / extreme** is suspect —
     "we saw it happen once; how often?" Demand the **frequency / distribution**, not the
     bare maximum; a one-off must be visible as a one-off.
   - **Significance in titles.** A panel title/caption should state **why the result
     matters** (its inferential purpose), not merely name the quantity plotted.
5. **Line editor.** Clarity and precision: undefined jargon, ambiguous sentences,
   redundancy, grammar, logical flow. Every sentence must earn its place and assert
   exactly one true thing.
6. **Methods / domain expert.** *Spawn whenever the deliverable rests on a specific
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
   the prose.
7. **Reuse auditor.** When the analysis code **re-implements something the project already
   does in tested production code**, flag it and check two things: (a) should the new code
   just **call the existing code** instead of duplicating it? and (b) where it does
   re-implement, does it **match the reference exactly** — same parameters, orientation,
   unit conversions, and guard clauses? Point to the canonical implementation by path/line.
   The project's own working code is the reference; the default is to reuse it, not
   re-derive it.

8. **Naive-reader accessibility.** *Spawn for any deliverable meant to be understood by a
   reader NOT already steeped in the work — an explainer, a slide deck, a figure a colleague
   must read cold.* Read each slide/panel with ZERO prior context and flag every place such a
   reader is lost. It exists because a deliverable can be every-number-correct, honest, and
   craft-clean and still be **unreadable to the audience it is for** — a gap the rest of the
   team does not cover. Checklist (rule groups):
   - **Self-contained.** Each slide/panel stands alone; **define every named method, term, and
     relative word the first time it appears there** — a relative word must name its referent
     ("secondary *to what*", "soft *relative to what*"). Define every non-obvious **unit** on the
     slide it first appears. Keep **internal code identifiers** (variable, function, field, and
     parameter names) OUT of audience-facing text — use the plain-language concept.
   - **Illustrate, don't name-drop.** Any non-trivial mechanism (a transform, a shuffle, a null
     model) is introduced **graphically**; reuse an existing illustration if the project has one.
   - **Terminology / reserved words.** Check every term against the project glossary; a reserved
     word may not be reused for a different concept; any new term is added to the glossary **in
     the same change**.
   - **Figure-craft for a naive reader.** Label panels by **letter (A/B)**, never spatial words
     ("left/right", "top/bottom"); **every line, marker, bracket, shaded span, arrow, and color
     must be identified by an on-figure label or legend** (no unexplained line, no unlabeled
     bracket); **do not annotate a histogram with vertical lines or bars** (they read as data
     height) — mark features with a distinct glyph (e.g. a down-diamond); mark known-answer /
     ground-truth elements with a **consistent glyph**; use **one glyph per concept**, identical
     within and across panels; make category colors **clearly contrasting** (not a low-contrast
     pair); axis labels state the **real quantity + units**, never a placeholder like "value".
   - **Consistency.** Any count named in prose must be **visible in the figure** (text says
     "two" → the figure shows two).
   - **Tone.** Consistent **sentence case**; no scattered Capitals or ALL-CAPS emphasis in prose;
     if the content is a list, **format it as a list** — never smuggle list items into a title or
     legend with separators.

**When new analysis code underlies the deliverable**, add agents **6 (methods expert)** and
**7 (reuse auditor)** — they review the code path that produced the numbers, not the prose.
Skip them only when no task-specific code was written (pure prose over already-verified data).

**For figures**, agents 1, 3, and 4 adapt: does the caption match what is actually
plotted? Does the figure or its caption **overclaim**? Are the plotted numbers consistent
with the underlying data? For an **explainer or any non-expert-facing figure/slide, also add
agent 8 (naive-reader accessibility)** — the reader-lost class of defect is invisible to the
rest of the team. Plus two **hard, non-negotiable figure-craft checks** (flag any violation):
- **Every axis labeled with NAME and UNITS** (e.g. `time (s)`, `dF/F_0`). An unlabeled axis
  is a defect — flag it.
- **Same data compared across panels → shared y-axis limits.** If panels show the same
  measurement two ways (e.g. condition A vs B), differing y-limits fake a difference via
  autoscaling — a slop bug. Deliberately different limits (full vs zoom vs detail) are allowed
  **only if explicitly marked** (asterisk on the deviating panel + a footnote that the scales
  differ). Unmarked scale changes → flag.

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
