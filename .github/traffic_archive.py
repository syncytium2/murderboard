#!/usr/bin/env python3
"""Append GitHub's 14-day traffic window to a CSV that keeps it.

WHY. GitHub serves clone and view counts for the LAST 14 DAYS ONLY, and keeps no history:
a day that falls out of the window is gone, and nothing anywhere records that it happened.
This repo is distributed by copying -- vendored into consumers, or installed as a plugin --
so a clone is the only event upstream can observe at all. Losing it means the project has
no idea whether anyone uses it, which is the question this script exists to answer.

WHAT THE NUMBERS ARE NOT. Read this before quoting any of them.

  * MOST CLONES ARE THIS REPO'S OWN CI. Every Actions JOB runs actions/checkout, and the
    gates workflow is four jobs (ubuntu, macos, python, lint), so one push costs about four
    clones. Measured over 2026-08-12..25: 236 CI jobs against 349 clones -- 68%. That is
    why ci_runs and ci_jobs are columns here rather than a caveat in prose: the confound is
    large enough that a reader who does not subtract it is not off by a little.

    clones - ci_jobs is the defensible number. Over that window it is 113, not 349.

  * clone_uniques CANNOT BE DECOMPOSED, so do not try. CI does not collapse to one unique
    per day, nor expand to one per job: 136 CI checkouts on 2026-08-25 produced 46 total
    uniques. The ratio is not even stable -- uniques per CI run fell from 3.3 to 1.28 as
    volume rose, which is what runner-IP reuse looks like from outside. GitHub's dedup key
    is not observable here, so there is no honest way to net CI out of this column. It is
    recorded because it is the only cross-day signal there is, NOT because it is a user
    count. Quoting it as one overstates by an unknown, large factor.

  * A PLUGIN INSTALL IS NOT DISTINGUISHABLE FROM A CLONE. Both are a fetch of this repo.
    Nothing in this data separates "someone installed the plugin" from "someone browsed
    the source", and Anthropic does not report installs to a plugin's author.

  * uniques DOES NOT SUM. GitHub counts unique cloners per day; the same person on two
    days is 2 here and 1 in GitHub's own 14-day total. Add the column and you overcount.

So this is a floor on interest and a shape over time, not a user count. Say so wherever
it gets quoted. The alternative -- publishing a number that cannot be defended -- is the
exact failure the murderboard exists to catch, and it would be embarrassing here.

USAGE
    python3 .github/traffic_archive.py --repo owner/name --out metrics/traffic.csv

Reads the token from $GH_TOKEN or $GITHUB_TOKEN. Needs push access to the repo: the
traffic API is admin-only, and a workflow's default GITHUB_TOKEN may not carry it (see
the workflow file). Exits 2 on an auth failure rather than writing a partial row -- a gap
in the record is recoverable, a row of zeros that looks like real data is not.

Rows are merged by date, newest value winning: today's counts keep growing until the day
closes, and a re-run must update that row rather than duplicate it. Stdlib only.
"""
import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request

FIELDS = ["date", "clones", "clone_uniques", "views", "view_uniques",
          "ci_runs", "ci_jobs"]


def api(repo, path, token):
    return api_raw(f"https://api.github.com/repos/{repo}/{path}", token)


def api_raw(url, token):
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "murderboard-traffic-archive",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def ci_checkouts(repo, token, since):
    """Actions runs and JOBS per day since `since` (YYYY-MM-DD).

    Jobs, not runs, is the checkout count: actions/checkout runs once per job, so a
    four-job matrix costs four clones per push. Counting runs here would understate the
    confound by ~4x, which is the whole reason this function exists.

    Returns None if the Actions API could not be read at all, and a dict otherwise -- the
    caller needs to tell those apart. A blank cell must mean "not measured" and a 0 must
    mean "no CI ran that day"; collapsing both to blank (or both to 0) makes every future
    reading of this file ambiguous in exactly the direction that flatters the numbers.
    """
    runs, page = [], 1
    try:
        while page <= 10:
            batch = api(repo, f"actions/runs?per_page=100&page={page}&created=%3E%3D{since}",
                        token).get("workflow_runs") or []
            if not batch:
                break
            runs += batch
            page += 1
    except Exception:
        return None

    per_day = {}
    for r in runs:
        day = (r.get("created_at") or "")[:10]
        if not day or day < since:
            continue
        d = per_day.setdefault(day, {"runs": 0, "jobs": 0})
        d["runs"] += 1
        try:
            d["jobs"] += api(repo, f"actions/runs/{r['id']}/jobs?per_page=100",
                             token).get("total_count", 0)
        except Exception:
            pass
    return per_day


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", required=True, help="owner/name")
    ap.add_argument("--out", required=True, help="CSV to merge into")
    args = ap.parse_args()

    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("error: no $GH_TOKEN or $GITHUB_TOKEN in the environment", file=sys.stderr)
        return 2

    try:
        clones = api(args.repo, "traffic/clones", token)
        views = api(args.repo, "traffic/views", token)
    except urllib.error.HTTPError as e:
        # 403 here almost always means the token lacks push access, not that the repo is
        # private. Name the likely cause: a silent daily failure is how this quietly stops
        # archiving and nobody notices until a year of data is missing.
        hint = " (the traffic API needs push access; a workflow's default GITHUB_TOKEN " \
               "often is not enough -- use a PAT secret)" if e.code == 403 else ""
        print(f"error: GitHub API {e.code} {e.reason}{hint}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"error: could not reach GitHub: {e.reason}", file=sys.stderr)
        return 2

    rows = {}
    if os.path.exists(args.out):
        with open(args.out, newline="", encoding="utf-8") as fh:
            for row in csv.DictReader(fh):
                if row.get("date"):
                    rows[row["date"]] = row

    def merge(payload, key, count_col, uniq_col):
        for point in payload.get(key) or []:
            day = (point.get("timestamp") or "")[:10]
            if not day:
                continue
            row = rows.setdefault(day, {f: "" for f in FIELDS})
            row["date"] = day
            row[count_col] = str(point.get("count", 0))
            row[uniq_col] = str(point.get("uniques", 0))

    merge(clones, "clones", "clones", "clone_uniques")
    merge(views, "views", "views", "view_uniques")

    # The CI confound, measured on the same days rather than assumed. Only for days the
    # traffic window still covers -- older rows keep whatever was recorded when they were
    # current, and back-filling them from a shorter Actions history would silently rewrite
    # measurements with worse ones.
    days = sorted(rows)
    window = {d for d in (p.get("timestamp", "")[:10] for p in clones.get("clones") or []) if d}
    if days:
        ci = ci_checkouts(args.repo, token, days[0])
        if ci is not None:
            # Only days the traffic window still covers. Older rows keep what was recorded
            # when they were current; back-filling them from a shorter Actions history
            # would silently rewrite real measurements with worse ones.
            for day in window:
                if day in rows:
                    got = ci.get(day, {"runs": 0, "jobs": 0})
                    rows[day]["ci_runs"] = str(got["runs"])
                    rows[day]["ci_jobs"] = str(got["jobs"])

    parent = os.path.dirname(args.out)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        for day in sorted(rows):
            w.writerow({f: rows[day].get(f, "") for f in FIELDS})

    # Report the DEFENSIBLE number, not the flattering one. Printing the raw clone total
    # here is how it ends up quoted somewhere with the caveat left behind.
    jobs = sum(int(r.get("ci_jobs") or 0) for r in rows.values())
    total = clones.get("count", 0)
    print(f"{args.out}: {len(rows)} days on record")
    print(f"  window: {total} clones, of which {jobs} were this repo's own CI jobs "
          f"-> {total - jobs} non-CI")
    print(f"  clone_uniques is recorded but NOT decomposable; do not quote it as users")
    return 0


if __name__ == "__main__":
    sys.exit(main())
