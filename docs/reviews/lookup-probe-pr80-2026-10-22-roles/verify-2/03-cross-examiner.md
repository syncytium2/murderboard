> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 3 ok — Read, Grep, Glob

**Role 3 (Cross-Examiner), blind verify pass of PR #80 (`lookup-probe`): 3 medium findings, 7 low, 1 info, no blockers.**

I read the full diff, the changed files and the three companions (DESCRIPTION-for-claude.md, PROMPT.md, TERMS.md). Under the roles directory I read only `00-lookup-probe.md`. I edited nothing.

**These agree everywhere:**
- **The probe's three items** (a real DOI, a made-up DOI, an RFC page): process file, skill, CLAUDE.md drop-in, the public page's ticker entry and README all say the same thing.
- **Example probe DOIs.** `10.1000/7652153ccbdc` and `10.1000/0b9e44c1d2a7` are identical in the process file, the skill and the roster comment.
- **Key format.** All 12 keys are 16 hex characters. The fake DOI is made by `openssl rand -hex 6` and the gate's regex `[0-9a-fA-F]{12}` matches it.
- **`00-lookup-probe.md`.** Its DOI row 2 (`10.1016/j.mimet.2018.03.010` → `c3c981a0da8ad342`) and RFC row 1 (4691 → `9fecaf80ad677470`) match the skill's tables. Its fake DOI `10.1000/de7821441222` is well-formed. I was not given the run record, so I could not check that the record's `Lookup:` line names that DOI.
- **The roles 2 and 6 text** in `agents/02-doi-or-die.md` and `agents/06-rtfm.md` matches the process file's role blocks word for word.
- **Rows 2 and 6 of the grants table** are identical, which is what the skill's claim that item 3 clears role 6 by proxy relies on.
- **Cross-references resolve:** skill steps 4a, 4b and 7; the skill's *Before the fan-out: probe the lookup*; the process file's *Output contract* and appendix; issue #74.
- **Dates:** 2026-10-14 for the incident (appendix and roster comment); 2026-09-15 for the earlier run; 2026-10-22 for the page stamp, sitemap, ticker, "Checked live" and the scanner's ⚠ comment.
- **Lookup tokens:** `live` / `not needed` / `unavailable` / undeclared, and what each does at the gate, are the same in the process table, README, skill, START-HERE, the roster comments and the roster's selftest.
- **The old Execution token:** `single-pass (forced)` has replaced `single-pass (subagents unavailable)` everywhere outside `docs/reviews/`.

**Findings** (location · issue · severity · suggested fix · verifiable against a source)

1. **The skill's database-coverage bullet vs role 2's checklist and the roster gate.**
   - Location: `skills/murderboard/SKILL.md` 4a, under "Two limits are stated rather than hidden", second bullet.
   - Issue: the bullet presents "role 2 counts identifiers outside its coverage as unreached" as a disclosure. But role 2's checklist says any `unreached: N` above 0 stops the main thread before synthesis, and the roster fails a `live` record whose archive shows it. So a connector-only `live` run that cites one DataCite DOI is a hard stop, which neither the skill nor the process file's "`role 2 only`" wording tells the reader.
   - Severity: medium.
   - Fix: say outright that an identifier outside the database's coverage stops the run under `live`. Or, if that is not intended, exempt coverage misses from the stop and change role 2's text and the gate to match.
   - Verifiable: yes.

2. **The public page's reason for hashing vs the process file's.**
   - Location: `docs/index.html`, ticker entry dated 2026-10-22.
   - Issue: the page says "The answer key is hashed, so the answers have to be looked up rather than recalled or read off the page". The process file says only that the agent "cannot read the answers off the page". Hashing does nothing against recall; what resists recall is the little-cited DOI, the fresh fake DOI and the obscure RFC.
   - Severity: medium.
   - Fix: drop "recalled" from the page, or credit recall resistance to the choice of items rather than to the hash.
   - Verifiable: yes.

3. **What the lookup scan covers vs the hosts the probe uses.**
   - Location: `murderboard_subagents.sh` (`RESOLVERS`), and its descriptions in the process file, README and skill.
   - Issue: item 3 fetches `rfc-editor.org`, but `RESOLVERS` lists only doi.org, Crossref and NCBI hosts. A `WebFetch(domain:rfc-editor.org)` deny, or a sandbox whose `deniedDomains` includes rfc-editor.org, fails the probe while the scanner it points to exits 0.
   - Severity: medium.
   - Fix: add `rfc-editor.org` to `RESOLVERS`, or state that the scan does not cover item 3's host.
   - Verifiable: yes.

4. **The scanner's coverage list differs across four places.**
   - Location: the scanner's coverage list in README (`murderboard_subagents.sh` row), the process file's Output contract, skill 4a, and the scanner's own header.
   - Issue:
     - README says "`dontAsk` with nothing allowed". The others say "no lookup route allowed", and the gate does fire on `allow:["Read"]`, so README's wording is wrong.
     - Only the process file lists "a deny on the whole shell".
     - None of the four lists `wget`/PowerShell fetchers, tool-name globs, or the warnings the scan issues (connector deny, `ask` rules, a PreToolUse hook on WebFetch, prose).
   - Severity: low.
   - Fix: write one canonical list and copy it to all four places, or have three of them point to the process file.
   - Verifiable: yes.

5. **When `00-lookup-probe.md` is required.**
   - Location: skill 4a ("The roster gate requires that file under `live`") and skill step 7, vs the process file's lookup table and `cmd_check`.
   - Issue: the skill states it unconditionally. The gate requires the file only when the record names an archive directory. A `live` record with `reports: not preserved` or no `reports:` line passes without it.
   - Severity: low. The skill always runs with `--require-reports`, so in practice the archive is named.
   - Fix: add "when the record names its archive" to the skill, matching the process table.
   - Verifiable: yes.

6. **An unknown `Lookup:` token is missing from the process table.**
   - Location: the process file's `Lookup:` table, Output contract.
   - Issue: the table lists four rows and does not say that an unknown token fails without the flag. README, the roster comments and the selftest ('unrecognized lookup FAILS', 'a hedge is not a token') all say it does. "Read the way `Execution:`'s is" implies it but does not state it.
   - Severity: low.
   - Fix: add a line next to "Two lines declaring different tokens fail…".
   - Verifiable: yes.

7. **The roster's EXIT CODES comment is incomplete.**
   - Location: `murderboard_roster.sh` header, exit 1 list.
   - Issue: it lists "a mode/execution/lookup line is missing or incoherent, Lookup: is `unavailable`, or the … archive is absent, incomplete, or empty". It omits three `live` failures the script implements: no `00-lookup-probe.md`, no probe DOI on the line or the DOI absent from the file, and role 2 or 6 reporting `unreached:` above 0.
   - Severity: low.
   - Fix: add those failures to the comment.
   - Verifiable: yes.

8. **A selftest comment claims a flag the test does not set.**
   - Location: `murderboard_roster.sh` selftest, the 'a bulleted live is recognized' test (its comment reads "And a bulleted live is a declaration too, under the flag.").
   - Issue: the test runs with `REQUIRE_LOOKUP=0`. Without the flag, a line that is never matched reads as undeclared and also exits 0. So this test, and 'bolded lookup line recognized', 'a fully bolded line is read' and 'a backticked token is read', cannot tell a recognized line from a missed one.
   - Severity: low.
   - Fix: run the recognition tests under `REQUIRE_LOOKUP=1`, or drop "under the flag" from the comment.
   - Verifiable: yes.

9. **How the key is normalized: prose vs code.**
   - Location: skill 4a.
   - Issue: the prose says "lower case, with every run of characters other than letters and digits turned into one space". The code applies NFKD, keeps only ASCII `[0-9a-z]` (non-ASCII letters are dropped, not kept), and strips the ends.
   - Severity: low.
   - Fix: say "ASCII letters and digits, after NFKD, trimmed".
   - Verifiable: yes.

10. **An unclear antecedent in the CLAUDE.md drop-in paragraph.**
    - Location: `CLAUDE.md` drop-in, "`…verify <report>` goes beside these … The two ask different questions".
    - Issue: "these" now covers the roster check and both scans, so "The two" no longer clearly means the roster check and `verify`.
    - Severity: low.
    - Fix: "The roster check and `verify` ask different questions".
    - Verifiable: yes.

11. **The public page's exit-code column for the roster.**
    - Location: `docs/index.html` roster row.
    - Issue: exit 1 still reads "a role is missing", while the row's new text says it also fails on the reviewers being unable to reach their sources. This gap predates the PR for Execution and reports and widens here.
    - Severity: low.
    - Fix: "1 · a role is missing, or a declaration fails".
    - Verifiable: yes.

12. **DESCRIPTION-for-claude.md is stale (companion).**
    - Location: its steps paragraph, roster paragraph and adoption paragraph.
    - Issue: it mentions neither probe, nor the Execution, reports or `Lookup:` lines and their flags. This predates the PR; the PR does not make it worse.
    - Severity: info.
    - Fix: none needed in this PR; note it for a later refresh.
    - Verifiable: yes.

PROMPT.md and TERMS.md contain nothing about the lookup probe or the gate's flags to contradict.

Files: `<worktree>/skills/murderboard/SKILL.md`, `<worktree>/doc_review_process.md`, `<worktree>/murderboard_roster.sh`, `<worktree>/murderboard_subagents.sh`, `<worktree>/README.md`, `<worktree>/CLAUDE.md`, `<worktree>/docs/index.html`, `<worktree>/DESCRIPTION-for-claude.md`
