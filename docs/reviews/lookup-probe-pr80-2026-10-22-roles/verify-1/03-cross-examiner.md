GRANT 3 ok — Read, Grep, Glob

**Cross-Examiner findings for PR #80 (`lookup-probe`), blind verify pass**

Overall, the documents mostly agree. They all describe three probe tasks and use the same tokens: `live`, `not needed`, and `unavailable`, which always fails. `--require-lookup` and `00-lookup-probe.md` are named the same way in the process file, the skill, the roster gate (comments, messages and selftest), README, CLAUDE.md and the page. Dates agree everywhere: the incident is 2026-10-14 and this change is 2026-10-22.

Step cross-references resolve:
- In the skill: 1a, 4a, 4b, 7, and "Preflight".
- In the process file: *Output contract*, the review step, the appendix, and *A connector reaches a role only through its grant* (a bold sentence opener there, not a heading).
- In the compiled agents: `agents/02-doi-or-die.md` and `agents/06-rtfm.md` match the process blocks word for word.

The Execution token fix (`single-pass (subagents unavailable)` → `single-pass (forced)`) removes an earlier mismatch with the skill and the gate. No stale copy of the old token remains outside a historical comment at `murderboard_roster.sh:170`.

`00-lookup-probe.md` matches the answer key:
- It uses the first row of the skill's table (`10.1016/j.jnutbio.2017.08.013`).
- The title and `2017-09-04T03:45:43Z` match the table.
- The fake DOI is `10.1000/` plus 12 hex characters, as specified.

Findings (location · issue · severity · suggested fix · could I verify it against a source):

1. **`murderboard_subagents.sh:47` (USAGE for `--lookup`) contradicts the process appendix.** · The script says "(issue #74 was the first)". The appendix entry (`doc_review_process.md` ~line 1662) says the #74 run "was the second such run on that machine", after a 2026-09-15 run that lost WebFetch the same way. · **major** (two shipped files disagree on a historical fact) · Change the script to "issue #74 is the one on record" or "the second on record", or cut the parenthetical. · **yes** (both texts are in the repo).

2. **The process file and the skill describe the third probe task differently, and the skill contradicts itself.**
   - The process file (step 2, lines 172–175) says: "read an arbitrary web page and quote a value from it… the third clears role 6, which reads documentation rather than databases."
   - The skill's prompt (SKILL.md:305) actually fetches `https://api.crossref.org/works/<real DOI>`. That is a database record from the same registry the prompt's own first line allows ("a resolver, a registry, or a literature database").
   - The skill's "What each answer proves" table (SKILL.md:329) still claims this shows "an arbitrary web page, not only a database".
   - The page is also fixed per table row, so it is not arbitrary.
   - The claim "a literature connector can pass the first two and not the third" (SKILL.md:331) rests on this distinction, which the task as written does not test.

   · **major** · Either point the third task at a page that is not a database, or reword the process file, the proves-table and the README/page phrasing to describe what it actually tests: a fetched Crossref JSON page. · **yes**.

3. **The phrase "`dontAsk` with nothing allowed" disagrees with the code and with its own selftest fixture.**
   - The phrase appears in the process file (line 1370), SKILL.md:348, the README subagents row, and the `murderboard_subagents.sh` header (line 46).
   - The code blocks when "nothing in permissions.allow lets a lookup through".
   - The selftest case named `'dontAsk with nothing allowed -> exit 1'` uses `allow:["Read"]`, so something is allowed.

   · **minor** · Use "`dontAsk` with no lookup route allowed" in all four places and in the selftest name. · **yes**.

4. **`murderboard_subagents.sh` now reads `permissions.allow` two different ways, and the companion docs repeat only one of them.**
   - The lookup scan treats an allow-list as pre-approval only, unless the mode is `dontAsk` (selftest `'lookup: an allow-list alone -> exit 0'`).
   - The subagent scan in the same file still reports "an allow-list without `Task`" as a BLOCK. A new ⚠ comment (lines 851–853) records that this reading was questioned in review.
   - The README subagents row, CLAUDE.md's drop-in paragraph (line 158) and skill step 1a (line 192–193) all still state the subagent reading as fact, with no ⚠.

   · **minor** (known and flagged in code; the readers' copies are not) · Either reconcile the two readings, or carry the same ⚠ into README, the CLAUDE.md drop-in and skill step 1a. · **yes** (internal contradiction; the Claude Code permissions documentation itself was not checked).

5. **The roster gate does not check the file name it tells people to write.**
   - The process file's token table (line 1352), SKILL.md:339 and :522, and the gate's own error message all name `00-lookup-probe.md`.
   - The code (`role_report_file "$dir" 0`, roster.sh:642) accepts any non-empty file whose leading number is 0, such as `0-notes.md` or `000.md`.

   · **minor** · Either check the exact name, or say "a file numbered 00, e.g. `00-lookup-probe.md`" in the docs and the message. · **yes**.

6. **"Parsed the same way as `Execution:`" (process file, line 1342) is only half true.**
   - The token cut is shared (`token_cut`).
   - The line match is not. Per the roster comment at ~line 489 it is deliberately wider: bullets, numbered items, headings and bold keys count. Any `unavailable` line wins over an earlier `live`.
   - The gate also accepts `not-needed`, which no document lists.

   · **minor** · Change the sentence to "the token is parsed the same way as `Execution:`; the line match is wider, and any `unavailable` line decides it", and either document `not-needed` or drop it. · **yes**.

7. **The skip condition is worded in two ways.**
   - The process file (lines 167 and 1353) says "no references, no named attribution, no outside method".
   - The skill (line 288–289) and the roster's `unavailable` message (roster.sh:592) add "**or tool**".
   - The gate does not check this condition, so only the documents disagree.

   · **nit** · Choose one wording; "method or tool" fits role 6's documentation case better. · **yes**.

8. **The CLAUDE.md drop-in paragraph is lopsided between the two probes.**
   - It now requires `--require-lookup`, and adds a clause saying a run "whose citation checker could reach no source" cannot pass.
   - It describes the subagent probe and `murderboard_subagents.sh --explain` in detail, but never mentions the lookup probe, `--lookup`, or the `00-lookup-probe.md` file that a `live` record with an archive must carry.
   - A consumer working by hand is required to produce a line that nothing in the paragraph tells them how to earn.
   - Separately, the order of the "so a …" clauses does not follow the order of the flags.

   · **minor** · Add one sentence on the lookup probe and `--lookup`, mirroring the subagent sentence. · **yes**.

9. **The page (`docs/index.html`) disagrees with itself.**
   - The changelog entry says "The report must record the result". The page's own wiring snippet (line 1541) is `roster.sh check REPORT.md` with no `--require-lookup`, and under that command an undeclared Lookup passes.
   - The snippet's comment "exit 1 if a role left no trace" is now also incomplete, because `Lookup: unavailable` exits 1 with no flag. That said, archive failures already made this comment incomplete before this PR.

   · **minor** · Add the flags to the snippet, or qualify the changelog sentence. · **yes**.

10. **The page's changelog overstates the incident compared with the appendix.**
    - The page says "every check still passed". The appendix says the grants gate passed only "once the header stopped claiming named agents", so it did not pass at first.
    - The page also calls them "the checker's own project settings". They were the consumer project's committed settings.

    · **nit** · "…and the gates still passed: the project's own settings blocked the web." · **yes**.

11. **The page calls roles 2 and 6 "citation checker", and so does the CLAUDE.md drop-in.** · The roster row "fails a report that says its citation checker could not reach any source" and the red "1" exit label ("its sources were out of reach") are both written for role 2 only. Every other document says "roles 2 and 6", and role 6 reads documentation. · **nit** · "…that says its reviewers could not reach their sources" · **yes**.

12. **The process file and README omit two things the gate does.**
    - The process file (line 1369) says the scan "names the blocking rule if a *settings file* holds one". The scanner also reads instruction files and warns on prose, PreToolUse hooks and `ask` rules. Its clean-path message also says "readable settings files".
    - The README roster row describes `unavailable` and `--require-lookup`, but not the probe-file requirement for `live` with an archive, nor that an unrecognized token always fails.
    - START-HERE.md (line 106) lists `--require-reports` but not `--require-lookup`. DESCRIPTION-for-claude.md, PROMPT.md and TERMS.md have nothing that conflicts.

    · **nit** · Optional one-clause additions. · **yes**.

13. **Skill step 4b (SKILL.md:386) lists the archive's file names without the probe file.** · The comment shows "01-prove-it.md, 02-doi-or-die.md, …" and leaves out `00-lookup-probe.md`, even though step 4a sends that file to "the role-report archive (step 4b)". `$REPORTS` is also first defined in 4b, after the probe has run. · **nit** · Add `00-lookup-probe.md` to that comment, and say to create the directory before saving the probe reply. · **yes**.

Not verified (outside my role): the six DOIs, titles and Crossref dates in the skill's table, apart from the first row, which matches the probe file; and the Claude Code `tools:` / MCP whole-server syntax.

Files: /Users/tonydefazio/Developer/murderboard-worktrees/lookup-probe/{doc_review_process.md, skills/murderboard/SKILL.md, murderboard_roster.sh, murderboard_subagents.sh, README.md, CLAUDE.md, docs/index.html, START-HERE.md, docs/reviews/lookup-probe-pr80-2026-10-22-roles/00-lookup-probe.md}
