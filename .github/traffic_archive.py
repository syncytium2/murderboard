#!/usr/bin/env python3
"""Append GitHub's 14-day traffic window to a CSV that keeps it.

WHY. GitHub serves clone and view counts for the LAST 14 DAYS ONLY, and keeps no history:
a day that falls out of the window is gone, and nothing anywhere records that it happened.
This repo is distributed by copying -- vendored into consumers, or installed as a plugin --
so a clone is the only event upstream can observe at all. Losing it means the project has
no idea whether anyone uses it, which is the question this script exists to answer.

WHAT THE NUMBERS ARE NOT. Read this before quoting any of them.

  * A CLONE IS NOT A USER. `actions/checkout` clones the repo on every CI run, and this
    repo runs a 3-job matrix on every push and every PR. Much of `count` is its own CI.
    `uniques` is the more honest column -- CI appears from a small pool of runner IPs --
    but it is not clean either.
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

FIELDS = ["date", "clones", "clone_uniques", "views", "view_uniques"]


def api(repo, path, token):
    req = urllib.request.Request(
        f"https://api.github.com/repos/{repo}/traffic/{path}",
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "murderboard-traffic-archive",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


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
        clones = api(args.repo, "clones", token)
        views = api(args.repo, "views", token)
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

    parent = os.path.dirname(args.out)
    if parent:
        os.makedirs(parent, exist_ok=True)
    with open(args.out, "w", newline="", encoding="utf-8") as fh:
        w = csv.DictWriter(fh, fieldnames=FIELDS)
        w.writeheader()
        for day in sorted(rows):
            w.writerow({f: rows[day].get(f, "") for f in FIELDS})

    print(f"{args.out}: {len(rows)} days on record "
          f"(this window: {clones.get('uniques', 0)} unique cloners, "
          f"{clones.get('count', 0)} clones)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
