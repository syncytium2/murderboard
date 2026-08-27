# Contributing

> **Just want to use it?** You are in the wrong file — see **[START-HERE.md](START-HERE.md)**.
> You do not need to contribute, fork, or understand this page to run a murderboard.
>
> **Either way, you need a repo of your own.** Whatever you review, and every record a review
> produces, belongs there. **Nothing of yours goes in this one** — not your documents, not your
> run records, not your project's rules. This repo is public and vendored: a commit here reaches
> everyone who copies from it, and it cannot be taken back.

## First: you probably want to vendor, not contribute

This repo is designed to be **copied into your project**, not depended on. There is no
package, no install step, and nothing here imports anything else here. Take the files you
want, stamp them, and go:

```bash
cp doc_review_process.md          your-repo/docs/
cp murderboard_roster.sh          your-repo/tools/
cp -r skills/murderboard          your-repo/.claude/skills/
# stamp line 1 or 2 of each copy:
#   vendored from syncytium2/murderboard @ <short-sha>
```

**Diverging is the expected outcome, not a failure.** Your project has different stakes,
different reviewers, and different failure modes. Rewrite the roles. Delete the ones that
don't earn their place. If your fork ends up unrecognisable, the tool did its job.

The one thing worth keeping is the **provenance stamp**, because
[`murderboard_freshness.sh`](murderboard_freshness.sh) reads it to tell you when your copy has
fallen behind — and a stale gate that reports nothing is the failure this whole repo is about.
Wire it into your `SessionStart` hook and it will announce itself.

So: open a PR when you have something that **generalises**. Keep it local when it's yours.

---

## What belongs upstream

**Yes:**

- A rule that would have caught a real defect, with the incident that produced it.
- A gate that can be shown to fail — see [Gates must be able to fail](#gates-must-be-able-to-fail).
- A fix to something that is factually wrong, a dead pointer, or a check that cannot fire.
- Portability fixes. BSD vs GNU `grep`/`sed`/`awk` differences, missing interpreters, shells
  that aren't bash. These are the bugs this repo keeps having.

**No:**

- Project-specific vocabulary, paths, or domain jargon in the core. The calcium-imaging origin
  survives only in the appendix of `doc_review_process.md` and in explicit back-compat branches
  of `fetch_paper.py`. New machinery is env-driven.
- Dependencies. `fetch_paper.py` is standard library only (plus *optional* `pypdf`/`pdftotext`,
  imported lazily inside the function that needs them). A consumer must be able to drop the
  file in and run it. CI enforces this.
- Rules with no incident behind them. See below — this is the one that gets PRs closed.
- **Anything that is yours rather than everyone's.** Your reviewed documents, your run records
  under `docs/reviews/`, your project's own rules, your notes. Those live in your repo. This is
  the easiest mistake on the list to make by accident, because running a murderboard *inside a
  clone of the murderboard* puts them here by default — check where the run record landed before
  you commit. (This repo made the same mistake in the other direction on 2026-08-26: a session
  did an unrelated project's work in this checkout, which is why `CLAUDE.md` now opens with a
  scope rule.)

---

## The house rules

### Every claim is verifiable, or it is flagged

This repo argues that documents ship wrong because nobody checks them against a real source.
It does not get an exemption.

- **No invented provenance.** If you write "vendored from X @ `abc1234`", that commit exists
  and contains that content. If you can't verify a historical detail, mark it — don't polish it.
- **No fabricated incidents.** Every "this happened" in these files happened. If you want a rule
  but have no incident, say so plainly: *"no incident yet, argued from first principles"* is an
  honest and acceptable framing. Inventing a war story to make a rule land is the exact failure
  mode the process file names.
- **No pointer a reader cannot follow.** This repo is public and most of its sibling projects
  are not. Naming a private repo as *attribution* is fine — `colonel_kernel` reported the
  fail-open bug, and saying so costs the reader nothing. Sending them there does.

### Gates must be able to fail

A gate that cannot fire manufactures exactly the confidence it was built to earn. This is not
theoretical here: the no-heredoc hook was live in several repos while exiting `0` for every
call, because it shelled out to `python`, `python` did not exist, and a missing interpreter
read as "nothing to check."

Worse, **the verification recipe shipped with the fix could not fail either.** It built a
python-free `PATH` by filtering entries matching `python`, which still left
`/opt/homebrew/bin/python3` reachable — so it ran the healthy path and printed the exit code it
wanted.

So, for any gate you add or change:

1. Ship a `--selftest` that proves **every branch** can fire, including the failure branches.
2. **Prove your test fails** against the broken version. Run it against the code before your
   fix and paste the failure into the PR. A test that has only ever been seen passing is not
   yet evidence.
3. Assert your preconditions. If a test depends on something being absent, check that it is
   actually absent before trusting the result.

### Know which file your change belongs in

- **`doc_review_process.md`** is the authority on *what* gets reviewed and by whom. **A new
  rule goes here.**
- **`skills/murderboard/SKILL.md`** owns only *how the review is summoned* — the steps that
  must not depend on being remembered. **A step that would otherwise be skipped goes here.**

Putting a rule in the skill hides it from consumers who read the process directly. Putting
call-up mechanics in the process file is how they ended up as prose in the first place.

If your change is a rule **and** changes what gets emitted, it touches both — do it in one
commit. A rule whose output channel still emits the old shape is a rule with no channel.

### Adding a review role

The roster is **derived**, never recalled: `murderboard_roster.sh` parses roles out of
`doc_review_process.md`, so a new role propagates to every consumer's coverage check for free.
That parser reads numbered entries between the `## The review team` heading and the next `## `
heading. **Keep that structure.** Reformat those headings and the roster silently parses zero
roles, at which point every consumer's check passes vacuously. CI guards the count; run
`bash murderboard_roster.sh list` and confirm your role appears.

---

## Before you open a PR

Run everything. It takes about ten seconds and needs nothing installed:

```bash
bash murderboard_roster.sh --selftest
bash murderboard_freshness.sh --selftest
bash require_commit_before_message.sh --selftest
bash tests/no_heredoc_hook_test.sh
python3 tests/fetch_paper_stdlib_test.py
bash murderboard_roster.sh count      # expect the current role count
for f in $(git ls-files '*.sh'); do bash -n "$f" || echo "SYNTAX $f"; done
```

CI runs all of it on **ubuntu and macOS**, plus advisory `shellcheck`. macOS is not redundant:
BSD and GNU tools disagree often enough that "passes on Linux" is not the claim we need. All
four checks are required on `main`.

### If you use Claude Code in this repo

`.claude/settings.json` wires a `PreToolUse` hook that **blocks writing source files through a
shell heredoc**, because heredocs corrupt string escapes silently and the damage still looks
correct in a diff. Use the `Write`/`Edit` tools for `.sh`/`.py`/`.m`/`.R` files. If the hook
blocks you, it is usually right.

The repo also assumes concurrent, stateless sessions — see
[`docs/session_protocol.md`](docs/session_protocol.md). Work in a worktree, don't commit on
`main`, push feature branches promptly.

### Commit messages

Titles here **state the problem, not the change**:

```
Every gate shipped a --selftest and nothing ever ran them
the no-heredoc gate FAILED OPEN where python3 is the only python
"Iterate until a blind pass produces no new findings" does not terminate
```

Not `add CI`, `fix hook`, `update docs`. The title is what a reader skimming `git log` needs in
order to know whether this commit is why their world changed. The body carries the evidence:
what you measured, what you verified, and what you could not.

If an agent wrote the code, say so — this repo carries a `Co-Authored-By` trailer for that and
the README is explicit about the division between authorship and review.

---

## Licence

Apache-2.0. By contributing you agree your contribution is licensed under it. No CLA.

## Reporting something broken

Open an issue. The most useful ones name a gate that **passed when it should not have** — that
is the failure this project exists to catch, and it is the hardest to notice from inside.
