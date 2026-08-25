#!/usr/bin/env python3
"""`--promote <url> "name.pdf"` must FAIL, not silently file the paper elsewhere.

`urls` is nargs="*", so a bare filename after --promote is parsed as a URL and dropped.
`promote()` then falls back to the cached title, and the paper lands in the library under
a name the operator never chose -- so the `--have` search that the whole promote/have
protocol exists to serve looks for a name that is not there. Nothing raises; the operator
sees a success line.

This file taught that exact wrong form in three places, including the hint printed at
runtime right after a successful fetch, which is the one a user copies.

Offline: argparse only, no network, no filesystem writes.
"""
import re
import subprocess
import sys
from pathlib import Path

TOOL = str(Path(__file__).resolve().parent.parent / "fetch_paper.py")
FAILURES = []


def run(args):
    return subprocess.run([sys.executable, TOOL] + args, capture_output=True, text=True)


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


print("fetch_paper --promote argument handling")

# 1. The wrong form must be refused, and must say what to type instead.
r = run(["--promote", "https://example.org/p", "Author 2020 title.pdf"])
check("bare filename after --promote is refused", r.returncode != 0, f"(rc={r.returncode})")
check("the refusal names --name", "--name" in r.stderr)
check("the refusal shows the corrected command", "did you mean" in r.stderr)

# 2. The alarm must be able to stay silent when it should: the correct form must parse.
#    It will fail later for want of a library, but NOT with an argument error.
r = run(["--promote", "https://example.org/p", "--name", "Author 2020 title.pdf"])
combined = r.stdout + r.stderr
check("the --name form is not an argument error",
      "did you mean" not in combined and "--promote takes one reference" not in combined,
      f"(rc={r.returncode})")
check("it gets past argparse to the real work",
      "NOT IN CACHE" in combined or "LIBRARY NOT FOUND" in combined,
      "(reaches promote(), which then reports the missing cache entry or library)")

# 3. No surviving documentation teaches the broken form. A doc string that shows
#    `--promote <ref> "file.pdf"` is how this defect propagated in the first place.
src = Path(TOOL).read_text(encoding="utf-8").splitlines()
# The broken shape precisely: --promote, a reference token, then a QUOTED token, with no
# --name between them. Prose that merely mentions `--promote` and happens to contain a
# quote later on the line is not it -- a looser pattern flagged two such lines and would
# have been switched off, which is how a check stops being a check.
BROKEN = re.compile(r'--promote\s+\S+\s+"')
offenders = [f"{i}: {ln.strip()[:70]}" for i, ln in enumerate(src, 1)
             if BROKEN.search(ln) and "--name" not in ln and "error(" not in ln]
check("no doc string still shows the broken form", not offenders,
      "" if not offenders else " | ".join(offenders))

print()
if FAILURES:
    print("FAILED: " + "; ".join(FAILURES))
    sys.exit(1)
print("all checks pass")
