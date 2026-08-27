# `metrics` — data only

This is an **orphan branch**. It shares no history with `main` and holds one file:
`traffic.csv`, appended once a day by `.github/workflows/traffic.yml` running on `main`.

**What the numbers mean, what they are not, and why they are published at all is on `main`,
in [`metrics/README.md`](../../blob/main/metrics/README.md). Read that before quoting any of
this.** The short version, which is the part people get wrong: **most of the `clones` column
is this repo's own CI**, and `clone_uniques` cannot have CI netted out of it, so it is not a
count of people.

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
