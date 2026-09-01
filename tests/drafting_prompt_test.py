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


def main():
    for p in (PROCESS, PROMPT):
        if not p.is_file():
            die(f"cannot read {p.name}")

    a = words_from_process(PROCESS.read_text(encoding="utf-8"))
    b = words_from_prompt(PROMPT.read_text(encoding="utf-8"))

    if a == b:
        print(f"ok — the banned list agrees in both copies ({len(a)} words: "
              f"{', '.join(sorted(a))})")
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
