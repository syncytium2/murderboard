# Murderboard run — the adoption docs, after the murderboard became installable

The murderboard was packaged as a Claude Code plugin, and both documents that tell a stranger
how to adopt it — `README.md` and the published page `docs/index.html` — still described
copying files as the only way in. The page went further and opened with **"Nothing to
install"**, a sentence the plugin had just made false.

This run reviewed the change that fixes that. **The most useful thing it caught was in the
draft, not the original:** the first version told readers that installing let them *"skip to
step 4"*, which is wrong in two directions, and would have sent every plugin user past the step
that points the literature tool at a library. A reviewer agent reading only the diff would have
had no way to know — the claim is only checkable against what the plugin's `hooks.json`
actually wires and what the numbered steps actually say.

Also caught: the page's own build gate had a **negative control that had silently expired**.
It mutated the stamp by substituting the literal `Born` date, which only worked while the page
had never been updated. Bumping `Updated` for the first time — which `CLAUDE.md` requires on
every change — made the mutation a no-op. It failed loudly rather than passing vacuously, which
is the only reason it was noticed.

---

## Header

- upstream:  `syncytium2/murderboard` — this repo IS upstream
- copy:      canonical (neither vendored nor installed; this is the source)
- freshness: **UNDETERMINED** — `murderboard_freshness.sh` exits 2 here by design: upstream
  carries no vendored stamp, so there is nothing to compare. Not a skipped gate; the gate ran
  and correctly declined to answer.
- artifacts:
  - `README.md` (`19845f1de1fc` → `53119d6a6da5`)
  - `docs/index.html` (`3b221476ff30` → `e84cc1ce844b`)
  - `tests/published_page_test.py` (fix to a control this run exposed)
  - `tests/plugin_manifest_test.py` (new gate this run added)
- roles:     11 of 11 run
- rounds:    3 (draft → findings applied → blind re-check → F3 reopened and fixed)

Execution: single-pass (subagents unavailable — see *Stated deviation*)

> **This line was added on 2026-09-04, and the run itself is unchanged.** The `Execution:`
> declaration did not exist when this record was written; the deviation below did, because its
> author chose to write it. That is exactly the argument for the field — the disclosure was
> real, voluntary, and invisible to every gate — so this record is annotated rather than left
> as the one worked example of the problem with no instance of the fix. Nothing else here has
> been touched.

### Stated deviation

**Run as a single-pass review walking every role in turn, not as eleven parallel subagents.**
The process permits scaling *how* the roles are run, never *which*; this session was operating
under an instruction not to spawn subagents without being asked. Every role below produced a
result or an explicit "nothing to check, and here is what I checked". The mechanical roles (2,
3, 10) were executed as commands rather than judgement, and their output is quoted.

The cost is honest to state: a single reviewer is a weaker adversary than eleven independent
ones, and role 4 in particular is less trustworthy when the attacker is also the author. Two of
the three substantive findings below were nonetheless in the author's own draft.

---

## Role ledger

| # | Role | Findings | Result |
|---|---|---|---|
| 1 | Claim & data verifier — "Prove It." | 2 | **F1**, **F2** below. Every factual claim in the new prose checked against the shipped code: `hooks/hooks.json` really does wire SessionStart freshness; the five files the copy claims to deliver all exist at the plugin root; the skill really does prefer a vendored copy (`VENDORED WINS`); an install really does live under `$HOME/.claude`. |
| 2 | Citation & reference validator — "DOI or Die." | 0 | All 9 external links on the page re-checked live: every one returns **200**, including the Zenodo DOI and the bugarach run record. No new citations added. |
| 3 | Consistency auditor — "Cross-Examiner." | 1 | **F3**. Also verified the install commands are byte-identical in README and the page, and that all four step names quoted in the new prose exist as real headings. |
| 4 | Adversarial reviewer — "Reviewer 2." | 1 | **F1** is its finding: "in one step" overclaimed a two-command procedure. Attacked the remaining claims and found no further overreach — the copying-vs-installing tradeoff is stated with its cost, not sold. |
| 5 | Line editor — "Kill Your Darlings." | 1 | **F4**. |
| 6 | Methods / domain expert — "RTFM." | 0 | The described mechanics match the implementation: two commands is genuinely the procedure, `/plugin update` is genuinely the remedy, and the install genuinely does not carry into a colleague's clone. Nothing to correct. |
| 7 | Reuse auditor — "Reinventing the Wheel." | 1 | **F5**. The install commands now exist in three files. Rather than deduplicate them — the page is deliberately the only copy of itself — the drift was **gated**. |
| 8 | Naive-reader accessibility — "You Lost Me." | 1 | **F6**. Also asked whether a reader knows *where* to type `/plugin …`; both documents now say explicitly that it is the Claude Code prompt, not a terminal. |
| 9 | Density & figure-first — "Show, Don't Tell." | 0 (1 declined) | Asked what should have been a figure. The install-vs-vendor tradeoff is the one genuinely comparative thing here and a two-row table would carry it more densely than three paragraphs. **Declined, with reason:** the section already ends in a two-up card contrast, and no rendering check exists in this session to verify a new component in both themes. Recorded rather than silently dropped. |
| 10 | Build & craft gate — "Ship It." | 1 | **F7** — and this role is why it was found. `tests/published_page_test.py`: page is complete, Jekyll-safe, balanced, every internal reference resolves, **19 negative controls all caught**. Confirmed the page still loads nothing over the network (the sole grep hit is the word "analytics" in prose that promises the opposite). Stamp bumped `0.8.0 → 0.9.0`, Updated `2026-08-26`, Born unchanged. |
| 11 | Argument order — "Start With the Problem." | 0 | Read the order the case is made in. The page still leads with the two-minute no-setup trial before either permanent route, which is right: the cheapest way to find out whether you want this should not sit behind an install. Installing then precedes copying, and the tradeoff paragraph follows both. No change. |

---

## Findings and adjudication

**F1 · Role 4 / Role 1 · overclaim · FIXED.** The draft said installing was done "in one step".
It is two commands. Corrected in both documents to "two commands"; the page now also says they
are typed at the Claude Code prompt "rather than in a terminal".

**F2 · Role 1 · false instruction · FIXED.** The draft told readers to "skip to step 4". Checked
against what the plugin actually does: it replaces the copying step and the *session-start* half
of wiring the gates. It does **not** set `MURDERBOARD_LIT`, and it does **not** wire the roster
check into CI. Both documents now enumerate what installing does and does not cover. This is the
finding that would have cost a real adopter a silently unusable literature tool.

**F3 · Role 3 · pre-existing inconsistency · FIXED (round 3).** `README.md` and
`docs/index.html` ordered their adoption steps **differently** — README was copy → lit tool →
gates → invoke; the page was vendor → gates → lit tool → make-default. Any prose referring to
"step 2" therefore meant different things in the two documents. Not introduced by this change.

First adjudicated as *flag, do not fix*, on the reasoning that reordering a published page's
instructions should not ride along on a change about installing. **That was overturned on the
author's instruction to resolve it**, and the reasoning was weaker than it looked: the two
documents describe one procedure, and leaving them disagreeing preserved a trap for whoever
next writes "step 2" while removing the only symptom that would have revealed it.

**README was moved to the page's order**, not the reverse — copy → gates → lit tool → make it
the default. The page's order is the better one on its merits: the gates are what keep the copy
you just made honest, so they belong next to it; the literature tool needs a PDF library many
adopters will not have to hand, so it is the most skippable of the four; and both documents
then close on the step that matters most. Checked first that nothing else in the repo refers to
these steps by number — the four hits for "step N" are the review process's own steps and the
skill's, none of them this list.

**F4 · Role 5 · prose · FIXED.** "To install it, if Claude Code is what you use — two commands,
typed at the Claude Code prompt" said "Claude Code" twice in one sentence. Tightened to "if you
use Claude Code … typed at its prompt".

**F5 · Role 7 · duplication · FIXED BY GATING.** The two install commands appear in `README.md`,
`docs/index.html` and the manifests. Renaming the plugin or moving the repo would leave three
documents confidently instructing strangers to type something that fails, while every existing
test still passed. `tests/plugin_manifest_test.py` now derives the expected commands from
`plugin.json`'s own `repository` URL and the two manifests' names, and asserts both documents
match. **Verified to fire:** renaming the plugin in README makes it fail.

**F6 · Role 8 · comprehension · FIXED.** The page referred to "the first / second / third /
fourth" step *before* the reader reaches the numbered list, which sits after a glossary. Replaced
with the steps' actual names.

**F7 · Role 10 · expired negative control · FIXED.** `tests/published_page_test.py`'s
"updated older than born" control substituted the literal `Born` date into the `Updated` field,
which only matched while the page had never been updated. The first real bump made it a no-op.
Rewritten to rewrite whatever `Updated` currently says, via the same regex the check itself uses.
A control that expires the first time the thing it guards is used is not a control.

---

## Residual ⚠ — the human must resolve these

1. **⚠ The published install command has never been executed in its published form.**
   `/plugin marketplace add syncytium2/murderboard` resolves a **GitHub** marketplace on the
   repo's default branch. What was tested end-to-end was the **local directory** form
   (`claude plugin marketplace add ./`), which installed, registered a `gitCommitSha`, and was
   then read correctly by the freshness gate. The GitHub form **cannot** be tested until these
   manifests are on `main`, because that is where the installer looks. **Run both commands on a
   clean machine immediately after merge**; until then the page documents an untested path.

2. ~~**⚠ README and the page order their adoption steps differently**~~ — **resolved in round 3.**
   README was moved to the page's order. See F3.

3. **⚠ Single-reviewer deviation.** See *Stated deviation*. Role 4's assurance is weaker than a
   parallel run's would have been.

---

## Verification

Round 2 re-ran every mechanical check against the corrected files, not the drafts:

```
tests/published_page_test.py     ok — 19 negative controls all caught
tests/plugin_manifest_test.py    all checks pass  (incl. the new drift gate)
tests/vendored_set_agrees_test.py all checks pass
murderboard_freshness.sh --selftest  all checks pass
murderboard_roster.sh --selftest     7 passed, 0 failed
murderboard_revendor.py --selftest   all checks pass — 0 problem(s)
```

Both artifacts' fingerprints moved (`README.md` `19845f1d…` → `53119d6a…`; `docs/index.html`
`3b221476…` → `e84cc1ce…`), confirming the fixes are in the files being shipped rather than
merely claimed. README's is the round-3 value: the round-2 hash was `c26d8f51…`, and the
reorder moved it again.
