> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 7 MISMATCH — missing Grep, Glob; holds Read, Bash, SubagentHandback (no editing tool held: no Edit, Write or NotebookEdit)

This is a finding about the run, not the artifact. I searched with `grep` through Bash instead, so the check itself lost nothing. The run record's `roles:` line should still say this role came in by a fallback path.

**What I checked**
- **Selftests on the branch:** roster 72/72 and subagents 19/19 pass. The roster selftest on origin/main passes 59/59.
- **Execution: parsing, before and after the refactor.** I pulled `execution_line`, `execution_head`, `execution_tail`, `report_execution` and `execution_cause` from origin/main and from the branch, then ran both on 25 constructed Execution: lines. The lines covered:
  - every separator: em dash, en dash, `--`, ` - `, a second colon, and a tight `—`
  - bold, bold around the whole line, blockquote, table cell, underscore, extra spaces, mixed case
  - `(forced)`/`(chosen)`, with and without a space
  - an empty token, `#`, `-` and `**Execution**:` prefixes
  - a comma used as a separator, and a contradiction in the tail

  **All 25 gave the same result on both. The `token_head` refactor does not change Execution: behavior.**
- **Lookup: lines.** I ran 18 decorated forms through `report_lookup`.
- **Scanner reuse in `murderboard_subagents.sh --lookup`.**
- **Overlap with `fetch_paper.py`.** I checked its host allowlist and its failure path, and looked for any DOI-resolution helper elsewhere in the repo. There is none: `doi.org` appears only in the new scanner code.

**Where it reuses correctly (no finding)**
- `lookup_line` uses the same grep pattern as `execution_line`, character for character: `^[[:space:]]*[*_|>[:space:]]*<Label>:`, case-insensitive, first match wins. So the two lines accept and miss exactly the same decorated forms.
- Lookup: goes through `token_head`, so its separators, markdown stripping and case folding are identical to Execution:.
- `--lookup` does not copy `scan_json` or `scan_prose`. It passes a mode into them and swaps `NAMES`, `TOOL` and the noun list. Everything else is inherited: the file precedence, the undeterminable outcome for unreadable files, missing python or malformed JSON (UNDET / UNDETERMINED), the exit codes, and the `--hook` silence. The selftest checks that the two scans do not trigger on each other's blockers.
- The skill calls the scanner exactly the way its subagent probe does (`[ -n "${SUBAGENTS:-}" ] && bash "$SUBAGENTS" … ; echo "exit=$?"`), using the same variable resolved during path resolution.

**Findings** (location · issue · severity · suggested fix · verified against a source)

1. **`murderboard_roster.sh` `lookup_line` (line ~349), inherited from `execution_line`.**
   - **Issue:** copying the Execution: pattern exactly also copies its blind spots, and here they decide whether the gate fails. These lines all come back as `undeclared`, which exits 0 when `--require-lookup` is not set:
     - `- Lookup: unavailable — x`
     - `**Lookup**: unavailable`
     - `# Lookup: unavailable`

     That defeats "`unavailable` FAILS, always, flag or no flag", which is the headline case of issue #74. For Execution: the same miss is harmless, because undeclared is an accepted state there. The repo already has a more forgiving parser, `reports_decl` (line ~380). It removes `` *`_|> `` everywhere and drops a leading `- ` before matching, and it would catch the first two forms.
   - **Severity:** medium.
   - **Fix:** have `lookup_line` strip decoration the way `reports_decl` does. Or, more simply, when no line is declared, still fail if any line matches `Lookup:.*unavailable` after stripping. Add `- Lookup: unavailable` and `**Lookup**: unavailable` to the selftest.
   - **Verified:** yes, by running these forms through the branch's functions.

2. **`murderboard_roster.sh` `execution_tail` (line ~227).**
   - **Issue:** the comment on `token_head` says the helper is shared "so the two cannot drift into separator rules that disagree". But `execution_tail` still carries its own copy of the separator chain (`%%—*`, `%%–*`, `%%--*`, `%% - *`, `%%:*`). The refactor stopped one function short, so a separator added to `token_head` would split the head and tail of the same line in different places.
   - **Severity:** low.
   - **Fix:** split the cut into a shared helper, for example a `token_raw_head` that returns the uncut head, and have both `token_head` and `execution_tail` call it. Or narrow the comment's claim.
   - **Verified:** yes.

3. **`skills/murderboard/SKILL.md` lookup probe, and the "any route counts" text in `doc_review_process.md` (lines ~171 and ~1344).**
   - **Issue:** neither mentions the repo's own literature tool. `doc_review_process.md` (line ~1164) says "All fetching goes through `fetch_paper.py`", so a role 2 that follows the process will try it. But `doi.org` is not in `ALLOWED_HOSTS` (`fetch_paper.py` lines 83–101). Both probe DOIs would come back REFUSED, so the probe fails, which is honest. But each refusal calls `flag_needed` (`fetch_paper.py` ~line 504, and ~515 on a fetch error), so the made-up `10.1000/murderboard-probe-0000` is written into the human's `<lit>/_NEEDED.md` want-list.
   - **Context:** `fetch_paper.py` is a fetcher for open-access papers, not a DOI resolver, so the probe is right not to depend on it. The documents just never say so.
   - **Severity:** low-medium.
   - **Fix:** add one sentence to the probe in both places: "`fetch_paper.py` is not a DOI route (`doi.org` is not on its allowlist) — do not run the probe through it, or the made-up DOI lands in `_NEEDED.md`." Optionally reconcile it with the "All fetching goes through fetch_paper.py" line.
   - **Verified:** yes (allowlist and failure path read in the worktree).

4. **`murderboard_subagents.sh` `NAMES` under `--lookup` (line ~159).**
   - **Issue:** the shell route is matched only as `Bash(curl…)` or `Bash(wget…)`. The repo's own sanctioned fetch path is `python3 fetch_paper.py` (urllib), and a `Bash(python3:*)` deny would not be reported.
   - **Severity:** low. The scan is advisory and the probe is the real gate.
   - **Fix:** either note this limit in the comment, or add `python3? .*fetch_paper` to the pattern.
   - **Verified:** yes, from the code. I did not run it.

5. **`murderboard_subagents.sh` `scan_json` text inherited in `--lookup` mode.**
   - **Issue:** the no-python message (line ~129) still says "cannot say whether it denies the Agent tool". This is wrong during a lookup scan, which was otherwise given its own WARN and BLOCK remedy text.
   - **Severity:** low.
   - **Fix:** choose the wording by `$SCAN`, as the remedy lines already do.
   - **Verified:** yes, from the code.

6. **`report_lookup` is now defined in both `murderboard_roster.sh` and `murderboard_subagents.sh`, with unrelated meanings.** One classifies a record's token; the other prints the scan report.
   - **Severity:** low. The scripts are separate, so nothing breaks today, but anyone searching for the name lands on the wrong one.
   - **Fix:** rename the scanner's version, for example `report_lookup_scan`.
   - **Verified:** yes.

All scratch fixtures are in `<scratch>/mb/scratch/role-7/`: `fn_base.sh`, `fn_new.sh`, `cases/`, `lk/`. Nothing in the repo was edited.
