> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 11 ok — Read, Grep, Glob

**Argument order: PR #80 (branch lookup-probe)**

I read each added section in place in `<worktree>/doc_review_process.md` and `<worktree>/skills/murderboard/SKILL.md`, using `<scratch>/mb/pr80.diff` to find them. I could not read the PR description, so it is not reviewed.

**Arc I judged against:** a runbook arc. For each instruction: the problem the reader is in → the rule → how to do it → how to tell pass from fail → what to do on each outcome. Appendix entries use the incident-log arc instead: what happened → why the gates missed it → the lesson.

### Spine of the compile-and-spawn section in SKILL.md (one claim per paragraph, as it now reads)
1. Compile the agent files first, because a stale file is a reviewer running an old checklist.
2. Probe the lookup with role 2's (DOI or Die) own agent before any role is spawned, because a role that cannot reach its sources still writes a full report (issue #74).
3. Send this exact probe prompt: one real DOI, one made-up DOI.
4. It passes only if both answers are right. The made-up DOI is the real test.
5. Any route counts, and one probe covers both roles that share the grant.
6. If both are right, record `Lookup: live` and carry on. Anything else stops the run before role 1: run the scanner, give the human the remedies, and "go ahead" cannot buy a passing record. The only honest way to skip the probe is a deliverable with nothing to look up.
7. The probe counts as a spawn for the cost gate, so it runs after the cost preflight.
8. Spawn each role by name, or use the fallback.
9. Expect the fallback on a repo's first run.
10. Path 3 cannot satisfy the grants gate.
11. Record which path you used.
12. Carry GRANT lines into the ledger. A MISMATCH is not a failure, except that a lookup failure has already stopped the run at the probe.
13. Scale to stakes in how roles run, not which ones.
14. A role with nothing to check still says what it checked.

**Cold open of the new block:** "Then probe the lookup…", and the problem follows in the next sentence. The rule comes first and the problem one sentence later, the same pattern as the subagent probe at the start of the skill. That is acceptable. The probe also sits where it should for someone running the steps in order: after compiling (it needs role 2's `agent-name` from `list`) and before the spawn. The old text after it ("Then spawn each row's…", the first-run fallback, the GRANT paragraph) still reads in order, and the new closing sentence of the GRANT paragraph is a correct back-reference.

### Findings

| # | Location | Issue | Severity | Suggested fix | Verified against source? |
|---|---|---|---|---|---|
| 1 | SKILL.md, compile-and-spawn section, lines 259–261 against 301–315 | The probe has to be spawned "by the same path the review will use", but which path that will be is only explained afterwards: named agent or fallback (301–303), "Expect the fallback on a repo's FIRST run, always" (305–310), and path 3 emitting no GRANT line (312–315). Someone running in order spawns role 2 before learning the named agent usually won't resolve on a first run. If it doesn't resolve, they have no instruction for the probe's own fallback. | Medium | Move the three path paragraphs (spawn by name and the fallback, first run, path 3) up to sit between the compile block and the probe. Or add one sentence to the probe: "if the name does not resolve, use the fallback below, the same one the roles will get". | yes |
| 2 | SKILL.md lines 294–296; process file lines 164–175 against 1335–1337 | The condition for skipping the probe ("nothing to look up … records `Lookup: not needed`") is the last sentence of the *failure* branch, after the prompt, the pass test and the stop. A reader decides whether to probe at all only after doing it. In the process file the review-step bullet never mentions the skip. It first appears in the output contract, about 1,150 lines later. | Medium | Put the skip condition right after the problem statement in both places: "If the deliverable cites nothing, names no attribution and rests on no outside method, record `Lookup: not needed` and skip this. Otherwise…". | yes |
| 3 | SKILL.md probe block, read against the subagent probe (lines 174–211) and the scale-to-stakes paragraph (329–340); process file lines 155–175 | The sequence can send a reader to a step they cannot do. When the subagent probe fails and the run goes single-pass (forced), the lookup probe still says to spawn role 2's own agent. That is impossible without subagents. The attribution case is already stopped earlier, but a deliverable with an outside method for role 6 (RTFM) and no attribution claim reaches the lookup probe with nothing it can follow. (The logic gap is also Reviewer 2's territory. I log it because the order is what exposes it.) | Medium | Say where the forced single-pass run does its lookup check: the main thread runs the same two-DOI prompt itself and records the route. Or say that forced single-pass with anything to look up does not proceed. | yes |
| 4 | Process file, grants section, connector paragraph (lines 943–949) | "A connector reaches a role only through its grant" points to "the table below", but it comes before the paragraph that sets up its premise ("Web access also goes to 2 and 6 — the only two roles whose sources live outside the repository", lines 955–956) and before the `model` paragraph. The reader is told how to change rows 2 and 6 before learning why those rows get web access. | Low | Move the connector paragraph to after the Bash-and-web paragraph, or directly under the table. The capability-is-a-stop pair (929–941) can stay where it is, because it qualifies the grant-declaration paragraph right above it. | yes |
| 5 | Process file, output contract, lines 1324–1329 | The code block of examples puts `Lookup: unavailable` alongside the valid tokens. That it always fails comes two sentences later. A reader skimming the block takes it as a fourth acceptable record. SKILL.md gets this order right: the template shows only `live \| not needed`, and `unavailable` is explained after. | Low | Drop `unavailable` from the example block and introduce it in the prose that follows ("a third token, `unavailable`, fails always…"), matching SKILL.md. | yes |
| 6 | Process file, review-step bullet, line 172 | "it does not continue on the grant line's `MISMATCH`" uses the grant line before it is defined (the grants section, line 916). The neighboring bullets already forward-reference *Output contract* by name; this one gives no pointer. | Low | Add "(see *Every reviewer declares its grant*)" or rephrase without the term: "even though the role would honestly report the tool as missing". | yes |
| 7 | SKILL.md line 298–299 | The cost-gate sentence is about *when* the probe runs relative to the cost preflight, but it comes after the stop branch, when the reader has already finished the probe. It has no effect on the order and does no work where it sits. | Low | Fold it into the probe's opening sentence ("…before any role is spawned, and after the cost preflight, since the gate treats the probe as a role spawn"), or cut it. | yes |
| 8 | SKILL.md step 7 template, line 669 | `Lookup: live \| not needed   # from step 4a's probe`: `not needed` does not come from the probe, it comes from skipping it. With finding 2 fixed, the comment should match. | Low | Change the comment to `# from the lookup probe, or its skip condition`. | yes |

### No findings, and what I checked
- **Process file, review-step bullet:** the rule is in the bold lead, the problem follows in the next sentence (only two roles reach outside the repo, and a blind role still reports), then the method, the pass test, and the stop. The issue #74 incident is a closing parenthetical, used as motivation and not retold. This matches the bullet before it. Apart from findings 2, 3 and 6, the order is sound.
- **Process file, grants section, the missing-capability pair (929–941):** the distinction is stated first, then why a MISMATCH stays non-fatal, then the capability that cannot be lost, then the incident as the illustration of "the wrong order". Leading with the claim is the house style, and the incident sits where a reader needs convincing. No defect.
- **Process file, new existence-check bullet in role 2's checklist (and its compiled copy):** rule, then what saved text does and does not prove, then the false negative on a silent lookup, then a worked example and the remedy. It sits before "How to establish the origin", which is the right order: existence before origin.
- **Appendix entry (1634–1651):** follows the incident-log arc. It tells what happened, why every gate passed, the escalation ("the second time on that machine"), then the lessons. The incident is told here, which is the right place. The rule sections only point to it. No defect.
- **SKILL.md GRANT paragraph's added exception (lines 326–327):** reads in order as a back-reference to a step already behind the reader. No defect.
- **SKILL.md step 7 additions (`unavailable` aside, gate paragraph, softened ⚠ sentence):** each comes after the thing it refers to. Only finding 8 applies.

Scope note: I judged order only. I did not check whether the DOI, title, 404 behavior or issue #74 details are accurate, which belongs to roles 1, 2 and 4. I also did not judge whether each paragraph reads clearly on its own, which belongs to role 8.
