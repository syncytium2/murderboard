> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 8 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit (deferred, loadable), plus Bash, Agent, Artifact, Skill, ToolSearch and the Claude Docs editing tools batch and update. I used only Read. I did not edit, write or delete any file.

# Role 8 (You Lost Me): blind verify pass, PR #80

I read these sources: the diff, `doc_review_process.md` and `SKILL.md` step 4a in the diff, the `murderboard_roster.sh` and `murderboard_subagents.sh` messages, the new site entry in place in `docs/index.html` (lines 697–703), and `00-lookup-probe.md`.

## Section verdicts

Each row lists the terms a cold reader meets first in that section, which of them the section defines, and whether reader (a) or (b) can follow it.

| section | terms first used here | defined here | cold reader follows? |
|---|---|---|---|
| Process file, probe bullet in step 2 | lookup probe, route, role 2's own agent, RFC, hashed key, `Lookup:` line | route (yes), RFC (no), hashed key (one clause, no) | yes. Reader (a) can follow it because it sends them to the skill. |
| Process file, "missing tool is a finding / missing capability is a stop" and the connector paragraphs | capability, connector, `mcp__<server>__*`, grant, revendor | connector (yes), grant (no, defined elsewhere in the file) | yes |
| Process file, `Lookup:` token table | live, not needed, unavailable, archive, `unreached:` | yes | yes |
| SKILL step 4a, "Before the fan-out: probe the lookup" | key(), normalized form, SHA-256, row, fake DOI, foreground/background, cost gate, fallback | key and normalization (yes), foreground/background (no), cost gate (no) | **no, blocking: scoring is underspecified** (findings 1–3 below) |
| `murderboard_roster.sh` lookup messages | blocking rule, route, connector, grant, quoted example, "12 hex" | mostly no | partly. Two messages leave the reader with no action (findings 6–7). |
| `murderboard_subagents.sh --lookup` messages | lift it, connector, background reviewer | no | yes, with the process file open |
| Site entry, 2026-10-22 | skill, citation checker, DOI, answer key, hashed, the check | none | **reader (b) follows it and lands somewhere false** (findings 4–5) |
| CLAUDE.md drop-in paragraph | hashed-key lookup, blocking rule on disk | no | misleads (finding 9) |

## Findings

Each finding gives its location, the issue, a severity, a suggested fix, and whether I could verify it against a source.

1. **SKILL step 4a, the "passes when" scoring table.**
   - **Issue:** The table scores only the answer. It never scores the route. The prompt forbids search engines and asks for "one line per item naming the route you used". Yet reader (a), following the table, passes item 1 when the key matches and passes item 3 the same way, even if the reply names WebSearch as the route. A search for a DOI string often returns its title, which is the 2026-09-15 snippet failure in the appendix. Item 2 needs no route at all: `NOT FOUND` is the scored answer. The reply on file even shows a model inferring it, writing "10.1000 is the DOI Foundation's documentation prefix, so this looks like a made-up DOI". The HTTP status or record ID the prompt requests is never scored either.
   - **Severity:** high.
   - **Fix:** add a row or column to the table: each item also needs a named route that is not a search engine or a local file. Item 2 also needs the resolver's own miss (an HTTP 404 or an empty registry record), not just the words `NOT FOUND`.
   - **Verified:** yes, against the SKILL table and `00-lookup-probe.md` line 24.

2. **SKILL step 4a, item 3 and the key match.**
   - **Issue:** "the document's title" is ambiguous for an RFC page. The probe's own reply says the page "has no `<title>` tag" and that it took the h1. A reply such as "RFC 4691: Guidelines for …" hashes differently, so it produces a key mismatch and a STOP. Because the key is opaque, reader (a) cannot tell a wrong route from a formatting difference. The same applies to item 1 when a route returns a title with a subtitle or markup.
   - **Severity:** medium.
   - **Fix:** in the prompt, say "the title as printed in the page heading, without the RFC number". Add one line for a mismatch: the human may open the DOI or RFC page themselves and run `key` on what they see. If that key matches the row, the reply was the problem, not the route. The hash hides the answer from the agent, not from the human.
   - **Verified:** yes, against the probe file, line 30.

3. **SKILL step 4a, the `key()` description.**
   - **Issue:** The prose says "every run of characters other than letters and digits turned into one space". The code keeps only ASCII a–z and 0–9 after NFKD. Greek letters vanish ("TGF-β" becomes "tgf") and accented letters split words. Anyone who hand-normalizes from the prose will get a different key. This is low risk for the six fixed rows, but it matters for any row someone adds.
   - **Severity:** low.
   - **Fix:** "every run of characters other than unaccented a–z and 0–9 (accents are stripped first; other scripts are dropped)".
   - **Verified:** yes.

4. **Site entry, the sentence "The answer key is hashed, so the answers have to be looked up rather than recalled or read off the page."**
   - **Issue:** Hashing stops the checker *reading* the answers off the page. It does nothing about *recall*. Choosing little-cited papers and a fake DOI made fresh for each run is what does that, and for the fake DOI it does not fully work (see finding 1). A visitor follows the sentence perfectly and credits hashing with something it does not do. "Hashed" is also undefined for this reader.
   - **Severity:** medium.
   - **Fix:** "The expected answers are stored scrambled, so the checker cannot copy them from the instructions, and the paper is obscure enough that it cannot answer from memory."
   - **Verified:** yes, reasoning from the SKILL text.

5. **Site entry, the headline "Reviewers who cannot reach their sources now halt the review before it starts" and the closing sentence "…fails the check".**
   - **Issue:** A visitor reads "halt" as enforced. The halt is an instruction the skill gives the agent running the review. The only mechanical enforcement comes after the fact: the roster gate fails a record that says `unavailable`, or a `live` record without its probe file. A run that skips the probe and writes `Lookup: not needed` passes every gate. The process file admits this: "`not needed` is the author's claim". "The check" is also undefined for a visitor. Grammatically, "reviewers … halt the review" makes the reviewers the actors.
   - **Severity:** medium.
   - **Fix:** headline something like "A review now stops before it starts if the citation checker cannot reach its sources". Make the last sentence "…and the end-of-run check fails a report that says they could not." Optionally add: "A run that claims there was nothing to look up is taken at its word."
   - **Verified:** yes, against the process file's token table.

6. **`murderboard_roster.sh`, the contradictory-token message "break or remove any quoted example".**
   - **Issue:** Reader (a) does not know what "break" means here. The obvious moves fail: the line pattern accepts leading spaces, `>` blockquotes, list marks and headings, and it does not skip code fences. Indenting or blockquoting the example does not help. A report that quotes the doc's three example lines in a fenced block fails as contradictory. One that quotes `Lookup: unavailable` to explain why it is not used fails always.
   - **Severity:** medium.
   - **Fix:** say how to break it, for example "start the line with a backtick or any word before `Lookup:`". Also say that fenced code is read.
   - **Verified:** yes, against the `lookup_lines` regex in the diff.

7. **`murderboard_roster.sh`, the messages for `unreached:` ("fix the route and re-run") and for a missing probe file ("run the probe again").**
   - **Issues:**
     - "Re-run" what: the probe, or the whole review? The `unavailable` message spells out "run the lookup probe again, then the whole review". These two do not.
     - Re-running the probe draws a new fake DOI, so the `Lookup:` line must change too. The message does not say so, and the reader then hits the "does not contain" failure.
     - "See doc_review_process.md" in the `unavailable` message names a long file without naming the section.
   - **Severity:** low.
   - **Fixes:**
     - "re-run the probe and the whole review"
     - "a new probe has a new fake DOI; update the `Lookup:` line to match"
     - name the section ("A connector reaches a role only through its grant").
   - **Verified:** yes.

8. **SKILL, the paragraph beginning "Spawned by name, the probe is not a call-up to the cost gate…".**
   - **Issue:** The paragraph is dense with jargon ("call-up", "fan-out's vocabulary", "the gate counts it"), and its upshot for the human is never stated. Will they be asked to confirm a second time?
   - **Severity:** low.
   - **Fix:** state the consequence: "Through the fallback you may be asked to confirm once more; that is expected."
   - **Verified:** no. This depends on how the model gate behaves, which I did not read.

9. **CLAUDE.md drop-in, "a hashed-key lookup of a real DOI…" and "…names a blocking rule on disk, and the run stops there".**
   - **Issues:**
     - The lookup is not done by hashed key. The answers are *checked* against hashed keys.
     - "Names a blocking rule" reads as though there always is one. The scan names one only if one is in a file.
     - "The run stops there" reads as though the script stops the run.
   - **Severity:** low.
   - **Fix:** "a lookup of a real DOI, a made-up one and a documentation page, scored against hashed answers… If it fails, the run stops, and `--lookup --explain` names a blocking rule if one is in a settings file."
   - **Verified:** yes.

10. **What reader (a) will take `Lookup: live` to certify (SKILL record template and process table).**
    - **Issues:**
      - The process file says plainly that `live` certifies the route, not the references. But the record template in step 7 shows only `Lookup: live | not needed`, and a reader copying that template omits `; probe <fake>`.
      - Without a `reports:` archive, `live` passes the gate on the author's word alone.
      - "roles 2 and 6" on the line reads as both being probed, when role 6 is cleared by proxy.
      - A PI reading the record will most likely take `live` to mean "citations were checked live".
    - **Severity:** low to medium.
    - **Fix:** put `; probe <fake>` in the template line. Add one clause to the template comment: "the route worked; whether each citation checked out is in role 2's report".
    - **Verified:** yes.

## Can reader (a) run the probe from the skill alone?

Mostly yes. Drawing the rows, filling in the prompt and running `key()` all work, given `python3` and `openssl`.

Telling pass from fail does not work. As written, the scoring passes a search-snippet answer and an unrouted `NOT FOUND` (finding 1). It can also false-fail an honest RFC title, with no way for the reader to diagnose why (finding 2).

## Gate messages

Each message names an action except the contradictory-token one (finding 6) and the two that say "re-run" without saying what (finding 7).
