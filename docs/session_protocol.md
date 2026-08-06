<!-- vendored from interface2 @ b01259f — canonical source; do NOT edit here, update upstream (interface2 docs/session_protocol.md) and re-copy -->
# Session protocol — multi-session coordination

> **Canonical source.** This file lives canonically in **interface2** (`docs/session_protocol.md`)
> and is **vendored** into consumer repos (colonel_kernel, fireflies, foundations, murderboard, …)
> with a line-1 provenance stamp. Do NOT edit a vendored copy in place — edit this original and
> re-copy. The companion hook is [`tools/session-start.hook.sh`](../tools/session-start.hook.sh).

---

## The mental model — you are NOT aware of other sessions

Multiple Claude Code (and human, and batch) sessions may run against this repo at once, on this
machine or another. **Assume it.** And be clear about a false intuition:

> "We're all Claude, so surely each session knows what the others are doing."

**It does not.** Each session is a **separate, stateless instance** — same model, no shared
memory, no live channel, no registry of running sessions to query. A session learns what another
session did **only by reading durable artifacts it left behind** — exactly the way a human would.
If it isn't written somewhere both sessions read, it does not exist to the other one.

Coordination is therefore **shared state on disk + discipline**, never telepathy.

## Two tiers of awareness

| Tier | What it covers | Channel |
|---|---|---|
| **1 — git-visible** | pushed branches, commits, merged work | `git fetch` + the startup scan below. Reliable. |
| **2 — NOT in git** | uncommitted edits, running jobs, "I'm about to overwrite this shared output," intent | a **machine-local session board** (below). Git is blind to all of it. |

The recurring failure is Tier 2: a session's best work sitting **uncommitted** in one machine's
working tree, invisible to every other session and one disk failure from gone.

## Startup checklist — BEFORE any work

1. **Read the repo's `CLAUDE.md`** (and this protocol).
2. **See who's active:**
   ```
   git fetch --all --prune
   git worktree list
   git branch -vv
   git log --oneline -8 --all
   ```
   Then read the **session board** (below).
3. **Work in your OWN worktree on your OWN branch** — never in a checkout another session may be
   using. One session ⇆ one worktree ⇆ one branch:
   ```
   git worktree add -b <task-slug> ../<repo>-worktrees/<task-slug> main
   ```
   (Worktrees live in a SIBLING dir *outside* the repo, so tooling never sees duplicate copies.)
4. **Claim any shared EXTERNAL output** (data dirs, render/export folders, anything outside git)
   on the session board before writing it.

## Branch & commit discipline

- **Push feature branches freely and promptly** — on creation (`git push -u origin <branch>`) and
  after commits. Never end a session, or go idle, with **unpushed commits**: single-copy work is
  one disk failure from lost. One branch ⇆ one worktree, so a feature-branch push is isolated and
  cannot collide with another session.
- **`main` is deliberate.** `git fetch` first; fast-forward or reviewed merge only; **never force**.
  Never commit on `main` directly — branch off it.
- **Never `rebase` / `reset` / force a shared (pushed) branch.** If two of your own sessions
  diverge on a branch, that is a human decision — surface it, don't resolve it by rewriting.
- If uncertain about any history-rewriting op, **stop and ask.**

## The session board (the Tier-2 ledger)

**The board is TWO files, and the split is the whole point.** A single machine-local board was
tried first and failed in a way worth carrying to any repo that adopts this: it *structurally*
cannot deliver a message to another machine.

- **`docs/SESSIONS.md` — in git.** Claims on shared external paths, exclusive-write claims,
  messages to another session, freezes, who is live where. **Default here.**
- **`../<repo>-worktrees/SESSIONS.md` — outside git, machine-local.** Only what genuinely cannot
  travel: live process ids, that box's free disk, local scratch paths.

The routing test is **not** "is this about my machine?" It is:

> **Can a session on another machine see, reach, or damage the thing you are claiming?**

Shared storage is the trap — a Dropbox or network mount is visible from *every* machine, so a claim
on it is cross-machine even though it feels local. Put it in git.

Each session:

- **adds a block at startup** — address (`<machine>/<branch>`), task, which external paths it will
  write, status;
- **marks it DONE on exit**, and releases any exclusive claim explicitly;
- **scans the board before writing any shared external output** — if an ACTIVE block claims it,
  use a different namespace or wait.

> **Evidence for the split, from the origin repo.** With a machine-local-only board: posts written
> on one machine addressed to the other were invisible to it, and an **exclusive write claim on a
> 127 GB canonical archive went unseen by the second machine for sixteen days.** Nothing was
> corrupted — but nothing prevented it either. The claim was real, correctly written, and unreadable
> from the only place it mattered.

## Durable knowledge lives in git, not machine-local memory

Machine-local Claude memory (`~/.claude/...`) does **not** sync between machines — it silently
diverges. Put durable cross-session / cross-project knowledge **in git**. Reserve memory for
genuinely per-machine facts (a drive letter, that box's role) — never project topology,
decisions, or task state.

### …and in `docs/`, not only in `CLAUDE.md` (Tony, 2026-08-04)

> *"CLAUDE.md is not reliable and sometimes gets ignored."*

`CLAUDE.md` is a **pointer, not a home**. It is long, it is read at a moment when there is
nothing to attach it to, and it gets skipped — so a rule that lives *only* there is a rule that
will eventually be missed. The ordering:

1. **Mechanize it** — a sapper rule, a git hook, a runnable check. Fires without anyone
   remembering. Always the first choice.
2. **Write a doc under `docs/`** — the full version, with the evidence and the cost, so a
   future session can act on it without having read `CLAUDE.md` at all.
3. **One line in `CLAUDE.md`** pointing at the doc. Never the detail itself.

Two failure modes this exists to stop, both observed here:

- **Pointers to files that are not on `main`.** Audited 2026-08-04: `CLAUDE.md` named
  `docs/FOUNDATIONS.md`, `docs/verification_gotchas.md`, `docs/style_conventions.md` and
  `tools/figcrop.py` — **all four existed only on feature branches**, so anyone working from
  `main` followed a link to nothing. `FOUNDATIONS.md` was the sharpest case: `CLAUDE.md`'s
  opening rule says to read it *and* tells the story of it having been missing once before.
  Land durable docs on a `main`-based branch, not on whichever branch you were standing in.
- **`CLAUDE.md` itself diverging per branch.** Same audit: 448–553 lines across branches, and
  `main` was missing the entire "read the foundations pair first" section that other branches
  had. Which rules applied depended on which worktree you were in. Prefer docs — additive and
  merge-friendly — over growing per-branch copies of one giant file.

**Mechanized:** `python tools/check_doc_links.py` reports every pointer in `CLAUDE.md` and
`docs/**` that names a file this branch does not have (exit 1 on findings; `--selftest` proves
it can still fire). It deliberately ignores vendored docs — `FOUNDATIONS.md` links to its home
repo's `docs/adr/*`, which is upstream's business, and including them buried the real findings
35-deep — and files that are gitignored by design. It is **not** wired into a hook yet, because
12 pre-existing orphans would block every commit; scope it to newly-added lines (the way
`sapper.sh` reads only what a commit ADDS) before gating on it.

Standing orphan list as of 2026-08-04 (run the tool for the current one): `pilot_no_sham.md`,
`TASK_sapper_rule_gaps.md`, `mlspike_param_review.md`, `murderboard_proposal_2026-07-29.md`,
`build_bakeoff_deck.py`, and four `foundations_md_audit.md` targets. Each lives on some feature
branch; each needs landing on `main` or its pointer corrected.

## Automate the scan — the SessionStart hook

[`tools/session-start.hook.sh`](../tools/session-start.hook.sh) runs the startup briefing
automatically at every session start/resume: current branch, an **unpushed / uncommitted alarm**
across all worktrees, the worktree list, recent commits, and the session board. It is
**self-configuring** (derives the repo name and the worktrees dir) and **deadline-bounded** (see
the warning below). Wire it in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup", "hooks": [ { "type": "command", "command": "bash .claude/hooks/session-start.sh", "timeout": 45 } ] },
      { "matcher": "resume",  "hooks": [ { "type": "command", "command": "bash .claude/hooks/session-start.sh", "timeout": 45 } ] }
    ]
  }
}
```

> **Do not drop the `timeout`, and do not let this hook get slow.** SessionStart hooks **block**
> initialization, and the SDK aborts the entire session at 60s with `Subprocess initialization did
> not complete within 60000ms` — an error that blames auth and network and will send you chasing
> the wrong thing for an hour. Exiting 0 is not enough: **"never fails" is not "never blocks."**
> A hook that always succeeds but returns too late takes the session down anyway.
>
> Set the hook `timeout` **above** the script's own `BUDGET` (so the script degrades loudly on its
> own terms first) and **below** 60 (so Claude Code kills the hook rather than the SDK killing the
> session). `timeout` is a sibling of `type`/`command` on the command object — not on the matcher,
> not on the `hooks` array.
>
> Cost scales with worktree and branch count, so a hook that is comfortable at 5 worktrees can be
> fatal at 32. Watch the `briefing took Ns` line the hook prints, and act when it climbs — do not
> wait for it to fail. Full incident writeup, including why the obvious fix (prune worktrees) did
> **not** work: interface2 `docs/postmortems/session-start-hook-timeout.md`.

## What this canNOT do (set expectations)

There is **no real-time channel** — you cannot ask "what is the other session thinking right now."
The tightest coupling available is **pushed state + the board, read at session start or on demand.**
Design around **checkpoints, not live sync.**

## Adopting this in a consumer repo (vendoring)

1. Copy `docs/session_protocol.md` and `tools/session-start.hook.sh` into the consumer (the doc
   under `docs/`; the hook into `.claude/hooks/session-start.sh`).
2. Add a **line-1 provenance stamp** to each copy: `vendored from interface2 @ <short-sha>`.
3. Add the `SessionStart` hook block above to the consumer's `.claude/settings.json`.
4. **To update:** re-copy both files and bump the stamp; `git diff` shows exactly what changed.

Repos may keep their OWN extensions on top of the vendored hook (interface2 does — its
`.claude/hooks/session-start.sh` adds repo-specific landmine scans). Keep the vendored core intact
and layer local additions around it, so the shared part stays re-copyable.
