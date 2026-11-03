> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 4 MISMATCH — missing Grep, Glob; holds Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch/update/guide, plus deferred NotebookEdit, WebFetch, WebSearch and other MCP tools (all loadable)

I used only Read and Bash, and I made network calls only through curl in Bash. I edited nothing in any repo. The only files I wrote were fixtures, made with printf, under …/scratchpad/mb/scratch/w-4/. I read no earlier review except 00-lookup-probe.md.

**Answer key recomputed independently.** All 12 keys match. Each DOI gives HTTP 302 at doi.org, and its Crossref title and its PubMed title (PMIDs 29032081, 29580982, 27378826, 28086892, 22316613, 27247839) both hash to the published key. Crossref citation counts run from 2 to 21. Each RFC page returns 200, and its `<span class="h1">` title hashes to its key. The pages have no `<title>` tag. A fake 10.1000/<12 hex> DOI gets 404 from both doi.org and Crossref. Both selftests pass: roster 90/0, subagents 35/0.

## Findings (location · issue · severity · suggested fix · verified against a source)

**1. SKILL.md 4a "the answer key is hashed"; docs/index.html "answers have to be looked up rather than recalled" · BLOCKING · verified yes**
Item 3 can be passed from memory. Before fetching anything, I wrote down the titles of RFCs 4691, 5153, 6127, 7058, 8137 and 3364 from recall and ran them through the skill's `key()`. All 6 matched the table.
- The hash does not stop recall. It turns the table into an offline oracle: the probed agent can check a guess against the key and correct it before answering.
- Item 3 is the only item that clears role 6. For a model like the one running these roles, it has no power.
- The public page states the opposite, so the public page is false.
- Fix:
  - Ask for a field nobody remembers instead of the title. Examples: the Location host and PII that doi.org redirects to, or the text of a stated section heading or line deep in the RFC.
  - Or take item 3 from a much larger rotating pool.
  - In either case, restate the claim as "not copied from this page". Drop "cannot be recalled".

**2. SKILL.md "a plain-text title on disk answers a later run's probe" (the archive is redacted for this reason) · HIGH · verified yes**
The PR's own reasoning applies to a copy it cannot redact: the harness transcript.
- I ran a pure-offline script over the parent session's transcript, `<session transcript>`. It hashes every 3–28-word span against the 12 published keys.
- It recovered **12 of 12** titles with no network.
- Every probe run writes the raw reply, with titles, into that file. With 6+6 fixed rows, a machine that has run the probe a few times holds the whole key in plain text.
- "Neither does any file on this machine" is enforced only by honor.
- Fix: state this limit next to the redaction rule. Rotating a larger pool reduces the leak but does not remove it.

**3. murderboard_roster.sh, the `live` archive check · HIGH · verified yes (fixture)**
The gate can be satisfied without any probe having run. The fixture:
- a record containing `Lookup: live — curl; …; probe 10.1000/abcdefabcdef`
- a `00-lookup-probe.md` whose only content is `10.1000/abcdefabcdef`
- result: rc=0 under `--require-execution --require-reports --require-lookup`

The main thread both chooses the fake DOI and writes the file. "Copied from an older run does not count" is therefore defeated by editing one string. The README's "with this run's probe DOI" overclaims: the gate checks the DOI the line names, not a DOI from this run.
- Fix, cheap and partial: also require one of the six DOI keys, one of the six RFC keys when the line says roles 2 and 6, and a `pass` line per item.
- State the residual in the README: the gate assumes an honest orchestrator.

**4. Gate under `Lookup: not needed` · HIGH · verified yes (fixture)**
The #74 record, rewritten as `Lookup: not needed — nothing cited`, passes (rc=0), even with role 2's archived report saying `unreached: 12` and "DOIs not resolved live". The `unreached` check runs only under `live`.
- This makes the skill's sentence false: *"'Go ahead anyway' cannot buy a passing record: the roster gate fails `Lookup: unavailable` however it is written."* Writing `not needed` buys exactly that. "Never after a probe that failed" is unenforced.
- Fix:
  - Run the `unreached` check for every token.
  - Fail `not needed` when the role 2 or role 6 report carries a nonzero `unreached` count or any DOI pattern.
  - Soften the skill sentence to match.

**5. The `unreached:` parser (`grep -ioE 'unreached:[[:space:]]*[0-9]+'`) · HIGH · verified yes (fixtures)**
Under `live`, each of these role-2 reports passes (rc=0):
- `**unreached:** 12`, a bold key. This gate's own Lookup parser goes out of its way to accept a bold key, and this one does not.
- `- Unreached — 12`
- `unreached: twelve`
- a report with no `unreached` line at all that says "I could not resolve any DOI".

A count that is never written passes the same as a zero, so the alarm cannot ring when the role omits it.
- Fix:
  - Under `live`, require the line to be present in 02 (and in 06 when roles 2 and 6 are named).
  - Strip markdown decoration around the key.
  - Fail any value that is not a number.

**6. `Lookup: live — …; role 2 only` · MEDIUM · verified yes (fixture)**
The gate never parses the roles clause. A methods document resting on library documentation can record `role 2 only` (a PubMed connector, no page fetch) and pass. Role 6 then cannot read a single documentation page, and nothing fails unless role 6 counts its unreached sources honestly. "Require the items the deliverable needs" is a judgment the orchestrator makes alone.
- Fix: when the line says `role 2 only`, require role 6's report to carry `unreached: 0` together with a stated reason, such as "no outside docs".

**7. The probe's power against the #74 environment · MEDIUM · verified partly (reasoning plus the issue text)**
In #74, WebSearch was present while WebFetch and curl were not.
- Item 2 (`NOT FOUND`) is passed by any agent with no route at all, so the probe's whole power sits on items 1 and 3.
- Item 3 is answerable from recall (finding 1). Item 1 is answerable from a search snippet that quotes the DOI.
- The route line is self-reported. The HTTP status or record ID the prompt asks for is never checked.
- An honest agent stops the run correctly. A sloppy one that searched and wrote "doi.org" passes.
- Fix: score the item-1 evidence. For example, require the redirect target host or the PII, keyed like the title, because that value appears in no snippet.

**8. Item 1 tests metadata resolution, not role 2's actual job · MEDIUM · verified no (reasoning)**
A 302 from doi.org clears role 2. But "says what is quoted" and origin-tracing need the paper's text. A sandbox or proxy that allows doi.org and blocks publisher hosts passes the probe. Paywalled papers are explicitly excluded from `unreached`. So a run whose role 2 opened no paper body is `live` and green.
- Fix: state the limit on the `Lookup:` line ("certifies identifier resolution, not full-text access"). Or add an open-access full-text item.

**9. Honest records that fail · LOW–MEDIUM · verified yes (fixtures)**
Each of these honest `live` records fails:
- One that adds the heading `## Lookup: what the probe found`. The heading is read as a contradictory token.
- One that quotes `> Lookup: not needed — nothing cited` inside a finding.
- One whose finding quotes the skill in a code block, ``` Lookup: unavailable — always fails ```. This prints "Roles 2 and 6 could not reach any source", which is wrong. A review of this very PR is the likely author of such a quote.
- One that writes `live-curl` with no spaces (unrecognized).

Fix: skip fenced code blocks and `>` quotes when matching lookup lines, or say plainly in the skill that quoting the grammar fails the gate.

**10. SKILL.md:423, `REPORTS=docs/reviews/<artifact-stem>_<YYYY-MM-DD>-roles`, which this PR edits · MEDIUM · verified yes (fixture)**
`reports_decl` still strips every `_`. The fixture `reports: draft_2026-10-22-roles/` resolves to `draft2026-10-22-roles/` and fails. #74 reported this exact bug as "Related, smaller", and this PR's own archive dodges it with a hyphenated name.
- The new `00-lookup-probe.md` check is unreachable on the archive name the skill prescribes.
- Fix it here, since this PR touches that line, or say in the PR that it is left open.

**11. murderboard_subagents.sh `--lookup` misses some blocking settings · LOW (it is a hint, not a gate) · verified yes (fixtures and Claude Code sandboxing docs)**
Each of these exits 0:
- An enabled sandbox with `network.allowedDomains: ["github.com"]`. The docs say allowed domains "start empty", so a sandboxed curl to doi.org is blocked. The scan reads only `deniedDomains`.
- `dontAsk` whose only allow entry is `mcp__slack` or `Bash(curl -X POST *)`. Each is counted as an open lookup route.
- A `PreToolUse` hook on `Bash`, which can veto curl. Only WebFetch matchers are flagged.

Fix: BLOCK when `sandbox.enabled` is true and `allowedDomains` covers no resolver. Do not count an unrelated connector, or a WARN-grade curl rule, as a route.

**12. Selftest assertion 'Lookup: live passes' (no archive, no probe DOI → 0) · LOW · verified yes**
The assertion makes it a passing case that `live` with no evidence is fine. My fixture confirms it with `--require-lookup` and without `--require-reports`: `Lookup: live — trust me` with nothing else passes. The skill's own flags close this, but README's description of `--require-lookup` does not mention that it depends on `--require-reports`.
- Fix: under `--require-lookup`, require the archive whenever the token is `live`.

## Checked and found sound
- The key arithmetic and its normalization, for the current 12 rows.
- The fake-DOI 404 on both routes.
- The "quoted live cannot mask unavailable" ordering.
- A table-row declaration passes.
- The two scans do not bleed into each other.
- The #74 deny list is flagged as a blocker.
