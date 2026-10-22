> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 4 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit (deferred, loadable), plus Agent, Artifact, Skill, ToolSearch, the Claude Docs editing tools (batch, update), and WebFetch/WebSearch (deferred, loadable)

Run notes:
- I worked through Read and Bash.
- I used Write twice, and only to create scratch files under `…/scratchpad/mb/scratch/x-4/`. A repo hook blocked a shell heredoc, so Write was the way to get a fixture script and a key-recomputation script onto disk. Neither file is in any repo.
- No repo file was edited, written or deleted.
- I did not load WebFetch or WebSearch.
- In `docs/reviews/`, the only file I read was `00-lookup-probe.md`.

## Findings — role 4, blind verify pass, PR #80 (`lookup-probe` @ 22a3f4c)

Format: location · issue · severity · suggested fix · verified against a source (yes/no)

**1. `murderboard_roster.sh` `unreached_count` and the role 2 / role 6 loop in `cmd_check`. Every case below was run against the real process file.**
- **Issue:** this check is the only end-of-run backstop for a run that should have stopped and did not. It passes whenever the count is missing or written in a form it does not parse, and it fails some honest zeros.
- **A role 2 report that admits the failure in prose passes:** "Could not resolve any of the 12 DOIs; no network." gives exit 0.
- **Count forms that also give exit 0, each with 12 unreached:**
  - `1. unreached: 12` (numbered; the Lookup-line matcher accepts this form, the count matcher does not)
  - `+ unreached: 12`
  - `### unreached: 12`
  - `| unreached | 12 |`
  - `Sources unreached: 12`
  - `unreached = 12`
  - `Unreached (no route): 12`
- **Honest zeros that fail (exit 1):** `unreached: none`, and `unreached: 0` when the same report also has a line starting with the quoted grammar `` `unreached: N` ``.
- **The selftest vouches for the gap.** The assertion 'live + this run's probe reply passes' runs over `lkroles/02-doi-or-die.md`, which contains `role 2 said things` and no `unreached:` line. So the suite already asserts that a live record whose role 2 never stated a count is clean.
- **Severity:** blocking.
- **Fix:**
  - When the archive is present, require an `unreached:` line in the role 2 and role 6 reports whenever the token is not `not needed` (better still, whenever the flag is set).
  - Accept numbered, `+` and heading prefixes, the same way `lookup_lines` does.
  - Treat `none` as 0.
  - Flip that selftest assertion so it fails; do not add a sibling test beside it.
- **Verified:** yes (fixtures run in scratch).

**2. `cmd_check`, the `live` evidence block, and the matching claims in SKILL.md, the process file and the roster comments ("holding the probe DOI… so a reply copied from an older run does not count", "a record of the probe a reader can check").**
- **Issue:** the gate greps `00-lookup-probe.md` for the fake DOI. The skill tells you to save "the prompt as sent", and the prompt always contains that DOI. So the check proves the prompt was saved, not that a reply exists or that it passed.
- **Constructed case:** a probe file in which every item failed (`item 1: fail — no route` / `item 2: fail` / `item 3: CANNOT FETCH`), next to `Lookup: live — curl; roles 2 and 6; probe 10.1000/0123456789ab`, with full flags, gives exit 0 ("lookup: live").
- **Why it matters here:** this is the #74 orchestrator again. It carries on past a stop the skill states only in prose, and with finding 1 nothing at the end catches it.
- **Severity:** major.
- **Fix:**
  - Have the scoring section carry a fixed per-item line (for example `item N: pass|fail`) and have the gate fail `live` on any `fail`, or on a missing scoring line for items 1–2.
  - Say plainly that the DOI check ties the file to the run, and nothing more.
- **Verified:** yes (run).

**3. SKILL.md step 4a, the probe bash block.**
- **Issue:** the block sets `doi_row`, `rfc_row`, `fake` and `key()`, and prints nothing.
  - In Claude Code each Bash call is a fresh shell; env vars and functions do not persist. A reader following the skill literally ends up with no row numbers to fill the prompt and no `$fake` to write into the step 7 `Lookup:` line much later.
  - Re-running the block draws different values, so the gate's DOI tie-check then fails an honest run.
  - Scoring with `key "<the title given>"` pastes an agent-supplied title into a double-quoted shell string, where `$`, backticks or `"` are interpreted. That gives a wrong key and a false stop.
- **Severity:** major.
- **Fix:**
  - End the block with `echo "doi_row=$doi_row rfc_row=$rfc_row fake=$fake"`.
  - Tell the reader to write `fake` into the archive (or the record draft) immediately.
  - Have `key` read the title from stdin or a file rather than argv.
- **Verified:** yes, for the absent echo (from the diff). That env vars do not persist comes from the harness's own Bash tool contract.

**4. `docs/index.html` new "What changed lately" entry, and the CLAUDE.md drop-in.**
- **Issue:** both claim more than the gate does.
  - The page says "a report that says it could not reach its sources fails the end-of-run check". The drop-in says "a run whose citation checker could reach no source cannot pass as one that checked".
  - Per findings 1 and 2, a report that says so in prose, or in any count form other than the exact one, passes. So does a `live` record over a failed probe.
  - The headline "A review now stops before it starts" describes an instruction to the orchestrating model. Nothing enforces it before the fan-out.
- **Severity:** major (the page is public and live on merge).
- **Fix:**
  - Fix findings 1 and 2, or narrow the wording to "a record declaring `unavailable`, or a role 2/6 report with an `unreached:` count above zero, fails".
  - Say "the skill stops the review" rather than "a review now stops".
- **Verified:** yes.

**5. Probe item 1 scoring, and the way the rows were chosen ("Checked live… each DOI redirects at doi.org").**
- **Issue:** the rows were checked against Crossref and PubMed titles, not against what the canonical granted route returns.
  - Three of the six DOIs (rows 1, 2 and 5) land on Elsevier, whose landing pages commonly refuse non-browser fetches.
  - A role 2 holding exactly its granted WebFetch that follows `doi.org` to the publisher can fail item 1 honestly. That is a false stop on a working route.
  - WebFetch also passes the page through a summarizer, which may reword a title (for example "&" versus "and", or a dropped subtitle). The key is exact after normalization.
- **Severity:** minor (it errs toward stopping, not toward passing).
- **Fix:**
  - Say in the prompt that a registry record suffices: Crossref `/works`, or a CSL-JSON `Accept` header on `doi.org`.
  - In the scoring table, note that a title mismatch on a route that otherwise returned a status or ID calls for a retry through the registry before the stop.
- **Verified:** partly.
  - All 12 keys recomputed live from Crossref and from the rfc-editor h1 match the tables.
  - The WebFetch behavior was not tested, because WebFetch is not in my grant.

**6. `lookup_lines` versus `execution_line` (fence handling).**
- **Issue:** a record that writes its header block inside a ``` fence (the skill shows that template fenced) has `Execution:` read and `Lookup:` skipped. So a fenced `Lookup: unavailable` gives exit 0 under the default flags.
- **Contradiction with the docs:** the process file and the roster comments say `unavailable` fails "always, flag or no flag".
- **Mitigations:**
  - It is caught under `--require-lookup` (as undeclared).
  - Of the existing records, only one has a line-start `Execution:` at all, and it is not fenced.
- **Severity:** minor.
- **Fix:** let an `unavailable` token fail wherever it appears, fenced or not, and skip fenced lines only for `live` and `not needed`. Or qualify "always".
- **Verified:** yes (run).

**7. Process file appendix (#74 entry) and the role 2 checklist's "(an instance is in the appendix)".**
- **Issue:** the appendix states details the linked issue does not support.
  - The issue says WebFetch was absent from the session and that curl was "denied by permission settings". It does not say the project's *committed* settings denied `WebFetch`, `Bash(curl:*)` and `Bash(wget:*)`, or that they had done so "since months before".
  - It also does not mention the "four candidate papers / two review articles", or a 2026-09-15 earlier run.
  - These come from a private consumer session that a public reader cannot follow, and the connector observation is attributed to "this repository's review of the fix", which the text does not locate.
- **Severity:** minor.
- **Fix:**
  - Attribute each such detail explicitly ("per the consumer session; not in the issue"), or add it to the issue.
  - Point to the review record by path.
- **Verified:** no, beyond reading issue #74.

**8. `murderboard_subagents.sh` `--lookup`: the sandbox branch, and the dead code.**
- **Issue 1 (unverified):** only `sandbox.network.deniedDomains` is checked. If the harness sandbox is allow-list based (`allowedDomains`), the common blocking shape is "sandbox enabled, resolvers not allowed", which this scan reports as clean. The scan does state that its exit 0 is not an all-clear.
- **Issue 2:** a duplicate `return None` at the end of `lookup_verdict`.
- **Severity:** minor.
- **Fix:** have RTFM confirm the sandbox schema and add the allow-list case, then drop the duplicate line.
- **Verified:** no (sandbox schema); yes (dead code).

## What I checked and found sound
- The scoped limit (equipment, not honesty) is stated consistently in the process file, the skill, the CLAUDE.md drop-in and the probe record. I found no claim that the probe catches guessing.
- `unavailable` in a bulleted, bolded, numbered or heading line fails.
- A fenced example line does not mask a real one.
- An `unreached:` count above zero fails under `not needed`.
- Every table key matches its live source.
- The lookup scan's rule parsing handles `Bash(curl *)`, `Bash(curl https://*)`, the `*` and `Web*` globs, and `dontAsk` with only a POST-scoped curl.

Scratch fixtures: `<scratch>/mb/scratch/x-4/t.sh` and `<scratch>/mb/scratch/x-4/keys.py`.
