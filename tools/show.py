#!/usr/bin/env python3
# vendored from armory @ 9e62f10 -- do NOT edit here; edit the canonical original (armory tools/show.py) and re-copy.
"""show — put a file where the human will actually see it, and say where it went.

THE FAILURE THIS EXISTS TO END
------------------------------
The agent file-send channel does not reach the user in the VS Code extension, and it
**returns success anyway**. Measured in this repo on 2026-09-01: `display=render` with an
SVG and `display=attach` with plain text were both sent, both returned
`1 file delivered to user.`, and neither produced anything on screen. Upstream:
anthropics/claude-code#76739 — open, `has repro`, labelled macos + windows + vscode, no
maintainer response, filed at CLI 2.1.207 and still failing at extension 2.1.252.

That is the estate's "can the alarm ring?" family: a check that reports success while
doing nothing. A bugarach session narrated **six** figures as seen across a long working
session; the user only found out because he opened a deployed site himself. The session
briefing gate — *"a visual finding? render the figure and show it"* — was satisfied every
time by a call that did nothing, so nothing failed anywhere in that loop.

WHY A PATH AND NOT A FILE
-------------------------
The fix is not a better pipe. It is an artefact that persists somewhere the user already
looks, plus **the absolute path printed as text**. `open` returning 0 proves the launcher
started, exactly as little as `1 file delivered` proved. The difference is that the file
is still there afterwards, so "I showed you X" is a claim the user can contradict. A
gate resting on this one is falsifiable; a gate resting on the send channel is not.

Never say a figure was shown on the strength of a call returning success. Print the path.

WHERE IT GOES
-------------
`<dropbox>/darkroom/<project>/` — the convention already in use by bugarach, downLow,
casebook, constellation and crossstream_memo, and the target of interface2's
`if2_darkroom()` (102 callers). haruspex/tools/hx_paths.py says the rule outright:
*"Never write a figure to a scratch or temp path: a human has to find it."*

THE ROOT IS RESOLVED, NEVER SPELLED
-----------------------------------
`dropbox_member_root()` is downLow/tools/data_root.py's, unchanged in behaviour: it reads
Dropbox's own `info.json`, which names the real local path, so the macOS
cloud-mount-vs-symlink distinction never has to be reasoned about and Windows needs no
second branch. Business account first — that is the one holding darkroom.

⚠ This matters beyond convenience. The member folder contains the user's name. **All 26
of the files armory flags as carrying a personal path are re-derivations of this
resolver that spelled it out instead of reading it** — including three copies inside
interface2 alone (`export_response_ratios.py`, `export_mean_sd_proportions.py`,
`export_stats_frame.py`, each building the root from `Path.home()` and two literal
folder names), and `fetch_paper.py`, which was deleted from its origin repo for exactly
that and appears here three times over. haruspex's own `dropbox()` hardcodes it via
DROPBOX_REL and is why hx_paths.py is on the list.

The literals are deliberately not quoted anywhere in this file. --selftest asserts it,
by checking this source against the root it just resolved at runtime — so the check
needs no copy of the name in order to look for it. That assertion went red on the first
run of this module, against a docstring that had spelled the folder out while explaining
not to.

So: resolve at runtime, hold it in memory, print it to the terminal, and write it to no
file. This module records the path nowhere.

USAGE
-----
    tools/show.py FIG.png                  copy to darkroom, open in the default viewer
    tools/show.py FIG.png --code           open as a tab in VS Code instead
    tools/show.py FIG.png --no-open        place it and print the path, open nothing
    tools/show.py A.png B.pdf              several at once
    tools/show.py --where                  print the darkroom dir for this project
    tools/show.py --selftest               prove the resolver and the copy work

    --project NAME    override the project folder (default: the git repo's name)
    ARMORY_DARKROOM   env override for the darkroom root, for CI or a non-standard install

EXIT STATUS
-----------
0 only if every file was placed. A failed *opener* is reported but does not fail the run:
the file is placed and the path is printed, which is the delivery that matters.
"""

from __future__ import annotations

import argparse
import json
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path

# --- the resolver: downLow/tools/data_root.py, behaviour unchanged -------------


def _info_json_candidates() -> list[Path]:
    home = Path.home()
    out = [home / ".dropbox" / "info.json"]
    for var in ("APPDATA", "LOCALAPPDATA"):
        base = os.environ.get(var)
        if base:
            out.append(Path(base) / "Dropbox" / "info.json")
    return out


def dropbox_member_root() -> Path | None:
    """The member folder, read from Dropbox's own info.json rather than guessed.

    Authoritative and OS-independent in content: it names the real local path, so the
    macOS symlink-vs-cloud-mount distinction never has to be reasoned about here.
    Prefers the business/team account, which is the one holding darkroom.
    """
    for info in _info_json_candidates():
        try:
            blob = json.loads(info.read_text(encoding="utf-8"))
        except Exception:
            continue
        for key in ("business", "personal"):
            path = (blob.get(key) or {}).get("path")
            if path and Path(path).is_dir():
                return Path(path)
    return None


def project_name(override: str | None = None) -> str:
    """The repo this is running in. Derived, so a consumer vendors this file unchanged.

    session-start.sh is self-configuring for the same reason and is the model here: a
    tool that must be edited per repo is a tool that drifts per repo.
    """
    if override:
        return override
    try:
        top = subprocess.run(["git", "rev-parse", "--show-toplevel"],
                             capture_output=True, text=True, timeout=10)
        if top.returncode == 0 and top.stdout.strip():
            return Path(top.stdout.strip()).name
    except Exception:
        pass
    return Path.cwd().name


def darkroom(project: str, create: bool = True) -> Path:
    """`<dropbox>/darkroom/<project>` — where things meant to be looked at go.

    Same convention as haruspex's darkroom() and interface2's if2_darkroom().
    """
    override = os.environ.get("ARMORY_DARKROOM")
    if override:
        root = Path(os.path.expandvars(os.path.expanduser(override)))
    else:
        member = dropbox_member_root()
        if member is None:
            raise SystemExit(
                "show: could not locate Dropbox from info.json.\n"
                f"  looked in: {', '.join(str(p) for p in _info_json_candidates())}\n"
                "  Set ARMORY_DARKROOM to the darkroom root, e.g.\n"
                "    ARMORY_DARKROOM='<dropbox>/darkroom'"
            )
        root = member / "darkroom"
    p = root / project
    if create:
        p.mkdir(parents=True, exist_ok=True)
    return p


# --- the opener ---------------------------------------------------------------


def open_with(path: Path, code: bool = False) -> tuple[bool, str]:
    """Hand the file to a viewer. Returns (launched, how) — NOT (seen, how).

    The distinction is the whole point of this module. Nothing here can confirm the
    user saw anything; only the printed path lets them tell us we are wrong.
    """
    system = platform.system()
    if code:
        exe = shutil.which("code")
        if exe:
            cmd = [exe, "-r", str(path)]
        elif system == "Darwin":
            cmd = ["open", "-a", "Visual Studio Code", str(path)]
        else:
            return False, "no `code` on PATH"
    elif system == "Darwin":
        cmd = ["open", str(path)]
    elif system == "Windows":
        try:
            os.startfile(str(path))  # type: ignore[attr-defined]
            return True, "startfile"
        except Exception as exc:
            return False, f"startfile failed: {exc}"
    else:
        exe = shutil.which("xdg-open")
        if not exe:
            return False, "no xdg-open on PATH"
        cmd = [exe, str(path)]
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
    except Exception as exc:
        return False, f"{cmd[0]} failed: {exc}"
    if r.returncode != 0:
        return False, f"{cmd[0]} exited {r.returncode}: {r.stderr.strip()[:200]}"
    return True, cmd[0]


# --- selftest -----------------------------------------------------------------


def selftest() -> int:
    """Prove the resolver and the copy work, without opening anything.

    mutation_check's rule: a selftest that cannot go red is decoration. Each check
    below fails loudly on a wrong answer rather than reporting a green run.
    """
    ok = True

    def check(label: str, cond: bool, detail: str = "") -> None:
        nonlocal ok
        ok &= cond
        print(f"  [{'PASS' if cond else 'FAIL'}] {label}{'  ' + detail if detail else ''}")

    print("show --selftest")

    member = dropbox_member_root()
    check("info.json names an existing member folder", member is not None and member.is_dir(),
          "(path not printed: it contains the user's name)")

    proj = project_name()
    check("project name derived", bool(proj), f"-> {proj}")

    try:
        dk = darkroom(proj)
        check("darkroom resolves and is writable", dk.is_dir() and os.access(dk, os.W_OK))
    except SystemExit as exc:
        check("darkroom resolves", False, str(exc).splitlines()[0])
        return 1

    probe = dk / ".show-selftest"
    try:
        probe.write_text("probe\n", encoding="utf-8")
        check("round-trips a file", probe.read_text(encoding="utf-8") == "probe\n")
    finally:
        probe.unlink(missing_ok=True)

    # Check this source against the root just resolved, so the test carries no copy of
    # the name it is looking for. Every path component of the member root is personal:
    # the account holder's name is one of them.
    source = Path(__file__).resolve().read_text(encoding="utf-8")
    leaked = sorted({part for part in (member.parts if member else ())
                     if len(part) > 3 and part not in ("Users", "home") and part in source})
    check("this source records no component of the resolved personal path",
          not leaked, f"leaked: {leaked}" if leaked else "")

    print("OK" if ok else "FAILED")
    return 0 if ok else 1


# --- main ---------------------------------------------------------------------


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(
        prog="show",
        description="Put a file in the darkroom, open it, and print where it went.")
    ap.add_argument("files", nargs="*", type=Path)
    ap.add_argument("--code", action="store_true", help="open as a tab in VS Code")
    ap.add_argument("--no-open", action="store_true", help="place and print, open nothing")
    ap.add_argument("--project", default=None, help="override the project folder name")
    ap.add_argument("--where", action="store_true", help="print the darkroom dir and exit")
    ap.add_argument("--selftest", action="store_true")
    a = ap.parse_args(argv)

    if a.selftest:
        return selftest()

    proj = project_name(a.project)

    if a.where:
        print(darkroom(proj))
        return 0

    if not a.files:
        ap.error("nothing to show (pass one or more files, or --where / --selftest)")

    dk = darkroom(proj)
    failed = 0
    for src in a.files:
        if not src.is_file():
            print(f"show: not a file: {src}", file=sys.stderr)
            failed += 1
            continue
        dest = dk / src.name
        shutil.copy2(src, dest)
        print(dest)                                   # the delivery. always printed.
        if not a.no_open:
            launched, how = open_with(dest, code=a.code)
            if not launched:
                # Not fatal: the file is placed and the path is printed, which is the
                # part the user can act on. Say so rather than implying it was seen.
                print(f"  (could not launch a viewer — {how}; open the path above)",
                      file=sys.stderr)
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
