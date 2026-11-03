# Murderboard run — PR #80, the lookup probe

**What was at stake.** On 2026-10-14 a consumer's murderboard run had no way to reach the web.
Its project settings denied WebFetch, `curl` and `wget`. The citation reviewer (role 2) and the
methods reviewer (role 6) both said so on their first line, the run carried on anyway, and every
end-of-run gate passed ([issue #74](https://github.com/syncytium2/murderboard/issues/74)).
PR #80 makes that a stop: a lookup probe before the fan-out, a `Lookup:` line in the record that
the roster gate reads, an `unreached:` count the gate reads in the role reports, a scan that
names the blocking setting, and a site entry. The probe text goes to every consumer that
vendors the process, and the site entry goes live on merge.

**What the review found, in the order it mattered.**

1. **The first probe could be passed without any lookup.** Its real DOI was the most-cited paper
   in metascience, and its fake DOI's suffix read `murderboard-probe-0000`. Roles 1, 2, 4 and 6
   each found this independently in round 1. The redesign drew a little-cited DOI at random,
   made a fresh fake DOI per run, and added a documentation-page item for role 6.
2. **Hiding the answers did not close the gap either.** Blind round 1 found the answer key in a
   file the probed agent can read. Hashing the key fixed that. Then blind round 2 showed a model
   recalling all six RFC titles, so that the hash became an oracle for checking a guess, and
   found every probe reply sitting in the session transcript. **Decision (Tony, 2026-10-22):**
   the probe is scoped to what #74 actually was, an agent that *honestly* cannot reach its
   sources. Every surface now says the probe checks equipment, not honesty.
3. **The original diagnosis was wrong.** This PR first said nothing on disk recorded the
   missing tools. Role 1 found the consumer's committed settings denying all three since
   2026-05-15. The scan now finds exactly that shape, and the claim is gone.
4. **The gate kept failing open on line forms.** A bulleted `- Lookup: unavailable`, a numbered
   `1)`, a table row, an unclosed fence, `unreached` in bold or behind `+`. It also read a
   `live` record over a probe that failed every item as clean. Each round found more, and
   each is now a selftest case: roster 59 → 115, scanner 9 → 40.
5. **The public page's table broke.** A longer exit label in a no-wrap cell grew the gates
   table from 1,571 to 4,963 px tall at desktop width (blind round 1, role 10, measured in
   headless Chrome). It is back to its original length.

**What would validate it.** The next consumer run behind a deny list like #74's should stop at
the probe and name the rule. A run with a working route should pass the probe, and the gate
should accept its live record together with its `00-lookup-probe.md`. A record declaring the
route unavailable, or whose role 2 counts unreached sources above zero, should fail.

**How it generalizes.** A missing tool is a finding, and a missing capability is a stop. That
is scoped here to the one capability a probe can test before the fan-out. Another role losing
its capability (role 1 without a shell) remains a residual.

## Residual ⚠ for the human

- ⚠ **Blind round 3 was not clean, and its fixes have not had a blind pass.** The user's
  instruction was one confirming round, then ship. Round 3 found parser edge forms, a `live`
  record over a failed probe, and message wording, all fixed after it with selftests. No
  fresh reviewer has read the result.
- ⚠ **By design, the probe cannot catch an agent that guesses or invents answers.** Stated in
  the process file, the skill, the drop-in paragraph, the appendix and the site entry.
- ⚠ **A role report with no `unreached:` line passes.** The checklist requires the line, and
  the gate reads it when it is present. A selftest asserts this residual, so it cannot change
  unnoticed.
- ⚠ **A connector grant makes the process file a locally adapted file**, merged by hand on
  every re-vendor. A grant read from the consumer's own config is not built.
- ⚠ **Pre-existing, noted and not fixed here:**
  - the subagent scan treats an allow-list without `Task` as a blocker, against the permissions
    documentation;
  - `DESCRIPTION-for-claude.md` describes neither probe;
  - the page's roster exit label and its 390 px table layout.
- ⚠ **The review archive is a redacted copy.** Local paths were replaced; the unredacted
  originals are kept outside the repository. The archive is named with a hyphen because the
  underscore bug PR #79 fixes is not merged here.
- ⚠ **The page's Updated date is 2026-10-22.** Re-date it, with the sitemap, if this merges
  on another day.
- ⚠ **This run's own probe.** The round-1 fan-out followed a probe on the *original* design,
  archived as `probe-round1-old-design.md`. The final-design probe in `00-lookup-probe.md` ran
  later in the run.

## Run record

- upstream:  syncytium2/murderboard @ 682c31b (origin/main)
- copy:      the canonical checkout, branch lookup-probe (PR #80)
- freshness: UNDETERMINED — the gate has no vendored stamp to read in the canonical repo; the branch is 0 commits behind origin/main
- artifact:  PR #80 —
             doc_review_process.md (9e44ee905005 -> fa1487f9b2e3)
             skills/murderboard/SKILL.md (99ab54cca9d1 -> d6b3d87f7829)
             murderboard_roster.sh (ba1da4e1e5ad -> 14bcd4f75992)
             murderboard_subagents.sh (0d846b83e607 -> 99d4122de4f7)
- roles:     11 of 11 run (inline fallback for roles 2, 4, 5, 8; spawned by registered name for the other seven)
- reports:   lookup-probe-pr80-2026-10-22-roles/
- rounds:    3 blind verify rounds (roles 1, 3, 4, 8, 10 each, fresh reviewers); the third was not clean, and its fixes were applied after it

Mode: standard
Execution: subagents — eleven in round 1, five fresh reviewers in each blind round
Lookup: live — curl to doi.org, Crossref and rfc-editor.org; roles 2 and 6; probe 10.1000/de7821441222

## Role ledger (round 1)

| # | role | grant, as declared | report |
|---|---|---|---|
| 1 | Prove It | GRANT 1 MISMATCH — missing Grep, Glob; holds no forbidden tools (held: Read, Bash, SubagentHandback) | `01-prove-it.md` |
| 2 | DOI or Die | GRANT 2 MISMATCH — missing Grep, Glob; holds Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch / __update (editing tools); WebFetch and WebSearch were deferred and loaded through ToolSearch; the bio-research PubMed connector was also loadable and used. No file was edited, written or deleted, and the scratch directory was not used. This reviewer was spawned through the fallback path, which belongs in the ledger. Losing Grep and Glob cost nothing, because I searched through Bash. | `02-doi-or-die.md` |
| 3 | Cross-Examiner | GRANT 3 ok — Read, Grep, Glob | `03-cross-examiner.md` |
| 4 | Reviewer 2 | GRANT 4 MISMATCH — missing Grep, Glob; holds Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch, mcp__claude_ai_Claude_Docs__update, mcp__claude_ai_Claude_Docs__guide, SubagentHandback. Through ToolSearch I could also have loaded deferred tools, including NotebookEdit, WebFetch, WebSearch and the Gmail and Dropbox write tools. | `04-reviewer-2.md` |
| 5 | Kill Your Darlings | GRANT 5 MISMATCH — missing Grep, Glob; holds Bash, Edit, Write, Agent, Skill, ToolSearch, Artifact, mcp__claude_ai_Claude_Docs__batch/update/guide | `05-kill-your-darlings.md` |
| 6 | RTFM | GRANT 6 MISMATCH — missing Grep, Glob; holds no forbidden tools (I have Read, Bash, WebSearch, WebFetch, plus the SubagentHandback harness tool) | `06-rtfm.md` |
| 7 | Reinventing the Wheel | GRANT 7 MISMATCH — missing Grep, Glob; holds Read, Bash, SubagentHandback (no editing tool held: no Edit, Write or NotebookEdit) | `07-reinventing-the-wheel.md` |
| 8 | You Lost Me | GRANT 8 MISMATCH — missing Grep, Glob; holds Bash, Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch, mcp__claude_ai_Claude_Docs__update (plus deferred WebFetch, WebSearch, NotebookEdit and others reachable through ToolSearch) | `08-you-lost-me.md` |
| 9 | Show, Don't Tell | GRANT 9 MISMATCH — missing Grep, Glob; holds no forbidden tools (Read, Bash, SubagentHandback) | `09-show-dont-tell.md` |
| 10 | Ship It | GRANT 10 MISMATCH — missing Grep, Glob; holds none forbidden (held: Read, Bash, SubagentHandback) | `10-ship-it.md` |
| 11 | Start With the Problem | GRANT 11 ok — Read, Grep, Glob | `11-start-with-the-problem.md` |

Every reviewer lacked Grep and Glob, which this session does not hold for any subagent; each searched through Bash instead. The four fallback roles also held editing tools no reviewer may have, and each reports using none. Blind-round reports are in `verify-1/`, `verify-2/` and `verify-3/` of the archive.
