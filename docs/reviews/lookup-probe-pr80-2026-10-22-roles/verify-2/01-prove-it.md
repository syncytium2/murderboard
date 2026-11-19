> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 1 MISMATCH: missing Grep and Glob; holds no forbidden tools. I hold Read, Bash and SubagentHandback, and used Bash for every search. No repo was edited; all scratch work is under <scratch>/mb/scratch/w-1/

# Role 1 (Prove It): blind verify of PR #80, worktree at d27f847

The worktree is clean apart from the untracked verify-2/ folder. The diff I generated from it is byte-identical to pr80-r3.diff.

**Bottom line:** the hashed answer key holds. All 12 keys recomputed exactly from live sources, and 00-lookup-probe.md is scored correctly. Every selftest count and stamp in the commit messages is right, and the incident facts check out against interface2. Recomputing turned up two medium defects and several low ones, listed under Findings.

## Claim ledger (quoted · source · recomputed · verdict)

### The answer key
I fetched each title live and hashed it with SKILL.md's own `key()` code.

**DOI table: Crossref title and PubMed title each hash to the key in the table**

| row | DOI | key | PubMed ID | Crossref citations | verdict |
|---|---|---|---|---|---|
| 1 | jnutbio | 8158b24485a47382 | 29032081 | 11 | match |
| 2 | mimet | c3c981a0da8ad342 | 29580982 | 17 | match |
| 3 | 7920631 | f2239725e003e19e | 27378826 | 7 | match |
| 4 | s12938 | 4155c5c381b502f4 | 28086892 | 18 | match |
| 5 | ultsonch | b652e1992adf872a | 22316613 | 21 | match |
| 6 | pcc | 9641451be262bf12 | 27247839 | 2 | match |

- All six DOIs return 302 at doi.org, so "redirects at doi.org", "indexed in PubMed" and "little-cited" all hold.

**RFC table: the `h1` title on each rfc-editor.org page hashes to the key in the table**

| row | RFC | key | verdict |
|---|---|---|---|
| 1 | 4691 | 9fecaf80ad677470 | match |
| 2 | 5153 | 0092afed0fda5485 | match |
| 3 | 6127 | 3ef3d2782e39acb6 | match |
| 4 | 7058 | b5968f1390b32c3d | match |
| 5 | 8137 | 23e9af9d35639e48 | match |
| 6 | 3364 | 3033e5ed1516b9ce | match |

- Every page returns 200.
- No page has a `<title>` tag, which confirms what the probe's reply says.

### Scoring in 00-lookup-probe.md
- The rows drawn were DOI row 2 (`10.1016/j.mimet.2018.03.010`) and RFC row 1 (4691); both keys match the table.
- The fake DOI `10.1000/de7821441222` is 12 hex characters and returns 404 at both doi.org and Crossref.
- The reply says the redirect goes to PII S0167701218302070. Confirmed.
- The reply's "RFC 4691, October 2006" matches the page header.
- The prompt in the file matches SKILL.md word for word. **Match.**

### Other recomputed quantities
- **DOI Foundation prefix and 404s:** `10.1000` is the DOI Foundation's prefix (`10.1000/182` resolves). The documentation's example fake DOIs `7652153ccbdc` and `0b9e44c1d2a7`, and the selftest's `0123456789ab`, all return 404. **Match.**
- **DataCite coverage:** `10.48550/arXiv.1706.03762` returns 302 at doi.org, 404 at Crossref and 0 hits in PubMed. `10.5281/zenodo.3509134` returns 302 at doi.org and 404 at Crossref. **Match.**
- **The PubMed Central ID converter:** for `10.1210/endocr/bqad150` it returns "Identifier not found in PMC". PubMed has it as 37793082, *Endocrinology* 2023. **Match.**
- **Selftest counts:** I ran both selftests at each commit.

  | commit | roster selftest | scanner selftest |
  |---|---|---|
  | origin/main | 59 | 9 |
  | 2cd1427 | 72 | 19 |
  | 7cec2d7 | 82 | 30 |
  | d27f847 | 90 | 35 |

  Every one passes with 0 failures, matching all of the commits' "a → b" claims. **Match.**
- **Stamps and tests:** page 0.15.2 → 0.15.3, Updated and sitemap 2026-10-22, plugin 0.16.0 → 0.17.0. All ten tests/*.py pass on d27f847, including published_page_test, and `murderboard_agents.py check` is clean. **Match.**
- **The retracted Execution token:** the process file on origin/main says `Execution: single-pass (subagents unavailable)`, and the gate rejects that token (exit 1) while accepting `single-pass (forced)`. **Match.**
- **The previous round's gate:** at 7cec2d7 the gate took any file numbered 0 as the probe reply (line 642 of murderboard_roster.sh in that version). **Match.**
- **Retractions stay retracted:** no tracked file outside docs/reviews still says "no file records", "murderboard-probe-0000", "pmed.0020124", or describes the timestamp design. **Match.**
- **`verify` with a connector in the grants row:** I put `mcp__pubmed__*` in row 2 of a scratch copy. A GRANT line repeating that entry passes. A line listing the connector's individual tools fails, and so does one omitting it. The compiled `tools:` line carries the entry. **Match.** The claim about the `tools:` field syntax itself is **unverifiable** here, since it rests on Claude Code's documentation.
- **The commit's "1571 → 4963 px" figure:** **unverifiable** by me; it needs a render, which is role 10's job.

### Incident facts in the appendix (interface2 @ 689b1369 and the working tree)
- **The settings:** `.claude/settings.json` denies `Bash(curl:*)`, `Bash(wget:*)` and `WebFetch`. All three were added in 575463b5 on 2026-05-15, which supports "months before". **Match.**
- **The selftest fixture** for issue #74 is an exact subset of that deny list, plus `Bash(rm -rf:*)`. **Match.**
- **Run against the real file,** the new `--lookup` scan reports 3 blockers and exits 1. **Match.**
- **First lines of the role reports:** role 2 and role 6 both open with `GRANT n MISMATCH — missing WebFetch`. **Match.**
- **Role 2's work:**
  - It matched all 12 DOIs offline against the papers' own saved text. **Match.**
  - It could not get the text of the four candidate papers or the two reviews. **Match.**
- **The confirmation afterwards:** 11 papers through PubMed and 1 through bioRxiv. **Match.**
- **The earlier run:** the 2026-09-15 REBOOTS run lost WebFetch in both rounds, and roles 2 and 6 say they worked from search-result snippets. **Match.**

## Findings (location · issue · severity · suggested fix · verified against a source?)

1. **Role 2 and 6 checklists, and murderboard_roster.sh's `unreached` grep** · The text says "the roster gate fails a `live` record whose archive shows it". I constructed role 2 reports and ran the gate on them:
   - These pass with exit 0: `**unreached:** 3`, `**unreached**: 3`, `Unreached sources: 3`, and `unreached: 0 (of 3 tried, 3 errored)`.
   - Only a plain or bulleted `unreached: 3`, or one wrapped in backticks, fails.
   - The Lookup: line was deliberately widened to accept a bold key "because a missed line is a missed failure", but the count line, which carries the same risk, was not.
   - The gate also reads only the top-level role 2 and 6 files, so a verify round's report in a subfolder is never read.

   · **Medium** · Accept `[*_]*` around the key, the way `lookup_lines` does, and add selftests for the bold forms. · Yes, by constructed records.

2. **The process file's connector paragraph: "`murderboard_revendor.py` will not overwrite it"** · This is false unless the consumer also lists the file under `adapted` in `.murderboard-vendor.json`. In murderboard_revendor.py (around lines 393–399), a file whose body differs and is *not* listed is re-copied, which silently drops the connector grant on the next re-vendor. · **Medium** · Tell readers to add the process file to `adapted`. · Yes (code).

3. **The site's "What changed lately" entry** has two problems:
   - It says "no reference had been looked up: the project's settings blocked the web". In fact the settings *allow* WebSearch, and role 2 ran web searches: it found PubMed IDs, the preprint, and candidate papers. What was blocked was resolving the DOIs.
   - It says "The answer key is hashed, so the answers have to be looked up rather than recalled". The hash only stops the agent reading answers off the page. Recall is countered by the papers being obscure, not by the hash.

   · **Low–medium** · Say "no DOI had been resolved; the settings blocked fetching pages", and "hashed, so the answers cannot be read off the page". · Yes (settings.json, role 2's report).

4. **Gate: a quoted example earlier in a record breaks a real `live` line** · The gate takes the first `10.1000/<12 hex>` it finds on any Lookup: line. A record that pastes the documentation's example (`probe 10.1000/7652153ccbdc`) in a code fence above its real line fails with "00-lookup-probe.md does not contain 10.1000/7652153ccbdc". That is a false failure, and the message is misleading. · **Low** · Take the DOI from the last `live` line, or refuse more than one `live` line, as the gate already does for a contradiction. · Yes (constructed record).

5. **RFC table, row 6 (RFC 3364)** · The page splits the title across two `<span class="h1">` elements. Taking only the first gives key 900016051d2d2ede, not 3033e5ed1516b9ce. The probe reply on file says its title "came from the page's h1 span", singular. An honest probe can therefore fail about 1 run in 6. · **Low** · Replace the row with a single-line title, or tell the probe to join all the title spans. · Yes (recomputed).

6. **murderboard_subagents.sh `--lookup` coverage** has two gaps:
   - Its resolver list leaves out rfc-editor.org, the route for item 3. `WebFetch(domain:rfc-editor.org)` and a sandbox denying rfc-editor.org both exit 0.
   - `Bash(curl https://doi.org/*)` covers a resolver but returns only WARN. The code's own comment says a scoped rule "BLOCKs here only when it covers a resolver".

   · **Low** · Add `rfc-editor.org` to the resolver list, and apply the resolver check to the URL in a Bash fetch rule. · Yes (constructed settings).

7. **Commit d27f847: "Its fix lines fit 80 columns"** · The `--lookup` warning for an instruction file prints a fix line 96 columns wide ("read the line; if it does forbid it, lift it…"). The other two fix lines are 77 and 73. · **Low** · Shorten that line. · Yes (measured).

8. **SKILL.md, the cost-gate paragraph: "Spawned by name, the probe is not a call-up to the cost gate"** · This holds only if the Agent call's description avoids role vocabulary. I ran murderboard_model_gate.sh on a fable transcript:
   - With description "Lookup probe": exit 0, not counted.
   - With description "Lookup probe for role 2": exit 2, blocked, because the agent name supplies the word "murderboard".
   - The fallback probe also exits 2, which matches what the paragraph says.

   · **Low** · Make the claim conditional, or drop it. · Yes (constructed payloads).

9. **Appendix wording**
   - It quotes "DOIs not resolved live" as what role 2 filed. Role 2 actually wrote "Live DOI resolution not tested · Minor (run residual)"; the quoted phrase is the run record's wording.
   - "an empty record through the connector" is not in the record or the issue, which say only "returned no PMID".

   · **Low** · Attribute the quotation to the record, and soften or source the connector detail. · Partly.

10. **Appendix: "here the cause sat in one"** · The committed deny list is confirmed. That this file governed the session is inferred: the run worked on files in a Dropbox folder outside the repository, and its role 7 report names other interface2 checkouts on that machine. · **Info** · Say "the committed settings deny…; the issue attributes the refusals to permission settings". · Partly.

11. **Info**
    - SKILL.md's `key()` applies NFKD without dropping combining marks, so an accented title hashes differently from the same title typed without the accent ("Fréchet" normalizes to "fre chet"). No title in the current key has a diacritic.
    - Issue #74's underscore bug in `reports_decl` is still present. That is out of scope for this PR, but the issue should not be closed by it.
