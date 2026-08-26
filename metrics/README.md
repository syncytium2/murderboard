# metrics/

`traffic.csv` is a permanent record of a number GitHub throws away.

GitHub serves clone and view counts for the **last 14 days only** and keeps no history.
This project is distributed by copying — vendored into a consumer, or installed as a
plugin — so a fetch of the repo is the only adoption signal that exists upstream at all.
Without something writing it down daily, the entire record of whether anyone uses this is a
rolling fortnight that nobody is reading.

`.github/workflows/traffic.yml` runs `.github/traffic_archive.py` once a day and merges the
window into the CSV, newest value per date winning. To run it by hand:

```
GH_TOKEN=$(gh auth token) python3 .github/traffic_archive.py \
    --repo syncytium2/murderboard --out metrics/traffic.csv
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
