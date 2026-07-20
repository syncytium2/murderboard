# CLAUDE.md — murderboard

This repo is the canonical source of the **murderboard**: an anti-slop review process
(`doc_review_process.md`) and a literature tool (`fetch_paper.py`). It is *consumed* by
other projects, which vendor copies of those two files. See [`README.md`](README.md).

## If you are working IN this repo

- Keep both files **project-neutral.** No hardcoded paths, project names, or domain jargon
  in the core — the calcium-imaging origin lives only in the appendix of
  `doc_review_process.md` and in explicit back-compat branches of `fetch_paper.py`
  (`IF2_LIT`/`IF2_PAPERS`, the `01-lit` autodetect). New machinery is env-driven.
- `fetch_paper.py` has no external dependencies beyond the standard library (+ optional
  `pypdf`/`pdftotext`). Keep it that way — a consumer must be able to drop it in and run it.
- After any change, bump nothing automatically — consumers re-vendor deliberately and stamp
  the commit they took (see README "Vendoring"). Just commit and push here.

## The drop-in paragraph for a CONSUMER's CLAUDE.md

Paste this into a consuming project's `CLAUDE.md` (adjust the vendored paths):

> ## Document deliverables — run the murderboard first (anti-slop)
> When asked for a **document** deliverable — explainer, methods/manuscript/abstract text,
> a figure or its caption, a report, or a human-facing handoff — do **not** hand over a
> first draft. Draft it, then run the review process in `docs/doc_review_process.md`
> (scale the reviewer team to stakes), apply the fixes, and deliver the corrected document
> **plus a short review report** with any residual `⚠` flags. When an agent needs a paper,
> use `tools/fetch_paper.py` with `MURDERBOARD_LIT` set — check `--have` first, `--need`
> what you can't reach. Vendored from `syncytium2/murderboard`.

## Practicing what it preaches

This repo's own docs are document deliverables — hold them to the same bar. Every claim in
`README.md`/`doc_review_process.md` must be verifiable or flagged; no invented provenance,
no fabricated incident. If you can't verify a historical detail, mark it, don't polish it.
