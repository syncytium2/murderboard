# The murderboard, described in detail — a briefing doc for Claude

*Written 2026-08-10. Everything in "Current state" is dated and volatile — re-verify with
`git fetch --all --prune`, `git status`, and `gh pr list` before relying on it. Everything
else describes the repo as designed and is stable until the files themselves change. All
claims here were verified against the repo's files, git history, and GitHub on the date
above; none are from memory.*

## What this project is

This repo, `syncytium2/murderboard`, is the canonical source of the **murderboard**: a
project-neutral, anti-slop review harness for document deliverables. A *murder board* is a
panel that tries to tear a thing apart before it ships, so that what survives is
trustworthy. It exists because slop ships when nobody adversarially checks
a draft against its real sources: statistics that disagree with the runs they summarize,
reference lists written from memory, counts that contradict themselves, captions that
overclaim, and plots that are internally consistent but wrong because the generating code
misused a library.

The repo is *consumed*, not imported: other projects vendor copies of its files and stamp
the commit they took. The primary consumer is **interface2**, a calcium-imaging analysis
project, which is also where the process originated — but the core files are deliberately
project-neutral, and the calcium-imaging origin survives only in the appendix of
`doc_review_process.md` and in explicit back-compat branches of `fetch_paper.py`.

Authorship, per the README: the ideas, decisions, and review are Tony's; the implementation
is Claude's. Commits before 2026-08-06 predate the enforced `Co-Authored-By` trailer and
should be assumed agent-authored unless they say otherwise.

## The five artifacts and how responsibility is split between them

**`doc_review_process.md` (837 lines)** is the process itself and the authority on *what*
gets reviewed and by whom. **`skills/murderboard/SKILL.md`** owns only *how the review is
summoned* — the steps that must not depend on being remembered. This boundary is
load-bearing and stated in `CLAUDE.md`: a new **rule** goes in the process file (a rule
placed in the skill is hidden from consumers who read the process directly); a new **step
that would otherwise be skipped** goes in the skill (call-up mechanics left in the process
file is exactly how they ended up as forgettable prose originally).

**`fetch_paper.py`** is the literature tool the reviewer roles use. It fetches open-access
papers, caches them, checks a curated library *before* downloading (`--have`), promotes
keepers into the library (`--promote`), and appends anything unreachable or paywalled to a
want-list (`--need`, and automatically on any failed fetch). It has no dependencies beyond
the Python standard library (plus optional `pypdf`/`pdftotext`) so a consumer can drop it in
and run it; keeping it that way is a standing rule. Its `IF2_LIT`/`IF2_PAPERS` env vars and
`01-lit` autodetect are the explicit interface2 back-compat branches; new machinery is
driven by `MURDERBOARD_LIT`.

**`murderboard_freshness.sh`** answers "is this consumer's vendored copy current?" by
comparing the consumer's stamp against upstream HEAD. Exit codes: 0 current, 1 stale,
2 unknown — it never returns a false "current". It is silent when current so it can run
unattended; `--hook` serves a cached answer and refreshes in a detached process so a
SessionStart hook never blocks on the network; `--selftest` proves every branch can still
fire. It is generalized beyond the murderboard itself: `--label`/`--slug`/`--clone`/`--file`
point the same gate at *any* vendoring relationship, so one tool polices every upstream a
repo vendors from. The session-protocol pair (`docs/session_protocol.md` and
`.claude/hooks/session-start.sh`) is **canonical here** as of 2026-08-21 — it originated in a
private repo and was adopted when murderboard went public, because a provenance stamp aimed
at a repo the reader cannot open is a dead end rather than a chain of custody.

**`murderboard_roster.sh`** is the coverage gate. It **derives** the role roster by parsing
`doc_review_process.md` (never recalls it from memory, so adding a role upstream propagates
to every consumer's check with no other edit) and verifies that a finished review report
accounts for **every** role. Exit codes: 0 all present, 1 a role missing, 2 unknown. It
exists because "every role runs" used to be prose: a run that fired 7 of 11 roles and a run
that fired all 11 produced reports no reader could tell apart.

**`skills/murderboard/SKILL.md`** is the Claude Code call-up. `/murderboard <artifact>` runs
the process as a sequence that cannot be half-executed: freshness gated at the moment of
review (not merely at session start), roster derived, the artifact resolved to the **built**
file rather than its generator and fingerprinted before and after, and a run record emitted
and then checked by `murderboard_roster.sh`. Consumers vendor it to
`.claude/skills/murderboard/`.

None of the five depends on another at runtime; the process doc tells reviewer agents to use
the lit tool when they need a paper, and the skill sequences the rest.

## How the process works

**Trigger:** any document deliverable — an explainer, methods/manuscript/abstract text, a
figure or its caption, a report, or a human-facing handoff. The core principle is that a
first draft is never handed over.

**Steps:** (0) *Preflight* — confirm the vendored process file itself is current
(mechanized by the freshness gate). (1) *Draft*. (2) *Review* — run the review team as
parallel subagents; **every role runs on every deliverable**; stakes scale *how* each role
runs, never *which* ones run. Each agent gets the draft plus pointers to real sources (data
paths, code, companion docs) and returns a structured finding list: location · issue ·
severity · suggested fix · could-I-verify-it-against-a-source. (3) *Synthesize* — the main
thread consolidates, dedupes, ranks by severity. (4) *Verify the fixes* — a fresh follow-up
pass re-reviews the **corrected** artifact, blind pass first. (5) *Deliver* — the corrected
document plus a summary and a **role ledger**.

**Adjudication rules:** a confirmed factual error is fixed; an unverifiable claim is flagged
inline (`⚠ VERIFY …`) — never deleted-and-hoped or replaced with a plausible guess; style
changes apply only when they improve precision; residual `⚠` flags surface prominently in
the delivery message.

**Output contract:** deliver (1) the corrected document, (2) a plain-language summary of
dimensions checked, issues found and fixed, verify rounds, and remaining flags, and (3) a
role ledger with **one row per role, all of them**, each carrying either findings or a
"no findings, and here is what I checked" line. The ledger is the only evidence the team
ran — "no findings from role 9" is worth nothing if role 9 was never spawned — and it is
checked mechanically by `murderboard_roster.sh check REPORT.md`, not by eye.

## The review team — eleven roles

Roles are split along two axes. First, **what it costs to satisfy them**: judgment calls
live with the reviewer whose mode of thought they match, while every check a script or a
render can decide lives in one role (agent 10) whose output is a table — because bundling a
mechanical check into a judgment role lets the prose answer cover for the file that was
never opened. Second, **the unit of analysis**: most roles read one slide or panel at a
time, so a defect whose unit is the whole sequence or the whole page is invisible to all of
them and needs a role whose unit matches (agents 9 and 11).

1. **Claim & data verifier — "Prove It."** Extracts every factual and quantitative claim and
   verifies each against actual data, code, or prior results. Returns a claim ledger
   (quoted value · cited source · recomputed value · verdict) and **recomputes rather than
   eyeballs**. Checks that a cited source actually *contains* the quantity quoted. Treats
   self-describing names ("X-free", "matched", "controlled") as claims. Keeps retracted
   claims retracted and verifies replacements as hard as what they replaced. Counts the
   **missing**, not just the present (how many values are blank/NA?), and when a
   deliverable *regenerates* something, diffs it against what it replaces and accounts for
   every difference including row count.
2. **Citation & reference validator — "DOI or Die."** Confirms every reference exists, says what
   is quoted, and **is the origin** — traced back to where the claim started and forward to what
   its authors did next; existence and correct attribution are only half the check. Zero
   tolerance for fabricated or guessed bibliographic metadata;
   never verifies a claim against a half-remembered paper — gets the text via the lit-cache
   protocol or flags it.
3. **Consistency auditor — "Cross-Examiner."** Cross-checks within the document and against
   companion docs: counts, totals, terminology, figure↔text agreement. Pins one canonical
   counting basis when a population can be counted several ways; requires any count named
   in prose to be visible in the figure; enforces consistent category order across figures
   and glossary discipline on terminology.
4. **Adversarial reviewer — "Reviewer 2."** Reads as a hostile peer reviewer: overreach,
   unsupported leaps, missing caveats, undefined quantities, unjustified magic numbers,
   fragile statistics resting on a single extreme rather than a distribution.
5. **Line editor — "Kill Your Darlings."** Clarity and precision: undefined jargon,
   ambiguous sentences, padding.
6. **Methods / domain expert — "RTFM."** Runs whenever the deliverable rests on a specific
   method or library: is this the *right* value/usage for the method (versus Reviewer 2's
   "is the reader told why" — same number, two lenses, filed once).
7. **Reuse auditor — "Reinventing the Wheel."** Catches analysis code that re-implements
   something the project already has.
8. **Naive-reader accessibility — "You Lost Me."** Runs for anything meant to be understood
   by a reader without the authors' context.
9. **Density & figure-first — "Show, Don't Tell."** Whole-page unit: what should have been a
   figure, and how much canvas each figure was given.
10. **Build & craft gate — "Ship It."** Every mechanical/renderable check, run against the
    **built artifact**, output as a table: labels, axis limits, overlap — including a figure
    colliding with *itself* (supertitle ink vs page edges, per-panel title collisions,
    tight-crop exports eating padding) — and the rule that **publishing is delivery**: a
    review directory, synced drive, or channel is a publication boundary and unvetted
    renders stay on the other side of it.
11. **Argument order — "Start With the Problem."** Whole-sequence unit: the order the case
    is made in.

## How the process evolves

Every rule is incident-driven: something shipped defective (or nearly did) in a consumer,
and the rule that would have caught it is filed here — in the role it belongs to, once, with
the incident recorded in the process doc's appendix. The repo's own standard applies to its
own docs: every claim in `README.md`/`doc_review_process.md` must be verifiable or flagged —
no invented provenance, no fabricated incidents; unverifiable historical detail gets marked,
not polished. All eleven merged PRs follow this pattern, e.g.: #2 sharpened roles from a
slide-deck review; #3/#4 added figure-craft and eight proposal rules plus role 11; #5–#8
mechanized the call-up and gates; #9 made distance-convention a stated convention rather
than a ban; #11 (the newest, merged 2026-08-09) added missingness-counting and
regeneration-diffs to role 1 after a ported treatment dictionary silently left 67% of
export rows unlabeled, and self-collision plus the publication-boundary rule to role 10
after a reviewer received two defective renders of the same figure on 2026-08-06.

## How a consumer adopts it

Vendor the files, stamp the commit taken, paste the drop-in paragraph from `CLAUDE.md` into
the consumer's own `CLAUDE.md`, put `murderboard_freshness.sh --hook` in a SessionStart hook
(so a stale copy announces itself instead of silently omitting rules already paid for), and
run `murderboard_roster.sh check` on every finished report. Re-vendoring is deliberate —
this repo never bumps anything for consumers; it just commits and pushes.

## Working conventions in this repo

Sessions are assumed concurrent and stateless — coordination happens only through git and
the session board (`docs/session_protocol.md`). Work happens in per-task worktrees, never as
commits on `main` in the primary checkout; feature branches are pushed promptly and merged by
PR. Shared external outputs are claimed on the session board before writing.

## Current state — derive it, do not read it here

This section used to carry a dated snapshot of branches, PR numbers and SHAs. It was wrong
within a fortnight, which is the predictable fate of volatile state written into a document
that nothing updates — and a briefing doc that is confidently stale is worse than one that
sends you to the source, because a reader has no way to tell which bullets have rotted.

Derive it instead, in this order, and trust nothing above it:

```bash
git fetch --all --prune
git log --oneline -5 origin/main
git status --short
gh pr list --state open
git worktree list
```

Everything else in this document describes the repo **as designed**, and is stable until the
files themselves change.
