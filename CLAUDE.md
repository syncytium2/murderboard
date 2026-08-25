# CLAUDE.md — murderboard

This repo is the canonical source of the **murderboard**: an anti-slop review process
(`doc_review_process.md`), a literature tool (`fetch_paper.py`), three gates that keep the
process honest (`murderboard_freshness.sh`, `murderboard_roster.sh`,
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
> pass as a clean one.

## Practicing what it preaches

This repo's own docs are document deliverables — hold them to the same bar. Every claim in
`README.md`/`doc_review_process.md` must be verifiable or flagged; no invented provenance,
no fabricated incident. If you can't verify a historical detail, mark it, don't polish it.
