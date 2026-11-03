> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 5 MISMATCH — missing Grep, Glob; holds Bash, Edit, Write, Agent, Skill, ToolSearch, Artifact, mcp__claude_ai_Claude_Docs__batch/update/guide

**Grant mismatch.** Both Grep calls failed with "No such tool available: Grep … use grep via the Bash tool instead." I worked around it by reading the files with Read only. I did not use Bash, Edit or Write, as instructed. I could not rerun `murderboard_prose.sh`; I relied on the main thread's pasted output, which found **no banned constructions in any added line**. Data plural: no new uses of "data". Spelling: one idiom flagged in finding 14.

**What I checked:** every added (+) line in `doc_review_process.md` and `skills/murderboard/SKILL.md`, including the role 2 checklist bullet. Also the added comments and user-facing messages in `murderboard_roster.sh` and `murderboard_subagents.sh`. I read the surrounding sections of both docs (process step 2, the grants section, the Output contract; skill sections 1a, 4a and 7) for context.

Format: location · issue · severity · suggested fix · verifiable against a source?

1. **SKILL.md 4a, "Both right → … / Anything else → STOP" block, last paragraph** · *"The only deliverable that skips the probe honestly is one with nothing to look up … and it records `Lookup: not needed`."*
   - The exemption is in the wrong place. It sits inside the failure branch, so a reader learns they could have skipped the probe only after it has failed.
   - **medium**
   - Fix: move it ahead of the probe prompt, e.g. "If the deliverable has nothing to look up (no references, no named attribution, no outside method), skip the probe and record `Lookup: not needed`."
   - Verifiable: yes (text order).

2. **SKILL.md 4a vs doc_review_process.md step 2** · The two files disagree about what the probe's point is.
   - Skill: *"**That half is the probe**: a route that answers *something* for every query passes a one-sided check."*
   - Process: *"The pair is the point — a route that answers *something* for every query passes a one-sided probe."*
   - "That half is the probe" contradicts "It passes only if **both** come back right" two sentences earlier. The rationale is also stated twice, nearly word for word, across the two files.
   - **medium**
   - Fix: keep the rationale in the process file only, which owns the rule. In the skill write "The made-up DOI is what makes this a test: …", or just point to the process.
   - Verifiable: yes.

3. **doc_review_process.md step 2, new bullet, opening** · *"Confirm the lookup works BEFORE the fan-out, too — the same probe, for roles 2 and 6."*
   - It is not the same probe. The bullet before it spawns a throwaway subagent; this one resolves two DOIs with role 2's own agent. "The same" sends the reader back to compare them.
   - **medium**
   - Fix: "— a second probe, this one for roles 2 and 6."
   - Verifiable: yes.

4. **doc_review_process.md step 2 bullet; SKILL.md 4a; role 2 checklist bullet (also compiled into `agents/02-doi-or-die.md`)** · "route" is used before it is defined.
   - Process: *"a route that answers something for every query"* comes before *"Any route that passes counts: WebFetch, a shell fetch, a literature connector."*
   - Role 2 checklist: *"know what the route covers before reading its silence"*. The only list nearby is "(WebFetch, a shell fetch, a literature connector)", and it is never called "routes". Role 2 reads its agent file on its own, so it never sees a definition.
   - **medium**
   - Fix: define on first use, e.g. "a route (WebFetch, a shell fetch, a literature connector) that answers…". In the role 2 bullet: "say through **what** route (WebFetch, …)".
   - Verifiable: yes.

5. **doc_review_process.md step 2 bullet** · *"If it fails, **the run stops before role 1** and says which route was tried; it does not continue on the grant line's `MISMATCH`."*
   - "continue on the grant line's MISMATCH" does not parse cleanly. The intended meaning is "it does not continue with the gap recorded only as a MISMATCH."
   - **low**
   - Fix: "it does not record the gap as a `MISMATCH` and carry on."
   - Verifiable: yes.

6. **doc_review_process.md grants section, "What a role cannot lose…" paragraph** · *"On 2026-10-14 the two happened in the wrong order: role 2 declared…"*
   - "the two" has no clear referent: the tool and the capability? the probe and the fan-out? the stop and the finding? What the sentence describes is "the lookup was confirmed after the review instead of before it."
   - **medium**
   - Fix: "On 2026-10-14 the lookup was confirmed after the review instead of before it: role 2 declared…"
   - Verifiable: yes.

7. **Same paragraph** · *"the lookup probe in step 2 establishes it"*
   - "step 2" is a bare label in a section far from the step list.
   - **low**
   - Fix: "the lookup probe in the Review step (step 2)".
   - Verifiable: yes.

8. **doc_review_process.md, "A connector reaches a role only through its grant."** · Two unclear phrases.
   - *"the 2026-10-14 role 2 held only the tools its list named"*: "its list" means its row in the grants table.
   - *"⚠ Untested here: whether `verify` accepts the names a role then declares against a wildcard row, so read those GRANT lines by eye."*: "the names a role then declares" is hard to parse.
   - **low**
   - Fix: "held only the tools its row in the table named." And: "⚠ Untested here: whether `verify` accepts a `GRANT` line listing individual connector tools when the role's row is a wildcard. Until it is tested, check those lines by eye."
   - Verifiable: yes.

9. **doc_review_process.md Output contract, new Lookup paragraph** · Three precision problems.
   - *"as the same kind of controlled token"*: "controlled token" is new here. Earlier text says only "token".
   - *"`live` names no tool, deliberately"*: the example lines name tools after the dash.
   - *"it is the author's claim, the reviewers can contest it, and a deliverable that cites anything is not one."*: "is not one" has an unclear antecedent.
   - **low**
   - Fix: "as a parsed token, like `Execution:`"; "The token `live` names no tool…"; "…and any deliverable that cites anything does not qualify."
   - Verifiable: yes.

10. **doc_review_process.md Output contract** · *"`murderboard_subagents.sh --lookup` is the scan for this probe"*
    - The scan is not "for" the probe. It is the file-level hint you run when the probe fails, as the skill uses it.
    - **low**
    - Fix: "is the file scan to run when this probe fails".
    - Verifiable: yes.

11. **SKILL.md 4a, probe paragraphs** · Two ordering problems.
    - *"**Then probe the lookup, with role 2's own agent, before anything else is spawned.**"* conflicts with the throwaway spawn in 1a, which has already happened.
    - The ordering reason sits in a trailing paragraph after the stop branch: *"The probe is one spawn, which the cost gate sees like any role spawn; it runs after the cost preflight for that reason."* "cost gate" and "cost preflight" also appear as two terms in one sentence.
    - **low**
    - Fix: "…before any role is spawned." Move the cost sentence into the opening paragraph, and use one term per mechanism.
    - Verifiable: yes.

12. **SKILL.md section 7** · Two unclear sentences.
    - *"`Lookup:` has a third token, `unavailable`, and the gate fails it — if you would be writing it, the run should have stopped at step 4a, and the record is not the place to say so."* "say so" is unclear: say what? And the process file lists `unavailable` as an ordinary example record line, so the two files read differently.
    - *"Write the token from what step 4a's probe returned — the same limit as `Execution:` applies, and a `live` token over a probe that never ran is a false record no report-reading gate can catch."* The sentence does two jobs, and "the same limit" is a pointer the reader has to chase.
    - Minor: "step 4a's probe" points to a heading ("Compile the specialists, then spawn them BY NAME") that does not mention the probe.
    - **low**
    - Fix: "…the run should have stopped at the lookup probe (4a); a record that says it documents a stop that was skipped." And split the second sentence: "Write the token from what the probe returned. As with `Execution:`, a `live` token over a probe that never ran is a false record, and no gate that reads the report can catch it." Consider adding "and probe the lookup" to the 4a heading.
    - Verifiable: yes.

13. **doc_review_process.md appendix entry "A role that could not reach its sources, and a run that continued"** · Passage test.
    - By my count the block runs about 250 words. That conflicts with the pasted gate result that every added paragraph is under 120 words; the gate may not count list items. I could not rerun the gate.
    - Its payload is the final "Lessons:" sentence. The 2026-10-14 sequence (WebFetch absent, curl denied, DOIs matched to saved text, gates green, connectors confirmed it afterwards) is told in full here *and* in the grants-section paragraph *and* in the step 2 parenthetical.
    - *"which is also how the case shows the tool is not the capability"* is clunky.
    - **medium**
    - Fix: keep the full narrative here and nowhere else. Cut the grants-section retelling to a single clause plus "(issue #74; see appendix)". Rewrite the clunky clause as "— the tool was missing, the capability was not."
    - Verifiable: yes for the redundancy. The word count is my own estimate.

14. **murderboard_subagents.sh `--lookup` help comment** · *"scan instead for what stops roles 2 and 6 reaching a source"*
    - "stops X reaching" is British. The house rule is American.
    - **low**
    - Fix: "stops roles 2 and 6 from reaching a source".
    - Verifiable: yes.

15. **murderboard_roster.sh, `--require-lookup` failure message** · *"A role that could not still writes about citations"*
    - Garden path: "could not still" reads as one unit.
    - **low**
    - Fix: "A role that could not reach one still writes about citations."
    - Verifiable: yes.

16. **Role 2 checklist bullet** · *"Resolve each one live and say through **what** (WebFetch, …)"*
    - Awkward phrasing, and "each one" is a step away from "identifier".
    - **low**
    - Fix: "Resolve each identifier live and name the route you used (WebFetch, …)."
    - Verifiable: yes.

**No findings** on the other added comments in both scripts. They are clear, define their terms, and the `WARN`/`BLOCK` remedy messages are concrete.
