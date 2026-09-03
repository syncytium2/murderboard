#!/usr/bin/env python3
"""Did the plugin version move FORWARD? Not merely "did it change".

    python3 .github/plugin_version_gate.py --was 0.3.0 --now 0.4.0
    python3 .github/plugin_version_gate.py --selftest

WHY THIS IS A FILE AND NOT THE `if` IT REPLACES. The gate in `ci.yml` compared the two
version strings for INEQUALITY:

    if [ "$now" = "$was" ]; then ...fail... fi
    echo "version bumped $was -> $now"

which passes a DOWNGRADE and reports it as a bump. That is not hypothetical: on 2026-09-03,
#38 merged and `main` went 0.2.0 -> 0.3.0. Every branch cut before that still said 0.2.0, so
the moment one of them re-baselined, the gate compared `now=0.2.0` against `was=0.3.0`, found
them unequal, printed **"version bumped 0.3.0 -> 0.2.0"**, and went green. PR #55 was in
exactly that state when this was found.

A downgrade is worse than the unchanged version this gate was built to catch. `claude plugin
update` keys on the number: shipping changed files under a LOWER one means no install ever
takes them, and `murderboard_freshness.sh --plugin` compares the two numbers and reports a
copy that is behind as though it were something else entirely. Both silent, both landing on
strangers — the same sentence the original gate wrote about its own failure mode, one case
short of covering it.

The bug is the standard shape for this repo: a check that verifies a PROXY (the string
changed) for the property it means to enforce (the number went up), and the proxy holds for
the failure. `--selftest` therefore keeps the old comparison as a NEGATIVE CONTROL: the
downgrade fixture must FAIL under `changed_only` and PASS under the real one, so a future
simplification back to `!=` cannot land quietly.

FAILS CLOSED on anything it cannot parse. A version that is not MAJOR.MINOR.PATCH is a
could-not-determine, and this gate's whole purpose is to refuse to say "fine" when it does
not know — the same rule the surrounding job already applies to a missing merge base.

Stdlib only. Lives in `.github/` beside `traffic_alert.py`, which keeps it OUT of the plugin
payload glob (`skills hooks commands agents .claude-plugin doc_review_process.md
fetch_paper.py murderboard_*.sh murderboard_*.py require_commit_before_message.sh`) — so
changing this gate never itself contends for a version number.
"""
import argparse
import sys

SEMVER_HELP = "versions are MAJOR.MINOR.PATCH, e.g. 0.3.1"


def parse(v):
    """(major, minor, patch) or None. None means could-not-determine, never 'equal'."""
    parts = (v or "").strip().split(".")
    if len(parts) != 3:
        return None
    out = []
    for p in parts:
        # `isdigit` and not int(): int() accepts "+1", " 1", unicode digits and "1_0",
        # any of which would order in a way nobody reading the file would predict.
        if not p.isdigit():
            return None
        out.append(int(p))
    return tuple(out)


def verdict(was, now):
    """('ok'|'unchanged'|'backwards'|'unparseable', message)."""
    a, b = parse(was), parse(now)
    if a is None or b is None:
        bad = was if a is None else now
        return "unparseable", "cannot compare versions: %r is not semver-shaped (%s)" % (
            bad, SEMVER_HELP)
    if b == a:
        return "unchanged", "the plugin payload changed but the version is still %s" % now
    if b < a:
        return "backwards", "the plugin version went BACKWARDS: %s -> %s" % (was, now)
    return "ok", "version bumped %s -> %s" % (was, now)


# The comparison this replaces, kept ONLY so the selftest can prove it fails the fixture
# that matters. Never call it for a real verdict.
def changed_only(was, now):
    return "ok" if now != was else "unchanged"


def selftest():
    fails = []

    def check(label, got, want):
        ok = got == want
        print(("  PASS  " if ok else "  FAIL  ") + label +
              ("" if ok else "   got %r want %r" % (got, want)))
        if not ok:
            fails.append(label)

    check("a normal minor bump passes", verdict("0.3.0", "0.4.0")[0], "ok")
    check("a patch bump passes", verdict("0.3.0", "0.3.1")[0], "ok")
    check("a major bump passes", verdict("0.9.9", "1.0.0")[0], "ok")
    check("an unchanged version fails", verdict("0.3.0", "0.3.0")[0], "unchanged")

    # The defect, as it actually occurred on 2026-09-03.
    check("THE BUG: 0.3.0 -> 0.2.0 is rejected", verdict("0.3.0", "0.2.0")[0], "backwards")
    check("a minor downgrade is rejected", verdict("0.4.0", "0.3.9")[0], "backwards")
    check("a patch downgrade is rejected", verdict("0.3.1", "0.3.0")[0], "backwards")
    check("a major downgrade is rejected", verdict("1.0.0", "0.9.9")[0], "backwards")

    # NEGATIVE CONTROL. The comparison this file replaces must FAIL the downgrade fixture,
    # or the fixture proves nothing and a revert to `!=` lands unnoticed.
    check("the OLD comparison PASSES the downgrade (which is the bug)",
          changed_only("0.3.0", "0.2.0"), "ok")
    check("...and the new one does not",
          verdict("0.3.0", "0.2.0")[0] != "ok", True)
    check("the old comparison agrees on the unchanged case (so this is not a rewrite)",
          changed_only("0.3.0", "0.3.0"), "unchanged")

    # Ordering is NUMERIC, not lexicographic. "0.10.0" < "0.9.0" as strings, and a repo
    # that ships ten minor versions would start rejecting every subsequent bump.
    check("0.9.0 -> 0.10.0 passes (numeric, not string, ordering)",
          verdict("0.9.0", "0.10.0")[0], "ok")
    check("0.10.0 -> 0.9.0 is still backwards", verdict("0.10.0", "0.9.0")[0], "backwards")

    # Fails closed, never 'ok'.
    for bad in ("", "0.3", "0.3.0-rc1", "v0.3.0", "0.3.x", "0. 3.0", "0.+3.0", "1_0.0.0"):
        check("unparseable %r is refused, not waved through" % bad,
              verdict("0.3.0", bad)[0], "unparseable")
    check("an unparseable BASE is refused too", verdict("nonsense", "0.4.0")[0], "unparseable")

    print()
    if fails:
        print("FAILED: " + "; ".join(fails))
        return 1
    print("all checks pass")
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--was")
    ap.add_argument("--now")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()
    if a.was is None or a.now is None:
        ap.error("--was and --now are both required")

    kind, msg = verdict(a.was, a.now)
    if kind == "ok":
        print(msg)
        return 0

    print("::error::" + msg)
    if kind == "unchanged":
        print("::error::Installs key on this number: without a bump, /plugin update is a")
        print("::error::no-op and the freshness gate compares two equal versions and says")
        print("::error::'current'. Bump it (and marketplace.json, which must match).")
    elif kind == "backwards":
        print("::error::This is usually a branch cut before someone else's bump landed:")
        print("::error::merge the base branch in, then set a number ABOVE %s." % a.was)
        print("::error::A lower number is worse than an unchanged one — /plugin update")
        print("::error::never takes the files, and nothing reports an error.")
    else:
        print("::error::Nothing is known about whether a bump was needed, so this fails")
        print("::error::closed rather than reporting a version it could not read.")
    print("::error::(marketplace.json must match plugin.json — the manifest test checks that.)")
    return 1


if __name__ == "__main__":
    sys.exit(main())
