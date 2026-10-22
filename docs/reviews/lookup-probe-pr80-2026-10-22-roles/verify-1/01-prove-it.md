GRANT 1 MISMATCH — missing Grep, Glob; holds no forbidden tools (holds Read, Bash, SubagentHandback)

This is a run finding, not one about the artifact. I did my searching with grep through Bash, so nothing was lost.

# Role 1 (Prove It): blind verify pass on PR #80, branch `lookup-probe` at 7cec2d7

I didn't edit anything in any repo. All scratch files are under /private/tmp/claude-501/-Users-tonydefazio-Developer-murderboard/e08dd00d-458d-4dc7-8229-49f1f45d6e83/scratchpad/mb/scratch/v-1/

## Findings

Each finding gives location · issue · severity · fix · whether I verified it against a source.

1. **The gate does not look for the file it names. It accepts any file numbered 0, and this PR's own committed archive would pass on the probe reply this PR retracts.**
   - **Location:** `murderboard_roster.sh` cmd_check, the `role_report_file "$dir" 0` call. The same claim appears in the process-file table ("that archive must hold `00-lookup-probe.md`"), in the SKILL step 7 text, and in the error message.
   - **What happens:** `role_report_file` matches any file whose leading digits equal 0, so `0-notes.txt` satisfies it. I built a record with `Lookup: live` pointing at `git archive HEAD` of `docs/reviews/lookup-probe-pr80-2026-10-22-roles/` and it passed with exit 0. At HEAD the only 0-file in that archive is `00-lookup-probe-round1-old-design.md`. That is the Ioannidis / `murderboard-probe-0000` reply, which the second commit says could be passed from memory. The round-2 `00-lookup-probe.md` is **untracked** (`git status`: `??`), yet the commit message says the reply "is archived as 00-lookup-probe.md".
   - **Severity:** Major.
   - **Fix:** match the exact basename `00-lookup-probe.md`, or correct all four texts. Commit the round-2 reply, and rename the old-design file so it doesn't start with `0`.
   - **Verified:** yes, by constructed records.

2. **A code comment claims the error message names the line it read. It doesn't.**
   - **Location:** `murderboard_roster.sh`, the comment above `lookup_grammar`: "a quoted `unavailable` above a real `live` -- fails closed, and the message says which line it read."
   - **What happens:** I tested it. The `unavailable` message and the `unrecognized` message both print a fixed text. Neither quotes or locates the line.
   - **Severity:** Minor.
   - **Fix:** print the matched line (and its number), or delete the clause.
   - **Verified:** yes.

3. **The SKILL's cost-gate claim holds only when the agent is spawned by name.**
   - **Location:** SKILL 4a, "The cost gate does not count the probe as a call-up, because it carries none of the fan-out's vocabulary."
   - **What happens:**
     - A probe sent to `subagent_type: murderboard-doi-or-die` with the probe prompt gives gate exit 0, so it is not treated as a call-up.
     - On the fallback path, the prompt is the agent file's contents ("role 1 of 11", "checklist"). There the gate counts it as a call-up and went on to the model check (exit 2 in my test, with no transcript).
     - SKILL says the fallback happens "on a repo's FIRST run, always".
   - **Severity:** Minor.
   - **Fix:** limit the claim to the named path. Alternatively, say that on the fallback path the probe is counted, which is harmless after the preflight.
   - **Verified:** yes, I ran the gate on both payloads.

4. **The scan misses a bare `Bash` deny, which removes curl.**
   - **Location:** `murderboard_subagents.sh --lookup`. Related: the selftest comment "A bare Bash deny is a louder problem than this scan names, and must not read as one" sits above a test of `Bash(rm:*)`, which is not a bare Bash deny.
   - **What happens:** `deny ["Bash"]` and `deny ["Bash(*)"]` both exit 0 and print nothing. The docs (permissions.md, "Tool name wildcards") say a bare-name deny removes the tool, so both rules kill the curl route the text names. The ⚠ in the process file covers role 1 losing Bash, not this scan's silence.
   - **Severity:** Minor.
   - **Fix:** WARN or BLOCK on a bare `Bash`/`PowerShell` deny or a `(*)` deny, and fix the comment or the fixture.
   - **Verified:** yes.

5. **False BLOCK in `dontAsk` mode when `Bash` is allowed.**
   - **Location:** the scanner's dontAsk branch.
   - **What happens:** `{"defaultMode":"dontAsk","allow":["Bash"]}` reports "nothing in permissions.allow lets a lookup through", but `Bash` pre-approves curl.
   - **Severity:** Minor.
   - **Fix:** treat a bare `Bash`/`PowerShell` allow as letting the lookup through.
   - **Verified:** yes.

6. **The sandbox check reads only `deniedDomains`.**
   - **Location:** the scanner's sandbox block, which the process file and README describe as "a sandbox denying the resolvers".
   - **What happens:** sandboxing.md says the allowed domains "start empty", and under `strictAllowlist` or `allowManagedDomainsOnly` any host not on the list is refused. A sandbox whose allowlist omits the resolvers is never flagged. The text's wording is narrow enough to be literally true.
   - **Severity:** Minor (coverage gap, not a false statement).
   - **Fix:** state the limit, or check `allowedDomains` when the strict flags are set.
   - **Verified:** yes (docs fetched today).

7. **"Exact deny list" overstates the fixture.**
   - **Location:** the commit message ("A selftest now carries that exact deny list") and the selftest comment ("as the consumer's committed settings actually had it").
   - **What happens:** the fixture has 4 entries. The consumer's `.claude/settings.json` at 689b136 has 23 deny entries, and the fixture's 4 are a subset. The scan verdict on the real file matches: 3 BLOCKs, exit 1.
   - **Severity:** Trivial.
   - **Fix:** say "the fetch-related entries of".
   - **Verified:** yes.

8. **The commit message says more files name the new flags than actually do.**
   - **Location:** commit 7cec2d7, "README, the drop-in paragraph and CI now name --require-lookup and --lookup."
   - **What happens:**
     - The CLAUDE.md drop-in names only `--require-lookup`.
     - CI names only `--lookup`.
     - README names both.
   - **Severity:** Trivial (commit text only).
   - **Fix:** none needed in the tree.
   - **Verified:** yes.

9. **Edge case: a line written without a colon is read as undeclared.** `Lookup — unavailable` and `Lookup unavailable` exit 0. This doesn't contradict any claim, because the grammar requires a colon.
   - **Severity:** Trivial.
   - **Verified:** yes.

## Claim ledger

Format: quoted value · source · what I recomputed · verdict.

**Selftests and gates**
- Roster selftest 59→72→82: ran base 682c31b, 2cd1427 and HEAD and got 59, 72, 82 passed with 0 failed · match
- Scanner selftest 9→19→30: got 9, 19, 30 · match
- All `tests/*.py` and `murderboard_agents.py check` · all exit 0 · match
- "agents 02 and 06 regenerated": both are in the diff and `check` agrees · match

**Version and date stamps**
- Plugin 0.16.0→0.17.0, in both plugin.json and marketplace.json (×2) · match
- Page 0.15.2→0.15.3; Updated 2026-10-21→2026-10-22; sitemap lastmod 2026-10-22; ticker entry 2026-10-22 · match (today is 2026-10-22)
- "--help printed a truncated header": the base header ends at line 37, but help printed `2,30p` · match

**The six probe DOIs**
Every one gives doi.org 302 and a Crossref title that matches the table exactly, character for character.

| DOI | `created.date-time` | PMID | Cited by |
|---|---|---|---|
| jnutbio.2017.08.013 | 2017-09-04T03:45:43Z | 29032081 | 11 |
| mimet.2018.03.010 | 2018-03-23T19:17:01Z | 29580982 | 17 |
| 10.1155/2016/7920631 | 2016-06-09T22:05:54Z | 27378826 | 7 |
| s12938-016-0298-3 | 2017-01-13T09:21:33Z | 28086892 | 18 |
| ultsonch.2011.12.010 | 2011-12-21T13:14:18Z | 22316613 | 21 |
| 10.4088/pcc.15l01844 | 2016-01-27T18:57:07Z | 27247839 | 2 |

- All six titles, timestamps, PubMed indexing and "little-cited" · match
- A fresh `10.1000/<12 hex>` gives a doi.org 404; `10.1000/182` resolves to the DOI Handbook (the IDF prefix); `openssl rand -hex 6` gives 12 hex characters · match
- The round-2 probe reply's PMID 29032081 and timestamp · match

**The NCBI example**
- The PMC ID converter answers `10.1210/endocr/bqad150` with "Identifier not found in PMC", verbatim, at the pmc.ncbi.nlm.nih.gov API · match
- PubMed indexes it as PMID 37793082, *Endocrinology* 2023 · match
- "an empty record through the connector": the issue says "returned no PMID" · consistent, not independently reproducible

**Incident facts in the appendix**
Sources: interface2 @ 689b136, the REBOOTS working tree, and issue #74.
- Settings deny `WebFetch`, `Bash(curl:*)`, `Bash(wget:*)`, present since 575463b5 on 2026-05-15 · match
- Roles 2 and 6 open with "GRANT n MISMATCH — missing WebFetch" · match, verbatim first lines
- 12 DOIs, each matched against the paper's own saved text · match (role 2 report)
- 4 candidate papers and 2 reviews unread · match
- "DOIs not resolved live" filed as a run residual · match (role 2 finding 6 is "Minor (run residual)"; the record's residual item 3)
- Roster and grants gates passed · match (I re-ran both, base and head, on the record: exit 0; `--require-lookup` now fails it)
- "once the header stopped claiming named agents" · the record has one git commit, so I can't see an earlier header. The issue attributes it. `verify` does fail a "(named agents)" variant of the record. Plausible; attributed, not independently verified.
- "confirmed all twelve through PubMed and bioRxiv connectors" · match per the issue (convert_article_ids / get_preprint). The record says "the bioRxiv API".
- Second run on that machine, 2026-09-15, two rounds, search snippets · match (REBOOTS rounds 1 and 2: roles 2 and 6 MISMATCH missing WebFetch; role 6 had curl denied and says it worked from snippets; role 2 says "search-result summaries")
- "The #74 record wrote its declaration lines as list bullets" · match (`- roles:`, `- Mode:`)

**What the text says the scanner and gates do**
- Tool-name globs `*` and `Web*`, scoped rules, `dontAsk`, allow-as-pre-approval, the `mcp__plugin_<p>_<s>__*` and `mcp__claude_ai_<s>__*` forms, and the required trailing `__*` in a subagent's `tools:` · match against code.claude.com permissions.md and sub-agents.md, fetched today
- The connector paragraph: a whole-server row compiles into the `tools:` line; `verify` passes `ok` when it repeats the entry; it fails when individual tools are listed · match (tested)
- `single-pass (subagents unavailable)` rejected by the gate · match (base gate refuses it)
- "no file records it" removed everywhere · match (git grep finds nothing outside docs/reviews)
- Round-1 defects named in the second commit: a bulleted `unavailable` exits 0, and an unrelated-domain WebFetch deny gives BLOCK · both reproduced on 2cd1427; both fixed at HEAD
- The `live` archive check and the "message says which line" comment · mismatches, see findings 1 and 2

## Source of record

For this artifact, the source of record is the review archive plus issue #74. I checked the archive against the claims about it, which is how finding 1 came up: the committed archive and the working tree differ by the untracked round-2 probe reply. I didn't read the earlier role reports, as instructed.
