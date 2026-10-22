GRANT 3 ok — Read, Grep, Glob

(SubagentHandback is the harness's hand-off tool, not a review tool. I hold no Edit, Write or NotebookEdit.)

**Role 3 — Cross-Examiner: findings on PR #80 (`lookup-probe`)**

Each finding: location · issue · severity · suggested fix · could I verify it against a source.

**1. The process file's single-pass wording fails the gate** (existing text, not new in this PR, but you asked)
- **Location:** `doc_review_process.md:159`
- **Issue:** The text tells the reader the record says `Execution: single-pass (subagents unavailable)`. The gate only accepts `(forced)` or `(chosen)` (`execution_cause`, roster.sh:311-319). A single-pass line with neither qualifier fails always, flag or not (roster.sh:512-520). The gate's own selftest pins this exact shape as `unstated` (roster.sh:772). The Output contract section of the same file (1256, 1290-1297) and the skill (409, 418) both use `single-pass (forced)`. Anyone following the review step by hand writes a line the gate rejects. The new Lookup bullet directly below it copies the same "The record then carries… see *Output contract*" pattern.
- **Severity:** High.
- **Fix:** Change it to `Execution: single-pass (forced)`.
- **Verified:** yes.

**2. `--help` now cuts off the usage text**
- **Location:** `murderboard_roster.sh:945` and `:955`
- **Issue:** Both print `sed -n '2,30p'`. The PR added three header lines, so line 30 is now the `--require-lookup` line. The help output loses that line's explanation (line 31), `--process` (32), `--selftest` (33) and the whole EXIT CODES block (35-38). Before the PR, `--process` and `--selftest` still printed.
- **Severity:** Medium.
- **Fix:** Use `2,38p`, or print up to a sentinel line instead of a fixed number.
- **Verified:** yes.

**3. The companion docs give the old roster command**
- **Location:** `CLAUDE.md:149` (the vendoring paragraph) and `README.md:133-137`
- **Issue:** Both still say `check --require-execution --require-reports`. The skill now runs `--require-lookup` as well (SKILL.md:443). The README comment lists what exit 1 means and leaves out the Lookup line. Neither file mentions the lookup probe or `--lookup`. Someone who runs the process by hand from the vendoring paragraph never opts into the new check.
- **Severity:** Medium.
- **Fix:** Add `--require-lookup` and one clause about the lookup probe to both.
- **Verified:** yes.

**4. Descriptions of the subagent scan don't mention `--lookup`**
- **Location:** `CLAUDE.md:7`, the `murderboard_subagents.sh` row at `README.md:53`, and the script's own header at `murderboard_subagents.sh:2-3`
- **Issue:** All three say the scan only reports what blocks subagents. Its exit-code text at lines 53-56 also says "NOT 'subagents work'", which reads oddly under `--lookup`.
- **Severity:** Low.
- **Fix:** Add one sentence to each about the second mode.
- **Verified:** yes.

**5. The roster gate's descriptions are incomplete**
- **Location:** `docs/index.html:1185-1193`, `DESCRIPTION-for-claude.md:64-69`, `START-HERE.md:104-108`
- **Issue:** All three describe exit 1 only as "a role is missing". It now also fires on `Lookup: unavailable`, always, with no flag. These docs already left out the Mode/Execution checks, so the PR widens an existing gap. If the page is edited, its Version/Updated stamp needs a bump.
- **Severity:** Low.
- **Fix:** At minimum, add the always-fails `unavailable` case to the README roster row (`README.md:51`), which already lists the one other always-fail rule (an archive named but missing).
- **Verified:** yes.

**6. One probe is said to answer for role 6, but it only tests DOIs**
- **Location:** `doc_review_process.md:164` ("the same probe, for roles 2 and 6"), `:934-936`; `SKILL.md:281` ("one probe answers for both")
- **Issue:** The process file defines role 6's capability as "reading a documentation page" (936). The probe only checks DOI resolution. A route that passes it, such as a PubMed connector (`Lookup: live — PubMed connector`, SKILL.md:421), can't read documentation pages, yet it would mark role 6 as able to reach its sources. The appendix's 2026-09-15 case was exactly that: a deliverable whose sources were documentation pages.
- **Severity:** Medium.
- **Fix:** Either add a page-fetch half to the probe, or say plainly that `live` certifies DOI resolution only, and that role 6 must be probed separately when its route isn't a general fetch.
- **Verified:** yes, for the inconsistency in the text. Whether connectors can read docs depends on the connector.

**7. "Probe" names two different checks, and "the same probe" blurs them**
- **Location:** `doc_review_process.md:164`
- **Issue:** "The same probe" refers to the subagent probe in the bullet above. That one is a different check: in the skill, the subagent probe runs at step 1a and the lookup probe at step 4a. The skill says "before anything else is spawned" (SKILL.md:252), which is only true after the subagent probe has already spawned one throwaway agent. There is no project glossary to check this against.
- **Severity:** Low.
- **Fix:** Write "a probe of the same kind", or name both of them: "subagent probe" and "lookup probe".
- **Verified:** yes.

**8. The probe is undefined for single-pass runs**
- **Location:** `doc_review_process.md:164-173`; `SKILL.md` step 4a and `:443`
- **Issue:** The probe is defined as a spawn of "role 2's own agent". A chosen single-pass run that cites things has no separate role-2 agent. A forced single-pass run can't spawn one at all. Yet the skill always passes `--require-lookup`. Neither file says how such a run gets a `Lookup:` token.
- **Severity:** Medium.
- **Fix:** Say what a single-pass run does: the main thread runs the same two-DOI probe itself and records the result.
- **Verified:** yes.

**9. The skill's template comment puts `not needed` under the probe**
- **Location:** `SKILL.md:410`
- **Issue:** The comment reads `Lookup: live | not needed  # from step 4a's probe`, but `not needed` is the path that skips the probe. Also, the `not needed` exemption is only mentioned inside the "Anything else → STOP" bullet (292-296). Read in order, it looks like something you only learn about after a probe fails.
- **Severity:** Low.
- **Fix:** Annotate it "`live` from the 4a probe; `not needed` instead of it". Move the exemption ahead of the probe prompt.
- **Verified:** yes.

**10. The gate's example of `not needed` is narrower than the rule**
- **Location:** `murderboard_roster.sh:275` (the error message for an unrecognized token) and selftest `:320`
- **Issue:** The example reads `not needed — the deliverable cites nothing outside itself`. The process file (1327, 1335-1337) and the skill (295, 422) define the token as no references, no named attribution *and* no outside method. The gate's example drops the outside-method condition. It is prose and never parsed, but it is the grammar the gate prints to teach the token.
- **Severity:** Low.
- **Fix:** Reuse the process file's sentence.
- **Verified:** yes.

**11. What the scan actually matches differs from how it's described**
- **Location:** `murderboard_subagents.sh:159` and `:206-212`, against `doc_review_process.md:1344-1345` and `SKILL.md:290`
- **Issue:** The docs say the scan names "a `WebFetch` or `Bash(curl …)` deny". The scan also BLOCKs on `WebSearch` and `wget` denies. WebSearch is not a lookup route in the process file's list ("WebFetch, a shell fetch, a literature connector"). The hook-matcher check, in the other direction, tests only the string `WebFetch`, so a PreToolUse hook matched on `Bash` (the curl route) is never flagged.
- **Severity:** Low.
- **Fix:** Either list WebSearch/wget in the docs or drop WebSearch from the match. Test the hook matcher against `Bash` too.
- **Verified:** yes.

**12. "States it on every run" is false under `--hook`**
- **Location:** `doc_review_process.md:1345-1346`; `murderboard_subagents.sh:305`
- **Issue:** With `--hook` and no blockers, `report()` returns before it reaches `report_lookup`. Nothing is printed, including the caveat. The subagent scan has the same silent hook path already (process 1316, CLAUDE.md:8), so the wording is consistent with that, but it is not literally true.
- **Severity:** Low.
- **Fix:** Write "on every run that prints".
- **Verified:** yes.

**13. One message still says "Agent tool" in `--lookup` mode**
- **Location:** `murderboard_subagents.sh:130`
- **Issue:** When python is missing, the message reads "cannot say whether it denies the Agent tool" even under `--lookup`.
- **Severity:** Low.
- **Fix:** Pick the noun by `$SCAN`.
- **Verified:** yes.

**Checked and consistent:**
- **Lookup tokens and parsing:** `live`, `not needed`, `unavailable` are the same in the process file (1321-1342), the gate's comments (330-348), its code (353-362, 552-579), its selftest, and the skill (410, 420-426, 483-486). The skill's `live | not needed` template plus its separate note on `unavailable` agrees with the process file's four examples. `Lookup:` and `Execution:` share one parser, `token_head`.
- **Step numbers:** the process file's "step 2" (lines 141 and 936) is its Review step. The skill's 1a, 4a and 7 refer correctly to its own headings (152, 242, 388). "Stop before role 1" matches in both.
- **Dates, issue, counts and identifiers:** 2026-10-14 and issue #74 match everywhere. "Twelve" citations matches in process 939 and 1639, roster.sh 339, and the selftest. Connectors are "PubMed and bioRxiv" throughout. The NCBI example (`10.1210/endocr/bqad150`, PMID 37793082, 2026-10-14) is identical in the process file and `agents/02-doi-or-die.md`.
- **Probe DOIs:** they appear only in the skill. `10.1371/journal.pmed.0020124` is Ioannidis, *PLoS Med* 2005, *Why Most Published Research Findings Are False*; that is from memory, not looked up live. The doi.org 404 for `10.1000/murderboard-probe-0000` is not verified: I have no web access.
- **Grants table:** rows 2 and 6 are identical (process 969 and 973), so "share a grant" holds. "Seven roles" hold Bash (roles 1, 2, 4, 6, 7, 9 and 10), matching scanner line 158.
- **Cross-references:** "see *Output contract*" resolves to the heading at line 1200. The skill's pointer to *A connector reaches a role only through its grant* resolves at process line 943.

Files: /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/doc_review_process.md, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/skills/murderboard/SKILL.md, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/murderboard_roster.sh, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/murderboard_subagents.sh, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/README.md, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/CLAUDE.md, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/docs/index.html, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/START-HERE.md, /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/DESCRIPTION-for-claude.md
