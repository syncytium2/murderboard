> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 8 MISMATCH — missing Grep, Glob; holds Edit, Write, Bash, Agent, Artifact, Skill, ToolSearch, Claude Docs batch/update (NotebookEdit deferred, loadable)

I used only Read. I did not edit, write, run or delete anything. I read: the role file, the whole PR #80 diff (`pr80-r4.diff`), SKILL.md lines 1–240 for context on `$SUBAGENTS`, `agent-name` and the subagent probe, and `docs/reviews/lookup-probe-pr80-2026-10-22-roles/00-lookup-probe.md`.

## Per-section verdict (reader (a) = the researcher who vendored this; reader (b) = a visitor to the site)

| section | terms first used here | defined here? | can a cold reader follow it? |
|---|---|---|---|
| process file, review step, "Confirm the lookup works BEFORE the fan-out" | route, RFC, #74 (bare at first mention, linked three lines later), single-pass | route: yes. RFC: no. #74: late | yes, with friction |
| process file, "a missing tool is a finding and a missing capability is a stop" | capability vs tool | yes, by example | yes |
| process file, "A connector reaches a role only through its grant" | connector, MCP, `.murderboard-vendor.json`, `adapted` | connector: yes. The other two: no | yes, but the `__*` paragraph is dense for (a) |
| process file, Output contract `Lookup:` table | live / not needed / unavailable | yes | yes |
| skill, "Before the fan-out: probe the lookup" | background or foreground spawn, `agent-name`, key, "drawn rows" (used before the block that draws them), registration agency, DataCite | partly | yes for running it. **No** for scoring a key that does not match (see F2) |
| roster gate, `unavailable` message | roles 2 and 6, route, literature connector, grant, lookup probe | none | **blocking**: five undefined terms in one message |
| `murderboard_subagents.sh --lookup` messages | roles 2 and 6, connector, route, lookup probe | none | **blocking**: four undefined terms |
| site, "What changed lately" 2026-10-22 | citation checker, DOI, end-of-run check | no | yes. They follow it, and part of it reads as false (see F7, F8) |

## Findings
*location · issue · severity · suggested fix · verified against a source?*

**F1. Roster gate's green summary and the `Lookup: live` line, read as "citations verified."** On success the gate prints `lookup: live` (diff line 741) and drops the prose after the dash. So a record saying `role 2 only` (connector, no documentation page reachable) prints the same green line as one saying `roles 2 and 6`. A co-author reading the record or the gate output will take `live` to mean the references were checked live. The process file says the opposite ("`live` certifies the route, not the references"), but only in the Output contract. Neither the record nor the gate output carries that sentence. The "equipment, not honesty" scope reaches the operator (the skill states it before the probe) and never reaches the person reading the finished record, who is the one who needs it. · **major** · Make the green line say what it certifies, e.g. `lookup: live (probe passed; route only, not the references)`, and echo the role scope it read. Have the skill's step-7 grammar suggest prose that says the same. · yes (diff lines 741, 1415, process Output contract)

**F2. Skill: what to do when the key does not match is unstated.** The hash prevents an eye comparison by design. A title that is right but formatted differently (inline `<i>` tags from Crossref, Greek letters, a subtitle) produces a mismatch. By the table, a mismatch is a fail, and a fail is STOP. Reader (a) cannot tell a formatting miss from a failed route, and gets no instruction. · **major** · Add one line: on a mismatch, read the returned title and the route's status. If the route plainly resolved, redraw another row and probe again. Do not hand-edit the title until it hashes. · yes (skill diff 1362–1397)

**F3. Roster gate message for a missing `00-lookup-probe.md`.** It says "If not, run the probe again (it draws a new fake DOI: put that on the Lookup: line)". Followed exactly, this produces a probe run *after* the review, and it satisfies the gate. A probe that ran after the fan-out did not gate it, but the record then reads as if it had. · **major** · Say the re-probe must come before re-running the reviewers ("run the probe, then the whole review again"), as the `unreached:` message already says. · yes (diff 704–707 vs 732–733)

**F4. Roster `unavailable` message: undefined terms, and an overclaim.**
- "Roles 2 and 6", "route", "literature connector … added to their grant" and "run the lookup probe again" appear with no pointer to where the probe lives.
- "(finds a blocking rule)" promises a result the scan often cannot give: its exit 0 is not an all-clear.

· **moderate (blocking under the three-term rule)** · Name the roles ("the citation and methods reviewers, roles 2 and 6"). Point to "the skill's step 4a, *Before the fan-out: probe the lookup*" and to the process section *A connector reaches a role only through its grant*. Change "finds" to "looks for". · yes (diff 652–663)

**F5. `--lookup` scan remedies.** "grant roles 2 and 6 a connector" has the same undefined terms, with no pointer to the process section that explains how to grant one. · **moderate** · Add that section name to the remedy string. · yes (diff 1093–1094)

**F6. Roster message for contradictory `Lookup:` lines.** Unlike every other lookup failure, it does not print the lines it read. The code comment says "Every failure prints the line it read." The reader has to hunt through the record for the conflicting lines. · **minor** · Print each `Lookup:` line found. · yes (diff 566–568 vs 666–671)

**F7. Site entry: "and every check still passed."** The same entry uses "check" for the end-of-run gate. A visitor reads "every check" as *every citation check passed*, meaning bad citations got through. The appendix says all twelve DOIs were later confirmed correct. What passed were the coverage gates. · **moderate** · Change to "and the end-of-run checks still passed" (or "the run's own gates"). · yes (diff 422; appendix 386–388)

**F8. Site entry headline: "A review now stops before it starts."** The visitor reads this as an enforced, mechanical stop that guarantees live-checked citations. In fact the stop is an instruction the reviewing AI follows and scores itself. The end-of-run gate enforces only what the record says. The probe's stated limit (it cannot catch a model answering from memory) is absent. Also, "before any reviewer starts, the checker must…" reads as self-contradictory, since the checker is a reviewer. · **moderate** · Add a clause: "it checks that the checker can reach sources, not that its answers are honest". Change "before any reviewer starts" to "before the review fans out". · yes (diff 421–422; process 222–225)

**F9. Process file, review step: "which is what #74 was."** The issue is named bare before its link (three lines later), and the incident is never glossed where it is first named. · **minor** · Gloss at first mention: "the case in issue #74, where the citation reviewer ran without web access". · yes (diff 222–227)

**F10. Process appendix, last sentence: "a capable model passed a fixed answer key from memory."** A cold reader takes this to mean the probe was shown not to work, then finds a fixed six-row public table still in the skill. The skill's reason for keeping it ("make a careless pass harder … a record") is not in the appendix. · **minor** · Add half a sentence: the drawn rows and hashed key remain, as a record and a hurdle, not as proof. · yes (diff 399–400; skill 1319–1325)

**F11. What the probe certifies, by item.**
- The fake DOI uses `10.1000`, the DOI Foundation's own prefix. The archived reply itself says "this looks like a made-up DOI", so the not-found answer can be guessed without any lookup.
- RFC titles are well within a model's memory, and the RFC item is what lets the `Lookup:` line say "roles 2 and 6". That line lets a reader infer that role 6's access to documentation was demonstrated, which this item cannot show for a model that guesses.
- In a single-pass run, the main thread generated the fake DOI and then answers and scores it itself.

The general caveat covers this, but the item-by-item "clears role N" table states clearance without qualification. · **moderate** · In the scoring table, mark the fake-DOI and RFC items as "clears an honest route" and note that single-pass self-scoring is weaker. · partly (archive line 26; skill table 1393–1397)

**F12. The archived probe as a worked example.** Its "Prompt as sent" wording differs from the skill's current template (the not-found wording, and "document's title" vs "title in the page's heading, without the RFC number"). Its scoring records only key matches, not the HTTP status/record ID or the route, though the skill says to score both. A researcher copying it as a model learns to score only the key. · **minor** · Add a note that the prompt predates the final template, and score the route and status explicitly. · yes (archive lines 7–19 vs skill 1350–1391)

**F13. Skill: "other characters than a–z and 0–9" is awkward, and "the drawn rows" comes before the block that draws them.** · **minor** · Change to "every run of characters other than…" and move the "what it can catch" paragraph below the block, or say "the rows drawn below". · yes

## Direct answers to the focus questions
- **Can the researcher run and score the probe from the skill alone?** They can run it: tools, prompt, tables and pass criteria are all there. Scoring breaks down on a key that does not match (F2).
- **What will they take `Lookup: live` to certify?** That the citations were checked live (F1). The scope sentence ("equipment, not honesty") is where the operator reads it, but not where a reader of the record or the gate output meets the word.
- **Can they act on each gate message?** Mostly. The `unavailable` message and the `--lookup` remedies use undefined jargon and give no location for the probe (F4, F5). The contradictory-lines message gives nothing to locate (F6). The missing-probe-file message leads to a post-hoc probe that passes (F3).
- **Does the site entry say something true that a visitor reads as false?** Yes: "every check still passed" (F7) and "stops before it starts" (F8).
