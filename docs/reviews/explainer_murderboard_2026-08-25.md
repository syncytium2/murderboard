# Murderboard run record — `docs/murderboard-explainer.html`

**Artifact:** `docs/murderboard-explainer.html` (hand-authored HTML; the file *is* the built
deliverable, no generator)
**Branch:** `explainer-page` · **Date:** 2026-08-25
**Fingerprint before:** `47b3cb1fade33259972cf9ff2ac6a9c4c07443677f5e04c77ecbec71d0003420`
**Process copy:** identical to `origin/main` @ `5e6b299`, verified by `git diff --quiet origin/main -- doc_review_process.md`
**Freshness gate:** `murderboard_freshness.sh --refresh --verbose` → **exit 2, UNDETERMINED**.
This repo *is* the upstream, so there is no vendored copy to compare. Recorded as undetermined
rather than passed, per the skill's rule.
**Roster:** derived by `murderboard_roster.sh list` → 11 roles. Not recalled.

---

## Calibration — read before quoting this record

This review found and fixed a large number of defects. **It is not a correctness proof.** The
round-by-round table below measures how quickly reviewers stopped finding things, not whether
anything remains. Eleven roles drawn from one model share their blind spots by construction, so
"11 of 11" is coverage of angles, not eleven independent looks.

---

## Convergence — findings by severity, per round

| Round | Kind | Blocking | Major | Minor / nit |
|---|---|---:|---:|---:|
| 1 | Full panel, 11 roles in parallel | 12 | ~53 | ~60 |
| 2 | Blind re-review (reviewer shown neither findings nor fixes) | 2 | 9 | 14 |
| 3 | Blind re-review (second blind reviewer) | 1 | 4 | 10 |

Blocking + major: **65 → 11 → 5**. Severity is falling monotonically, so the escalate-to-a-human
condition was not triggered.

**Stopping reason: round cap reached (3 rounds).** Round 3's blocking finding was the absence of
this record, which this record retires; its four majors were applied. **No fourth blind round was
run, so this run is delivered as UNCONVERGED** — a capped run and a clean run must not read alike.
What that means concretely: the fixes applied after round 3 have not themselves been re-reviewed.

---

## Role ledger — all eleven, every one

| # | Role | Outcome |
|---|---|---|
| 1 | Claim & data verifier — "Prove It." | 14 findings. Built a 44-row claim ledger; ran all three gate selftests (33 assertions) rather than reading them. Caught "prose for years" (repo is five weeks old), the four-vs-three fault count, a stale provenance block, the role-2 carve-out stated without its condition, and the output contract prescribing a round count the process had retired. |
| 2 | Citation & reference validator — "DOI or Die." | 7 findings. Verified all four github URLs live, the Apache-2.0 claim, and the Zenodo DOI. Traced "kill your darlings" past Faulkner (false) to Quiller-Couch 1916, and one step further to Johnson via Boswell, stopping at an unnamed tutor. Found the page had no author, no DOI, and a review credit pinned to no version. |
| 3 | Consistency auditor — "Cross-Examiner." | 13 findings. Recomputed every count on the page. Found "three scripts" counted five different ways across the repo, a glossary header that promised words the section never used, and the third gate documented to a directory the page did not name. |
| 4 | Adversarial reviewer — "Reviewer 2." | 18 findings, 5 blocking. The most consequential role on this run: the page claimed the process "raises the floor" while the repo's own README says plainly that nothing has been measured against a baseline. Also: the roster gate reads the *report*, not the run; reviewer correlation was never disclosed; the drafter adjudicates their own review unaudited. |
| 5 | Line editor — "Kill Your Darlings." | 28 findings. Found the rhetorical tic ("an X that Y is not an X") used nine times, four phrases duplicated verbatim between the summary and the body, and the seat-05 entry — its own — the only roster row that was not a sentence. |
| 6 | Methods / domain expert — "RTFM." | 8 findings. Read all five tools before judging the page's description of them. Found `fetch_paper.py` does *not* search the library before downloading, the freshness gate's defaults are entirely murderboard-specific, and `murderboard_revendor.py` needs a config file the page never mentioned. Confirmed the CSS token graph is symmetric and complete. |
| 7 | Reuse auditor — "Reinventing the Wheel." | 18 findings. Applied its checklist rather than its title on a document with no analysis code, and returned the run's most structural finding: the page hand-maintains a roster this repo *derives and CI-gates*, and re-implements the no-Claude on-ramp in prose while `PROMPT.md` and `START-HERE.md` — the project's actual front door — go unlinked. |
| 8 | Naive-reader accessibility — "You Lost Me." | 17 findings, 4 blocking. Found the audience-split sentence had been silently deleted by an earlier edit, with dead `.thesis`/`.standfirst` CSS left behind as evidence. Established the page had no implementation path for a non-programmer. |
| 9 | Density & figure-first — "Show, Don't Tell." | 8 findings. Counted zero figures in 3,240 words and five consecutive prose-only blocks. Its central finding: the process is a *cycle* with a feedback edge and a round cap, drawn as a straight numbered list — prose cannot draw an edge that returns. |
| 10 | Build & craft gate — "Ship It." | 24-row check table, 4 FAIL. Computed WCAG contrast rather than estimating it: `--ink-faint` failed 4.5:1 in **all six** fg/bg combinations, worst case 3.08:1. Also found no `<meta charset>` on a file with 257 non-ASCII bytes, no viewport, and a 1.4px overflow at 320px masked by `overflow-x: hidden`. |
| 11 | Argument order — "Start With the Problem." | 9 findings. Read only the sequence. Found the problem and the limits each stated twice, the page's own review disclosure placed *after* the adoption ask with no nav entry, and the roster gate introduced before the report it checks. |

`murderboard_roster.sh check` was run against this file; see below.

---

## What was applied

Every blocking and major finding was applied except those recorded as residual below. The
substantive changes:

- **Provenance and counts.** "Prose for years" removed (repo is five weeks old). Fault count
  corrected to three. The whole provenance block rewritten and pointed at this record.
- **Honesty about evidence.** The README's mechanical-vs-empirical split imported: it is now
  stated on the page that whether this finds more than another approach **has never been
  measured**, that the process cannot observe its own misses, and that eleven roles from one model
  are not eleven independent looks.
- **Fidelity to the process.** Step 04 split into blind-then-follow-up in that order, with the
  three-round cap, the escalate-on-flat-severity branch, and the "moved" verdict. Output contract
  now asks for the per-round severity table and the stopping reason instead of a bare round count.
  The role-2 carve-out stated once, with its trigger.
- **The gates, described accurately.** The roster gate now says it checks that *the report accounts
  for* every role, with an explicit note that it reads the report and not the run. "Never returns a
  false fine" scoped to the two gates that hold the property. The message gate no longer credits
  itself with reading the message.
- **Tools.** `--promote` corrected (`--name`, or the filename is silently discarded), the revendor
  config step added, `--have` described as the manual step it is.
- **Accessibility and craft.** `--ink-faint` and `--warn` retuned; every text token now clears
  4.5:1 against every surface in both themes (computed minimum 4.53:1). `<meta charset>` and
  viewport added. Dead CSS removed. 320px overflow fixed.
- **Reader path.** Glossary split and moved to where the terms are first used. A signpost restored
  saying where the technical assumptions begin. `PROMPT.md` and `START-HERE.md` linked. Author,
  copyright and DOI added.
- **Figure.** An inline SVG of the review loop, showing the feedback edge from Verify back to
  Review, its cap, and the blind/follow-up ordering — the thing prose could not draw.

---

## Residual — flagged, not fixed

1. **⚠ UNCONVERGED.** Stopped at the round cap, not at a clean blind round. Round-3 fixes have not
   been re-reviewed.
2. **⚠ No `<!doctype html>` and no `<html lang>`.** The file is authored to be wrapped by a
   publisher that supplies them. Opened directly from disk it will render in quirks mode, where the
   gates table loses its inherited font. Flagged rather than fixed because adding them would break
   the publish path; the head comment no longer claims disk-rendering parity.
3. **⚠ The two-axis role matrix (role 9, F2) was not built.** Placing all eleven seats would require
   editorial judgment for the eight the process never places, and role 9 itself warned that a
   precise-looking chart on imprecise data is its own defect.
4. **⚠ The appendix incidents are internal to a private project** and cannot be audited from
   outside. The page now says so.
5. **⚠ Effectiveness is unmeasured.** No baseline, no rate. Stated on the page.
6. **Upstream, not this branch.** `doc_review_process.md`'s role-2 headline still reads pre-#30
   (tracked on #31). `README.md` says "three tools under `tools/`" and "two checks"; there are four
   and three. `murderboard_revendor.py` and `README.md` say the freshness gate holds ten
   stamp-shaped strings; recomputation gives eleven. `fetch_paper.py`'s own docstring shows the
   `--promote` form that silently discards the filename.

---

## Method and deviations

Eleven roles were spawned as parallel subagents, each instructed to read its charge from
`doc_review_process.md` rather than from a summary. Two blind rounds followed, each by a reviewer
given the artifact and its sources and explicitly told nothing about prior findings or fixes.
Role 10 re-ran mechanically after every fix round, as the process requires for rendering
deliverables.

**Deviation:** the freshness gate returned 2 rather than 0 (no vendored copy exists upstream of
itself); proceeded, as the skill permits, with the verdict recorded.
