# CLAUDE.md — murderboard

This repo is the canonical source of the **murderboard**: an anti-slop review process
(`doc_review_process.md`), a literature tool (`fetch_paper.py`), four gates that keep the
process honest (`murderboard_freshness.sh`, `murderboard_roster.sh`, `murderboard_prose.sh`,
`require_commit_before_message.sh`), and the call-up skill
(`skills/murderboard/SKILL.md`). It is *consumed* by other projects, which vendor copies.
See [`README.md`](README.md).

**The repo has a public website: <https://murderboard.tonydefazio.com/>.** It is served by
GitHub Pages from `main` + `/docs`, so **`docs/index.html` is live** — a push to `main` that
touches it deploys it, with no review step in between. That file is the explainer, it is the
*only* copy (two copies drift; this repo has already had that failure), and its invariants are
enforced by `tests/published_page_test.py` in CI. Do not add a second copy, and do not point
anything at `docs/murderboard-explainer.html` — that was its name before #36.

**The division of labour matters when editing.** `doc_review_process.md` is the authority on
*what* gets reviewed and by whom; the skill owns only *how the review is summoned* — the parts
that must not depend on being remembered. A new **rule** goes in the process file. A new step
that would otherwise be skipped goes in the skill. Putting a rule in the skill hides it from
consumers who read the process directly; putting call-up mechanics in the process file is how
they ended up as prose in the first place.

## If you are working IN this repo

- **This repo is for murderboard development only** — the process, the gates, the lit tool, the
  skill, the site, and their tests. Work that is not *about* the murderboard (course or workshop
  material, session plans, reviews of another project's documents, scratch notes for something
  else) belongs in its own repo. This is not tidiness. Other projects vendor from here, so
  anything committed lands in their copies, and a public history cannot be recalled once it has
  been cloned. The failure is quiet: doing foreign work in this checkout leaves no trace until
  the day something foreign gets committed.
  **This line states the rule; it does not enforce it.** Enforcement is a `PreToolUse` guard
  wired from `.claude/settings.local.json` — deliberately local and unshipped, because it encodes
  one maintainer's filing habits rather than anything about the murderboard, and it is a filename
  heuristic that catches the obvious case and nothing subtler.
- Keep every file **project-neutral.** No hardcoded paths, project names, or domain jargon
  in the core — the calcium-imaging origin lives only in the appendix of
  `doc_review_process.md` and in explicit back-compat branches of `fetch_paper.py`
  (`IF2_LIT`/`IF2_PAPERS`, the `01-lit` autodetect). New machinery is env-driven.
- `fetch_paper.py` has no external dependencies beyond the standard library (+ optional
  `pypdf`/`pdftotext`). Keep it that way — a consumer must be able to drop it in and run it.
- **`docs/index.html` loads nothing over the network** — no webfont, no script, no analytics,
  no CDN. The page says so in a comment at its own top, and the claim is what makes "renders
  the same opened from disk, air-gapped, or behind a captive portal" true. Breaking it is
  invisible on the machine of whoever breaks it, so `tests/published_page_test.py` gates it.
  If analytics is ever wanted, that is a decision to raise, not a change to slip in.
- **The page footer carries a stamp: `Born · Version · Updated`.** When you change
  `docs/index.html`, bump **Version** and set **Updated** to the date you publish. **Born is
  `2026-07-20`, the date of this repo's first commit (`4a92748`), and it does not drift** —
  `tests/published_page_test.py` pins it to a literal and fails if it moves, because a born-on
  date that can be quietly edited is just another mutable field. Versions are
  `MAJOR.MINOR.PATCH`; the site started at `0.1.0` on 2026-08-25. (This stamp is the *page's*
  version and is unrelated to the vendoring stamps below, which track upstream commits.)
  **Born has been corrected exactly once, on 2026-09-03**, from `2026-08-25` (the day the page
  first served) to the first-commit date. The rule this line used to state — "Born never
  changes" — was aimed at *silent* drift, and it does not oblige anyone to keep an
  acknowledged error: colonel_kernel and no_peak both say "Born" and both mean their first
  commit, so this page was the only stamp of the five that agreed with neither convention in
  use. A correction made deliberately, in one commit, with the reason written into
  `published_page_test.py` beside the constant, is the act the pin exists to force. A second
  correction is not a precedent this sets — **if you think Born should move again, that is a
  decision to raise, not a change to make.**
- After any change, bump nothing automatically — consumers re-vendor deliberately and stamp
  the commit they took (see README "Vendoring"). Just commit and push here.
- **This repo is PUBLIC (Apache-2.0).** Two rules follow, and neither is optional:
  - **Never write a pointer the reader cannot follow.** No paths into private sibling repos,
    no "see the postmortem in X" where X is unreachable, no instructions to vendor from a repo
    that 404s. Naming a private repo as *attribution* is fine — `colonel_kernel` reported the
    fail-open bug, and saying so costs the reader nothing. Sending them there does.
  - **The session protocol and both `.claude/hooks/` scripts are CANONICAL HERE** as of
    2026-08-21. They used to be vendored from a private repo and carried "do NOT edit here"
    stamps; those stamps are gone and the files are edited in this repo now. Consumers stamp
    `vendored from syncytium2/murderboard @ <short-sha>`.
- Anything a stranger runs on a fresh clone must actually work. `.claude/settings.json` ships
  to them too — it must not reference a machine layout or a repo only you can reach.

## The drop-in paragraph for a CONSUMER's CLAUDE.md

Paste this into a consuming project's `CLAUDE.md` (adjust the vendored paths):

> ## Document deliverables — run the murderboard first (anti-slop)
> When asked for a **document** deliverable — explainer, methods/manuscript/abstract text,
> a figure or its caption, a report, or a human-facing handoff — do **not** hand over a
> first draft. **Invoke `/murderboard <artifact>`** (the vendored skill in
> `.claude/skills/murderboard/`); it gates freshness, derives the role roster, resolves the
> **built** artifact rather than its generator, and emits a checkable run record. Without the
> skill, follow `docs/doc_review_process.md` by hand: draft, run the review team (**every role
> runs** — scale *how* you run them to stakes, never *which* ones), apply the fixes,
> **re-review the repaired artifact — blind pass first**, and deliver the corrected document
> **plus a summary and a role ledger** with any residual `⚠` flags. When an agent needs a paper,
> use `tools/fetch_paper.py` with `MURDERBOARD_LIT` set — check `--have` first, `--need`
> what you can't reach. Vendored from `syncytium2/murderboard` — put
> `tools/murderboard_freshness.sh --hook` in your SessionStart hook so a stale copy announces
> itself instead of silently omitting rules you have already paid for, and run
> `tools/murderboard_roster.sh check <report>` on the finished report so a dropped role cannot
> pass as a clean one. Run `tools/murderboard_prose.sh <artifact>` and **paste its output into
> role 5** — that half of the role is a search, and a search nobody ran reads exactly like a
> search that came back empty. **Every artifact this produces is ours and stays here** — the
> corrected document, the run record under `docs/reviews/`, any rule we add. Upstream is where
> the process comes from, never where our reviews go.

## Practicing what it preaches

This repo's own docs are document deliverables — hold them to the same bar. Every claim in
`README.md`/`doc_review_process.md` must be verifiable or flagged; no invented provenance,
no fabricated incident. If you can't verify a historical detail, mark it, don't polish it.
