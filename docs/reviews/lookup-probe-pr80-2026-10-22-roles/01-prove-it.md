GRANT 1 MISMATCH — missing Grep, Glob; holds no forbidden tools (held: Read, Bash, SubagentHandback)

(Run note for the ledger: I used `grep` through Bash instead of the missing tools, so the review itself lost nothing. I edited nothing in either repo. Scratch files are only under /private/tmp/claude-501/-Users-tonydefazio-Developer-murderboard/e08dd00d-458d-4dc7-8229-49f1f45d6e83/scratchpad/mb/scratch/role-1/.)

**Input defect, for the main thread.** The diff file the reviewers were given (/private/tmp/claude-501/-Users-tonydefazio-Developer-murderboard/e08dd00d-458d-4dc7-8229-49f1f45d6e83/scratchpad/mb/pr80.diff) covers 5 files. The PR changes 7 (`git diff --stat origin/main...HEAD`). The diff file leaves out `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json`, and the brief's list of changed files leaves them out too.

## Claim ledger (quoted value · cited source · recomputed value · verdict)

| # | Claim | Source | What I got when I re-ran it | Verdict |
|---|---|---|---|---|
| 1 | Roster selftest 59 → 72 | `murderboard_roster.sh --selftest` on origin/main and on the branch | 59 passed / 72 passed. The 13 new assertions are the 13 `t` calls in the diff | match |
| 2 | Subagent scan selftest 9 → 19 | `murderboard_subagents.sh --selftest`, both trees | 9 / 19 (9 new `t` calls plus 1 `case` check) | match |
| 3 | Plugin 0.16.0 → 0.17.0 | `.claude-plugin/plugin.json` and `marketplace.json` (both fields) | 0.16.0 → 0.17.0 in all three places | match |
| 4 | #79 takes 0.16.1 | `gh pr diff 79` | 0.16.1 | match |
| 5 | "All selftests and tests/*.py pass" | all 7 `*.sh --selftest`, 10 `tests/*.py`, `murderboard_agents.py check` | every one exits 0; all 11 agent files agree with the process file | match |
| 6 | The four committed records give the same results as on main; the outside review already fails | roster check, branch vs main | same verdict for all four; the only change is the added `lookup: undeclared` field | match |
| 7 | Ioannidis DOI resolves with that title, PLoS Med 2005 | doi.org content negotiation | "Why Most Published Research Findings Are False", PLoS Medicine, 2005-08-30 | match |
| 8 | `10.1000/murderboard-probe-0000` is a 404 at doi.org | `curl` against the handle API and against doi.org | 404 and 404 | match |
| 9 | ID converter answers "Identifier not found in PMC" for 10.1210/endocr/bqad150; PubMed has it as PMID 37793082; 2023 *Endocrinology*; not in PMC | idconv API and esummary | exact string returned; PMID 37793082, Endocrinology 2023; the PubMed record lists no PMC id | match |
| 10 | Twelve DOIs, found in the paper's own saved text | incident role 2 report | "same 12 distinct DOIs"; each found in the frozen source text | match |
| 11 | "Four candidate papers" not opened | role 2 finding 2 | items (a)–(d): three at search-result level, one "not opened" | match |
| 12 | "Two review articles" | role 2 finding 3 | Jamieson & Piet 2022; Piet et al. 2015 | match |
| 13 | Roles 2 and 6 declared `MISMATCH — missing WebFetch` on their first line | 02/06 reports | both first lines | match |
| 14 | Roster and grants gates both exited 0 | re-ran 08f5ddb's roster (`--require-reports`) and `verify` on the record at 689b136 | both green ("9 ok, 2 mismatch, header agrees") | match. Note: issue #74 says `verify` first refused, until the header stopped claiming named agents. "Exited 0" describes the final state only |
| 15 | Citations confirmed afterwards through PubMed and bioRxiv | run record, residual 3 | 11 via PubMed plus 1 via the bioRxiv API | match. "By the main session" comes from the issue only, since the record says "verified independently" |
| 16 | The main session filed "DOIs not resolved live" as a **minor** residual | run record | It is residual 3 in the record (the issue says "item 2"), and the record does not call it minor. "Minor (run residual)" is the severity role 2 gave its own finding 6 | partly unsupported |
| 17 | 2026-09-15: second time on that machine; WebFetch lost across two rounds; sources were documentation pages; role 2 worked from snippets and said so | REBOOTS_2026-09-15-roles | Windows `C:\Users\defazio` paths, like #74. Round 1 and round 2 roles 2 and 6 all say missing WebFetch and `curl` denied (round 3 ran role 5 only). Sources were Slurm, MathWorks, ARC and RFC pages. Role 2 says "search-result summaries" | match |
| 18 | "Seven roles" hold Bash (scan comment) | grants in `agents/*.md` | roles 1, 2, 4, 6, 7, 9, 10 = 7 | match |
| 19 | Roles 2 and 6 share a grant | agent `tools:` lines | identical: Read, Grep, Glob, Bash, WebSearch, WebFetch | match |
| 20 | **"WebFetch was absent from the session, which no file records"** (process file lines 174 and 1346, SKILL.md line 285, the caveat `murderboard_subagents.sh` prints on every run at line 340, its selftest comment at line 425, commit message, PR body) | consumer repo `.claude/settings.json` at 689b136 | **The committed file has `permissions.deny` containing `"WebFetch"`, `"Bash(curl:*)"` and `"Bash(wget:*)"`, all since 575463b5 (2026-05-15), before both incidents.** The branch's own `--lookup` scan, run against a copy of that file, prints 3 BLOCKs and exits 1, then prints directly below them the caveat that "no file said so" | **mismatch** |
| 21 | `unavailable` "fails the gate always, flag or no flag" | `lookup_line` regex and my edge-case runs | `- Lookup: unavailable — no WebFetch` exits **0** without the flag, and so do `- **Lookup:** unavailable`, `1. Lookup: unavailable` and `## Lookup: unavailable`. The matcher accepts only `* _ \| >` and whitespace as a prefix, never a `- ` list bullet. The #74 record writes its declaration lines as bullets (`- Mode: standard`) | **mismatch** |
| 22 | `--lookup` "names a WebFetch or Bash(curl …) deny" | the scan's regex and my runs | it also BLOCKs on a `WebSearch` deny and on `Bash(wget …)`. WebSearch is not one of the routes the text lists | prose understates the code |
| 23 | Prose hits are WARNs and print on the clean path | my runs plus the selftest | true outside `--hook`. Under `--hook`, prose-only WARNs are silent (exit 0, no output), which matches the hook's general design | match (non-hook mode) |

## Findings (location · issue · severity · suggested fix · verified against a source?)

1. **Process file lines 174 and 1346, SKILL.md line 285, `murderboard_subagents.sh` lines 339–340 and 425, commit message, PR body.** The incident's diagnosis is wrong. The consumer's committed `.claude/settings.json` denies `WebFetch`, `Bash(curl:*)` and `Bash(wget:*)`, and has since 2026-05-15. A file did record it, and it is one the new scan reads. Run against that file, the new scan catches the incident and then contradicts itself in the next line. The "tool is absent from the session" argument is the PR's justification for why the scan can only hint, and the evidence does not support it. ⚠ I could not confirm that the 10-14 session's cwd loaded that file: its artifacts sit under Dropbox, though it used interface2's vendored process. The 09-15 run certainly ran in an interface2 worktree. · **Major.** It is printed to every user on every `--lookup` run. · Restate the incident as "WebFetch, curl and wget were denied in the project's own settings file" (that is attribution, not a path). Keep a general caveat that a session can lack a tool with no file recording it, without claiming #74 as the example. Add a selftest that models the real shape: `deny: [Bash(curl:*), Bash(wget:*), WebFetch]`. · yes (git show at 689b136, git log -S, scan output).

2. **The probe design (process file review step; SKILL.md 4a).** The probe does not tell "can reach the network" apart from "cannot". (a) The known-good pair is the most famous DOI and title in metascience, and a model with no tools can answer it from memory. The fake suffix literally reads `murderboard-probe-0000`, so "NOT FOUND" can be inferred. The route line is self-reported. (b) "Any route counts" does not exclude **WebSearch**, which role 2 is granted and held in **both** incidents (#74 role 2: "held: … WebSearch"; 09-15: "WebSearch loaded via ToolSearch"). A web search finds the Ioannidis paper and finds nothing for the fake, so the probe would very likely have **passed on both machines it was written for**. Those runs would then record `Lookup: live — WebSearch` and the gate would pass. This is a replacement claim that the incident's own data refute. · **Major / possibly Blocking**, for the main thread to adjudicate. · Use an obscure, recently registered real DOI, rotated or chosen at run time, and require a field the model cannot know, such as the registration timestamp from the handle API or the DOI's `URL` target. Use a fake suffix that looks plausible (random, under a real publisher prefix). Require the raw response (HTTP status or JSON excerpt) in the reply. State explicitly whether search snippets count as resolution. Role 2's own report says they do not. · yes (role reports; doi.org; reasoning about the probe text).

3. **`murderboard_roster.sh` `lookup_line`; process file "fails the gate always, flag or no flag"; SKILL.md "fails with or without a flag".** A bulleted `- Lookup: unavailable` exits 0 without `--require-lookup`. The drop-in paragraph and the README tell manual users to run `check <report>` with no flag, so for them the "always" claim is false in the format consumers actually write (see the #74 record's `- Mode: standard`). With the flag, the same line fails, but as "undeclared", which is misleading. The prefix gap already exists for Mode and Execution. This PR's new claim is the one it breaks. · **Major.** · Allow `-`, `+` or `1.` list markers and `#` in the prefix class, or grep any line containing `Lookup:` with no `unavailable` exemption. Add a selftest `'- Lookup: unavailable' FAILS without the flag`. · yes (reproduced: noflag=0, flag=1).

4. **Process file and SKILL.md descriptions of `--lookup`.** The scan also BLOCKs on a `WebSearch` deny and on `Bash(wget …)`, and the text does not say so. The WebSearch match also contradicts the stated route list (WebFetch, shell fetch, connector). · Minor. · Name both in the text, or drop WebSearch from `NAMES`. · yes.

5. **Appendix: "filed 'DOIs not resolved live' as a minor residual."** The record does not call it minor. The issue calls it item 2, but in the record it is item 3. · Minor. · Drop "minor", or attribute the severity to role 2's own rating. · yes.

6. **Appendix: "the roster gate and the grants gate both exited 0".** True of the final record. The issue says `verify` refused until the header stopped claiming named agents, which is the one point where a gate did fire. · Minor. · Add "after the header was corrected to the fallback wording". · yes (issue #74, and the gate re-run).

7. **Process file: "the 2026-10-14 role 2 held only the tools its list named".** It also held SubagentHandback. The point still stands, since it held no connector. · Nit. · "held no connector". · yes.

## What I checked and found clean
- Every version number.
- Both selftest deltas, recounted against the diff.
- All tests and gates on the branch.
- The record-by-record roster comparison against main.
- Every DOI, PMID and title claim, checked live on 2026-10-22.
- Every incident count (12, 4, 2, two rounds, "second time", "seven roles").
- That roles 2 and 6 share a grant.
- Skill step references (4a, step 7, review step 2).
- That `docs/index.html` is untouched.

**Sources not consulted by the PR:** the consumer's own permission settings. These are the record of the incident's environment, and they contradict the diagnosis (finding 1).

Key paths:
- /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/murderboard_roster.sh (`lookup_line`, line 349)
- /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/murderboard_subagents.sh (lines 339–340, 425)
- /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/doc_review_process.md (lines 162–175, 1346)
- /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/skills/murderboard/SKILL.md (line 285)
