# `metrics` — data only

This is an **orphan branch**. It shares no history with `main` and holds data files only:

| file | what it is | written by |
|---|---|---|
| `traffic.csv` | who fetches this repo | `.github/workflows/traffic.yml` on `main`, once a day |
| `review_cost.csv` | what a round of the murderboard costs, per role | `metrics/measure_review_cost.py` on `main`, by hand after a review |

**What the numbers mean, what they are not, and why they are published at all is on `main`,
in [`metrics/README.md`](../../blob/main/metrics/README.md). Read that before quoting any of
this.** The short version of each, which is the part people get wrong:

- **Most of the `clones` column is this repo's own CI**, and `clone_uniques` cannot have CI
  netted out of it, so it is not a count of people.
- `review_cost.csv` counts the **reviewers only** — the session that spawns them, reads their
  eleven reports and writes the record is not in it, so every figure is a floor. Its
  `billable_tokens` excludes cache reads, which are the larger number and are carried in their
  own column for that reason.

## Why the data is not on `main`

Two reasons, and the second is the one that decided it.

1. `main` is a protected branch requiring status checks, so the workflow's push was rejected
   (`GH006`). The fix could have been a token with write access to `main`; putting a secret
   that can write to `main` into a public repository is a worse trade than an extra branch.
2. **`main`'s history is something people read.** Its commit messages are problem statements,
   written deliberately. A daily `traffic: <date>` commit would add ~365 entries a year and
   drown them. A data series and a curated log want different branches.

## Editing this by hand

Don't. The workflow rewrites `traffic.csv` wholesale from the last 14 days GitHub will
serve, merging by date with the newest value winning. A hand edit to a day still inside that
window is silently overwritten on the next run; one to a day outside it survives and is then
indistinguishable from measured data.

`review_cost.csv` has no workflow behind it, so nothing would ever overwrite a hand edit —
which makes editing it worse, not safer. Its rows come out of subagent transcripts that are
local to one machine and get pruned, so a row nobody can regenerate is a row nobody can check.
Append to it only by running `metrics/measure_review_cost.py` while the transcripts are still
there. **A cost figure that was typed rather than measured is the exact defect this file was
added to correct** — see the last section of `main`'s [`metrics/README.md`](../../blob/main/metrics/README.md).
