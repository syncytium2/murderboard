#!/usr/bin/env python3
"""Every tool that decodes subprocess output must NAME its encoding.

`subprocess.run(..., text=True)` with no `encoding=` decodes using the machine's LOCALE
codec. That is UTF-8 on macOS and Linux, and cp1252 on a default Windows install. Every
core murderboard file carries em-dashes and curly quotes, so the difference is not
academic.

`murderboard_revendor.py::_git` is how UPSTREAM FILE CONTENT arrives -- `git show
<ref>:<path>` -- and its result is compared against a local file read as UTF-8 and then
written back over the local one. Reported 2026-08-24 and open until this test.

WHAT CP1252 ACTUALLY DOES TO THESE FILES, which is worse than "it corrupts them", because
it does two different things and only one of them is visible:

    —  U+2014  em dash        SILENT mojibake  ->  'â€”'
    “  U+201C  open quote     SILENT mojibake  ->  'â€œ'
    ⚠  U+26A0  warning sign   SILENT mojibake  ->  'âš\\xa0'
    ”  U+201D  close quote    RAISES UnicodeDecodeError

So a Windows re-vendor CRASHES on a file containing a closing curly quote and SILENTLY
CORRUPTS one containing only em-dashes -- and the crash is the lucky outcome. The mojibake
loses the body comparison against a UTF-8 read of the local file, so every vendored file
reports as drifted even under `--check`, and a real run writes the corruption back.

`fetch_paper.py::pdf_to_text` has the same shape around `pdftotext`, and is worse still:
the `except Exception: pass` below it swallows the decode error, so a paper that extracts
fine on macOS returns an EMPTY STRING on Windows and the caller sees an empty PDF rather
than a failure.

WHY THIS IS A TEST AND NOT A CODE REVIEW NOTE. The defect is invisible on the machine of
anyone positioned to find it -- it cannot reproduce on the maintainer's laptop, on macOS
CI, or on Linux CI, because all three have a UTF-8 locale. So this test FORCES a non-UTF-8
locale (`LC_ALL=C` with Python's UTF-8 mode and C-locale coercion both switched off, which
yields US-ASCII) and runs the real function in a child interpreter under it. ASCII is a
stand-in and not the real thing -- it fails loudly where cp1252 is half-silent -- so
check 1 pins the silent-mojibake property directly at the byte level, and the AST contract
in check 5 is what holds the line for call sites nobody has written yet.

NOT fixed with PYTHONUTF8=1: an environment variable helps only where someone remembered
to set it, in every consumer and every environment, forever. That is precisely the
"fires only if someone remembers" failure this repo's gates exist to remove.

Offline: builds a throwaway git repo in a temp dir. No network.
"""
import ast
import os
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []

# The punctuation that actually appears in these files. An em-dash alone would pass a fix
# that special-cased one character. The closing curly quote is deliberately included: it
# is the one that RAISES under cp1252 rather than mojibaking, so a fix that only silenced
# exceptions would still fail here.
SAMPLE = "process — the “murderboard” — François Poincaré · 90° ⚠ ✓"

# A child interpreter whose locale codec is NOT UTF-8. Python 3.7+ coerces the C locale to
# C.UTF-8 (PEP 538) and turns on UTF-8 mode (PEP 540) by itself, either of which would
# quietly defeat this whole file, so both are switched off explicitly.
ASCII_ENV = dict(os.environ, LC_ALL="C", LANG="C",
                 PYTHONCOERCECLOCALE="0", PYTHONUTF8="0")


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


# 1. The property that makes this dangerous rather than merely wrong: for the commonest
#    character in these files, the bad decode produces valid text and no exception. Pure
#    bytes, no subprocess -- if this stops being true the rest of the file is arguing
#    about nothing.
try:
    silent = "—".encode("utf-8").decode("cp1252")
    check("cp1252 turns an em dash into valid text WITHOUT raising (so it is silent)",
          silent != "—", repr(silent))
except UnicodeDecodeError:
    check("cp1252 turns an em dash into valid text WITHOUT raising (so it is silent)",
          False, "it raised -- the silent-corruption premise no longer holds")

# 2. ...and the OTHER half, which is why "it corrupts files" undersells it: the same codec
#    hard-fails on a closing curly quote. Both outcomes are in these files.
try:
    "”".encode("utf-8").decode("cp1252")
    check("cp1252 hard-fails on a closing curly quote (the other failure mode)", False,
          "it decoded -- the two-failure-modes claim in this docstring is now wrong")
except UnicodeDecodeError:
    check("cp1252 hard-fails on a closing curly quote (the other failure mode)", True)

# 3. The forced-ASCII child must really be non-UTF-8, or check 4 passes vacuously.
probe = subprocess.run(
    [sys.executable, "-c", "import locale; print(locale.getpreferredencoding(False))"],
    capture_output=True, text=True, encoding="utf-8", env=ASCII_ENV)
codec = probe.stdout.strip().lower()
check("the test can force a non-UTF-8 locale (else this file proves nothing)",
      codec not in ("utf-8", "utf8", ""), "locale codec = " + (codec or "?"))

# 4. The real function, over real git output, under that locale.
with tempfile.TemporaryDirectory() as td:
    clone = Path(td) / "up"
    clone.mkdir()
    (clone / "doc.md").write_text(SAMPLE + "\n", encoding="utf-8")
    env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_SYSTEM=os.devnull,
               GIT_AUTHOR_NAME="t", GIT_AUTHOR_EMAIL="t@e",
               GIT_COMMITTER_NAME="t", GIT_COMMITTER_EMAIL="t@e")
    for args in (["init", "-q", "-b", "main"], ["add", "doc.md"], ["commit", "-qm", "s"]):
        subprocess.run(["git", "-C", str(clone), *args], capture_output=True, env=env)

    # Import the shipped module in the child and call _git for real, so this tracks the
    # function rather than a copy of it. The child prints ascii(), NOT repr(): Python 3's
    # repr leaves non-ASCII intact, so the child would die encoding its own stdout under
    # an ASCII locale and an unrelated stdout failure would masquerade as a decode bug.
    prog = (
        "import sys; sys.path.insert(0, %r)\n"
        "import murderboard_revendor as m\n"
        "r = m._git(%r, 'show', 'HEAD:doc.md')\n"
        "sys.stdout.write(ascii(r.stdout))\n" % (str(ROOT), str(clone))
    )
    got = subprocess.run([sys.executable, "-c", prog], capture_output=True,
                         text=True, encoding="utf-8", errors="replace", env=ASCII_ENV)

    want = ascii(SAMPLE + "\n")
    if got.returncode != 0:
        tail = (got.stderr or "").strip().splitlines()
        check("_git() returns upstream content byte-exact under a non-UTF-8 locale", False,
              tail[-1] if tail else "child exited %d" % got.returncode)
    else:
        check("_git() returns upstream content byte-exact under a non-UTF-8 locale",
              got.stdout.strip() == want,
              "" if got.stdout.strip() == want else "got " + got.stdout.strip()[:70])


# 5. The contract, for call sites nobody has written yet. Checks 1-4 police one function;
#    the next `text=True` added to these tools would reintroduce the defect untested.
#
#    Parsed with `ast`, not grepped. A regex over these files matches this repo's own
#    dense commentary -- the docstrings here and in murderboard_revendor.py both contain
#    the literal `text=True` while explaining the bug -- and a test that reports its own
#    explanation as an offender is a test people switch off.
def bare_text_calls(path):
    """Call sites that decode subprocess output without naming the codec."""
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    out = []
    for node in ast.walk(tree):
        if not isinstance(node, ast.Call):
            continue
        f = node.func
        if not (isinstance(f, ast.Attribute) and f.attr in ("run", "Popen", "check_output")
                and isinstance(f.value, ast.Name) and f.value.id == "subprocess"):
            continue
        kw = {k.arg: k.value for k in node.keywords if k.arg}
        decodes = any(
            isinstance(kw.get(n), ast.Constant) and kw[n].value is True
            for n in ("text", "universal_newlines"))
        if decodes and "encoding" not in kw:
            out.append("%s:%d" % (path.name, node.lineno))
    return out


offenders = []
for name in ("murderboard_revendor.py", "fetch_paper.py"):
    offenders += bare_text_calls(ROOT / name)

check("the shipped tools name an encoding at every decoding subprocess call",
      not offenders, "" if not offenders else "BARE: " + ", ".join(offenders))

# The alarm must be able to ring. If the walker ever stops recognising these calls it
# would report a clean sheet forever, which is the same silence the defect had.
seen = sum(1 for name in ("murderboard_revendor.py", "fetch_paper.py")
           for node in ast.walk(ast.parse((ROOT / name).read_text(encoding="utf-8")))
           if isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)
           and node.func.attr in ("run", "Popen", "check_output")
           and isinstance(node.func.value, ast.Name) and node.func.value.id == "subprocess")
check("...and it actually found the calls (not a vacuous pass)", seen >= 2, "%d call(s)" % seen)

print()
if FAILURES:
    print("FAILED: " + "; ".join(FAILURES))
    print('Fix by passing encoding="utf-8" to the subprocess call -- NOT by setting')
    print("PYTHONUTF8=1, which only helps where someone remembered to set it.")
    sys.exit(1)
print("all checks pass")
