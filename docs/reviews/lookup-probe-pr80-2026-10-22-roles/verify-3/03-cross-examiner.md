> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 3 ok — Read, Grep, Glob

**Role 3 (Cross-Examiner), blind verify pass of PR #80 (`lookup-probe` branch)**

**Scope.** I read the whole diff (`pr80-r4.diff`) and these files in the worktree: the Output contract section of `doc_review_process.md`, the grants table rows, the SKILL.md headings, the docs/index.html tools table, and `00-lookup-probe.md`. I also grepped the companion docs (DESCRIPTION-for-claude.md, PROMPT.md, TERMS.md, START-HERE.md) for roster flags, record lines and lookup terms. The repo has no glossary file, so I could not check terms against one.

**One process slip to disclose.** A broad grep for `Lookup:` over `docs/reviews/*.md` returned a few lines from earlier role reports (`08-you-lost-me.md`). I ignored them and opened no other review file. A narrower grep for the probe DOI then named two `verify-2/` reports that contain it. I did not open those either. The findings below come only from the artifact and `00-lookup-probe.md`.

Findings (location · issue · severity · suggested fix · verified against a source):

1. **`murderboard_roster.sh` `unreached_count()` against "fenced code is skipped" (process Output contract, SKILL.md step 7, `lookup_lines` comment)**
   - **Issue:** Fence skipping applies only to `Lookup:` lines. `unreached_count` reads the whole role report, fences included. It also strips backticks before matching. So if role 2 or 6 quotes the grammar at the start of a line (`` `unreached: N` ``, or `unreached: 3` inside a fence), the gate reads `?` or `3` and fails the record, whatever the token. That is a likely case for any review of this PR. The skill's sentence "A quoted example of the grammar belongs in a fenced code block, which the gate skips" tells readers that quoting is safe, and for `unreached:` it is not.
   - **Severity:** medium.
   - **Fix:** Run `unreached_count` through the same awk fence filter `lookup_lines` uses, and add a selftest for a fenced `unreached: 3`. Otherwise, state in the process file and the role 2/6 blocks that the `unreached:` line is read even inside fences.
   - **Verified:** yes (code in the diff).

2. **Role 2 block (`doc_review_process.md` ~l.450, `agents/02-doi-or-die.md` l.101–103) against Output contract l.1375, README roster row, SKILL.md step 7 and `murderboard_roster.sh` l.723 ("Under ANY token")**
   - **Issue:** The role 2 block says "the roster gate fails a **`live`** record whose archive shows it". Everywhere else, the gate fails the record under every token. The code and the selftest (`not needed + role 2 unreached: 12 FAILS`) agree with "every token". So the role 2 text understates the rule that #74 is about.
   - **Severity:** low-medium.
   - **Fix:** Change it to "the roster gate fails any record whose archive shows it". Edit the process file, then regenerate the agents with `murderboard_agents.py write`.
   - **Verified:** yes.

3. **SKILL.md step 4a "record `Lookup: live — <route>; roles <2 and 6 | 2>; probe <$fake>`" and the step 7 template, against the process ("`roles 2 and 6`, or `role 2 only`") and every worked example**
   - **Issue:** Filling the skill's template with the second option gives `roles 2`. The process file and all four example lines say `role 2 only`. The gate does not read this text, so nothing breaks, but two different grammars are documented for one field.
   - **Severity:** low.
   - **Fix:** Use `<roles 2 and 6 | role 2 only>` in both places in the skill.
   - **Verified:** yes.

4. **`00-lookup-probe.md` "Prompt as sent" against the SKILL.md probe prompt**
   - **Issue:** The archived prompt is from an earlier wording:
     - Item 1 does not have "or `NOT FOUND` with what the route returned instead".
     - Item 3 says "reply with the document's title". The skill now says "the title in the page's heading, without the RFC number".

     Since this is the prompt actually sent, the archive is honest. Still, a reader comparing the two will see the PR's own evidence disagree with the PR's own prompt.
   - **Severity:** low.
   - **Fix:** Leave the archive as it is. Add one line to the run record or the archive header saying the probe ran on an earlier revision of the prompt and naming what changed.
   - **Verified:** yes.

5. **`00-lookup-probe.md` against SKILL.md answer tables** (no defect, recorded as checked)
   - **Issue:**
     - DOI row 2 (`10.1016/j.mimet.2018.03.010`) gives key `c3c981a0da8ad342` in both the table and the archive.
     - RFC row 1 (4691) gives `9fecaf80ad677470` in both.
     - The fake DOI `10.1000/de7821441222` is 12 hex characters, which matches the gate's regex `10\.1000/[0-9a-fA-F]{12}` and `openssl rand -hex 6`.
     - The example DOIs `7652153ccbdc` and `0b9e44c1d2a7` are 12 hex characters, and they are identical in the process file, the skill and the roster comment.
     - The selftest key `8158b24485a47382` matches DOI row 1.

     I could not recompute the SHA-256 values with my tools.
   - **Severity:** none.
   - **Fix:** none needed.
   - **Verified:** yes for agreement between files; no for the hash values themselves.

6. **The run record does not exist yet**
   - **Issue:** No `docs/reviews/lookup-probe-pr80-2026-10-22*.md` file is present. When it is written, its `Lookup:` line must name `probe 10.1000/de7821441222`, or the gate fails it against this archive. This is a forward check, not a current defect.
   - **Severity:** info.
   - **Fix:** Check the line against the archive when the record is written.
   - **Verified:** yes (glob and grep).

7. **What `--lookup` is said to detect differs by document**
   - **Issue:** The process Output contract lists "a `WebFetch` or `curl` deny, **a deny on the whole shell**, `dontAsk`…, sandbox `deniedDomains`". The README subagents row, the `murderboard_subagents.sh` header and SKILL.md step 4a all leave out the whole-shell deny, which the code BLOCKs (bare `Bash` and `Bash(*)`). The process also says the scan "reads the settings and instruction files and names a blocking rule". But under `--lookup`, hits in instruction files are only ever WARN, never BLOCK. CLAUDE.md gets this right: "names a blocking rule if a settings file holds one".
   - **Severity:** low.
   - **Fix:** Add "the whole shell" to the three shorter lists. In the process, say that instruction-file hits are warnings.
   - **Verified:** yes.

8. **Exit-1 meanings understated: docs/index.html l.1199 and README roster row**
   - **Issue:** The exit-1 pill still says only "a role is missing". The row's own text now adds that the gate "also fails a report that says its reviewers could not reach their sources". README's "**1 one missing**" has the same gap. The pattern existed before this PR, since report and execution failures were not listed either, but this PR adds another unlisted exit-1 cause.
   - **Severity:** low.
   - **Fix:** Change the index.html pill to "a role or a declaration fails", or similar, and make the same change in the README row.
   - **Verified:** yes.

9. **README usage comment (l.134–140)**
   - **Issue:** The comment says the command exits 1 if the report "will not say … whether roles 2 and 6 could reach their sources". It does not mention that it also fails when the report says they could *not* (`unavailable`), or when `unreached:` is above zero. START-HERE does cover this ("a report saying they could not fails either way").
   - **Severity:** low.
   - **Fix:** Add ", or says they could not" to the comment.
   - **Verified:** yes.

10. **Output contract deliverable (4) (`doc_review_process.md` l.1241)**
    - **Issue:** It describes the archive as "one file per role" and does not mention `00-lookup-probe.md`. The skill (4b comment, step 4a) and the gate require that file whenever a `live` record names its archive.
    - **Severity:** low.
    - **Fix:** Add "plus `00-lookup-probe.md` when the record says `live`".
    - **Verified:** yes.

**Checked and consistent across all surfaces:**
- **Scope "equipment, not honesty":** process step 2, the process appendix, SKILL.md, the CLAUDE.md drop-in and the `murderboard_roster.sh` comment.
- **The three probe items, and which item clears which role:** process, skill, CLAUDE.md, index.html changelog.
- **What counts as a route:** search engines and local files are excluded in the process, the skill and the role 2 block.
- **The token table:** live, not needed, unavailable and missing line, plus the contradiction and unknown-token failures. Process, skill, README, roster code and selftests agree.
- **Grants:** rows 2 and 6 are identical, which item 3's proxy claim needs. The agent frontmatter matches the grants table.
- **Execution token:** `single-pass (forced)` is now used throughout, and no `subagents unavailable` remains in prose.
- **Cross-references resolve:** *Output contract*; the skill's "step 4a / Before the fan-out: probe the lookup", 4b and 7; *A connector reaches a role only through its grant*; and "an instance is in the appendix" (`10.1210/endocr/bqad150`, PMID 37793082).
- **Issue #74 details:**
  - Dates 2026-10-14 and 2026-09-15.
  - The deny list `WebFetch`, `Bash(curl:*)`, `Bash(wget:*)` is the same in the appendix, the subagents selftest and SKILL.md.
  - The appendix's "twelve" DOIs and "two connectors" (PubMed and bioRxiv) match the "Why not fail" paragraph.
- **Roster flags:** CLAUDE.md, README and SKILL.md step 7 give the same three-flag command.
- **Dates:** the page stamp `Updated 2026-10-22` and the sitemap `lastmod` agree.

Files: <worktree>/murderboard_roster.sh, <worktree>/doc_review_process.md, <worktree>/skills/murderboard/SKILL.md, <worktree>/agents/02-doi-or-die.md, <worktree>/README.md, <worktree>/docs/index.html, <worktree>/docs/reviews/lookup-probe-pr80-2026-10-22-roles/00-lookup-probe.md
