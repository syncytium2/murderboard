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

**The cron time is nominal.** It asks for 04:17 UTC and GitHub has been running it 11–12
hours late. That is GitHub's scheduler under load, not a fault here, and it costs nothing:
the window is 14 days, so the archive stays lossless as long as a run lands within a
fortnight of the last one.

## Being told when it changes

A file is a record, not a notification — nobody opens a CSV on a branch each morning, so the
archive answers *what happened* and never *did anything happen*. `.github/traffic_alert.py`
answers the second question and **is silent unless one of these fires**, because a check that
speaks daily gets filtered into a folder and stops being read:

| Signal | Why it is trusted |
|---|---|
| a new **star**, **fork** or **watcher** | deliberate human acts, impossible for CI to cause |
| a **referrer that is not `github.com`** | the only signal that says *where* — someone linked to this repo somewhere |
| **more unique page viewers in a day than ever before** | the baseline of 1 is the maintainer; CI never renders a page |
| a **new high in non-CI clones** | the weakest, and labelled so where it is reported: "non-CI" excludes only this repo's own Actions jobs, and still counts the maintainer's clones, mirrors and scanners |

`clone_uniques` is deliberately **not** a trigger. It cannot have CI netted out of it, so a
rise in it is not attributable to anything, and waking someone for an uninterpretable number
is how an alert earns being ignored.

When something fires, the workflow opens an issue — GitHub emails the repo owner, so there is
no third-party mail service and no extra secret. Thresholds are high-water marks kept in
`signals.json` on the `metrics` branch, so one event is reported once rather than every day
afterwards. The first run records the baseline and stays quiet: everything is "new" on a
first run, and an alert that fires for reasons that are not events teaches the reader to
ignore the next one, which will be real.

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
