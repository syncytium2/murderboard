> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 1 MISMATCH — missing Grep, Glob; holds no forbidden tools (held: Read, Bash, SubagentHandback)

That mismatch is a fact about this run, not the artifact. I did every search through Bash, so the check lost nothing. I also had no Write tool, which mattered once: the repo's heredoc hook blocked a scratch script, so I ran the skill's own inline `key()` function instead.

# Role 1 (Prove It): blind verify of PR #80, branch lookup-probe at 22a3f4c

**Summary.** Every number I could recompute matches:
- all 12 answer-key hashes;
- the selftest counts;
- the version and date stamps;
- every appendix fact that a source can settle.

Three things in the text are claimed more broadly than the code delivers:
- **`unreached:` forms.** Several common ways of writing the count are not recognized.
- **`Lookup:` forms.** A numbered item written as `1)` is not recognized.
- **`dontAsk` scan.** It evaluates each settings file alone, so a route allowed in another file produces a false blocker.

Nothing is blocking. Anything I could not check is marked "unverifiable" in the ledger, with the reason.

## Claim ledger
Columns: quoted value · cited source · recomputed value · verdict.

### DOI answer key in SKILL.md
I resolved each DOI at doi.org, took the title from Crossref and from PubMed, and hashed both with the skill's `key()`.

| row | DOI | quoted key | doi.org | Crossref key | PubMed key | verdict |
|---|---|---|---|---|---|---|
| 1 | 10.1016/j.jnutbio.2017.08.013 | 8158b24485a47382 | 302 | 8158b24485a47382 | 8158b24485a47382 (PMID 29032081) | match |
| 2 | 10.1016/j.mimet.2018.03.010 | c3c981a0da8ad342 | 302 | c3c981a0da8ad342 | c3c981a0da8ad342 (29580982) | match |
| 3 | 10.1155/2016/7920631 | f2239725e003e19e | 302 | f2239725e003e19e | f2239725e003e19e (27378826) | match |
| 4 | 10.1186/s12938-016-0298-3 | 4155c5c381b502f4 | 302 | 4155c5c381b502f4 | 4155c5c381b502f4 (28086892) | match |
| 5 | 10.1016/j.ultsonch.2011.12.010 | b652e1992adf872a | 302 | b652e1992adf872a | b652e1992adf872a (22316613) | match |
| 6 | 10.4088/pcc.15l01844 | 9641451be262bf12 | 302 | 9641451be262bf12 | 9641451be262bf12 (27247839) | match |

"Little-cited": Crossref citation counts are 11, 17, 7, 18, 21 and 2. Match.

### RFC answer key in SKILL.md
I fetched each page and hashed the text of its heading span (`<span class="h1">`).

| row | RFC | quoted key | recomputed key | heading spans | verdict |
|---|---|---|---|---|---|
| 1 | 4691 | 9fecaf80ad677470 | 9fecaf80ad677470 | 1 | match |
| 2 | 5153 | 0092afed0fda5485 | 0092afed0fda5485 | 1 | match |
| 3 | 6127 | 3ef3d2782e39acb6 | 3ef3d2782e39acb6 | 1 | match |
| 4 | 7058 | b5968f1390b32c3d | b5968f1390b32c3d | 1 | match |
| 5 | 8137 | 23e9af9d35639e48 | 23e9af9d35639e48 | 1 | match |
| 6 | 7154 | 613447dfa6fb99dc | 613447dfa6fb99dc | 1 | match |

- "Each RFC page shows its title in a single heading": true for all six.
- "RFC 3364 … title spans two headings": it has 2 heading spans. Match.
- "the page has no `<title>` tag" (in the probe reply): no `<title>` on any of the pages. Match.

### Other claims in SKILL.md and the probe archive

| quoted value | source | recomputed | verdict |
|---|---|---|---|
| doi.org answers an unregistered 10.1000 suffix with 404 | live | 10.1000/de7821441222, 7652153ccbdc and 0b9e44c1d2a7 all return 404 | match |
| A DataCite DOI is missing from Crossref and PubMed but resolves at doi.org | live, using 10.48550/arXiv.1706.03762 | doi.org 302, Crossref 404, PubMed 0 hits | match |
| `key()` drops combining marks | ran the block | key("Café") = key("Cafe") = a860b858265b22da | match |
| The old key block, pasted into interactive zsh, left the fake DOI empty | pasted the pre-fix block (HEAD~1) through a pty into `zsh -f -i` | `fake=[]`, and `doi_row` was empty too ("command not found: #") | match, but understated: both row variables were also lost |
| The new block works when pasted | same pty test | fake=10.1000/57a35c3d6312, row=1 | match |
| 00-lookup-probe.md, item 1: key c3c981a0da8ad342 = DOI row 2 | recomputed | equal; doi.org Location is linkinghub …/S0167701218302070, as the reply says | match |
| 00-lookup-probe.md, item 2: NOT FOUND | live | 404 | match |
| 00-lookup-probe.md, item 3: key 9fecaf80ad677470 = RFC row 1, dated October 2006 | page | equal; the page says October 2006 | match |
| Archived role reports are redacted of local paths | counted files containing /Users/, /private/tmp/, /home/ or C:\Users (contents not read) | 0 files | match |

### Selftests, stamps and the CI loop

| quoted value | source | recomputed | verdict |
|---|---|---|---|
| roster selftest 90 → 96 | `--selftest` at HEAD~1 and at HEAD | 90 and 96 (origin/main has 59) | match |
| scanner selftest 35 → 38 | same | 35 and 38 (origin/main has 9) | match |
| Page version 0.15.2 → 0.15.3, Updated 2026-10-22 | docs/index.html, origin/main | as stated | match |
| Born 2026-07-20 | docs/index.html | unchanged | match |
| sitemap lastmod 2026-10-22 | docs/sitemap.xml | 2026-10-22 | match |
| plugin and marketplace 0.16.0 → 0.17.0 | the two manifests | as stated | match |
| All 10 tests/*.py pass | ran them | 10 ok | match |
| Site entry "cut to 57 words" | docs/index.html | 57 with the link text "Details › #80", 54 without, 72 with the heading | match only if the link text counts |
| CI runs the scanner in both modes and accepts exit 0 or 1 | ran it on the worktree | subagents 1, lookup 0 | match |

### Incident facts in the process file's appendix

| quoted value | source | recomputed | verdict |
|---|---|---|---|
| The project's committed settings denied `WebFetch`, `Bash(curl:*)` and `Bash(wget:*)` | interface2 689b136:.claude/settings.json | present in the deny list | match |
| … "and had since months before" | `git log -S` in interface2 | added 2026-05-15 in 575463b5, five months before | match |
| Roles 2 and 6 declared `GRANT n MISMATCH — missing WebFetch` on their first line | 02-doi-or-die.md and 06-rtfm.md at 689b136 | yes, line 1 of each | match |
| Role 2 found each of the twelve DOIs in the paper's own saved text | 02 report | "All 12 DOIs … appears in that paper's own frozen copy" | match |
| Role 2 could not open the four candidate papers or the two reviews | 02 report | candidates (a)–(d) were not read in full; the two reviews were not obtained | match |
| Filed "live DOI resolution not tested" as a minor run residual | 02 report, finding 6 | "Minor (run residual)" | match |
| The record carried it as "DOIs not resolved live" | the run record | residual item 3, now struck through | match |
| The roster gate passed | replayed the gate | origin/main gate exit 0; HEAD gate also exits 0 by default, because the record has no Lookup: line | match |
| The grants gate passed | replayed `verify` (HEAD and 08f5ddb) on the record | exit 0, "9 ok, 2 mismatch" | match |
| The main session confirmed all twelve through PubMed and bioRxiv | record residual item 3; issue #74 | 11 through PubMed, 1 through bioRxiv | match |
| 10.1210/endocr/bqad150: "Identifier not found in PMC"; PMID 37793082; 2023 Endocrinology | PMC idconv API, PubMed esummary | exact errmsg; PMID 37793082, Endocrinology 2023, no PMC ID | match |
| "through the PubMed connector, a record with no PMID and no error" (observed 2026-10-22) | the connector | I have no connector | unverifiable |
| A 2026-09-15 run lost WebFetch across two rounds, sources were documentation pages, role 2 worked from snippets and said so | REBOOTS_2026-09-15-roles (round 1 and round2) | roles 2 and 6 report MISMATCH missing WebFetch in both rounds; curl denied; Slurm, ARC and MathWorks pages; "search-result snippets" stated | match |
| … "on that machine" | none | the issue puts the 10-14 run on "the Windows box"; I cannot tell which machine the 09-15 run used | unverifiable (the text hedges it with "per the consumer session") |
| The issue attributes the refusals to permission settings | issue #74, root cause item 2 | "denied by permission settings" | match |
| "a capable model passed a fixed answer key from memory" | verify-2/04 (off limits to me) | — | unverifiable by instruction |

### Claude Code behavior the text relies on
Source: Anthropic's documentation pages sub-agents, permissions, mcp and settings, fetched live.

| quoted value | recomputed | verdict |
|---|---|---|
| The `tools:` field needs `mcp__<server>__*` with the trailing `__*` | sub-agents.md:496 | match |
| Plugin servers are named `mcp__plugin_<plugin>_<server>` | mcp.md:523 | match |
| claude.ai connectors are named `mcp__claude_ai_<server>` | permissions.md:573 | match |
| `verify` compares a role's tools to its row exactly | `tool_set()` compares the two lists as sets, ignoring case | match |
| A deny rule with a tool-name glob removes the tool | permissions.md "Tool name wildcards" | match |

### "X does Y" claims about the gate and the scanner, run on constructed records and settings

| quoted value | recomputed | verdict |
|---|---|---|
| `unavailable` always fails (plain, bullet, bold key, `3.`, heading, uppercase, blockquote) | exit 1 for each | match |
| A fenced `Lookup:` line is skipped; a fenced example DOI does not stand in for the real one | exit 0, and the real DOI is the one checked | match |
| Two different tokens fail; an unknown token fails | exit 1 for both; two identical lines pass | match |
| `live` with an archive needs 00-lookup-probe.md holding the line's DOI | wrong DOI exit 1; right DOI exit 0 | match |
| `unreached:` is read in bold, dashed and bulleted forms; a non-number fails; it is read under every token | recognized: plain, `**unreached:** 3`, `- `, `* `, em dash, hyphen, "unreached sources", "several", `not needed` with 12, no Lookup: line with an archive | match for these forms |
| … the same claim, other common forms | **not recognized (exit 0): `+ unreached: 2`, `1. unreached: 2`, `\| unreached \| 3 \|`, `## unreached: 2`, "Unreached count: 3"** | MISMATCH, see finding 1 |
| The scan treats rfc-editor.org as a resolver | domain deny, curl URL deny and sandbox deny all BLOCK | match |
| A curl rule aimed at a resolver blocks | `Bash(curl -s https://doi.org/*)` blocks; `curl https://example.com/*` does not | match |
| The #74 settings are found | 3 BLOCK lines, exit 1 | match |
| "dontAsk with no lookup route allowed" | **`dontAsk` plus `allow:[Read]` in user settings and `allow:[WebFetch]` in project settings gives BLOCK, exit 1** | MISMATCH, see finding 3 |

## Findings
Each finding gives location · issue · severity · suggested fix · whether I verified it against a source.

1. **`unreached_count` misses common forms.**
   - Location: murderboard_roster.sh, `unreached_count`; the commit message's "bulleted forms"; the code comment "a missed count is a missed failure".
   - Issue: the regex `^[[:space:]>-]*unreached` does not match a `+` bullet, a numbered item, a table cell, a heading or "Unreached count:". A role 2 report that writes its count in any of these forms passes a `live` record with sources unreached. The `Lookup:` line regex accepts every one of these prefixes, so the two parsers disagree.
   - Severity: minor to moderate. It fails open on exactly the case the gate exists for.
   - Fix: reuse the `Lookup:` prefix class `([-+*_|>#[:space:]]|[0-9]+\.)*` and allow a `|` cell. Add selftests for `+` and numbered forms.
   - Verified: yes (constructed archives).

2. **`1) Lookup: unavailable` passes.**
   - Location: `lookup_lines`; the process file says "a numbered item … count".
   - Issue: only the `N.` form is matched, so a `N)` numbered item is never read.
   - Severity: minor.
   - Fix: accept `[0-9]+[.)]`.
   - Verified: yes.

3. **The `dontAsk` check runs one file at a time.**
   - Location: murderboard_subagents.sh, the `--lookup` `dontAsk` branch.
   - Issue: Claude Code merges `permissions.allow` across scopes (settings.md:298). With `dontAsk` in one file and the route allowed in another, the scan reports a blocker that is not there and exits 1. Separately, an allow rule reaching only `WebFetch(domain:rfc-editor.org)` counts as a route even though it reaches no DOI resolver (nit).
   - Severity: minor. The scanner is a hint, but its exit 1 names a knob that is not the cause.
   - Fix: gather the allow rules from every file the scan reads before judging `dontAsk`.
   - Verified: yes.

4. **An unclosed fence hides the verdict.**
   - Location: `lookup_lines`.
   - Issue: a stray opening fence hides every `Lookup:` line after it, so a real `unavailable` below it passes. This is consistent with CommonMark, but it fails open.
   - Severity: low.
   - Fix: if a fence is still open at end of file, either reread the file without fence skipping or fail.
   - Verified: yes.

5. **The commit message understates the zsh defect.**
   - Location: commit 22a3f4c, "left the fake DOI empty".
   - Issue: `doi_row` and `rfc_row` were also lost.
   - Severity: nit.
   - Fix: "left all three variables empty".
   - Verified: yes (pty reproduction).

6. **The archived scoring does not record the route check.**
   - Location: 00-lookup-probe.md, "Scored by the main thread".
   - Issue: the scoring lines record only the answer and its key. They do not record the route or the HTTP status / record ID that SKILL.md's scoring table now requires. The reply does contain them (302, 404, curl to doi.org and rfc-editor.org). The prompt is labeled "as sent" and uses the earlier wording, which is honest.
   - Severity: nit.
   - Fix: add the route and status to each scoring line, or note that this probe predates the route rule.
   - Verified: yes.

7. **The word count depends on counting the link.**
   - Location: commit message, "57 words".
   - Issue: the 57 includes the link text.
   - Severity: nit.
   - Fix: none needed, or say "57 including the link".
   - Verified: yes.

## Group membership and what was not consulted
- The relevant source of record here is issue #74 plus the interface2 run at 689b136. I checked the appendix against both, including the settings file the text did not name by commit; it agrees.
- The withdrawn claim (that the probe is unforgeable) was not re-inherited: the process file, the skill, the drop-in paragraph and the site entry all now say "equipment, not honesty". The replacement wording ("catches an agent that honestly cannot reach its sources") is consistent with what the gate does.

## Files
- Changed files, all under <worktree>/: murderboard_roster.sh, murderboard_subagents.sh, skills/murderboard/SKILL.md, doc_review_process.md, docs/reviews/lookup-probe-pr80-2026-10-22-roles/00-lookup-probe.md
- Scratch fixtures: <scratch>/mb/scratch/x-1/
- I did not edit any repository.
