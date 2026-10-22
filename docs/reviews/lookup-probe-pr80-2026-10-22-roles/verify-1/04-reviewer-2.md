GRANT 4 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit (deferred), plus Agent, Artifact, Skill, ToolSearch outside the grant

(I searched with grep through Bash. I edited, wrote and deleted nothing in any repo. All scratch work is under /private/tmp/claude-501/-Users-tonydefazio-Developer-murderboard/e08dd00d-458d-4dc7-8229-49f1f45d6e83/scratchpad/mb/scratch/v-4/. I read only 00-lookup-probe.md from the earlier review's archive.)

**Answer key: correct.** I resolved all six rows live on 2026-10-22:
- doi.org returned 302 for every row.
- Crossref's title and `created.date-time` match the table exactly for every row.
- Each row has a PubMed hit: 29032081, 29580982, 27378826, 28086892, 22316613, 27247839.
- Crossref citation counts are 11, 17, 7, 18, 21 and 2, so "little-cited" holds.
- A fresh `10.1000/<12 hex>` returned 404 at both doi.org and Crossref.
- Selftests pass: roster 82/82 and scanner 30/30. `murderboard_agents.py check` exits 0.
- I compiled a copy of the process file with `mcp__plugin_bio-research_pubmed__*` added to row 2. The wildcard reaches the agent's `tools:` line. `verify` passes a GRANT line that repeats the wildcard and fails one that lists an individual tool instead, as the process text claims.

Findings (location · issue · severity · suggested fix · verified against a source?):

1. **SKILL.md, the real-DOI table · The answer key ships inside the files role 2 can read.** Role 2 holds Read/Grep, and the probe runs inside the consumer's repo, where the vendored `.claude/skills/murderboard/SKILL.md` holds every title and every `created.date-time`. `grep -r 7920631 .` in this worktree returns the table row. Role 2's own checklist says "check the library first", so an honest agent with no network can find and report the answers, along with an invented route line. A second leak follows from the design. Every passing run archives `00-lookup-probe.md` in plaintext under `docs/reviews/`, and there are only six rows, so after a handful of runs the project's own archive holds the whole key. The page's line "None of these can be answered from memory" is true and beside the point: they can be answered from disk. · **blocking** · Draw the real DOI from a large live pool (Crossref `/works?sample=1` from the orchestrator), or store only hashes of the title and timestamp in the table, so that the gate can check an answer while the agent cannot read one. Also stop archiving the plaintext answer, or keep it outside the probing agent's reach. · yes (grep shows the key in the files role 2 can read)

2. **Process "Lookup: live" and SKILL "single-pass … main thread answers the probe itself" · In a single-pass run, the agent answering the probe already has the key in context.** The main thread loaded SKILL.md to run `/murderboard`, so the table is in its prompt. The probe there has no power at all: whoever answers it is the one holding the key. · **blocking** · A single-pass run must probe through something that does not hold the key: a spawned agent, or a shell fetch whose raw output is archived. Item 1's hash fix also covers this. · yes (by construction)

3. **Process role 2 and 6 rule "Count what no route reached … above zero, the main thread stops"; the token table · The mid-run stop is prose only, and #74 can recur after a passing probe.** `live` certifies only that the probe passed. Consider a run where the probe passes and role 2 then reports "3 sources unreached". The orchestrator carries on, as #74's orchestrator carried on past an honest MISMATCH, and writes `Lookup: live` truthfully. The archive holds the probe file, and every gate goes green. No token exists for "probe passed, route failed in the review", and no gate reads the count. I also tested `- **Lookup**: unavailable in role 2 mid-run (3 refs)` below a `Lookup: live` line, and the gate exits 0. · **major** · Require an `unreached: N` line in the archived reports of roles 2 and 6, and have the roster gate fail any N > 0 under `live`. · yes (ran the gate)

4. **Probe task 3 and its row in "What each answer proves" · Fetching `api.crossref.org` does not prove the role "can read an arbitrary web page".** It proves the route reaches one bibliographic JSON API. A sandbox network allow-list, or `WebFetch(domain:api.crossref.org)` approved under dontAsk, passes this task while role 6 still cannot open docs.python.org or any readthedocs page. The task is also answered in the same leaked table. · **major** · Give role 6 its own target: a documentation page chosen per run, with a value only a live fetch returns (a release date or version string from a changelog), checked by the orchestrator. · partly: I tested the scanner below; the domain-restricted case is reasoned, not run

5. **SKILL.md "Every row … is indexed in PubMed"; role 2's "Count what no route reached" · The key is drawn from the coverage of the route it tests.** All six rows are biomedical Crossref DOIs. Under a sanctioned "PubMed connector, papers only" route, or the Crossref + PubMed routes this PR's own probe used, real DataCite DOIs come back as misses. I checked `10.48550/arXiv.1706.03762` and `10.5281/zenodo.3509134`: doi.org 302, Crossref 404, PubMed 0. Role 2 then sees "not found", not "no route reached". Those land in the bucket that does not stop the run, or get flagged as fabricated. The fake-DOI task cannot tell these apart either, because it also returns a Crossref 404. · **major** · Require doi.org itself, the registry-agnostic resolver, for the existence check. If only a connector is available, record its coverage on the `Lookup:` line and have role 2 count out-of-coverage identifiers as unreached. · yes (resolved live)

6. **roster.sh `report_lookup` · The first token wins and conflicting declarations are accepted.** A record with `Lookup: not needed — example` above `Lookup: live — curl` reports "not needed", so the requirement for `00-lookup-probe.md` disappears. `live` and `not needed` together pass silently, although `verify` refuses a report that gives both verdicts for one role. · **major** · Fail when two different non-`unavailable` tokens appear. · yes (ran it)

7. **The `Lookup:` table, `not needed` · `not needed` is unverifiable and nothing acts when it is contested.** The author, who wrote the draft, decides it before the fan-out. A run whose probe failed can write `not needed` and pass every gate; "never after a probe that failed" exists only in prose. "Roles 2 and 6 can contest it" has no consequence: the roles are not told, and a contest after the fan-out changes nothing. Any deliverable that names a library is arguably not "not needed". · **major** · Under `not needed`, have the gate scan the artifact or role 2's archived report for DOI, URL or reference patterns and fail on a hit. Tell roles 2 and 6 the declaration in their prompt, and make a contest a stop. · no (design analysis)

8. **roster.sh, the `00-lookup-probe.md` check · Any non-empty bytes pass, and any file whose name starts with digits equal to 0 counts (`0.md`, `000-x.md`).** An old run's probe file copied into a new archive passes; nothing ties it to this run. The skill says the gate "cannot check that the probe's answers were right", but the key sits in the same vendored tree, so it could. · **minor** (larger once item 1 is fixed) · Have the record name the fake DOI it used, and have the gate require that DOI and a key match (or hash match) in the probe file. · yes (read `role_report_file`)

9. **subagents.sh `--lookup` · The scanner misses blockers of the sanctioned route and reports false blockers.** A hint, not a gate, but its exit code is 1. Results:
   - `deny ["mcp__plugin_bio-research_pubmed"]` reads as clean, yet that blocks the connector route the process recommends.
   - A sandbox `network.allowedDomains: ["github.com"]` reads as clean, because only `deniedDomains` is read.
   - dontAsk with `allow ["Bash"]` reports BLOCK, although curl is fully allowed.
   - dontAsk with `allow ["Bash(curl https://doi.org/*)"]` reports BLOCK.

   · **minor** · Treat an mcp deny without a wildcard as WARN. Read `allowedDomains`. Count a bare `Bash` allow and scoped curl allows as routes under dontAsk. · yes (ran each case; the allowedDomains semantics are from memory, not checked against the docs)

10. **Process "add its server to rows 2 and 6 in your copy" · The only connector path conflicts with re-vendoring.** If the edited process file is not listed under `adapted`, `murderboard_revendor.py` recopies it, the connector grant disappears, and the probe fails on the next run. If it is listed, the process file is frozen and stops receiving every upstream rule change. The paragraph mentions neither, and it cuts against CLAUDE.md's "new machinery is env-driven". · **major** for strangers, who are the readers · Move connector grants to consumer config (an env var or `.murderboard-vendor.json` key) that the compiler merges into rows 2 and 6. At minimum, name the `adapted` trade-off. · yes (read revendor.py lines 113–116 and 394–396)

11. **Process "the third clears role 6" · Role 6 is cleared by proxy.** The probe spawns only role 2's agent. That holds only while the two rows grant identical tools and both roles are spawned by the same path. Grant a connector or domain to row 2 alone, or let one role resolve by name while the other falls back, and the probe cleared a toolset role 6 does not hold. · **minor** · State the assumption, or spawn role 6 for the page-fetch task. · no

12. **SKILL.md probe procedure · Permission prompts can make the probe pass and the fan-out fail.** In default permission mode, WebFetch prompts per domain and curl is not pre-approved. A foreground probe gets the human's approval, while the fan-out runs in the background against publisher redirect domains and documentation hosts nobody approved. The scanner warns only on explicit `ask` rules, not on the default. · **minor** (unverified) · Run the probe with the same background setting as the fan-out. · no (I did not test background-agent prompting)

13. **The gate's token grammar · Ordinary markdown forms of an honest line fail, all exit 1 with the grammar message:**
   - `**Lookup: live** — curl`
   - ``Lookup: `live` — curl``
   - `Lookup: live (curl)`
   - `Lookup: live.`

   `Execution:` behaves the same way, so the two lines are at least consistent, and the gate fails closed. · **nit** · Strip backticks and surrounding bold from the token. · yes (ran it)

14. **SKILL.md "Pick one row of the table below at random" · No mechanism makes the choice random.** The fake DOI gets `openssl rand`, but the row is picked by the model. This PR's own probe used the first row. · **nit** · Use `$(( $(openssl rand -hex 1 | …) % 6 ))`, or the large live pool from item 1. · yes (00-lookup-probe.md used row 1)

Checked and sound:
- `unavailable` fails in bullet, number, heading, bold-key and masked forms.
- The probe is spawned by the same path the roles use.
- The token-head and token-tail split was factored into one `token_cut`.
- The selftest counts in the commit message hold: roster 59→72→82, scanner 9→19→30.
- The connector entry format compiles and verifies as the process text describes.
- The rationale for not failing every *missing* MISMATCH is consistent with #74's facts as the issue reports them.
