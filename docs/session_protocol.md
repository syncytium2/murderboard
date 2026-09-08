<!-- canonical source: syncytium2/murderboard docs/session_protocol.md — edit HERE, then re-copy into consumers -->
# Session protocol — multi-session coordination

> **Canonical source.** This file lives canonically in **`syncytium2/murderboard`**
> (`docs/session_protocol.md`) and is **vendored** into consumer repos with a line-1 provenance
> stamp. Do NOT edit a vendored copy in place — edit this original and re-copy. The companion
> hook is [`.claude/hooks/session-start.sh`](../.claude/hooks/session-start.sh).
>
> **Where it came from.** This protocol was written in a *private* repo (`interface2`) and
> vendored here at `6e8aff6`. Murderboard adopted it as canonical on 2026-08-21, when this repo
> went public: a stamp pointing at a repo the reader cannot open is not provenance, it is a dead
> end. The older stamps remain in this file's git history, unaltered.
>
> Be precise about what a private upstream breaks, because the imprecise version of this
> sentence shipped here first and had to be corrected. `murderboard_freshness.sh --clone` will
> resolve a private upstream from a local checkout, so on the author's own machine the gate
> answers `0`/`1` normally — and that is the trap. Everywhere else there is no checkout and no
> route to a private host, so the answer is `2` (unknown), which in `--hook` mode is **silent**.
> A private upstream does not disable the gate; it makes the gate answer for one person and say
> nothing to everyone else, which is harder to notice. And what `--clone` compares against is a
> working copy's `HEAD` — whatever is checked out at that moment — not a published ref.

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
- **`../<repo>-worktrees/SESSIONS.md` — the machine-local board.** Only what genuinely cannot
  travel: live process ids, that box's free disk, local scratch paths.

  ⚠ **This path is not guaranteed to be outside git, and until 2026-09-04 this line said it was.**
  On that date four repos in this estate had it replaced with a **symlink into a private
  coordination repo**, because the boards were 678 KB across six repos on one disk with no Time
  Machine destination and no cloud sync — nothing to restore from. Reads and appends pass through
  a symlink unchanged, and the SessionStart hook derives this path rather than hardcoding it, so
  nothing needed to know. **The routing test below is unaffected: it asks what the content is, not
  where the file sits.** But do not assume this file is unversioned, and never put something here
  on the strength of it being invisible.

  **OPEN, and deliberately not resolved here — how the split reads for a PUBLIC consumer.** The
  rule above sends claims to `docs/SESSIONS.md` *in the repo's own git*, which for a public repo
  means **publishing them** — and claims name shared external paths, which may be private repos or
  a shared drive. This protocol was written in a private repo (`interface2`) and does not address
  the case. `syncytium2/murderboard` is public and consequently has **no** in-git board at all, so
  it is not running this split; that is the gap, not an oversight to tidy. Resolving it is a
  decision about the protocol, not an edit to it.

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

**Worth mechanizing** — a link checker that reports every pointer in `CLAUDE.md` and `docs/**`
naming a file the current branch does not have (exit 1 on findings, plus a `--selftest` so it
can be shown to still fire). Two things that only became obvious once one existed:

- **Exempt vendored docs.** A vendored file links into *its home repo's* tree, which is
  upstream's business, not this branch's. Including them buried the real findings 35-deep.
- **Scope it to newly-added lines before gating on it.** Any repo with a backlog of orphaned
  pointers will have every commit blocked on day one, and the gate gets disabled instead of
  obeyed.

> Not shipped with murderboard — this describes a tool worth writing for your own repo, not
> one you can copy from here.

## Automate the scan — the SessionStart hook

[`.claude/hooks/session-start.sh`](../.claude/hooks/session-start.sh) runs the startup briefing
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
> wait for it to fail. The obvious fix — prune worktrees — did **not** resolve it; the rule that
> came out of the incident is the one stated in the hook's own header: bound the WHOLE script
> with a deadline, because per-call caps multiply.

## What this canNOT do (set expectations)

There is **no real-time channel** — you cannot ask "what is the other session thinking right now."
The tightest coupling available is **pushed state + the board, read at session start or on demand.**
Design around **checkpoints, not live sync.**

## Adopting this in a consumer repo (vendoring)

1. Copy `docs/session_protocol.md` and `.claude/hooks/session-start.sh` into the consumer (the
   doc under `docs/`; the hook into `.claude/hooks/session-start.sh`).
2. Add a **line-1 provenance stamp** to each copy:
   `vendored from syncytium2/murderboard @ <short-sha>`.
3. Add the `SessionStart` hook block above to the consumer's `.claude/settings.json`.
4. **To update:** re-copy both files and bump the stamp; `git diff` shows exactly what changed.
5. **Check staleness mechanically** rather than remembering to:

   ```bash
   bash murderboard_freshness.sh --hook --label session-protocol \
        --file docs/session_protocol.md --file .claude/hooks/session-start.sh
   ```

   Wire that into the consumer's own `SessionStart` block, so a stale copy announces itself
   instead of silently omitting rules you have already paid for.

Repos may keep their OWN extensions on top of the vendored hook — a consumer's
`.claude/hooks/session-start.sh` can add repo-specific scans around the shared core. Keep the
vendored core intact and layer local additions around it, so the shared part stays re-copyable.
