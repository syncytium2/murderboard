<!-- vendored from interface2 @ 7065f5e — canonical source; do NOT edit here, update upstream (interface2 docs/session_protocol.md) and re-copy -->
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

A plain file **outside the repo and NOT in git** — e.g. `../<repo>-worktrees/SESSIONS.md`. It is
machine-local on purpose: it tracks this machine's *live* state and the shared *external* paths git
can't see. Each session:

- **adds a block at startup** — id, branch, task, which external paths it will write, status;
- **marks it DONE on exit;**
- **scans the board before writing any shared external output** — if an ACTIVE block claims it,
  use a different namespace or wait.

## Durable knowledge lives in git, not machine-local memory

Machine-local Claude memory (`~/.claude/...`) does **not** sync between machines — it silently
diverges. Put durable cross-session / cross-project knowledge **in git** (a short rule in
`CLAUDE.md`, or a doc under `docs/`). Reserve memory for genuinely per-machine facts (a drive
letter, that box's role) — never project topology, decisions, or task state.

## Automate the scan — the SessionStart hook

[`tools/session-start.hook.sh`](../tools/session-start.hook.sh) runs the startup briefing
automatically at every session start/resume: current branch, an **unpushed / uncommitted alarm**
across all worktrees, the worktree list, recent commits, and the session board. It is
**non-blocking** (never fails a session) and **self-configuring** (derives the repo name and the
worktrees dir). Wire it in `.claude/settings.json`:

```json
{
  "hooks": {
    "SessionStart": [
      { "matcher": "startup", "hooks": [ { "type": "command", "command": "bash .claude/hooks/session-start.sh" } ] },
      { "matcher": "resume",  "hooks": [ { "type": "command", "command": "bash .claude/hooks/session-start.sh" } ] }
    ]
  }
}
```

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
