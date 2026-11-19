> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 8 MISMATCH — missing Grep, Glob; holds Bash, Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch, mcp__claude_ai_Claude_Docs__update (plus deferred WebFetch, WebSearch, NotebookEdit and others reachable through ToolSearch)

Run note: this role came up through the fallback path and holds editing tools that no reviewer may have. I used only Read. I could not search with Grep, so the Output contract cross-reference is marked unverified below.

**What I checked:** all of <scratch>/mb/pr80.diff. I also read the new text in place: SKILL.md lines 180–340 and doc_review_process.md lines 1255–1340. Two cold readers: a vendoring researcher, and someone who meets the roster gate's `Lookup: unavailable` message on their own run. "Panel" here means a block of added text.

## Per-block verdict (terms first used · defined here? · can a cold reader follow?)

| Block | Terms first used | Defined here? | Follow? |
|---|---|---|---|
| doc_review_process.md step 2, "Confirm the lookup works BEFORE the fan-out" | fan-out, probe, route, WebFetch, shell fetch, literature connector, grant line, `MISMATCH`, Output contract, issue #74 | none. Grant/`MISMATCH` are defined ~750 lines later (~l.900); WebFetch and connector are never defined | **BLOCKING**: 3+ undefined terms |
| process, "A missing tool is a finding; a missing capability is a stop" | tool vs capability, `Grep`/`Bash`, step 2's probe | the capability is defined ("reaching a source outside the repository") | yes, mostly |
| process, "A connector reaches a role only through its grant" | connector, MCP server, `tools:` field, `mcp__<server>__*`, rows 2 and 6 of "the table below", `verify` | none | **BLOCKING**: assumes Claude Code subagent internals |
| process, Lookup tokens block (l.1321ff) | route, capability, `--require-lookup`, `murderboard_subagents.sh --lookup` | partly | no: "the route is not the capability" |
| process, DOI or Die bullet "Existence is established by resolving…" | offline matching, PMC/ID converter | yes, by the example | yes, a good block |
| process appendix, issue #74 entry | consumer project, roster gate, grants gate | yes, in context | yes |
| SKILL.md lookup probe (4a) | role 2's `agent-name`, cost gate, cost preflight, `$SUBAGENTS`, `$PROCESS` | `agent-name` is defined above | yes for this skill's user |
| roster gate messages (unavailable / unrecognized / undeclared) | route, lookup probe, roles 2 and 6 | no | **no**: see the roster gate's `Lookup: unavailable` message below |
| murderboard_subagents.sh `--lookup` messages | route, probe, literature connector | no | partly |

## Findings (location · issue · severity · suggested fix · verifiable against a source?)

1. **process l.1325–1326 and the roster.sh comment block, the example `Lookup: live — PubMed and bioRxiv connectors; WebFetch absent from the session`.** A reader follows this perfectly and gets it wrong. The example is built from the 2026-10-14 run. In that run role 2 had *no* route, and the connectors belonged to the main session after the review (the appendix says so). Under the new rule that run should have recorded a stop, not `live`. The justifying sentence makes it worse: "a gate that demanded WebFetch would fail the run that verified every citation through a connector". That presents the incident run as the model of a good `live`. A cold reader learns that `live` means "someone, at some point, got the citations through some route". · **High** · Write the example as a hypothetical ("role 2 granted a PubMed connector; WebFetch absent"). In the rationale, say the connector route must belong to role 2 and must have passed the probe. Drop the claim that the 10-14 run "verified every citation". · yes (appendix, same diff)

2. **"Lookup: live" across the process file, SKILL.md and the roster gate's success line: what a reader takes it to certify.** A methods-section author reads "lookup: live" in a green gate line as "my citations were checked live". It certifies far less. Two fixed DOIs resolved correctly through some route role 2's spawn held. Two further gaps:
   - **The probe paper is in every index.** Ioannidis 2005 is open access, in PMC and in PubMed. A PMC-only route passes the probe and then reads silence as "does not exist" for every non-PMC paper. That is the exact failure the new DOI or Die bullet describes with `10.1210/endocr/bqad150`.
   - **One DOI probe cannot answer for role 6.** "One probe answers for both" is false whenever the route is a literature connector. A connector resolves DOIs but cannot open a library's documentation page, which is role 6's source (the appendix's 2026-09-15 case was documentation pages).

   · **High** · State in one sentence beside the tokens: "`live` records that the probe passed; it does not certify any citation in the deliverable". Either make role 6's probe fetch a documentation page, or require `live` to name a route that reaches both kinds of source. Say that the probe paper is deliberately easy, so passing it does not show coverage. · yes (SKILL.md l.263–276; process l.1331)

3. **Roster gate message for `Lookup: unavailable` (roster.sh, the `unavailable)` branch).** Someone meeting this cold learns that their run failed, but not what to do:
   - "fix the route": route is never defined, and nothing points them to `murderboard_subagents.sh --lookup` or the connector section.
   - "re-run them": this reads as re-run roles 2 and 6 only. The skill means the run should stop before role 1 and probe again.
   - It never mentions `not needed`. A reader whose deliverable cites nothing has no way out from this message.
   - It speaks only of DOIs and citations, so a reader whose role 6 sources are manuals is told about the wrong thing.

   · **High** · Rewrite along these lines: "Lookup: unavailable fails always. Roles 2 and 6 could not reach outside sources, so their checks did not happen. Run `murderboard_subagents.sh --lookup --explain` to find a blocking rule; give role 2 a working route (web access or a literature connector, see 'A connector reaches a role only through its grant' in doc_review_process.md); re-run the lookup probe, then the whole review. If the deliverable cites nothing and uses no outside method, declare `Lookup: not needed` instead." · yes

4. **Roster gate message for an undeclared Lookup (`--require-lookup`).** It says what is missing but not what to write. Unlike the unrecognized-token branch, it lists no example tokens. · Medium · Print the same three example lines. · yes

5. **SKILL.md l.256 vs l.294–296: when the probe may be skipped.** The probe instruction is unconditional ("before anything else is spawned"). The skip condition ("the only deliverable that skips the probe honestly is one with nothing to look up") is buried inside the *failure* branch. A reader reviewing a caption that cites nothing, on an offline machine, runs the probe, fails it, and STOPs when they should have recorded `not needed`. · Medium · Open the probe paragraph with the skip test: "If the deliverable has no references, named attributions or outside methods, record `Lookup: not needed` and skip this". · yes

6. **SKILL.md l.279, "STOP, before role 1".** A cold reader can take "role 1" for "step 1" and restart the whole skill. The skill also says "before anything else is spawned", yet the step 1a subagent probe has already been spawned by then. It is also unclear whether a stopped run writes a run record. The skill's l.682 says not to write `unavailable` ("the record is not the place"). The process file says "the record then carries a `Lookup:` line" and lists `unavailable` as one of four tokens on equal footing. So a person working by hand from doc_review_process.md would honestly write `unavailable` and finish the run. · Medium · Say "stop before spawning any reviewer". Have the process file say plainly that `unavailable` means no review record is written, only a note to the human. If a stopped run does leave a record, say so in both files. · yes

7. **process l.1331, "the route is not the capability".** "Route", "tool" and "capability" are used inconsistently across the files:
   - process l.1331 says "the route is not the capability".
   - the appendix says "the tool is not the capability".
   - roster.sh says "the tool's name is not the capability".
   - the new section header contrasts a "missing tool" with a "missing capability".

   A cold reader cannot tell whether a route is a tool, and the aphorism reads as philosophy rather than as an instruction. · Medium · Replace it with plain words: "`live` does not name a tool, because any working way of looking things up counts: WebFetch, a shell download, or a literature connector". Use one noun ("route") throughout. · yes

8. **process step 2 (l.161ff): the probe as given to someone working by hand.** Readers who follow the process file without the skill (the consumer paragraph allows this) are told to resolve "one identifier that exists and one that cannot". They do not get the two DOIs or the pass criteria, which live only in SKILL.md. They will invent a fake DOI that may collide with a real one, or pick a real one that only their own route indexes. · Low-Medium · Put the two DOIs and the expected title in the process file too, or point to the skill section by name. · yes

9. **process, "A connector reaches a role only through its grant", ⚠ line.** "Read those `GRANT` lines by eye" does not say what to look for. It also leaves the reader to discover the risk that `verify` may fail a run whose grant line names a wildcard connector. To this reader, `mcp__<server>__*` and "rows 2 and 6 of the table below" are opaque. · Medium · Add one worked line: the table row before and after, and what a correct GRANT line then looks like. State what to do if `verify` rejects it. · yes (I did not look up how `verify` behaves)

10. **process step 2: "see *Output contract*".** I could not confirm that a section with that title exists; without Grep I could not search for it. If it does not, the cross-reference leads nowhere. · Low · Name the real section heading. · no, unverified

11. **murderboard_subagents.sh `--lookup` messages.**
    - The header "lookup preflight (what roles 2 and 6 can reach)" claims more than the scan can see. Its own caveat says it cannot see the tool list.
    - The blocker line "role 2 may not be able to resolve a citation here" leaves out role 6.
    - The BLOCK remedy "give roles 2 and 6 another route (a literature connector)" does not say how. On the clean path a green "no lookup blocker found" line is printed above WARN lines, which a skimmer reads as the all-clear.

    · Low-Medium · Rename the header to "lookup preflight: rules in files that could block roles 2 and 6". Name role 6 in the blocker line. Point the remedy at the connector section. When WARN lines follow, print the green line in neutral color. · yes
    - Boundary note, not role 8's call, passed on for roles 1 and 3: under `--hook` the early return fires before the lookup report, so prose WARN lines are silent. That cuts against the code comment "a warning nobody is shown is a scan that found something and said clean".

12. **SKILL.md, record template line `Lookup: live | not needed  # from step 4a's probe`.** `not needed` comes from skipping the probe, not from its result. A reader may think they must run the probe to earn `not needed`. · Low · Change the comment to "from step 4a: the probe result, or the skip test". · yes

13. **process step 2: issue #74 appears inline in rule text as the justification.** The repo is public and the issue can be followed, so it passes the pointer rule. But the cold reader does not know it is a GitHub issue in this repo. · Low · Write "issue #74 in this repo's tracker" on first use. · yes

What reads well: the new DOI or Die bullet, with its NCBI/PMC example, is clear to a stranger. It is the one block in the diff that teaches by mechanism rather than history. The appendix entry is legible once the reader reaches it.
