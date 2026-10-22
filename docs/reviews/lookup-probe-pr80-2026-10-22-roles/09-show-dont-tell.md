> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 9 MISMATCH — missing Grep, Glob; holds no forbidden tools (Read, Bash, SubagentHandback)

(I used grep and awk through Bash, so the missing tools cost the check nothing. Record the mismatch in the ledger as a finding about the run.)

**Role 9: density and figure-first review of PR #80, branch `lookup-probe`**

**Two checks don't apply to markdown:** the rendered figure's share of the canvas (and the empty-margin rule), and the caption check. Neither document has a figure, a canvas or a caption.

**Thresholds I used:**
- I dropped the 40-words-per-slide limit, because a markdown section is not a slide.
- A paragraph over 60 words is flagged.
- A block over 120 words is the prose script's own flag.
- "Visual" means a code block, a table or a blockquote.

**Measurements:**
- `bash murderboard_prose.sh` on both files, output saved in <scratch>/mb/scratch/role-9/.
- The script counts a whole list as one block, so its figures are coarse. The per-section counts below come from the diff's `+` lines.
- On doc_review_process.md the script exits 1, but all its hits are at lines 600–611. That is the existing banned-word list, outside the diff and role 5's concern.

## Count table — one row per added section

| Section (file:line) | Words added | Largest paragraph | Visual? | Notes |
|---|---|---|---|---|
| Process, review step, lookup-probe bullet (doc_review_process.md:164–175) | 186 | 186 | n | Longest bullet in the review step; the others run 4–157 words. It sits inside the 2123-word list block at line 119. |
| Process, role 2, "Existence is established by resolving" bullet (:420–431) | 166 | 166 | n | Sits in the role-2 block, already 2745 words (prose script, line 370). |
| Process, grants section, "missing tool / missing capability" and "connector" (:929–949) | 286 in 3 paragraphs | 119 | n | Three paragraphs of prose in a row, no visual. |
| Process, output contract, `Lookup:` line (:1321–1347) | 252 in 5 paragraphs (61 of them in code) | 118 | y (examples block, gate command) | The token meanings sit in a 118-word paragraph *after* the examples. |
| Process, appendix incident (:1620–1637) | 283 | 283 | n | Longest of the last seven appendix entries (the others run 160–268). |
| Skill, lookup probe (SKILL.md:256–299) | 475 | 93 (two paragraphs at 93) | y (prompt blockquote, bash block) | |
| Skill, step-4 exception sentence (:326–327) | 33 | 33 | n | |
| Skill, `Lookup:` in the output template and examples (:410, :420–426) | 84 | 38 | y | |
| Skill, "And it reads the `Lookup:` line" (:483–486) and the gate command (:443) | 61 | 51 | partly | |
| Skill, "What this gate still does NOT do" edit (:506–508) | about +10 net | — | n | |

**Totals:** about 973 words added to the process file and about 654 to the skill, by my count of `+` lines, code included.

## Findings

Format: location · issue · severity · suggested fix · could I verify it against a source.

1. **The issue #74 incident is told in six places, three of them as full narratives.**
   - Locations: process :173–175 (a parenthetical of about 30 words), :938–941 ("On 2026-10-14 the two happened in the wrong order…", about 45 words), the appendix at :1620 (283 words), plus single clauses at process :1346, SKILL :258–259 and SKILL :285.
   - Severity: **major**.
   - Fix: tell the story only in the appendix. In the body, replace each telling with "(issue #74; appendix)".
   - Relocate, don't delete: the grants-section version has one detail the appendix lacks. The main session confirmed the citations, through connectors role 2 had never been handed. Move that clause into the appendix entry.
   - Keep one clause in the skill. Per the repo's CLAUDE.md, the rationale belongs in the process file.
   - Verified: yes (grep).

2. **"`unavailable` fails always" is stated four times.**
   - Locations: process :1333; SKILL "Go ahead anyway" (:290); SKILL "`Lookup:` has a third token" (:424); SKILL "And it reads the `Lookup:` line" (:483). Three of the four are in the skill alone.
   - Severity: **major**.
   - Fix: covered by the token table in finding 3. The skill keeps one sentence and a pointer to the table. The "third token" paragraph and the `unavailable` half of :483 go.
   - Verified: yes.

3. **Figure: the `Lookup:` grammar should be a table.**
   - Location: process :1331–1338, the 118-word paragraph after the examples block.
   - Severity: **major**.
   - Fix: replace the paragraph with a token table, columns *token · when it is honest · who can contest it · gate by default · under `--require-lookup`*. Four rows:
     - `live — <route>`
     - `not needed — <why>`
     - `unavailable`
     - (no line at all)
   - The rationale for "`live` names no tool" becomes one line under the table.
   - Precedent: the same document's `Execution:` section (:1290–1297) gives each token its own bullet, so a list matching that form is also acceptable. The current prose-after-examples form matches neither.
   - Verified: yes.

4. **Figure: the probe's pass/fail logic is a 2×2 truth table written as prose.**
   - Location: process :168–170 ("The pair is the point — a route that answers *something*… passes a one-sided probe, and a route that misses a real paper fails it honestly"), restated at SKILL :267–272.
   - Severity: **minor**.
   - Fix: a 2×2 table in the process file. Rows: real DOI comes back FOUND with the correct title / it doesn't. Columns: the made-up DOI comes back NOT FOUND / it comes back found. The four cells:
     - **PASS**
     - **FAIL — route answers everything**
     - **FAIL — route misses real papers**
     - **FAIL**
   - The skill keeps its concrete DOIs and its "Both right / Anything else" bullets, which are already a decision list and fine as they are. Its "It passes only if both…" paragraph can lose its last sentence ("That half is the probe…") and point to the table.
   - Verified: yes.

5. **"A failed probe stops the run before role 1; it is not a `MISMATCH`" is stated three times in each file.**
   - Process locations: the review step at :171–172, the grants section at :937–939, the output contract at :1334–1335.
   - Skill locations: :277 ("STOP, before role 1"), :326–327 (the step-4 exception), :424–425.
   - Severity: **minor**.
   - Fix, process: keep the procedure in the review step and the principle in the grants section ("A missing tool is a finding; a missing capability is a stop" is the best statement of it). Drop the clause from the output contract.
   - Fix, skill: keep the STOP bullet and the 33-word signpost. Fold :424–425 into the single line from finding 2.
   - Verified: yes.

6. **The same list of routes, and the same idea, keeps recurring.**
   - "WebFetch, a shell fetch, a literature connector" appears three times: process :170–171, process :424, SKILL :275.
   - "The route is not the capability" appears three times in the process file: :939, :1331, :1631.
   - Severity: **minor**.
   - Fix: list the routes once, in the review step. Elsewhere write "by any route (see the lookup probe)".
   - Verified: yes.

7. **The new review-step bullet makes an already dense list denser.**
   - Location: process :164–175. At 186 words it is the longest bullet in the review step. It carries procedure, rationale and an incident.
   - Severity: **minor**.
   - Fix: findings 1, 4 and 6 cut it to about 90 words of procedure plus a pointer. Nothing is lost; the material moves to the appendix and the table.
   - Verified: yes (measured).

8. **The scan's blind spot is stated twice.** "WebFetch was absent from the session, and no file records it" appears at process :1346 and SKILL :284–286.
   - Severity: **low**.
   - I'd accept it: the skill needs the warning at the exact point where someone reads the scan's exit 0, and that is call-up mechanics. No change asked.
   - Verified: yes.

9. **Optional figure for the role-2 "Existence" bullet.**
   - Location: process :425–431, the PubMed Central ID converter vs PubMed example.
   - Severity: **low / optional**.
   - The example is evidence that a silent lookup doesn't prove a paper is missing. It could be a three-row table, *route → answer*:
     - the NCBI ID converter answers "Identifier not found in PMC"
     - PubMed answers PMID 37793082
     - a title search finds the paper
   - Prose also works here, because it is one worked example. It is copied verbatim into agents/02-doi-or-die.md, which is compiled output, so that copy is expected and not a finding.
   - Verified: yes.

10. **Prose is right for three sections; no figure is asked:**
    - the appendix entry (:1620): a narrative incident, the genre of the appendix;
    - the connector paragraph (:943–949): conditional instructions plus a ⚠ caveat, which must stay on the page;
    - the skill's remedies paragraph (:288–290).
    - Verified: yes.

**Net effect if findings 1–7 are applied:** roughly 250–300 words come off the process body and about 120 off the skill, and two tables are added. No caveat is lost; each one has a single home, either the appendix or the token table.
