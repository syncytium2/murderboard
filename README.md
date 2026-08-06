# murderboard

A project-neutral **anti-slop review harness** for document deliverables, plus the
literature tool that feeds it. The name is the old sense of *murderboard*: a panel that
tries to tear a thing apart before it ships, so what survives is trustworthy.

It is a small set of files you vendor into a project — the process, the two checks that keep
it honest, and the skill that calls it up:

| File | What it is |
|---|---|
| [`doc_review_process.md`](doc_review_process.md) | The process. A team of adversarial reviewer roles (claim/data verifier, citation validator, consistency auditor, hostile peer reviewer, line editor, methods expert, reuse auditor, naive-reader accessibility, density/figure-first, build & craft gate, argument order) that check **every claim against a real source**, verify **every citation**, attack overreach, ask whether a null result could ever have failed, ask what should have been a figure, read the order the case is made in, and run the mechanical checks against a **render** — before a doc, figure, or report is handed over. **Every role runs on every deliverable**; what scales to stakes is how you run them, not which ones. Roles are split along two axes: what it **costs** to satisfy them (judgment calls sit with the reviewer whose mode of thought they match; every check a script or a render decides sits in one role with a table for an output, so a skipped check leaves a visible hole), and their **unit of analysis** (a defect whose unit is the whole sequence or the whole page is invisible to every per-slide reader). |
| [`fetch_paper.py`](fetch_paper.py) | The lit tool. Fetches open-access papers, **caches** them, checks a curated library **before** downloading (`--have`), **promotes** keepers into it (`--promote`), and **flags** anything it can't reach to a want-list (`--need`, and auto on any failed/paywalled fetch). |
| [`murderboard_freshness.sh`](murderboard_freshness.sh) | The freshness gate. Answers "is this consumer's vendored copy current?" by comparing the stamp against upstream HEAD — **0 current · 1 stale · 2 unknown**, never a false "current". Silent when current, so it runs unattended; `--hook` serves a cached answer and refreshes detached, so a SessionStart hook never blocks on the network. `--selftest` proves every branch can still fire. This is step 0 of the process, mechanized. |
| [`murderboard_roster.sh`](murderboard_roster.sh) | The coverage gate. **Derives** the role roster from `doc_review_process.md` (never recalled, so a new role propagates to every consumer for free) and checks that a finished review report accounts for **every** role — **0 all present · 1 one missing · 2 unknown**. It exists because "every role runs" was prose: a run that fired 7 of 11 roles and one that fired all 11 cleanly produced reports no reader could tell apart. |
| [`skills/murderboard/SKILL.md`](skills/murderboard/SKILL.md) | The call-up, for consumers using Claude Code. `/murderboard <artifact>` runs the process **as a sequence that cannot be half-executed**: freshness gated at the moment of review (not at session start), roster derived, artifact resolved to the built file rather than its generator and fingerprinted before/after, and a run record emitted and then checked by `murderboard_roster.sh`. Vendor it to `.claude/skills/murderboard/`. |

None depends on another at runtime; the process doc simply tells its reviewer agents to use
the lit tool when they need a paper, and the skill sequences the rest.

## Why it exists

Slop ships when nobody adversarially checks a draft against its real sources: a statistic
that disagrees with the run it summarizes, a reference list written from memory, a count
that contradicts itself, a figure whose caption overclaims. Worse, a plotted number can be
perfectly consistent with its caption and still be wrong because the *code* that produced
it misused a library. The murderboard is the standing habit that catches those before a
human's name is on them. (The `doc_review_process.md` appendix lists the concrete incidents
that motivated each rule.)

## How a project adopts it

1. **Copy the files** into the consuming repo — `doc_review_process.md` under `docs/`, the
   three tools under `tools/`, and `skills/murderboard/SKILL.md` to
   `.claude/skills/murderboard/SKILL.md` — and stamp each with the upstream commit you copied
   from, so drift is visible. See "Vendoring" below.
2. **Point the lit tool at your library** by setting `MURDERBOARD_LIT` to a directory of
   PDFs (ideally on a synced/shared drive so the cache is shared across machines):
   ```
   export MURDERBOARD_LIT="/path/to/your/lit"
   python3 tools/fetch_paper.py --have <author> <keyword>
   ```
3. **Wire the two gates so they fire without being remembered.** Freshness at session start
   (early warning) and again inside the skill at the moment of review (the actual gate);
   coverage against the finished report:
   ```
   bash tools/murderboard_freshness.sh --hook       # SessionStart: silent unless stale
   bash tools/murderboard_roster.sh check REPORT.md # after a run: 1 if a role is missing
   ```
4. **Invoke it from your `CLAUDE.md`.** Add a rule that document deliverables run through the
   murderboard before delivery — pointing at `/murderboard` where the skill is installed, and
   at `doc_review_process.md` otherwise. See this repo's [`CLAUDE.md`](CLAUDE.md) for a
   drop-in paragraph.

## Vendoring (the update contract)

There are no submodules — each consumer holds its **own copy**, which keeps a fresh
checkout self-contained on any machine. The cost is manual updates. To keep that honest:

- When you copy the files in, add a one-line stamp in the consuming repo (e.g. top of the
  vendored `doc_review_process.md`, or a `docs/adr`/`decisions` note):
  `vendored from syncytium2/murderboard @ <short-sha>`.
- To update a consumer, re-copy both files and bump the stamp. `git diff` on the vendored
  copy then shows exactly what changed since the last pull.

## The lit tool in one screen

```
python3 fetch_paper.py <url> ...            # fetch OA paper(s), cache, print text
python3 fetch_paper.py --have <kw> ...      # search the curated library FIRST (prevents re-downloads)
python3 fetch_paper.py --promote <url> "Name.pdf"   # file a keeper into the library
python3 fetch_paper.py --need "<citation>"  # flag a paper for a human to fetch
python3 fetch_paper.py --list               # what the cache holds
```

- **Open-access hosts only** (PMC, EuropePMC, arXiv, bioRxiv, PLOS, eLife, …; full list in
  the tool). It refuses paywalled publisher hosts and flags them to the want-list instead
  of scraping.
- **Config:** `MURDERBOARD_LIT` (library dir), `MURDERBOARD_PAPERS` (cache dir override).
  `IF2_LIT` / `IF2_PAPERS` are honored too, for the project this tool originated in.
- **Needs** Python 3; `pypdf` (or `pdftotext`) for PDF text extraction.

## Provenance

Extracted and generalized from the `interface2` calcium-imaging project, where it grew out
of real slop incidents (see the process-doc appendix). `interface2` is the origin and first
consumer; `colonel_kernel` and `fireflies` (the `R` analysis app) are being wired up as
consumers.
