#!/usr/bin/env python3
"""The two tools must agree about WHICH FILES ARE VENDORED.

`murderboard_revendor.py --example-config` tells a consumer which files to copy.
`murderboard_freshness.sh`'s STAMPED_FILES is the list the gate walks to (a) find a
stamp to compare against upstream and (b) warn that some OTHER vendored file carries a
different stamp. A file in the first list and not the second is copied into consumers
and then never checked for drift -- silently, because the gate finds some other file,
reports on that one, and exits 0.

That is not hypothetical. `tools/murderboard_revendor.py` was added to the vendored set
by #29 and never added to STAMPED_FILES, so from #29 until this test every consumer's
re-vendor tool could rot without the freshness gate saying a word -- in the gate whose
entire job is to notice exactly that.

Offline: reads two files in this repo, runs the config generator with no network.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


def stamped_files():
    """Parse the STAMPED_FILES heredoc-free block out of the shell gate."""
    text = (ROOT / "murderboard_freshness.sh").read_text(encoding="utf-8")
    m = re.search(r'^STAMPED_FILES="\n(.*?)^"', text, re.S | re.M)
    if not m:
        return None
    return [ln.strip() for ln in m.group(1).splitlines() if ln.strip()]


def config_files():
    out = subprocess.run(
        [sys.executable, str(ROOT / "murderboard_revendor.py"), "--example-config"],
        capture_output=True, text=True, check=True,
    ).stdout
    cfg = json.loads(out)
    fam = [f for f in cfg["families"] if f.get("label") == "murderboard"]
    if not fam:
        return None
    return fam[0]["files"], fam[0].get("remap", {})


print("vendored-set agreement")

sf = stamped_files()
check("STAMPED_FILES parses out of the gate", sf is not None and len(sf) > 0,
      f"({len(sf) if sf else 0} entries)")

got = config_files()
check("the example config yields a murderboard family", got is not None)

if sf and got:
    files, remap = got
    # The alarm must be able to ring: if the config ever stops listing files, this test
    # would pass vacuously. Assert it found some.
    check("the example config lists files to vendor", len(files) > 0, f"({len(files)})")

    missing = [f for f in files if f not in sf]
    check("every vendored path is known to the freshness gate", not missing,
          "" if not missing else "MISSING FROM STAMPED_FILES: " + ", ".join(missing))

    # NOT checked, deliberately: the values in `remap`. They are UPSTREAM paths, not
    # consumer paths -- murderboard_revendor.py resolves `up_rel = remap.get(rel, rel)`
    # and then runs `git show <ref>:<up_rel>` against the upstream clone. Asserting that
    # STAMPED_FILES contains them would be the exact trap the config's own comment warns
    # about ("your paths are not its paths"), and "fixing" the gate to satisfy it would
    # add this repo's layout to every consumer's drift check.
    _ = remap

print()
if FAILURES:
    print("FAILED: " + "; ".join(FAILURES))
    print("Fix by adding the named path(s) to STAMPED_FILES in murderboard_freshness.sh,")
    print("or by removing them from --example-config if they are genuinely not vendored.")
    sys.exit(1)
print("all checks pass")
