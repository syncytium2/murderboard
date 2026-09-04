#!/usr/bin/env python3
"""The banned-construction list exists twice. Prove the two copies still agree.

WHY THIS EXISTS. `doc_review_process.md` role 5 is the authority on the house voice;
`DRAFTING-PROMPT.md` restates it forwards, for pasting into a chat before anything is
written. Two copies of one list is the drift failure this repo has already had once
(the explainer page, #36), and drift here is silent in the worst direction: the drafting
prompt keeps permitting a word the review still fails you for, so a writer follows the
prompt and the murderboard rejects the result.

PROMPT.md is generated and CI diffs it against its generator. This list is not generated
-- the drafting prompt is prose written for a human, not a role roster -- so it gets a
comparison instead.

EXIT  0 the two lists agree   1 they do not   2 could not read a file / find a list
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PROCESS = ROOT / "doc_review_process.md"
PROMPT = ROOT / "DRAFTING-PROMPT.md"


def die(msg):
    print(f"drafting_prompt_test: {msg}", file=sys.stderr)
    sys.exit(2)


def words_from_process(text):
    """Role 5 carries the list as a bold run: **delve, leverage, ... tapestry**."""
    m = re.search(r"\*\*delve,(.*?)\*\*", text, re.S)
    if not m:
        die("no bold banned-word run found in doc_review_process.md role 5 "
            "(expected it to start `**delve,`) -- if the list moved, update this test")
    run = "delve," + m.group(1)
    return {w.strip() for w in run.replace("\n", " ").split(",") if w.strip()}


def words_from_prompt(text):
    """The drafting prompt carries the same list mid-dot separated, under NEVER."""
    for line in text.splitlines():
        if line.strip().startswith("delve"):
            return {w.strip() for w in line.split("·") if w.strip()}
    die("no banned-word line found in DRAFTING-PROMPT.md "
        "(expected a line beginning `delve`) -- if the list moved, update this test")


TOOL = ROOT / "murderboard_prose.sh"


def forms_from_tool(text):
    """murderboard_prose.sh carries the phrase patterns as `<label>::<regex>` lines.

    The words are derived from the process file at run time, so they cannot drift. The
    labels cannot be derived -- a regex is not a word list -- so they are checked here:
    a form the tool searches for and role 5 never names is a rule enforced by a script
    that no reviewer can quote and no author can read.
    """
    # Bounded by the heredoc, not by "a line containing ::". The opener is `<<'FORMS'` and
    # the closer is a bare `FORMS`; keying on the bare word alone starts the capture at the
    # CLOSING delimiter and then scoops up the shell that parses these lines, so the test
    # reports the parser's own `label=${line%%::*}` as an unnamed construction.
    inside = False
    labels = set()
    for line in text.splitlines():
        if "<<'FORMS'" in line:
            inside = True
            continue
        if inside and line.strip() == "FORMS":
            break
        if inside and "::" in line:
            labels.add(line.split("::", 1)[0].strip())
    if not labels:
        die("no `<label>::<regex>` form lines found in murderboard_prose.sh")
    return labels


def main():
    for p in (PROCESS, PROMPT, TOOL):
        if not p.is_file():
            die(f"cannot read {p.name}")

    # Collapse whitespace before matching: the process file wraps at ~95 columns, so
    # "In today's ___" is split across a line break in role 5 and a naive substring test
    # reports it missing. Curly apostrophes are folded for the same reason.
    def flat(s):
        return " ".join(s.replace("’", "'").split())

    role5 = flat(PROCESS.read_text(encoding="utf-8"))
    unnamed = sorted(
        lb for lb in forms_from_tool(TOOL.read_text(encoding="utf-8"))
        if flat(lb) not in role5
    )
    if unnamed:
        print("FAIL — murderboard_prose.sh searches for constructions role 5 never names:")
        for lb in unnamed:
            print(f"  {lb}")
        print("  A script enforcing a rule the process file does not state is a rule the "
              "author cannot read and the reviewer cannot quote.")
        return 1

    a = words_from_process(PROCESS.read_text(encoding="utf-8"))
    b = words_from_prompt(PROMPT.read_text(encoding="utf-8"))

    if a == b:
        n_forms = len(forms_from_tool(TOOL.read_text(encoding="utf-8")))
        print(f"ok — the banned list agrees in both copies ({len(a)} words: "
              f"{', '.join(sorted(a))}), and role 5 names all {n_forms} forms "
              f"murderboard_prose.sh searches for")
        return 0

    print("FAIL — doc_review_process.md and DRAFTING-PROMPT.md disagree about the "
          "banned-construction list.")
    only_process = sorted(a - b)
    only_prompt = sorted(b - a)
    if only_process:
        print(f"  the review bans, the drafting prompt permits: {', '.join(only_process)}")
        print("    -> a writer who follows the prompt gets failed by role 5 for obeying it")
    if only_prompt:
        print(f"  the drafting prompt bans, the review permits: {', '.join(only_prompt)}")
        print("    -> the prompt is enforcing a rule no reviewer will back it up on")
    print("  doc_review_process.md is the authority. Fix DRAFTING-PROMPT.md to match, "
          "or change both deliberately.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
