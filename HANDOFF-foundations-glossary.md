# Session handoff — cross-repo foundations/glossary

**Purpose of this file:** a working handoff so a *new* Claude session can continue
without re-deriving context. It is not a canonical murderboard doc — delete it once the
work it describes is done. It currently lives on branch `claude/agent-review-bmz5fs`
(the same branch as PR #1); if a new session lands on the default branch and can't see
it, check out that branch or have the human point you here.

Written 2026-07-22.

---

## The goal

The main project spans several repos:

- **interface2** — on **GitLab** (the origin project; first consumer of the murderboard).
- **fireflies** — on GitHub (`syncytium2`), the R analysis app.
- **colonel_kernel** — on GitHub (`syncytium2`), referred to as "kernel."
- **murderboard** — on GitHub (`syncytium2`), the shared *anti-slop* tooling that the
  others vendor (this repo).

Claude sessions repeatedly get **fundamental, project-central concepts wrong**. To fix the
most annoying failures, the team wrote a **glossary + foundations document** — it currently
lives in **colonel_kernel**. The problem to solve: **it is not yet a "global" document that
every Claude session (across all these repos) reliably reads.**

## What we concluded this session (strategy — carry these forward)

1. **There is no true cross-repo "global" CLAUDE.md.** What a session auto-loads is the
   *working repo's own* `CLAUDE.md` (reliable; covers teammates + web/cloud sessions), and
   optionally `~/.claude/CLAUDE.md` (per-user-per-machine — does **not** cover collaborators
   or fresh cloud containers, so not a real global). Therefore "global" in practice means:
   **present in, or pointed-to by, every repo's `CLAUDE.md`.**

2. **This is the same problem the murderboard already solves via vendoring** — canonical
   source in one repo, copied into each consumer with a provenance stamp
   (`vendored from <repo> @ <sha>`), plus a **drop-in `CLAUDE.md` paragraph** that makes the
   session load-bear on the doc. Reuse that machinery for the foundations/glossary.

3. **Do NOT put the foundations/glossary *inside* murderboard.** Murderboard is deliberately
   **project-neutral** (its CLAUDE.md forbids project names/paths/domain jargon in the core).
   The foundations/glossary is **project-specific truth** — the opposite. Same vendoring
   *mechanism*, but a **separate artifact with its own home**. Mixing them would poison the
   neutral core.

4. **Framing that fits the existing worldview:** the murderboard already forbids reasoning
   about *papers* from memory (the lit-cache protocol: "get the text or flag the paper").
   The foundations doc is that same rule applied to *project concepts* — don't reason about
   core concepts from priors; ground in the doc.
   `foundations.md : project concepts :: lit-cache : papers`.

## Open decision (needs the human)

**Where should the canonical foundations/glossary live?**
- **interface2** — the domain's origin/truest source, but on GitLab, so GitHub-hosted
  consumers would vendor copies rather than reference it live.
- **colonel_kernel** — where it lives today; keep as canonical, vendor into the others.
- **a new dedicated repo** (sibling to murderboard) whose only job is to be vendored
  everywhere — cleanest ownership, one more repo to maintain.

No decision was made. Recommendation was to **read the existing doc first**, then choose.

## Why this couldn't be finished in the originating session

The originating session was scoped to **`syncytium2/murderboard` only**, and could not read
colonel_kernel. Every avenue dead-ended:
- `mcp__github__*` API tools → hard-denied (`Allowed repositories: syncytium2/murderboard`).
- `git clone` via the session proxy → prompted for a password it can't supply (proxy scoped
  to murderboard).
- `add_repo` (the in-session scope-widening tool) → returned `-32003 requires approval`, but
  the approval prompt never rendered on the human's surface.

This is a **session-scoping / surface issue, not a GitHub-auth issue** — the account is
authorized; the session just wasn't started with colonel_kernel as a source.

## What the NEW session needs (setup)

**Start the session with BOTH `syncytium2/murderboard` AND `syncytium2/colonel_kernel` as
source repos** (ideally `fireflies` too). Select them in the repo/source picker when creating
the Claude Code web session — do not rely on `add_repo` mid-session (that's what failed).

## First tasks for the new session

1. Locate and read the **foundations + glossary** doc(s) in colonel_kernel (grep for a
   `glossary`/`foundations`/`concepts` file; check `docs/`, repo root, and any `CLAUDE.md`).
2. **Evaluate** them against:
   - **Coverage** — do they actually cover the concepts Claude keeps getting wrong? (Ask the
     human for the specific recurring failures if not obvious from the doc.)
   - **Structure** — glossary (term → definition) vs foundations (conceptual grounding);
     are both present and is the split clean?
   - **Does it load-bear in-session?** — is it written so a session *acts* on it, or is it
     passive reference? Is anything in a `CLAUDE.md` forcing it to be read?
   - **Portability** — what would it take to make it a **vendored cross-repo artifact**
     (project-neutral phrasing where possible, provenance stamp, a reusable drop-in
     `CLAUDE.md` paragraph)?
3. Report findings + a recommendation on the **canonical home** (open decision above), then
   propose the wiring (vendor vs reference, and the drop-in paragraph).

## Status of the murderboard work already done (PR #1)

Independent of the above, this branch (`claude/agent-review-bmz5fs`, PR
`https://github.com/syncytium2/murderboard/pull/1`) already contains completed work on
`doc_review_process.md`:
- Gave the seven review-team agents **aggressive codenames**: 1 **Prove It**, 2 **DOI or
  Die**, 3 **Cross-Examiner**, 4 **Reviewer 2**, 5 **Kill Your Darlings**, 6 **RTFM**,
  7 **Reinventing the Wheel**. Cross-references re-anchored on the names.
- Removed two calcium-imaging tokens that had leaked into the core (`mean firing rate` →
  `mean rate`; axis example `dF/F_0` → `signal (a.u.)`), keeping domain origin in the
  appendix only.
- Added a one-line boundary between **Reviewer 2** and **RTFM** on unjustified constants.

That work is finished and unrelated to the foundations/glossary task — mentioned only so the
new session isn't surprised by the branch contents.
