# metrics/

**The data is on the [`metrics`](../../tree/metrics) branch, not here.** This directory holds
only the explainer, because the numbers are easy to misread and should not travel without it.

`traffic.csv` is a permanent record of a number GitHub throws away.

GitHub serves clone and view counts for the **last 14 days only** and keeps no history.
This project is distributed by copying — vendored into a consumer, or installed as a
plugin — so a fetch of the repo is the only adoption signal that exists upstream at all.
Without something writing it down daily, the entire record of whether anyone uses this is a
rolling fortnight that nobody is reading. It is already doing its job: the series carries
**2026-08-12**, a day GitHub no longer serves.

`.github/workflows/traffic.yml` runs `.github/traffic_archive.py` once a day and merges the
window into the CSV on the `metrics` branch, newest value per date winning.

**Why a separate branch.** `main` is protected and rejected the workflow's push (`GH006`).
Handing the workflow a token that can write to `main` would put that secret in a public
repository, which is a worse trade than an extra branch — and the better reason is that
`main`'s history is a curated log of problem statements that ~365 `traffic: <date>` commits a
year would drown. The branch is **bootstrapped by hand and the workflow will not create it**:
an archive that silently restarts from empty is indistinguishable from one that was always
empty, and the discarded days cannot be recovered to tell them apart.

To run it by hand, against a checkout of the data branch:

```
git fetch origin metrics && git worktree add ../metrics origin/metrics
GH_TOKEN=$(gh auth token) python3 .github/traffic_archive.py \
    --repo syncytium2/murderboard --out ../metrics/traffic.csv
```

## Columns

| column | meaning |
|---|---|
| `date` | UTC day |
| `clones` | clone operations GitHub counted |
| `clone_uniques` | GitHub's unique-cloner count **for that day** |
| `views` | github.com page views |
| `view_uniques` | unique viewers of github.com pages |
| `ci_runs` | this repo's own Actions runs that day |
| `ci_jobs` | this repo's own Actions **jobs** that day |

Blank and zero mean different things. **Blank is "not measured"** — the Actions API could not
be read on that run. **Zero is "no CI ran that day."** They are recorded distinctly on purpose;
collapsing them would make every later reading of this file ambiguous in the direction that
flatters it.

## Read this before quoting any of it

**Most clones are this repo's own CI.** `actions/checkout` runs once per **job**, not per run,
and the `gates` workflow is four jobs — ubuntu, macos, python, lint — so a single push costs
about four clones. `pages-build-deployment` adds more. Over **2026-08-12 … 2026-08-25**:

> **349 clones, of which 236 were this repo's own CI jobs — 68%.**
> The defensible figure is **113 non-CI clones**, not 349.

That is why `ci_runs`/`ci_jobs` are columns rather than a caveat in prose. The confound is
large enough that a reader who does not subtract it is not off by a little.

**`clone_uniques` cannot be decomposed, so do not try.** CI does not collapse to one unique per
day, and it does not expand to one per job either: 136 CI checkouts on 2026-08-25 produced 46
total uniques. The ratio is not even stable — uniques per CI run fell from 3.3 to 1.28 as
volume rose, which is what runner-IP reuse looks like from outside. GitHub's deduplication key
is not observable here, so there is no honest way to net CI out of that column. It is kept
because it is the only cross-day signal there is, **not** because it is a user count.

**A plugin install is indistinguishable from a clone.** Both are a fetch of this repo. Nothing
here separates "someone installed the plugin" from "a crawler mirrored the source", and
Anthropic does not report plugin installs to a plugin's author.

**`clone_uniques` does not sum.** GitHub counts unique cloners per day; the same person on two
days is 2 down the column and 1 in GitHub's own 14-day total.

## The baseline, and what it actually says

Recorded when this file was first committed, **2026-08-26**:

| signal | 14 days |
|---|---|
| non-CI clones | 113 |
| **unique page viewers** | **1** |
| referrers | `github.com` only |
| stars / forks / watchers | 0 / 0 / 0 |

**113 non-CI clones is not 113 people.** Nobody clones a repository they have never looked at,
and exactly one human viewed this one — opening `/pulls`, `/issues`, `/pull/22`–`/25` and a
commit, which is the maintainer working, not a stranger evaluating. The realistic composition
of the remainder is mirroring services, scrapers and dependency scanners, which begin hitting a
repository as soon as it is public, plus the maintainer's own clones across worktrees, machines
and the three consumer repos. The clone ramp begins on 2026-08-21, the day this repo went
public.

So the honest reading of the baseline is **roughly zero strangers have found this project** —
which is the expected state of a repository that went public five days earlier and has never
been announced anywhere. No referrer from an aggregator, a newsletter or a social post appears
in the data, because no such link exists yet. The absence is not rejection; it is obscurity.

That is precisely why the baseline is worth committing rather than waiting for better numbers.
It is the pre-announcement reading, and it is what makes any later change attributable instead
of merely hoped for.

**These numbers are published deliberately.** A project whose entire argument is that claims
should be checkable against sources, and that overclaiming is the defect worth building a
process around, does not get to keep its own adoption figures flattering and unexamined.

---

## `review_cost.csv` — what a round of the murderboard costs

`traffic.csv` records whether anyone takes this process. `review_cost.csv` records what it
costs them when they do, because the honest answer decides whether a reader can afford it and
the process file asks for eleven roles without ever having said a price.

One row per role per recorded run. Like `traffic.csv` the data is on the
[`metrics`](../../tree/metrics) branch and the explainer is here; unlike `traffic.csv` nothing
regenerates it on a schedule, so it grows only when someone runs the tool after a review.

```
python3 metrics/measure_review_cost.py                        # print, change nothing
python3 metrics/measure_review_cost.py --csv <path>/review_cost.csv
```

It reads the `usage` block the harness stamps on every assistant turn of every subagent
transcript it can find, and sums it per role. It measures; it does not estimate, and it has no
way to fill a gap.

**Run it while the transcripts still exist.** They are local to the machine that ran the review
and the harness prunes them, so a round not measured before it ages out is not recoverable —
the same reason `traffic.csv` exists at all. That also means this file records the runs someone
*remembered* to measure, which is not a sample of anything: do not read the set of rows as the
set of reviews.

### Columns

| column | meaning |
|---|---|
| `project` | repo the review ran in, with the operator's home path stripped |
| `session` | harness session that spawned the eleven — the join key back to a transcript |
| `started` | UTC timestamp of the first agent in the fan-out |
| `role_n`, `role` | role number and slug, **blank when the run predates the compiler** |
| `turns` | assistant turns that role took |
| `output_tokens` | everything the role generated, thinking included |
| `thinking_tokens` | the subset of output that was reasoning |
| `new_input_tokens` | context written fresh into cache (`cache_creation`) |
| `cache_read_tokens` | context re-read from cache across the role's turns |
| `billable_tokens` | `input + output + cache_creation` — **cache reads excluded** |

`role_n` blank is "not identifiable", not "no role". Runs before `murderboard_agents.py`
pasted each role's block into the prompt inline and named no file, so the transcript records
which *work* was done but not which *number* did it. Guessing an order to fill the column
would invent the one fact the file is supposed to establish.

### The measured baseline — five eleven-role runs, three repos

| run | date | billable | output | cache reads |
|---|---|---|---|---|
| bugarach `74de1c4b` | 2026-08-14 | 3,141,042 | 307,079 | 36,873,622 |
| bugarach `0d964231` | 2026-08-17 | 1,786,769 | 95,099 | 10,782,927 |
| colonel-kernel `e7eea5eb` | 2026-08-22 | 1,863,469 | 230,672 | 23,582,664 |
| murderboard `79c34fe1` | 2026-08-24 | 1,700,364 | 326,839 | 30,044,901 |
| murderboard `b7620242` | 2026-08-28 | 1,597,426 | 236,512 | 26,384,348 |

**One round of eleven roles costs roughly 1.6–3.1M billable tokens**, median ~1.8M. Under the
3-round cap in `doc_review_process.md` a document that runs to the cap costs **6–13M**.

### Read this before quoting any of it

**These figures are the reviewers only.** The session that spawns the eleven, reads their
eleven reports, applies the fixes and writes the run record is not in this file, and it is not
small — reading eleven reports is the most context-heavy turn in the whole process. Every
number here is a floor.

**`billable_tokens` excludes cache reads on purpose, and they are the larger number.** The
2026-08-28 run read 26.4M tokens out of cache against 1.6M billable. Cache reads are billed at
a fraction, so folding them in overstates cost — but quoting `billable` alone hides that a
round of the murderboard moves ~28M tokens of context, which is what actually bounds how many
reviews can run at once. Both columns are in the file because either one alone misleads.

**Cost is not evenly spread across the eleven, and not by design.** In the 2026-08-28 run the
dearest role cost 1.9× the cheapest (`prove-it` 186,886 · `start-with-the-problem` 100,369). It
follows roughly how far each role went out and read — turns correlate with cost at r ≈ 0.61 in
that run, loosely enough that `ship-it` took the most turns of any role and came third on cost.
It does not follow the role's importance. **Do not use this file to decide which roles to
drop.** It says what the eleven cost, not which are worth it, and the process file's rule
stands: scale *how* you run the roles, never *which* ones. Whether this ordering holds across
runs is **not yet answerable** — only the 2026-08-28 run records which role is which, so there
is one observation, and one observation is not a pattern.

**Run-to-run variance is dominated by the artifact, not the roster.** Every run here is eleven
roles; they differ by ~2×. A per-round budget derived from one run will be wrong for the next.

### The figure this file was written to correct

On 2026-08-28 a session in this repo reported a per-role table for the `b7620242` run totalling
**833,142 tokens**, described as "eleven roles on this branch, measured", and that figure and
the ~3.3M ceiling derived from it reached a case study in a sibling teaching repo.

**No measurement produced it.** The session's transcript contains no tool call between the
question and the answer, and no tool result anywhere in it carries those numbers. They are also
not recoverable: no accounting over the eleven subagent transcripts — output, new input, cache
creation, thinking, or any sum of them — yields either the total or the per-role range it was
built from (56,615–93,270; the real per-role range is 100,369–186,886).

The measured total for that run is **1,597,426 billable tokens, 1.92× the figure reported**, and
the 3-round ceiling is **~6.4M, not ~3.3M**. The argument the number was serving — that the cap
bounds rounds while every round re-runs all eleven, so cost is `roles × rounds` and only one
factor is capped — is unaffected, and stronger.

It is worth being exact about the failure, because it is this project's own subject. Nothing
lied and no role failed: **no role ran.** A cost claim was asserted in conversation, was
plausible, was written down, and was carried into a document that teaches other people this
process — and the only thing standing between it and a reader was that someone later went and
looked. That is the case for `metrics/measure_review_cost.py` existing rather than a number
living in prose. A figure you can regenerate is a figure that can be wrong out loud.
