> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 2 MISMATCH — missing Grep, Glob; holds Edit, Write, Agent, Artifact, Skill, ToolSearch, mcp__claude_ai_Claude_Docs__batch / __update (editing tools); WebFetch and WebSearch were deferred and loaded through ToolSearch; the bio-research PubMed connector was also loadable and used. No file was edited, written or deleted, and the scratch directory was not used. This reviewer was spawned through the fallback path, which belongs in the ledger. Losing Grep and Glob cost nothing, because I searched through Bash.

**Role 2 (DOI or Die): PR #80, branch `lookup-probe`. Every identifier was resolved live on 2026-10-22, and each row names its route.**

Each row gives: location · issue · severity · suggested fix · could I verify it against a source.

1. **SKILL.md probe, the known-good DOI `10.1371/journal.pmed.0020124`** · It resolves. doi.org returns 302 to dx.plos.org, the handle API returns responseCode 1, and Crossref gives "Why Most Published Research Findings Are False", John P. A. Ioannidis, *PLoS Medicine*, 2005-08-30. The PubMed connector maps it to PMID 16060722 / PMC1182327. The attribution is correct. **One thing the PR does not mention:** Crossref records a 2022-08-25 correction, `10.1371/journal.pmed.1004085`, titled "Correction: Why Most Published Research Findings Are False". The probe still works. But a route that returns the correction record also contains the expected title. And the process's own rule says to check for corrections, which the chosen exemplar quietly carries. · Minor · Either note the correction, or require the probe's FOUND line to name the year or journal, not only the title. · Yes. Routes: curl to doi.org and its handle API, the Crossref REST API (`works` and `filter=updates:`), and the PubMed connector `convert_article_ids`.

2. **SKILL.md probe, the made-up DOI `10.1000/murderboard-probe-0000`** · Confirmed as claimed. doi.org returns HTTP 404, and the handle API returns responseCode 100 (handle not found). · — · none · Yes. Route: curl to doi.org and `doi.org/api/handles/`.

3. **SKILL.md, "`10.1000`, the DOI Foundation's own prefix"** · Supported. `10.1000/182`, the DOI Handbook, resolves to `doi.org/hb.html` on the Foundation's own site. I did not fetch a page that states the prefix assignment in words. · — · none · Partly. Route: curl to doi.org.

4. **SKILL.md probe design, the choice of the two DOIs** · Neither half of the pair needs a lookup to answer. The Ioannidis paper is among the most-cited papers in existence, so a model can return its title from memory. A suffix that literally reads `murderboard-probe-0000` announces that it is fake. So a role with no working route can pass both halves. That reopens the hole the probe exists to close: on 2026-10-14, role 2 held WebSearch and lacked WebFetch and curl. "Any route that passes counts" also lets a web *search* stand in for *resolving* an identifier, which the new existence bullet says is the check. This is a judgment and I did not test it. · Major · Use a known-good DOI that is obscure, and preferably rotate it, then check the returned title against a value the model is unlikely to know. Give the fake a suffix that looks plausible, for example in the same pattern as the real one, under a registered prefix. Require the probe reply to quote one field that only a live answer carries, such as the HTTP status or the handle `responseCode`. · No, not tested empirically.

5. **Process file, role 2 checklist and agents/02, the claim that PMID 37793082 is Mansano 2023 *Endocrinology* at `10.1210/endocr/bqad150`** · Correct. NCBI esummary gives "Fasting Modulates GABAergic Synaptic Transmission to Arcuate Kisspeptin Neurons in Female Mice", *Endocrinology*, 2023 Sep 23, by Mansano NDS, Vieira, Araujo-Lopes, Szawka, Donato Jr and Frazão R. Crossref agrees, and doi.org redirects to academic.oup.com/endo. · — · none · Yes. Routes: NCBI E-utilities esummary, Crossref, and doi.org.

6. **The same bullet, "NCBI's ID converter searches PubMed Central only … answers 'Identifier not found in PMC'"** · The quoted message is exact. The live API at `pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/articles/` returns `"status":"error","errmsg":"Identifier not found in PMC"` for that DOI. NCBI's documentation supports the scope claim: "will only return related IDs if the article is in PubMed Central (PMC)". **Two caveats:**
   - The PubMed **connector** (`convert_article_ids`) is the route the incident actually used. Through it, the same DOI comes back as a bare record holding only `doi` and `requested-id`, with no error and no message. A reader using the connector will never see the quoted words. Their warning sign is an empty record.
   - The 2026-10-14 record says only that the converter "returned no PMID". The verbatim message is therefore today's observation, but the sentence dates it to 2026-10-14.
   · Minor · Add "(through a connector, a record with no PMID and no error)". Date the quote to the day it was actually seen, or drop the date from it. · Yes. Routes: the NCBI idconv API by curl, the NCBI documentation by WebFetch, and the PubMed connector.

7. **Process grants section, the claim that Claude Code's subagent `tools:` field takes `mcp__<server>__*`** · Confirmed. The documentation at code.claude.com/docs/en/sub-agents says: "The `tools` and `disallowedTools` fields also take entries for a whole MCP server", with `mcp__github__*` in the `tools` example. It also warns that a server name containing `__` needs its whole name plus `__*`, and that the form without `__*` matches nothing in `tools`. The PR's text is correct, but it omits that trap. · Minor · Add "(the trailing `__*` is required in `tools`)". · Yes. Route: WebFetch of the Claude Code documentation.

8. **Issue #74 as cited across the files** · The issue exists, is open, and is titled "A role that cannot do its job must stop the run…". It supports the facts the PR attributes to it:
   - WebFetch was absent from the session, and ToolSearch returned only WebSearch;
   - `curl` to doi.org was denied;
   - roles 2 and 6 each declared `MISMATCH — missing WebFetch`;
   - both gates passed;
   - the "DOIs not resolved live" residual;
   - 11 papers were confirmed through PubMed and 1 through bioRxiv;
   - the converter missed Mansano.

   The run record at interface2@689b136 agrees. Role 2's verbatim GRANT line there reads "missing WebFetch … harness denied `curl` to doi.org", and its findings say each DOI was matched "offline against the paper's frozen full text". · — · none · Yes. Routes: `gh issue view 74` and `git show` of the run record and the role reports.

9. **Process grants section, "the 2026-10-14 role 2 held only the tools its list named"** · Very nearly true. The verbatim GRANT line lists Read, Grep, Glob, Bash, WebSearch, "plus SubagentHandback". That is harmless, but the sentence is absolute and the evidence is not. Also, that role held **WebSearch**, which matters for the probe-choice finding above. · Minor · Say "held no connector". · Yes (run record).

10. **Process grants section, the claim that the citations were "confirmed only *after* it, by the main session"** · The record says the 12 citations were "verified independently" after the run, and the issue calls it "what actually worked". Neither text names the main session as the actor in so many words. The role reports rule out role 2, so the inference is plausible. · Minor · Accept it, or say "after the run". · Partly.

11. **Appendix, "It was the second time on that machine … a 2026-09-15 run there lost WebFetch the same way across two rounds … role 2 worked from search-result snippets and said so"** · The REBOOTS_2026-09-15 role reports confirm a mismatch on WebFetch in role 2 and role 6 in round 1, and in role 2 in round 2. The round-2 role 2 report says "`curl` was denied by the permission system, so every web check below rests on search-result snippets from the official pages". That confirms the "same way", "two rounds" and "snippets" parts. **"Same machine" I could not verify.** Nothing I read places either run on the Windows box that #74 names. · Minor · Keep it if the maintainer can confirm it. Otherwise say "in the same consumer project". · Partly (role reports in the interface2 working tree).

12. **Appendix, "Reported by the consumer session that ran it, with the run record and verbatim role reports"** · The issue was authored by the `syncytium2` account, and its text reads as the session's ("as found on the Windows box"). The evidence commit, interface2@689b136, says "Evidence for syncytium2/murderboard#74" and is co-authored by Claude. However, the issue itself gives only paths, stating the files "live on the PI's Dropbox, not in git". The files were committed to a private repo afterwards and never attached to the issue. "Reported … with the run record" therefore overstates what a stranger can follow, though it is acceptable as attribution. · Minor · Say "Reported by the consumer session that ran it, which quoted the run record and the role reports." · Partly (issue text and commit message).

13. **Appendix and issue, other incident details** · These match the run record:
   - "four candidate papers", plus two reviews (Jamieson & Piet 2022, Piet 2015);
   - "twelve" DOIs;
   - "every published recording".
   · — · none · Yes (run record).

**Surface I did not check:** the role 6 half of the probe (that roles 2 and 6 share a grant row is confirmed at doc_review_process.md lines 969 and 973), and the shell scripts' code. Both belong to other roles. Nobody was asked whether the 2026-09-15 run happened on the same machine. That is a residual ⚠ for the maintainer.
