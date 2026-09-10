#!/usr/bin/env python3
"""The library autodetect must find a shelf belonging to somebody who is not the author.

WHY THIS FILE EXISTS. `_lit_root()`'s third resolution step used to be two literal paths
naming one institution and one person. It worked perfectly on the machine it was written
for, which is exactly why nobody noticed it could not work anywhere else -- and being a
convenience fallback, it was invisible to anyone who had set $MURDERBOARD_LIT.

It failed the way an unshippable literal always fails: in a consumer. bugarach vendored
the file, its secrets gate caught the two names only after they had merged to a public
`main`, and it removed the whole tool rather than patch a vendored copy. That deleted
`_NEEDED.md` with it -- the channel a reviewer uses to ask a human for a paper it cannot
reach -- and a month later the same repo drafted a proposal whose central mechanism was
already refuted in a literature its shelf held none of.

So this test does not grep for the old names. Grepping for "the names we already removed"
only ever catches the mistake we have already made. It builds a shelf under a FICTIONAL
institution and a FICTIONAL person and asserts the tool finds it, which is the property
that was actually missing: the autodetect must match a LAYOUT, not a person.

Offline: temp dirs only, no network, no writes outside tempfile.
"""
import os
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import fetch_paper  # noqa: E402

FAILURES = []


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


def lit_root_with_home(home, **env):
    """Call _lit_root() with $HOME pointed at a fixture tree and the env vars controlled."""
    saved = {k: os.environ.get(k) for k in ("HOME", "MURDERBOARD_LIT", "IF2_LIT")}
    try:
        os.environ["HOME"] = home
        for k in ("MURDERBOARD_LIT", "IF2_LIT"):
            os.environ.pop(k, None)
        for k, v in env.items():
            os.environ[k] = v
        return fetch_paper._lit_root()
    finally:
        for k, v in saved.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


print("fetch_paper._lit_root autodetect")

# Every layout the autodetect claims to cover, each under names belonging to nobody real.
# If a spelling here stops resolving, a real person's shelf stops being found.
LAYOUTS = {
    "personal Dropbox at the home root": ("Dropbox", "01-lit"),
    "team Dropbox with a member folder": ("Fictional Institute Dropbox", "Ada Nobody", "01-lit"),
    "macOS CloudStorage mount": (
        "Library", "CloudStorage", "Dropbox-FictionalInstitute", "01-lit"),
    "macOS CloudStorage team mount": (
        "Library", "CloudStorage", "Dropbox-FictionalInstitute", "Ada Nobody", "01-lit"),
}

for label, parts in LAYOUTS.items():
    with tempfile.TemporaryDirectory() as home:
        shelf = Path(home, *parts)
        shelf.mkdir(parents=True)
        got = lit_root_with_home(home)
        check(label, got is not None and Path(got).samefile(shelf), "got %r" % (got,))

# A home with no shelf must come back None -- NOT a /tmp stand-in, which would report an
# empty library as a real one and make --have answer "you don't have it" for every paper.
with tempfile.TemporaryDirectory() as home:
    Path(home, "Documents").mkdir()
    check("no shelf anywhere -> None", lit_root_with_home(home) is None)

# A directory that merely looks like the target must not be mistaken for it: the pattern
# is anchored at $HOME and needs the `01-lit` leaf, so neither half alone is enough.
with tempfile.TemporaryDirectory() as home:
    Path(home, "Dropbox", "papers").mkdir(parents=True)
    Path(home, "01-lit-notes").mkdir()
    check("Dropbox without an 01-lit leaf -> None", lit_root_with_home(home) is None)

# The wildcards must be the tool's own. A home directory whose name contains a glob
# metacharacter is legal on every platform this runs on, and reading it as a pattern
# would make the autodetect quietly find nothing on exactly the machines it is for.
with tempfile.TemporaryDirectory() as parent:
    home = Path(parent, "home [work] * dir")
    (home / "Dropbox" / "01-lit").mkdir(parents=True)
    got = lit_root_with_home(str(home))
    check("a home directory containing glob metacharacters still resolves",
          got is not None and Path(got).samefile(home / "Dropbox" / "01-lit"),
          "got %r" % (got,))

# An explicit path always wins, and comes back exactly as given. The autodetect
# canonicalizes (a Dropbox root is reachable under several symlinked names, and the hit
# must not depend on which one globbed first); a path the operator typed is theirs.
with tempfile.TemporaryDirectory() as home:
    auto = Path(home, "Dropbox", "01-lit")
    auto.mkdir(parents=True)
    explicit = Path(home, "elsewhere")
    explicit.mkdir()
    for var in ("MURDERBOARD_LIT", "IF2_LIT"):
        got = lit_root_with_home(home, **{var: str(explicit)})
        check("$%s overrides the autodetect" % var, got == str(explicit), "got %r" % (got,))

# A symlinked alias of one shelf must resolve to the one directory, not to whichever
# spelling sorts first -- otherwise cache paths and _NEEDED.md move between runs.
with tempfile.TemporaryDirectory() as home:
    real = Path(home, "Library", "CloudStorage", "Dropbox-FictionalInstitute", "01-lit")
    real.mkdir(parents=True)
    alias_root = Path(home, "Dropbox")
    try:
        alias_root.symlink_to(real.parent, target_is_directory=True)
    except (OSError, NotImplementedError):
        print("  SKIP  symlinked alias (no symlink support here)")
    else:
        got = lit_root_with_home(home)
        check("symlinked alias resolves to the real directory",
              got == os.path.realpath(str(real)), "got %r" % (got,))

print()
if FAILURES:
    print("FAILED: " + "; ".join(FAILURES))
    sys.exit(1)
print("OK")
