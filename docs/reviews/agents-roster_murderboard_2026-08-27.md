# The gate built to catch unfalsifiable checks shipped as one

`murderboard_agents.py verify` was added to this branch with a claim attached, written into
`CLAUDE.md`, `skills/murderboard/SKILL.md` and a public pull request: *a run where the reviewers
had none of their tools cannot pass as one where they did.*

Role 4 constructed the failure that claim denies. It takes four lines:

```
- roles: 11 of 11 run (named agents)
GRANT 1 ok — nothing whatsoever, I hold no tools
... ×11
→ "all 11 roles declared a grant (11 ok, 0 mismatch), and the header agrees"   exit 0
```

`GRANT_LINE_RE` captures the role number and the word `ok`. Everything after the em dash — the
tool list, the entire substance — is discarded, and never compared against the grants table the
same program parsed moments earlier. Role 1 then walked it from the other side: eleven rows of
`GRANT n MISMATCH — missing everything` under an `(inline fallback)` header also exits 0.

The gate cannot fail in the direction it was written for. That is `doc_review_process.md`'s own
rule — *"a check that cannot fail is not a check, and the danger is that it PASSES"* — violated
inside the tool written to enforce it, by the person who wrote the rule down two commits earlier.

Worse than the defect is that the compiler's `--selftest` **asserts the weaker behaviour on
purpose**: `"the same MISMATCH under a 'fallback' header PASSES"`. The design was always narrower
than the sentence advertising it. The two were never reconciled, and nothing would have noticed.

## What this run was

The first live exercise of the compiled review team, run as a new user's session would run it:
paths resolved without assumption, freshness gated, roster derived, agent files compiled and
checked, then eleven reviewers spawned — each reading only its own compiled file.

**Every one of the eleven declared `GRANT n MISMATCH`.** None parroted back the grant it was told
it should hold. Each named the editing tools it had been handed — `Edit`, `Write`, `NotebookEdit`
— that the process file forbids every reviewer, and each stated it had edited nothing. The
declaration mechanism works. The gate reading those declarations does not.

## Run record

- upstream:  syncytium2/murderboard @ e749eba
- copy:      vendored @ e749eba
- freshness: UNDETERMINED (`no vendored copy found` — this is upstream; exit 2 by design)
- artifact:  `73dad04..HEAD`, 24 files, +2302/-15. `doc_review_process.md` 5ba71a5,
             `murderboard_agents.py` 7e29ae1, `SKILL.md` bc55c87, `README.md` 9370d76,
             `CLAUDE.md` 6f79d34, `agents/` tree d0a5f21
- roles:     11 of 11 run (inline fallback)
- rounds:    0 blind verify rounds — fixes not yet applied

### Role ledger

| # | role | grant declared | findings |
|---|---|---|---|
| 1 | Prove It | GRANT 1 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit | 12 + 14-row claim ledger |
| 2 | DOI or Die | GRANT 2 MISMATCH — missing Grep, Glob; holds Write, Edit | 5, + 4 external mechanics confirmed |
| 3 | Cross-Examiner | GRANT 3 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit | 12 |
| 4 | Reviewer 2 | GRANT 4 MISMATCH — missing Grep, Glob; holds Write, Edit, NotebookEdit | 11 |
| 5 | Kill Your Darlings | GRANT 5 MISMATCH — missing Grep, Glob; holds Edit, Write | 19 |
| 6 | RTFM | GRANT 6 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit | 9 |
| 7 | Reinventing the Wheel | GRANT 7 MISMATCH — missing Grep, Glob; holds Write, Edit | 10 |
| 8 | You Lost Me | GRANT 8 MISMATCH — missing Grep, Glob; holds Edit, Write | 20 + per-unit verdict |
| 9 | Show, Don't Tell | GRANT 9 MISMATCH — missing Grep, Glob; holds Edit, Write | 9 + measurement table |
| 10 | Ship It | GRANT 10 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit | 7 + 45-row run table |
| 11 | Start With the Problem | GRANT 11 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit | 13 |

## Blocking — reproduced by hand, not merely reported

**B1 · `verify` has no power over the case it names.** Above. Fix: parse the declared tool list
and set-compare against `grants[n]["tools"]`; a forbidden tool present is a hard fail regardless
of the word the reviewer chose. Until then, soften the claims in `CLAUDE.md`, `SKILL.md` and the
PR body to what the gate does: *a report that does not carry a grant declaration for every role
cannot pass as one that does.*

**B2 · `write` destroys a consumer's own subagents.** — **REPAIRED 2026-08-28 in `869fc23`.**
Ownership is now read from the file's content (a generated banner), never from its name or its
directory; `check` no longer counts a foreign file as an orphan, so the unattended `check || write`
has nothing left to trigger. Two selftest assertions had to be **flipped** — they had been green
since the tool was written and were describing the deletion as correct. That is now a rule in
role 4's checklist and an incident in the appendix. Original finding, unedited: Every consumer-facing instruction points
`--dir` at `.claude/agents`, the *shared* project agents directory. The orphan sweep unlinks every
`*.md` it did not generate, and `SKILL.md` step 4a runs `check || write` unattended on every
review. Reproduced:

```
BEFORE: my-own-agent.md  team-deploy-bot.md
        removed my-own-agent.md
        removed team-deploy-bot.md
AFTER:  (only the eleven remain)
```

Fix: scope the sweep to files carrying the generated banner. Nothing else in that directory is
the compiler's to remove.

**B3 · A real MISMATCH can be laundered into `ok`.** `declared[n] = v` inside `finditer` is
last-write-wins, and **every compiled agent file contains the literal line
`GRANT 4 ok — Read, Grep, Glob, Bash`**. Any later quotation flips an honest MISMATCH clean. The
selftest missed it because the process-file template uses `<n>` placeholders; the compiled files
substitute real digits. Fix: MISMATCH is sticky, or a role declaring both is a hard failure.

## High

| # | finding | found by |
|---|---|---|
| H1 | Compiled files carry pointers to material that never arrives: `10-ship-it` ×3, `11` ×1, and roles 2 and 6 told to "follow the lit-cache protocol **below**" — no such section, and `fetch_paper.py` appears in zero agent files | 2, 5, 8, 11, 3 |
| H2 | `11-start-with-the-problem.md` carries "Where the weight falls" — team-wide prose about roles 6, 7, 9 — swallowed by the slice boundary. Refutes the compiler's central promise, in one file of eleven | 1, 3, 5, 8, 11 |
| H3 | Path 3 (role block from `$PROCESS`) can *never* pass the gate: the block contains the checklist but not the grant-declaration instruction, so that role emits no `GRANT` line. "All three paths run the same eleven roles" is true and misleading | 9 |
| H4 | Two sources for a role's nickname — `roster.sh` reads the role title, the compiler reads the grants table — and nothing reconciles them | 7 |
| H5 | The roster parse was reinvented. `murderboard_prompt.sh:50-64` is the in-repo precedent: it shells out to `roster.sh` with the reason written down. The two parsers already disagree on a repeated `## The review team` heading, so "scoped exactly like `murderboard_roster.sh`" is false | 7 |
| H6 | Five agent `description:` fields open with *"Spawn for / Spawn whenever…"* — a **conditional**, in the field a harness reads to decide whether an agent applies, contradicting "every role runs on every deliverable" | 1, 3 |
| H7 | The Bash paragraph partitions roles as `{1,4,7,9,10}`; the table ten lines below also grants Bash to 2 and 6. The authority contradicts itself, and the compiler reads only the table | 1, 3, 5, 9 |
| H8 | `docs/index.html` is live, unchanged, and now wrong: three gates, three scripts, no compiler in the vendor list or the adoption recipe | 1, 3, 8 |
| H9 | `README.md` adoption step still says "the **four** tools under `tools/`"; the install inventory omits the review team | 8 |
| H10 | *"every word in them is sliced out of `doc_review_process.md`"* — false. 294 words per file are generated by the compiler, and several are rules that live **only** there | 1 |
| H11 | *"two copies of the published page, drifted"* — unsubstantiated. Git shows one explainer, renamed. The real incident is the page drifting from the **process file**. Repeated in code, `CLAUDE.md`, two commits and a public PR | 2 |
| H12 | Docstring gap 3, *"the team was invisible"* — false. `murderboard_roster.sh list` already printed all eleven. The true gap is that they were listable but not spawnable | 5 |

## Medium and below — recorded, not enumerated here

`grants=1` printed when no compiler is vendored (a gate that never ran reported as one that
failed); `NAMED_MODES` substring matching that both fails open on `(named subagents)` and fails
closed on an honest `(inline fallback — named agents did not resolve)`; `ROLES_LINE_RE` capturing
counts it never checks; an unguarded `read_text` turning a non-UTF-8 file into a traceback exiting
1; consumer commands missing `python3` and `tools/`; the CI `check` hint missing `--dir`; the
`AGENTDIR` heuristic testing "is a plugin" rather than "is the murderboard"; `MultiEdit` forbidden
by the test but not by the process file; the stdlib gate not covering the new tool; the revendor
stamp corrupting agent frontmatter if ever added to a vendor config; symlinks on a Windows clone;
hardcoded "eleven" in a skill that boasts of picking up role 12; "three gates" in two files that
now ship four; and every existing record in `docs/reviews/` failing the new gate with nothing
marking them grandfathered.

Role 9's measurement: **every one of the eleven files puts its unique payload last**, eight below
50%. `05-kill-your-darlings.md` is 96% shared boilerplate wrapped around a 29-word checklist.

## What held up

Role 10 ran 45 checks and every gate is green: the compiler's 32-case selftest, all eight repo
tests, all five gate selftests, `agents/` byte-identical to a fresh compile, all eleven
frontmatters parsing under a real YAML parser and agreeing with the grants table, both manifests
at 0.2.0, and the version-bump gate passing on the real diff. It cloned the repo fresh: **both
symlinks resolve and 13/13 tests pass for a stranger**. It ran the consumer path end to end in a
simulated consumer repo and the eleven files compiled into `.claude/agents/` correctly.

Roles 2 and 6 independently confirmed from the documentation the four mechanics the design rests
on: plugins auto-load `agents/` at plugin root; `.claude/agents/` is the project path and
*outranks* a plugin's copy; the frontmatter contract is right; `model: inherit` is valid. Role 2
added that symlinks resolving inside a plugin root are preserved in the install cache — so both
new symlinks are safe — and that creating a scope's **first** agent file in a **new** directory
requires a restart, which is exactly what the README tells consumers to do.

## Residual ⚠

- **⚠ Path 1 is untested.** No run has yet spawned a *registered* murderboard agent. Whether a
  named subagent actually receives its restricted tool set is unverified; this run is one
  datapoint and it is a MISMATCH.
- **⚠ Nobody was asked.** No one consulted Anthropic or the plugin-authoring community on whether
  compiling agent files at skill-invocation time is a supported pattern or fights the watcher.
  One question would settle it faster than the web searches that were run.
- **⚠ Literatures searched.** Official Claude Code docs and the `anthropics/claude-code` issue
  tracker. Not searched: the Agent SDK reference, marketplace schema changelogs, versioned docs.
- **⚠ Cross-scope name collision.** With the plugin installed and this repo open, eleven agent
  *names* exist in two scopes. Precedence is documented; that the two sets stay identical is
  asserted by no test.
- **⚠ This was not a blind pass.** The same session wrote the artifact and briefed the reviewers.
  The process requires a blind pass first; this run did not have one.
