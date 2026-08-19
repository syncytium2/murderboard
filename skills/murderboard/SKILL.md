---
# canonical: syncytium2/murderboard skills/murderboard/SKILL.md
# When vendoring, REPLACE this line with: vendored from https://github.com/syncytium2/murderboard @ <short-sha> — do NOT edit here; update by re-copying.
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

Consumers vendor these files to different places. Find them before anything else:

```bash
root=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
for p in docs/doc_review_process.md doc_review_process.md; do
  [ -r "$root/$p" ] && PROCESS="$root/$p" && break
done
for p in tools/murderboard_freshness.sh murderboard_freshness.sh; do
  [ -r "$root/$p" ] && FRESH="$root/$p" && break
done
for p in tools/murderboard_roster.sh murderboard_roster.sh; do
  [ -r "$root/$p" ] && ROSTER="$root/$p" && break
done
```

If `$PROCESS` is missing, **stop** and say the repo has not vendored the murderboard — do not
reconstruct the process from memory. A remembered murderboard is the thing this whole
apparatus exists to prevent.

## 1. Freshness — a HARD GATE, here, now

```bash
bash "$FRESH" --refresh --verbose ; echo "exit=$?"
```

- **exit 0** — current. Proceed.
- **exit 1 — STALE. STOP.** Re-vendor from upstream first, then start over. Do not "note it
  and continue": a review run against a stale process silently omits rules the process has
  already learned, and the report will claim coverage it did not have.
- **exit 2** — could not determine. Proceed, but the run record's `freshness:` field says
  `UNDETERMINED`, and you say so in the delivered summary.

This is deliberately **not** the same as the SessionStart freshness check. That one is an
early warning: it serves a *cached* verdict, once, at startup, for whichever worktree the
session began in. This one fires in the worktree you are actually reviewing in, at the moment
you review, with `--refresh` so it cannot serve a stale cache. Keep both.

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

Scale to stakes in *how* you run them, never in *which* ones:

- **Substantial deliverable** (methods, manuscript, explainer, deck, multi-paragraph report)
  → parallel subagents, one per role, via the Agent tool.
- **Small deliverable** (a caption, a one-liner) → a single-pass self-review that still walks
  every role's checklist in turn and still produces role 10's table.

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
- vendored:  <sha of this repo's copy>           # from step 1
- freshness: current | UNDETERMINED
- artifact:  <path> (<hash before> -> <hash after>)
- roles:     <n> of <n> run
- rounds:    <n> blind verify rounds to clean
```

Then the **role ledger** — one row per role, all of them, each with its finding count or its
"nothing to check, here is what I checked" line — followed by the findings and their
adjudications, and any residual `⚠` the human must resolve.

Finally, gate your own output:

```bash
bash "$ROSTER" check docs/reviews/<artifact-stem>_<YYYY-MM-DD>.md ; echo "exit=$?"
```

**exit 1 means a role is missing from the ledger — the run is not finished.** Either that role
never ran (run it) or it ran and left no trace (record it). Do not deliver past a failing
check; a report that cannot show all its roles is the failure mode this skill was built for.

## What to hand the human

The corrected deliverable, the path to the run record, and a short plain summary: what was
checked, what was found and fixed, how many verify rounds, and every residual `⚠`. A
deliverable with unresolved `⚠` flags is **not "done."**
