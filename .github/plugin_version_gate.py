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

IT IS NOT ONLY BRANCHES CUT TOO EARLY, and reading it that way is how a reviewer talks
themselves out of checking. What arms this is not which side of `main` a branch sits on, it is
that **the number is stale relative to a queue that keeps moving**. A branch ABOVE `main` today
is below it after two merges. Worked example, live on 2026-09-03: #49 held 0.4.0 against a
0.3.0 `main` — a genuine bump. #51 then also took 0.4.0 and merged, making `main` 0.4.0, at
which point #49 was merely *equal* and correctly blocked. #52 then took 0.5.0 and merged, and
#49's untouched, once-correct 0.4.0 became a downgrade the old gate would have reported as
`version bumped 0.5.0 -> 0.4.0`. Nobody edited #49; the queue moved underneath it. The session
that owned it had checked an hour earlier and concluded it was unexposed, which it was, then.

So the rule the humans need alongside this gate is **a deferred version is only valid against
the `main` it was chosen for** — not "watch out if you are below main". Reported by
murderboard-7a, who found it by re-checking a branch they had already declared safe.

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
import json
import subprocess
import sys

SEMVER_HELP = "versions are MAJOR.MINOR.PATCH, e.g. 0.3.1"
MANIFEST = ".claude-plugin/plugin.json"


def read_version(text, where):
    """('ok', v) | ('unreadable', why). Never conflates unreadable with absent."""
    try:
        doc = json.loads(text)
    except Exception as e:
        return "unreadable", "%s is not valid JSON (%s)" % (where, e)
    if not isinstance(doc, dict):
        return "unreadable", "%s is not a JSON object" % where
    if "version" not in doc:
        return "unreadable", "%s has no 'version' key" % where
    v = doc["version"]
    if not isinstance(v, str):
        return "unreadable", "%s has a non-string version (%r)" % (where, v)
    return "ok", v


def read_base(base, path=MANIFEST, cwd=None):
    """('absent'|'ok'|'unreadable', value-or-why) for the manifest at `base`.

    THE THREE STATES THE SHELL COLLAPSED INTO ONE. The version it replaces read `was` as:

        was=$(git show "$base:.claude-plugin/plugin.json" 2>/dev/null \\
              | python -c "...['version']" 2>/dev/null || echo "")
        if [ -z "$was" ]; then echo "...first introduction"; exit 0; fi

    Both `2>/dev/null` and the `|| echo ""` are load-bearing in the wrong direction: an
    ABSENT file, a file that is not JSON, and a file with no `version` key all arrive as
    the empty string, and all three are answered "no plugin.json on the base commit —
    first introduction" with exit 0. Only the first is that. The other two are
    could-not-determine, and the gate was asserting the one thing it had not checked.

    This is the worse direction of the two defects in that block. A downgrade at least
    printed `version bumped 0.3.0 -> 0.2.0`, which is wrong but visible to anyone reading
    the log. `first introduction` reads as NORMAL, and nobody investigates a green check
    that says the expected thing.

    The remedy is already in this step's own history: `f62acb3` gave the merge-base
    failure a distinct could-not-determine state that reports and fails CLOSED, with a
    comment saying "the other gates in this repo all have a distinct could-not-determine
    state ... because the alternative is silently shipping an unbumped plugin." That
    reasoning covered this extraction verbatim and was never applied to it.
    """
    r = subprocess.run(["git", "show", "%s:%s" % (base, path)], cwd=cwd,
                       capture_output=True, text=True, encoding="utf-8")
    # encoding is named, not inherited from the locale. Same defect as PR #55 fixed in
    # murderboard_revendor.py's _git: `text=True` alone decodes with cp1252 on Windows and
    # mojibakes silently. CI is Linux, but this file is read by people on their own machines.
    if r.returncode != 0:
        return "absent", None                     # genuinely not there — first introduction
    return read_version(r.stdout, "the manifest at %s" % base[:7])


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

    # The ABOVE-MAIN case, which reads as safe by inspection and is not. #49 held 0.4.0
    # against a 0.3.0 main (a real bump), was overtaken twice, and its untouched number
    # became a downgrade without anyone editing it. Staleness, not direction, is what arms
    # this — so the same number must be a bump, then blocked, then rejected, as main moves.
    check("0.4.0 is a real bump against a 0.3.0 main", verdict("0.3.0", "0.4.0")[0], "ok")
    check("...the SAME 0.4.0 is blocked once main reaches 0.4.0",
          verdict("0.4.0", "0.4.0")[0], "unchanged")
    check("...and is a DOWNGRADE once main reaches 0.5.0, untouched",
          verdict("0.5.0", "0.4.0")[0], "backwards")
    check("the old comparison called that last one a bump (the false green)",
          changed_only("0.5.0", "0.4.0"), "ok")
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

    # --- the three states the shell collapsed into "first introduction" ------------------
    #
    # Built against a REAL git repo, not by stubbing read_base: the bug lived in the
    # boundary between `git show`, a pipe and `|| echo ""`, and a fixture that mocks the
    # boundary away cannot see it. Reported by murderboard-7a, 2026-09-03.
    import tempfile, os
    with tempfile.TemporaryDirectory() as td:
        env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
                   GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@e",
                   GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@e")

        def commit(body):
            """Commit `body` as the manifest (or remove it when None); return the sha."""
            d = os.path.join(td, ".claude-plugin")
            os.makedirs(d, exist_ok=True)
            p = os.path.join(d, "plugin.json")
            if body is None:
                if os.path.exists(p):
                    os.remove(p)
            else:
                with open(p, "w", encoding="utf-8") as fh:
                    fh.write(body)
            subprocess.run(["git", "-C", td, "add", "-A"], capture_output=True, env=env)
            subprocess.run(["git", "-C", td, "commit", "-qm", "x", "--allow-empty"],
                           capture_output=True, env=env)
            return subprocess.run(["git", "-C", td, "rev-parse", "HEAD"],
                                  capture_output=True, text=True, encoding="utf-8",
                                  env=env).stdout.strip()

        subprocess.run(["git", "-C", td, "init", "-q", "-b", "main"],
                       capture_output=True, env=env)
        # Something else must exist, or the "absent manifest" commit has nothing in it.
        with open(os.path.join(td, "README"), "w") as fh:
            fh.write("x\n")

        sha_absent = commit(None)
        sha_corrupt = commit('{"version": 0.3.0 oops')
        sha_nokey = commit('{"name": "murderboard"}')
        sha_nonstr = commit('{"version": 30}')
        sha_good = commit('{"version": "0.3.0"}')

        # The fixture repo is not the cwd, so every read has to be told where to look.
        def rb(sha):
            return read_base(sha, ".claude-plugin/plugin.json", td)

        check("an ABSENT base manifest is 'absent' (a real first introduction)",
              rb(sha_absent)[0], "absent")
        check("THE FAIL-OPEN: CORRUPT base json is 'unreadable', not 'absent'",
              rb(sha_corrupt)[0], "unreadable")
        check("a base with NO version key is 'unreadable', not 'absent'",
              rb(sha_nokey)[0], "unreadable")
        check("a base with a NON-STRING version is 'unreadable'",
              rb(sha_nonstr)[0], "unreadable")
        check("a good base returns its version", rb(sha_good), ("ok", "0.3.0"))

        # NEGATIVE CONTROL for this defect, matching the one the downgrade fixture gets.
        # The shell it replaces answered all three of the above identically, and its
        # answer was exit 0 with "first introduction". If a future version reintroduces
        # that flattening, these must be what fails.
        def shell_equivalent(sha):
            """`git show ... 2>/dev/null | python ... 2>/dev/null || echo ""` then [ -z ]."""
            r = subprocess.run(["git", "show", "%s:.claude-plugin/plugin.json" % sha],
                               cwd=td, capture_output=True, text=True, encoding="utf-8")
            if r.returncode:
                return ""
            try:
                return json.loads(r.stdout)["version"]
            except Exception:
                return ""
        check("the OLD shell reads CORRUPT as empty -> 'first introduction' (the bug)",
              shell_equivalent(sha_corrupt), "")
        check("the OLD shell reads NO-KEY as empty -> 'first introduction' (the bug)",
              shell_equivalent(sha_nokey), "")
        check("...and it cannot tell either from a genuinely absent file",
              shell_equivalent(sha_absent), "")
        check("...so all three were one state to it, and are three to us",
              len({rb(s)[0] for s in (sha_absent, sha_corrupt, sha_good)}), 3)

    print()
    if fails:
        print("FAILED: " + "; ".join(fails))
        return 1
    print("all checks pass")
    return 0


def resolve(base, path=MANIFEST):
    """(was, now) or ('', reason) — reads both sides itself, so the shell cannot flatten them.

    Doing the reading HERE rather than in `ci.yml` is the point. The three-states-into-one
    bug existed because the extraction lived in a shell pipeline whose failure modes are
    invisible (`2>/dev/null || echo ""`) and untestable. In here every state has a name and
    a fixture.
    """
    kind, val = read_base(base, path)
    if kind == "absent":
        return "absent", None
    if kind == "unreadable":
        return "undeterminable", val
    was = val
    try:
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
    except OSError as e:
        return "undeterminable", "cannot read %s in the working tree (%s)" % (path, e)
    # `now` was read by a bare `python -c` with no error handling, so a manifest broken
    # enough to make json.load RAISE killed the step with a traceback under `set -e`
    # instead of the gate's own message. Fail-closed either way, but a step whose house
    # style is to say what it could not determine should not have one voice that doesn't.
    kind, val = read_version(text, path)
    if kind != "ok":
        return "undeterminable", val
    return was, val


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--was")
    ap.add_argument("--now")
    ap.add_argument("--base", help="commit to read the previous manifest from")
    ap.add_argument("--file", default=MANIFEST)
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args()
    if a.selftest:
        return selftest()

    if a.base:
        was, now = resolve(a.base, a.file)
        if was == "absent":
            print("no %s at %s — first introduction, nothing to bump against" % (a.file, a.base[:7]))
            return 0
        if was == "undeterminable":
            print("::error::" + now)
            print("::error::The base manifest exists but could not be read, so it is NOT a")
            print("::error::first introduction and nothing is known about whether a bump was")
            print("::error::needed. Failing closed — the same rule f62acb3 applied to a")
            print("::error::missing merge base in this step.")
            return 1
        a.was, a.now = was, now
    elif a.was is None or a.now is None:
        ap.error("pass --base, or both --was and --now")

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
