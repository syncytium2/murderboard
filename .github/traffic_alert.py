#!/usr/bin/env python3
"""Say something ONLY when the picture changes.

WHY THIS EXISTS. traffic.csv is a good record and a bad notification. Nobody opens a CSV on
a branch every morning, so a file on its own answers "what happened?" and never answers
"did anything happen?" -- which is the question actually being asked. This compares today's
reading against the last one it saw and speaks only on a change worth a person's attention.

SILENT BY DEFAULT, and that is the whole design. A check that reports every day gets filtered
into a folder and stops being read, at which point it is decoration. This one has nothing to
say on an ordinary day and exits 0 without output.

WHAT COUNTS AS A CHANGE, and why these and not others:

  * A STAR, FORK, or WATCHER. Deliberate human acts, individually rare here (all three are
    currently 0), and impossible for CI to cause. The highest-confidence signal available.
  * A REFERRER THAT IS NOT github.com. This is the one that answers WHERE, not just whether.
    A new referring domain means someone linked to this repo somewhere, and that link is the
    discovery channel -- far more actionable than a count going up.
  * MORE UNIQUE PAGE VIEWERS IN A DAY THAN EVER BEFORE. The baseline is 1, which is the
    maintainer. 2 means somebody else opened the page. CI never renders a page.
  * A NEW HIGH IN NON-CI CLONES. Deliberately the weakest of the four and labelled as such in
    the issue it raises: "non-CI" only means "not this repo's own Actions jobs". It still
    counts the maintainer's own clones, mirrors, scrapers and scanners. It fires on a new
    high-water mark rather than a fixed threshold so it calibrates itself instead of relying
    on a number somebody guessed.

WHAT IS DELIBERATELY NOT A TRIGGER: clone_uniques. It cannot have CI netted out of it (see
metrics/README.md on main), so a rise in it is not attributable to anything and alerting on
it would mean waking someone for a number that cannot be interpreted.

STATE lives in signals.json beside the CSV on the metrics branch. Comparing against stored
state rather than against yesterday's row is what keeps a single event from being reported
every day forever.

USAGE
    python3 .github/traffic_alert.py --repo owner/name --dir <metrics checkout>

Writes the updated signals.json. Prints a human-readable report to stdout ONLY when
something fired, and writes the same text to $GITHUB_OUTPUT as `body` (plus `fired=true`)
when running under Actions, so the workflow can raise an issue with it. Stdlib only.
"""
import argparse
import csv
import json
import os
import sys
import urllib.error
import urllib.request

STATE = "signals.json"


def api(repo, path, token):
    # NOT an f-string with a bare "/{path}": an empty path then leaves a trailing slash,
    # and /repos/owner/name/ is a 404 while /repos/owner/name is the repo itself.
    url = f"https://api.github.com/repos/{repo}" + (f"/{path}" if path else "")
    req = urllib.request.Request(
        url,
        headers={
            "Accept": "application/vnd.github+json",
            "Authorization": f"Bearer {token}",
            "X-GitHub-Api-Version": "2022-11-28",
            "User-Agent": "murderboard-traffic-alert",
        },
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--repo", required=True)
    ap.add_argument("--dir", required=True, help="checkout of the metrics branch")
    args = ap.parse_args()

    token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
    if not token:
        print("error: no $GH_TOKEN or $GITHUB_TOKEN", file=sys.stderr)
        return 2

    try:
        repo = api(args.repo, "", token)
        refs = api(args.repo, "traffic/popular/referrers", token)
    except urllib.error.HTTPError as e:
        print(f"error: GitHub API {e.code} {e.reason}", file=sys.stderr)
        return 2
    except urllib.error.URLError as e:
        print(f"error: could not reach GitHub: {e.reason}", file=sys.stderr)
        return 2

    csv_path = os.path.join(args.dir, "traffic.csv")
    rows = []
    if os.path.exists(csv_path):
        with open(csv_path, newline="", encoding="utf-8") as fh:
            rows = [r for r in csv.DictReader(fh)]

    def num(r, k):
        try:
            return int(r.get(k) or 0)
        except ValueError:
            return 0

    now = {
        "stars": repo.get("stargazers_count", 0),
        "forks": repo.get("forks_count", 0),
        "watchers": repo.get("subscribers_count", 0),
        "referrers": sorted({r.get("referrer", "") for r in refs if r.get("referrer")}),
        "max_view_uniques": max((num(r, "view_uniques") for r in rows), default=0),
        "max_non_ci": max((num(r, "clones") - num(r, "ci_jobs") for r in rows), default=0),
    }

    state_path = os.path.join(args.dir, STATE)
    first_run = not os.path.exists(state_path)
    was = {}
    if not first_run:
        try:
            was = json.load(open(state_path))
        except Exception:
            first_run = True

    lines = []
    if first_run:
        # Record the baseline; do not announce it. Everything is "new" on a first run, and an
        # alert that fires once for reasons that are not events teaches the reader to ignore
        # the next one, which will be real.
        print(f"{STATE}: baseline recorded, nothing reported (first run)")
    else:
        for key, label in (("stars", "star"), ("forks", "fork"), ("watchers", "watcher")):
            if now[key] > was.get(key, 0):
                d = now[key] - was.get(key, 0)
                lines.append(f"- **{d} new {label}{'s' if d > 1 else ''}** "
                             f"({was.get(key, 0)} → {now[key]})")

        fresh = [r for r in now["referrers"] if r not in was.get("referrers", [])]
        for r in fresh:
            lines.append(f"- **New referrer: `{r}`** — someone linked to this repo there. "
                         f"This is the one signal that says *where*, so it is worth following.")

        if now["max_view_uniques"] > was.get("max_view_uniques", 0):
            n = now["max_view_uniques"]
            lines.append(f"- **{n} unique page viewer{'s' if n != 1 else ''} in a day**, "
                         f"up from a previous high of {was.get('max_view_uniques', 0)}. "
                         f"The baseline of 1 is the maintainer; above that is somebody else.")

        if now["max_non_ci"] > was.get("max_non_ci", 0):
            lines.append(f"- **New high in non-CI clones: {now['max_non_ci']} in a day** "
                         f"(previous high {was.get('max_non_ci', 0)}). "
                         f"*Weakest of these signals* — \"non-CI\" only excludes this repo's "
                         f"own Actions jobs, and still counts the maintainer's own clones, "
                         f"mirrors and scanners.")

    with open(state_path, "w", encoding="utf-8") as fh:
        json.dump(now, fh, indent=2, sort_keys=True)
        fh.write("\n")

    if not lines:
        return 0

    body = ("Something changed in this repository's traffic. Raised automatically by "
            "`.github/traffic_alert.py`; it is silent unless one of these fires.\n\n"
            + "\n".join(lines)
            + "\n\nThe full series is on the [`metrics`](../../tree/metrics) branch. "
              "**Read [`metrics/README.md`](../../blob/main/metrics/README.md) before "
              "quoting any of it** — most clone traffic is this repo's own CI, and "
              "`clone_uniques` cannot have CI netted out of it at all.\n\n"
              "Close this once you have looked. It will not be raised again for the same "
              "event: the thresholds are high-water marks stored in `signals.json`.\n")
    print(body)

    # THE BODY GOES TO A FILE, NEVER THROUGH THE SHELL. It contains backticks -- `metrics`,
    # `clone_uniques`, `signals.json` -- and a workflow doing
    #     gh issue create --body "${{ steps.alert.outputs.body }}"
    # interpolates it inside double quotes, where bash executes backticked spans as command
    # substitution. That is a broken issue at best and arbitrary execution at worst, from
    # text that partly originates in referrer strings supplied by whoever links to the repo.
    # --body-file removes the shell from the path entirely.
    body_file = os.environ.get("ALERT_BODY_FILE")
    if body_file:
        with open(body_file, "w", encoding="utf-8") as fh:
            fh.write(body)

    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write("fired=true\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
