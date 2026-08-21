#!/usr/bin/env python3
"""Enforce the one invariant CLAUDE.md states about fetch_paper.py:

    "fetch_paper.py has no external dependencies beyond the standard library
     (+ optional pypdf/pdftotext). Keep it that way -- a consumer must be able
     to drop it in and run it."

A consumer vendors this file and runs it. A single `import requests` added in
passing would break every consumer at import time, and nothing else in this
repo would notice. So: parse the module and require every MODULE-LEVEL import
to be stdlib.

Imports inside a function body are exempt on purpose -- that is how the optional
pypdf/pdftotext support is written, and a lazy import cannot break a consumer
that never calls the path it lives on.
"""
import ast
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET = ROOT / "fetch_paper.py"

# Documented, deliberate exceptions: optional accelerators, imported lazily.
ALLOWED_NON_STDLIB = {"pypdf"}


def main() -> int:
    if not TARGET.is_file():
        print(f"FAIL cannot find {TARGET}", file=sys.stderr)
        return 2

    try:
        stdlib = sys.stdlib_module_names
    except AttributeError:  # Python < 3.10
        print("SKIP sys.stdlib_module_names needs Python 3.10+", file=sys.stderr)
        return 0

    tree = ast.parse(TARGET.read_text(encoding="utf-8"), filename=str(TARGET))

    # Module level only: direct children of Module, not nested in a def/class.
    offenders = []
    for node in tree.body:
        if isinstance(node, ast.Import):
            names = [a.name for a in node.names]
        elif isinstance(node, ast.ImportFrom):
            # `from . import x` has no module to judge; there are no packages here.
            names = [node.module] if node.level == 0 and node.module else []
        else:
            continue
        for name in names:
            top = name.split(".")[0]
            if top in stdlib or top in ALLOWED_NON_STDLIB:
                continue
            offenders.append((node.lineno, name))

    if offenders:
        print("FAIL fetch_paper.py imports non-stdlib modules at module level:", file=sys.stderr)
        for lineno, name in offenders:
            print(f"  fetch_paper.py:{lineno}  {name}", file=sys.stderr)
        print(
            "\nA vendored copy must run on a bare interpreter. Move it inside the\n"
            "function that needs it, or add it to ALLOWED_NON_STDLIB with a reason.",
            file=sys.stderr,
        )
        return 1

    print(f"ok  fetch_paper.py: all module-level imports are stdlib "
          f"(checked against Python {sys.version_info.major}.{sys.version_info.minor})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
