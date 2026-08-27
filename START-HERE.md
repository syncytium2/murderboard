# Start here

**You do not need Claude. You do not need to install anything. You do not need to know git.**

The murderboard is a way of getting a document torn apart before you send it, by making an
AI check it role by role instead of asking "is this good?" and getting a compliment.

Pick the level that matches you. Level 1 takes two minutes and needs nothing but a browser.

> Want the longer version first — why this exists, the eleven roles, and what a finished review
> looks like? **[murderboard.tonydefazio.com](https://murderboard.tonydefazio.com/)**

---

## Level 1 — Any AI chat. Two minutes. No install.

1. Open **[PROMPT.md](PROMPT.md)** and copy the whole block inside the ``` fence.
2. Paste it into ChatGPT, Claude, Gemini, Copilot, a local model — whatever you use.
3. It will reply with one line and wait. **Now paste your document.**
4. Read what comes back. Fix what's real. Ignore what isn't — it is a reviewer, not a boss.

That's the whole thing. Everything else on this page is automation for doing this often.

> **The one habit that makes it work.** If your document rests on data, code, or references,
> **give the assistant those too.** Otherwise it can only check the text against itself, which
> catches typos and contradictions but not the thing that actually ruins a document: a number
> that disagrees with the source it came from. The prompt tells it to say which findings it
> could not verify. Take that list seriously — it is the honest part of the review.

**Why it beats "please review this."** Asking an AI to review a draft gets you a polite
summary and three suggestions. This makes it work through eleven fixed roles — one only checks
citations, one only checks whether claims match sources, one only reads as a confused newcomer,
one only asks what should have been a figure — and report each separately, so a role that found
nothing is visible as a role that ran, not as a role that got skipped.

---

## Level 2 — Claude Code. Five minutes.

> **From here on you need a repo of your own.** Level 1 writes nothing. Level 2 does: each
> review leaves a run record, and it belongs in *your* project. Do not work inside a clone of
> this repo — that is how your documents end up in somebody else's tool.

If you use [Claude Code](https://claude.com/claude-code), you can run the whole thing with one
command instead of pasting.

Copy **four files** into your project (keep the folder layout):

```
doc_review_process.md                    ->  docs/doc_review_process.md
murderboard_roster.sh                    ->  murderboard_roster.sh
murderboard_freshness.sh                 ->  murderboard_freshness.sh
skills/murderboard/SKILL.md              ->  .claude/skills/murderboard/SKILL.md
```

The fastest way to get them:

```bash
git clone https://github.com/syncytium2/murderboard.git
cd your-project
cp ../murderboard/doc_review_process.md docs/
cp ../murderboard/murderboard_roster.sh ../murderboard/murderboard_freshness.sh .
mkdir -p .claude/skills/murderboard
cp ../murderboard/skills/murderboard/SKILL.md .claude/skills/murderboard/
```

Then, in Claude Code:

```
/murderboard docs/my-report.md
```

**Copy all four.** The skill calls the two `.sh` files as gates; with only the process file and
the skill, it hits an undefined state instead of a clear error. They are small and have no
dependencies.

---

## Level 3 — Make it fire without being remembered.

This is the actual point of the project, and it is worth reading
[`doc_review_process.md`](doc_review_process.md) before you get here.

A rule that depends on being remembered is not a rule. So:

- **Coverage** — after a review, `bash murderboard_roster.sh check REPORT.md` exits `1` if the
  report is missing a role. A run that fired 7 of 11 roles and a clean run otherwise look
  identical.
- **Freshness** — `bash murderboard_freshness.sh --hook` tells you when your copy has fallen
  behind this repo. Wire it into your `SessionStart` hook. A stale process silently omits rules
  you already paid for.
- **The paragraph for your `CLAUDE.md`** — [README](README.md#how-a-project-adopts-it) has a
  drop-in block that makes an agent run the murderboard on document deliverables by default,
  rather than when someone thinks to ask.

---

## What works without Claude, specifically

Most of it. Only the skill and the `.claude/hooks/` scripts are Claude Code specific.

| | needs an AI? | needs Claude? |
|---|---|---|
| [`PROMPT.md`](PROMPT.md) / [`murderboard_prompt.sh`](murderboard_prompt.sh) | any chat model | no |
| [`doc_review_process.md`](doc_review_process.md) | it is prose — a person can run it | no |
| [`murderboard_roster.sh`](murderboard_roster.sh) | no — plain shell | no |
| [`murderboard_freshness.sh`](murderboard_freshness.sh) | no — plain shell | no |
| [`fetch_paper.py`](fetch_paper.py) | no — plain Python, stdlib only | no |
| [`skills/murderboard/SKILL.md`](skills/murderboard/SKILL.md) | — | **yes** |
| [`.claude/hooks/`](.claude/hooks/) | — | **yes** |

You can run a murderboard entirely by hand: read the process file, work the roles yourself,
write the report, and check your own coverage with `murderboard_roster.sh check`. That is
slower and it still works — the roles are the idea, the tooling is just what stops you
skipping one.

---

## Common questions

**Do I have to use all eleven roles?** Yes — that is the one rule worth keeping. What scales
to how much you care is *how thoroughly* you run each role, never *which ones you run*. The
role you skip is the one that would have caught it, and a skipped role leaves no trace.

**It found 40 things and I don't have time.** Fix blocking and major; record the rest as known
and move on. The process caps this deliberately: stop when a re-review turns up no blocking or
major findings, or after three rounds, whichever is first. "Keep going until it's clean" does
not terminate — every fix is new text, and new text generates new findings.

**It's inventing problems.** Tell it so, and ask which findings it verified against a source
you actually gave it. Findings it can't ground are the ones to distrust. If you gave it no
sources, most of the review is style opinion, and that is on the setup, not the model.

**Can I delete roles I don't care about?** Once you understand why each exists — yes. It is
your fork. Read the appendix of the process file first; each rule is there because something
shipped broken.

**Where do I ask for help?** Open an issue: <https://github.com/syncytium2/murderboard/issues>
