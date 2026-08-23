#!/usr/bin/env python3
"""murderboard_revendor — re-copy vendored files and bump their stamps, surgically.

    python3 murderboard_revendor.py --check      report what would change, touch nothing
    python3 murderboard_revendor.py              do it
    python3 murderboard_revendor.py --selftest   prove the rewrite cannot spread
    python3 murderboard_revendor.py --example-config > .murderboard-vendor.json

WHY THIS IS A FILE AND NOT THREE LINES OF SED. Because it was three lines of sed, and on
2026-08-14 the third one silently corrupted a vendored doc in a consumer repo: the
substitution ran over the WHOLE FILE and rewrote a second, unrelated stamp-shaped string
in the body, leaving the file asserting it was vendored at a commit from the wrong repo
entirely. Nothing failed and nothing warned. It was caught only because the next
re-vendor re-copied that body and repaired it — which is the same bug with its evidence
deleted.

That is not a hypothetical here. `murderboard_freshness.sh` carries **ten** stamp-shaped
strings in its body, by design: it documents and echoes the stamp format. It is also one
of the files this repo tells you to vendor. Bump its stamp with a whole-file substitution
and you rewrite ten strings you did not mean to touch, in the gate whose entire job is to
notice drift.

WHAT "SURGICAL" MEANS. Exactly one line of a file may carry a stamp:

  * line 1 normally;
  * line 2 when line 1 is a `#!` shebang, which must stay first;
  * the `"_vendored"` key's line in JSON, which has no comments.

Everything else is body and is never touched, however stamp-shaped it looks.

TWO FAILURE MODES THIS REFUSES TO HAVE:

  * **Silently doing nothing.** A stamp sitting on some *other* early line is reported as
    an error, not skipped. `murderboard_freshness.sh` scans the first five lines for a
    stamp, so a file can be perfectly gated and still be invisible to a line-1/2 writer —
    unbumped forever while the run prints success. See `--selftest` case 6.
  * **Churn.** A stamp written full-length is *current* against its own abbreviation.
    Without that, every long stamp reports as needing a bump on every run, forever, and
    noise is what gets a check switched off.

THIS FILE IS ITSELF VENDORED, WHICH DECIDES ITS DESIGN. It ships in the murderboard set
and is copied into consumers like everything else — so it has to survive its own contract:
`do not edit vendored copies in place`. That is the one difference from the two
implementations this is ported from (downLow's `tools/revendor.py`, then no_peak's
hardened version, 2026-08). Both hold their vendor set in a `FAMILIES` list *inside* the
script, which makes the script a locally-adapted file the moment it is configured — and a
locally-adapted file can never be cleanly re-copied. The tool for re-vendoring could not
re-vendor itself.

So configuration lives in `.murderboard-vendor.json` in the consuming repo, and this file
stays byte-identical to upstream. List it in its own `files` set (the example config does)
and it will re-copy and re-stamp itself along with everything else.

Stdlib only, no imports beyond it — a consumer drops it in and runs it.
"""
import argparse
import json
import os
import re
import subprocess
import sys
from pathlib import Path

STAMP_RE = re.compile(r"@ [0-9a-f]{7,40}")

# How far in `murderboard_freshness.sh` looks for a stamp. A stamp inside this window but
# NOT on the eligible line is the dangerous case: gated, yet invisible to a writer that
# only ever touches line 1/2. Kept equal to the gate's own window on purpose.
GATE_SCAN_LINES = 5

DEFAULT_CONFIG = ".murderboard-vendor.json"

EXAMPLE_CONFIG = {
    "hook": ".claude/hooks/session-start.sh",
    "families": [
        {
            "label": "murderboard",
            "slug": "syncytium2/murderboard",
            "clone": "~/Developer/murderboard",
            "ref": "origin/main",
            "files": [
                "docs/doc_review_process.md",
                "tools/murderboard_freshness.sh",
                "tools/murderboard_roster.sh",
                "tools/murderboard_revendor.py",
                "tools/fetch_paper.py",
                ".claude/skills/murderboard/SKILL.md",
            ],
            # murderboard's own layout is FLAT — no tools/ prefix, and skills/ rather than
            # .claude/skills/. Your paths are not its paths, so state the mapping rather
            # than deriving it: a prefix-stripping rule silently resolves the wrong file
            # the first time either repo rearranges.
            "remap": {
                "docs/doc_review_process.md": "doc_review_process.md",
                "tools/murderboard_freshness.sh": "murderboard_freshness.sh",
                "tools/murderboard_roster.sh": "murderboard_roster.sh",
                "tools/murderboard_revendor.py": "murderboard_revendor.py",
                "tools/fetch_paper.py": "fetch_paper.py",
                ".claude/skills/murderboard/SKILL.md": "skills/murderboard/SKILL.md",
            },
            # Anything you have edited locally. Listed here, the tool REPORTS the drift and
            # refuses to overwrite it, instead of silently reverting your change on every
            # re-vendor. Leave empty until you actually adapt something.
            "adapted": [],
        }
    ],
}


# --- the surgical part -------------------------------------------------------------

def stamp_line_index(text, is_json):
    """The one line that may carry the stamp, or None.

    Four positions, each forced by a format that will not accept a comment on line 1:

      * line 1 normally;
      * line 2 when line 1 is a `#!` shebang, which must stay first;
      * the `"_vendored"` key's line in JSON, which has no comments;
      * inside YAML frontmatter when line 1 is `---`. `skills/murderboard/SKILL.md` is
        this case, and it is not a consumer's mistake — upstream's own line 3 *instructs*
        you to put the stamp there. A line-1/2 rule would refuse to bump SKILL.md in
        every consumer that vendors it, which is most of them.
    """
    lines = text.split("\n")
    if is_json:
        for i, line in enumerate(lines):
            if '"_vendored"' in line:
                return i
        return None
    if not lines:
        return None
    if lines[0].strip() == "---":
        for i in range(1, len(lines)):
            if lines[i].strip() == "---":       # end of frontmatter
                break
            if STAMP_RE.search(lines[i]):
                return i
        return 1                                # frontmatter, not yet stamped
    return 1 if lines[0].startswith("#!") else 0


def bump_stamp(text, new, is_json):
    """Rewrite the stamp on the one eligible line and NOTHING else."""
    i = stamp_line_index(text, is_json)
    if i is None:
        return text
    lines = text.split("\n")
    if i < len(lines) and STAMP_RE.search(lines[i]):
        lines[i] = STAMP_RE.sub("@ " + new, lines[i])
    return "\n".join(lines)


def stamp_is_current(text, new, is_json):
    """True when the recorded stamp names `new` — at either abbreviation."""
    i = stamp_line_index(text, is_json)
    if i is None:
        return False
    lines = text.split("\n")
    if i >= len(lines):
        return False
    m = STAMP_RE.search(lines[i])
    if not m:
        return False
    have = m.group(0)[2:]
    return have.startswith(new) or new.startswith(have)


def recopy_with_stamp(local, up, is_json):
    """Upstream's content, carrying the local stamp line. NOT `local prefix + upstream`.

    The obvious reconstruction — keep everything up to and including the stamp line, then
    append upstream whole — is wrong for every format whose stamp is not on line 1, and it
    is wrong *silently*: upstream's own first lines come back a second time. A shebang file
    gets two `#!` lines (the second one inert, so nothing complains), and a YAML
    frontmatter file gets two `---` fences, which reopens the block and swallows the real
    body as metadata. Inherited from the implementation this was ported from and caught
    only by running it against a real consumer.

    The stamp is an INSERTED line, so re-copying means putting it back into upstream at the
    position upstream reserves for it — never splicing two prefixes together.
    """
    i = stamp_line_index(local, is_json)
    llines = local.split("\n")
    if i is None or i >= len(llines) or not STAMP_RE.search(llines[i]):
        return up                                   # nothing to preserve
    stamp_line = llines[i]
    j = stamp_line_index(up, is_json)
    if j is None:                                   # e.g. JSON with no _vendored key yet
        j = 1
    ulines = up.split("\n")
    j = min(j, len(ulines))
    return "\n".join(ulines[:j] + [stamp_line] + ulines[j:])


def body_of(text, is_json):
    """The file as upstream holds it, with our injected stamp line removed."""
    i = stamp_line_index(text, is_json)
    lines = text.split("\n")
    if i is None or i >= len(lines) or not STAMP_RE.search(lines[i]):
        return text
    return "\n".join(lines[:i] + lines[i + 1:])


def misplaced_stamp_line(text, is_json):
    """A stamp the gate WILL see but this writer would never touch. 1-based, or None.

    This is the quiet one. The file is stamped, the freshness gate reads it happily, and
    a line-1/2 writer bumps nothing while reporting success — so the copy drifts forever
    behind a green check. Caller treats it as an error, never as "nothing to do".
    """
    eligible = stamp_line_index(text, is_json)
    lines = text.split("\n")
    if eligible is not None and eligible < len(lines) and STAMP_RE.search(lines[eligible]):
        return None
    for i, line in enumerate(lines[:GATE_SCAN_LINES]):
        if i != eligible and STAMP_RE.search(line):
            return i + 1
    return None


# --- config, and the cross-check against the gate ----------------------------------

def load_config(root, path):
    p = Path(path) if path else root / DEFAULT_CONFIG
    if not p.is_absolute():
        p = root / p
    if not p.is_file():
        return None, p
    try:
        return json.loads(p.read_text(encoding="utf-8")), p
    except ValueError as e:
        print("revendor: %s is not valid JSON: %s" % (p, e), file=sys.stderr)
        sys.exit(2)


DEFAULT_LABEL = "murderboard"      # murderboard_freshness.sh's own default


def hook_scope(hook_path, label):
    """How the freshness gate is configured for `label`. Three outcomes, not two.

      None  — no invocation for this label. The config names a family nothing polices.
      []    — an invocation exists but scopes no `--file`, so the gate falls back to its
              own built-in `STAMPED_FILES` list. A legitimate setup, and NOT a
              disagreement; there is simply nothing to cross-check against.
      list  — explicitly scoped. Compare it, strictly.

    Collapsing the first two into "empty" is what makes this dangerous: a caller then
    reads "no files" as "nothing to check" and the cross-check written to stop a file
    dropping out of the gate silently does nothing itself. The version this is ported from
    had exactly that bug, for a different reason — it scanned line-at-a-time, so a
    backslash-continued invocation matched `--label` on one line and `--file` on later
    ones, matched neither, and returned empty for every family from the day it was
    written. Continuations are therefore joined FIRST.

    The invocation may live in a hook script or in a settings file; this only reads text,
    so either works.
    """
    if not hook_path or not hook_path.is_file():
        return None
    joined = hook_path.read_text(encoding="utf-8").replace("\\\n", " ")
    for line in joined.split("\n"):
        if "murderboard_freshness" not in line:
            continue
        if ("--label " + label) in line:
            pass
        elif label == DEFAULT_LABEL and "--label" not in line:
            pass                        # an unlabelled invocation IS the default family
        else:
            continue
        # The invocation is often embedded in JSON (".claude/settings.json"), so a token
        # arrives carrying the enclosing quote, a trailing comma, or a backslash from the
        # JSON escaping — `.claude/hooks/session-start.sh",`. Compared raw, every such
        # path "disagrees" with the config and the cross-check reports a difference that
        # is punctuation. Noise like that is what gets a check switched off, so strip it.
        return [t.strip("\\\"',") for t in re.findall(r"--file (\S+)", line)]
    return None


def _git(clone, *args):
    return subprocess.run(["git", "-C", str(clone), *args], capture_output=True, text=True)


def run(root, cfg, cfg_path, check_only):
    if cfg is None:
        print("revendor: no %s found (looked at %s)." % (DEFAULT_CONFIG, cfg_path), file=sys.stderr)
        print("  This tool ships with murderboard but is configured per consumer.\n"
              "  Start one with:  python3 %s --example-config > %s"
              % (Path(__file__).name, DEFAULT_CONFIG), file=sys.stderr)
        return 2

    hook_path = None
    if cfg.get("hook"):
        hook_path = root / cfg["hook"]

    rc = 0
    for fam in cfg.get("families", []):
        label, files = fam["label"], fam["files"]

        if hook_path and hook_path.is_file():
            hooked = hook_scope(hook_path, label)
            if hooked is None:
                print("revendor: %s runs no freshness gate for %r." % (cfg["hook"], label),
                      file=sys.stderr)
                print("  This config names a family that nothing polices, so a stale copy\n"
                      "  here would never announce itself. Add the invocation, or drop the\n"
                      "  family. Not guessing which.", file=sys.stderr)
                return 1
            if hooked and sorted(hooked) != sorted(files):
                print("revendor: %r disagrees with the freshness gate." % label, file=sys.stderr)
                print("  only in %s: %s" % (DEFAULT_CONFIG, sorted(set(files) - set(hooked))),
                      file=sys.stderr)
                print("  only in the gate:  %s" % sorted(set(hooked) - set(files)), file=sys.stderr)
                print("  Reconcile them. Two hand-maintained lists that disagree is exactly\n"
                      "  how a file quietly stops being gated.", file=sys.stderr)
                return 1
            if not hooked:
                print("%s: gate is unscoped (its built-in file list); no cross-check possible"
                      % label)

        clone = Path(os.path.expanduser(fam["clone"]))
        if not (clone / ".git").exists():
            print("revendor: no clone of %s at %s" % (fam["slug"], clone), file=sys.stderr)
            rc = 1
            continue
        ref = fam.get("ref", "origin/main")
        _git(clone, "fetch", "-q", "origin")
        new = _git(clone, "rev-parse", "--short", ref).stdout.strip()
        if not new:
            print("revendor: cannot resolve %s in %s" % (ref, clone), file=sys.stderr)
            rc = 1
            continue

        recopied, bumped, missing, held, misplaced, unstamped = [], [], [], [], [], []
        for rel in files:
            up_rel = fam.get("remap", {}).get(rel, rel)
            r = _git(clone, "show", "%s:%s" % (ref, up_rel))
            if r.returncode:
                missing.append("%s (looked for %s)" % (rel, up_rel))
                continue
            up, p = r.stdout, root / rel
            if not p.is_file():
                missing.append("%s (not present locally)" % rel)
                continue
            is_json = rel.endswith(".json")
            loc = p.read_text(encoding="utf-8")

            bad_line = misplaced_stamp_line(loc, is_json)
            if bad_line is not None:
                misplaced.append("%s (stamp on line %d)" % (rel, bad_line))
                continue
            if stamp_line_index(loc, is_json) is None or not STAMP_RE.search(
                    loc.split("\n")[stamp_line_index(loc, is_json)]):
                unstamped.append(rel)
                continue

            want = loc if stamp_is_current(loc, new, is_json) else bump_stamp(loc, new, is_json)
            if body_of(loc, is_json) != up:
                if rel in fam.get("adapted", []):
                    held.append(rel)          # report drift, never overwrite an adaptation
                else:
                    want = recopy_with_stamp(want, up, is_json)
                    recopied.append(rel)
            elif want != loc:
                bumped.append(rel)
            if not check_only and want != loc:
                p.write_text(want, encoding="utf-8")

        verb = "would re-copy" if check_only else "re-copied"
        print("%s  upstream %s" % (label, new))
        print("  %s (body changed): %s" % (verb, recopied or "none"))
        print("  stamp bumped only:    %d file(s)" % len(bumped))
        if held:
            print("  !! body differs but file is LOCALLY ADAPTED — merge by hand: %s" % held)
            rc = 1
        if unstamped:
            print("  !! no stamp on the eligible line, nothing bumped: %s" % unstamped,
                  file=sys.stderr)
            print("     Add one (line 1, or line 2 behind a shebang) or the copy drifts\n"
                  "     silently.", file=sys.stderr)
            rc = 1
        if misplaced:
            print("  !! STAMP IN THE WRONG PLACE — the gate sees it, this tool will not\n"
                  "     touch it, so it would stay unbumped behind a green check: %s" % misplaced,
                  file=sys.stderr)
            rc = 1
        if missing:
            print("  !! not found upstream: %s" % missing, file=sys.stderr)
            rc = 1
    return rc


# --- selftest ----------------------------------------------------------------------

def selftest():
    """The rewrite must be surgical, and every fixture must be able to fail."""
    bad = 0

    def check(label, got, want):
        nonlocal bad
        ok = got == want
        bad += (not ok)
        print("  %s %s" % ("PASS" if ok else "FAIL", label))
        if not ok:
            print("         got  %r\n         want %r" % (got, want))

    FULL = "b2b2ba2d6c42cef07850bd7be2db3aa4d019151c"

    # 1. The shape that corrupted a real file: true stamp on line 1, another in the body.
    doc = ("<!-- vendored from syncytium2/murderboard @ aaaaaaa — do not edit here. -->\n"
           "# Title\n"
           "The murderboard is vendored @ b2b2ba2; the gate reports current.\n")
    out = bump_stamp(doc, "ffffff1", False)
    check("line-1 stamp is rewritten", out.split("\n")[0].count("ffffff1"), 1)
    check("body stamp is UNTOUCHED", "@ b2b2ba2" in out, True)
    check("exactly one stamp changed", out.count("ffffff1"), 1)

    # 2. THE NESTING CASE. The body string is a PREFIX of the real full-length stamp, so
    #    a substitution aimed at the short form eats the long one too. A fixture using
    #    two DISTINCT strings passes while this still breaks — hence its own case.
    nest = ("<!-- vendored from syncytium2/murderboard @ %s — do not edit. -->\n"
            "# Title\nThe murderboard is vendored @ b2b2ba2; gate current.\n" % FULL)
    outn = bump_stamp(nest, "ffffff1", False)
    check("full-length line-1 stamp is rewritten", outn.split("\n")[0].count("ffffff1"), 1)
    check("body PREFIX of that stamp survives", "@ b2b2ba2;" in outn, True)
    check("long form gone from the body too", FULL not in outn, True)

    # 3. THE SHEBANG CASE. A line-1-only writer skips every shell/python file it is given
    #    and reports success — the same quiet wrongness, one layer down.
    sh = ("#!/usr/bin/env bash\n"
          "# vendored from syncytium2/murderboard @ %s — canonical THERE.\n"
          "# A comment mentioning @ b2b2ba2 for context.\n" % FULL)
    outs = bump_stamp(sh, "ffffff1", False)
    check("shebang stays on line 1", outs.split("\n")[0], "#!/usr/bin/env bash")
    check("line-2 stamp IS rewritten", "ffffff1" in outs.split("\n")[1], True)
    check("body stamp below a shebang survives", "@ b2b2ba2" in outs.split("\n")[2], True)
    check("body_of drops the stamp line, not the shebang",
          body_of(sh, False).split("\n")[0], "#!/usr/bin/env bash")

    # 4. JSON, which has no comments and so uses a key.
    js = ('{\n "_vendored": "syncytium2/murderboard @ aaaaaaa — re-copy.",\n'
          ' "note": "see @ b2b2ba2"\n}\n')
    outj = bump_stamp(js, "ffffff1", True)
    check("json stamp is rewritten", "ffffff1" in outj.split("\n")[1], True)
    check("json body stamp is UNTOUCHED", "@ b2b2ba2" in outj, True)

    # 5. An unstamped file must come back unchanged rather than acquiring a stamp.
    plain = "# nothing to see\nbody\n"
    check("unstamped file is unchanged", bump_stamp(plain, "ffffff1", False), plain)

    # 6. THE GATED-BUT-UNBUMPABLE CASE, which is this port's addition. The freshness gate
    #    scans five lines; this writer touches one. A stamp in between is green to the
    #    gate and invisible to the writer, so the copy drifts forever behind a passing
    #    check. It must be reported, never silently skipped.
    late = ("# A header comment.\n"
            "# Another.\n"
            "# vendored from syncytium2/murderboard @ aaaaaaa — third line.\n"
            "body\n")
    check("a stamp on line 3 is REPORTED, not ignored",
          misplaced_stamp_line(late, False), 3)
    check("bumping it changes nothing (which is why it must be reported)",
          bump_stamp(late, "ffffff1", False), late)
    check("a correctly placed stamp is not flagged",
          misplaced_stamp_line(doc, False), None)
    check("a shebang file stamped on line 2 is not flagged",
          misplaced_stamp_line(sh, False), None)

    # 6b. YAML FRONTMATTER — SKILL.md's case, and the reason case 6 alone is not enough.
    #     Upstream's own SKILL.md tells the vendoring consumer to put the stamp on line 3,
    #     inside the frontmatter block, because line 1 must be `---`. Treating that as
    #     "misplaced" would refuse to bump SKILL.md in every consumer that vendors it.
    fm = ("---\n"
          "# canonical: syncytium2/murderboard skills/murderboard/SKILL.md\n"
          "# vendored from https://github.com/syncytium2/murderboard @ aaaaaaa — do NOT edit.\n"
          "name: murderboard\n"
          "---\n\n"
          "Body text mentioning @ b2b2ba2 in passing.\n")
    check("frontmatter stamp is found, not flagged", misplaced_stamp_line(fm, False), None)
    outf = bump_stamp(fm, "ffffff1", False)
    check("frontmatter stamp IS rewritten", "ffffff1" in outf.split("\n")[2], True)
    check("the --- fence is untouched", outf.split("\n")[0], "---")
    check("a body stamp below the frontmatter survives", "@ b2b2ba2" in outf, True)
    check("exactly one stamp changed in a frontmatter file", outf.count("ffffff1"), 1)
    check("body_of drops the stamp line, keeping the fence",
          body_of(fm, False).split("\n")[0], "---")

    # 6c. THE RE-COPY RECONSTRUCTION. `local prefix + upstream` duplicates upstream's own
    #     opening lines whenever the stamp is not on line 1 — a second `#!` (inert, so
    #     nothing complains) or a second `---` fence, which reopens the frontmatter block
    #     and swallows the body as metadata. Silent both times, and inherited from the
    #     ported implementation. Caught only by running against a real consumer.
    up_sh = ("#!/usr/bin/env bash\n"
             "# CANONICAL SOURCE: syncytium2/murderboard — edit HERE.\n"
             "echo hello\n")
    loc_sh = ("#!/usr/bin/env bash\n"
              "# vendored from syncytium2/murderboard @ aaaaaaa — do NOT edit here.\n"
              "# CANONICAL SOURCE: syncytium2/murderboard — edit HERE.\n"
              "echo OLD\n")
    got_sh = recopy_with_stamp(loc_sh, up_sh, False)
    check("re-copy keeps exactly one shebang", got_sh.count("#!/usr/bin/env bash"), 1)
    check("re-copy keeps the local stamp", "@ aaaaaaa" in got_sh, True)
    check("re-copy takes upstream's body", "echo hello" in got_sh and "echo OLD" not in got_sh, True)
    check("re-copy is idempotent", recopy_with_stamp(got_sh, up_sh, False), got_sh)
    check("and its body now matches upstream", body_of(got_sh, False), up_sh)

    up_fm = ("---\nname: murderboard\n---\n\nBody.\n")
    loc_fm = ("---\n# vendored from syncytium2/murderboard @ aaaaaaa — do NOT edit.\n"
              "name: murderboard\n---\n\nOLD body.\n")
    got_fm = recopy_with_stamp(loc_fm, up_fm, False)
    check("re-copy keeps exactly two --- fences", got_fm.split("\n").count("---"), 2)
    check("frontmatter re-copy keeps the local stamp", "@ aaaaaaa" in got_fm, True)
    check("frontmatter re-copy is idempotent", recopy_with_stamp(got_fm, up_fm, False), got_fm)
    check("and its body now matches upstream", body_of(got_fm, False), up_fm)

    # The broken reconstruction must FAIL these, or the fixtures prove nothing.
    def prefix_splice(local, up, is_json):
        i = stamp_line_index(local, is_json) or 0
        return "\n".join(local.split("\n")[:i + 1]) + "\n" + up

    check("prefix-splicing FAILS the shebang fixture",
          prefix_splice(loc_sh, up_sh, False).count("#!/usr/bin/env bash"), 2)
    check("prefix-splicing FAILS the frontmatter fixture",
          prefix_splice(loc_fm, up_fm, False).split("\n").count("---"), 3)

    # 7. PROVE THE FIXTURES HAVE POWER. Each guarded bug must FAIL its fixture — a test
    #    that cannot fail is the reason this file exists.
    def whole_file_sub(text, new):        # the implementation that corrupted a real file
        return STAMP_RE.sub("@ " + new, text)

    def line1_only(text, new):            # the earlier version, applied to a shebang file
        lines = text.split("\n")
        if STAMP_RE.search(lines[0]):
            lines[0] = STAMP_RE.sub("@ " + new, lines[0])
        return "\n".join(lines)

    check("a whole-file substitution FAILS the nesting fixture",
          "@ b2b2ba2;" in whole_file_sub(nest, "ffffff1"), False)
    check("a line-1-only implementation FAILS the shebang fixture",
          "ffffff1" in line1_only(sh, "ffffff1"), False)

    # 8. Full-vs-short sha is not staleness. Without this, every long stamp reports as
    #    needing a bump on every run, forever — and churn is what gets a check ignored.
    long_stamped = "<!-- vendored from syncytium2/murderboard @ %s -->\nbody\n" % FULL
    check("full stamp is current against its own short form",
          stamp_is_current(long_stamped, FULL[:7], False), True)
    check("short stamp is current against the full form",
          stamp_is_current("# vendored @ %s\nbody\n" % FULL[:7], FULL, False), True)
    check("a genuinely different sha is NOT current",
          stamp_is_current(long_stamped, "ffffff1", False), False)

    # 9. The gate cross-check. Three outcomes that must stay distinguishable — collapsing
    #    "nothing polices this" into "nothing to compare" is how the check turns itself
    #    off. Continuations are joined first, because the ported version scanned
    #    line-at-a-time and so returned empty for every family from the day it was written.
    import tempfile
    with tempfile.TemporaryDirectory() as td:
        h = Path(td) / "session-start.sh"
        h.write_text("#!/usr/bin/env bash\n"
                     "bash tools/murderboard_freshness.sh --hook --label session-protocol \\\n"
                     "     --slug syncytium2/murderboard \\\n"
                     "     --file docs/doc_review_process.md --file tools/fetch_paper.py\n")
        check("continuation lines are joined before scanning",
              hook_scope(h, "session-protocol"),
              ["docs/doc_review_process.md", "tools/fetch_paper.py"])
        check("a label nothing polices is None, not empty", hook_scope(h, "nope"), None)

        # The common real-world shape: an unlabelled invocation, which IS the default
        # family, scoping no files because the gate uses its own list. That must read as
        # "unscoped" ([]), never as "unpoliced" (None) — an early version failed here and
        # would have refused to run in every consumer configured this way.
        s = Path(td) / "settings.json"
        s.write_text('{"command": "bash tools/murderboard_freshness.sh --hook"}\n')
        check("an unlabelled invocation is the default family, unscoped",
              hook_scope(s, DEFAULT_LABEL), [])
        check("...and does not answer for some other label",
              hook_scope(s, "session-protocol"), None)

        # The invocation usually lives in JSON, where every path arrives wearing the
        # enclosing quote and a comma. Found on the first run against a real consumer:
        # `.claude/hooks/session-start.sh",` was reported as disagreeing with
        # `.claude/hooks/session-start.sh`, a difference made entirely of punctuation.
        j = Path(td) / "settings.json"
        j.write_text('{\n "command": "bash tools/murderboard_freshness.sh --hook '
                     '--label session-protocol --slug syncytium2/murderboard '
                     '--file docs/session_protocol.md '
                     '--file .claude/hooks/session-start.sh",\n "timeout": 10\n}\n')
        check("JSON quoting is stripped from --file paths",
              hook_scope(j, "session-protocol"),
              ["docs/session_protocol.md", ".claude/hooks/session-start.sh"])

    # 10. The real motivating file, if it is next to us: ten stamp-shaped strings in a
    #     body that a whole-file substitution would rewrite.
    here = Path(__file__).resolve().parent / "murderboard_freshness.sh"
    if here.is_file():
        body = here.read_text(encoding="utf-8")
        n = len(STAMP_RE.findall(body))
        check("murderboard_freshness.sh still has body stamps worth protecting", n > 1, True)
        check("a whole-file substitution would rewrite all of them",
              len(STAMP_RE.findall(whole_file_sub(body, "ffffff1"))) == n and
              "ffffff1" in whole_file_sub(body, "ffffff1"), True)
        check("this tool rewrites none of them (no stamp on its eligible line)",
              "ffffff1" in bump_stamp(body, "ffffff1", False), False)

    print("\n%s — %d problem(s)" % ("FAILED" if bad else "all checks pass", bad))
    return 1 if bad else 0


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--check", action="store_true", help="report, change nothing")
    ap.add_argument("--selftest", action="store_true", help="prove the rewrite is surgical")
    ap.add_argument("--example-config", action="store_true",
                    help="print a starter .murderboard-vendor.json")
    ap.add_argument("--config", help="path to the vendor config (default %s)" % DEFAULT_CONFIG)
    ap.add_argument("--root", help="repo root (default: this file's directory)")
    a = ap.parse_args()

    if a.selftest:
        return selftest()
    if a.example_config:
        print(json.dumps(EXAMPLE_CONFIG, indent=2))
        return 0

    root = Path(a.root).resolve() if a.root else Path(__file__).resolve().parent
    cfg, cfg_path = load_config(root, a.config)
    return run(root, cfg, cfg_path, a.check)


if __name__ == "__main__":
    sys.exit(main())
