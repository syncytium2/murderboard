# murderboard

[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.22063835.svg)](https://doi.org/10.5281/zenodo.22063835)
[![gates](https://github.com/syncytium2/murderboard/actions/workflows/ci.yml/badge.svg)](https://github.com/syncytium2/murderboard/actions/workflows/ci.yml)

## ▶ [**START HERE**](START-HERE.md) — new to this? Two minutes, no install, no Claude needed.

**In a hurry:** open **[PROMPT.md](PROMPT.md)**, copy the block, paste it into any AI chat,
then paste your document. That is a working murderboard. Everything below is how to stop
having to remember to do it.

The rest of this README is written for someone wiring this into a project. If that is not you
yet, [START-HERE.md](START-HERE.md) is the page you want.

---

> **Authorship.** The ideas, decisions, and review here are mine; the code is Claude's
> (Anthropic's Claude Code). I set the problems, made the calls — including overriding rules
> the model had adopted — and merged nothing I hadn't reviewed. I did not write the
> implementation.
>
> Agent commits carry a `Co-Authored-By: Claude` trailer. Commits predating 2026-08-06 are
> from before that was enforced automatically, so **assume agent authorship unless a commit
> says otherwise.**

A project-neutral **anti-slop review harness** for document deliverables, plus the
literature tool that feeds it. The name is the old sense of *murderboard*: a panel that
tries to tear a thing apart before it ships, so what survives is trustworthy.

It is a small set of files you vendor into a project — the process, the two checks that keep
it honest, and the skill that calls it up:

| File | What it is |
|---|---|
| [`doc_review_process.md`](doc_review_process.md) | The process. A team of adversarial reviewer roles (claim/data verifier, citation validator, consistency auditor, hostile peer reviewer, line editor, methods expert, reuse auditor, naive-reader accessibility, density/figure-first, build & craft gate, argument order) that check **every claim against a real source**, verify **every citation**, attack overreach, ask whether a null result could ever have failed, ask what should have been a figure, read the order the case is made in, and run the mechanical checks against a **render** — before a doc, figure, or report is handed over. **Every role runs on every deliverable**; what scales to stakes is how you run them, not which ones. Roles are split along two axes: what it **costs** to satisfy them (judgment calls sit with the reviewer whose mode of thought they match; every check a script or a render decides sits in one role with a table for an output, so a skipped check leaves a visible hole), and their **unit of analysis** (a defect whose unit is the whole sequence or the whole page is invisible to every per-slide reader). |
| [`fetch_paper.py`](fetch_paper.py) | The lit tool. Fetches open-access papers, **caches** them, checks a curated library **before** downloading (`--have`), **promotes** keepers into it (`--promote`), and **flags** anything it can't reach to a want-list (`--need`, and auto on any failed/paywalled fetch). |
| [`murderboard_freshness.sh`](murderboard_freshness.sh) | The freshness gate. Answers "is this consumer's vendored copy current?" by comparing the stamp against upstream HEAD — **0 current · 1 stale · 2 unknown**, never a false "current". Silent when current, so it runs unattended; `--hook` serves a cached answer and refreshes detached, so a SessionStart hook never blocks on the network. `--selftest` proves every branch can still fire. This is step 0 of the process, mechanized. **Not murderboard-only:** `--label`/`--slug`/`--clone`/`--file` point the same gate at *any* vendoring relationship, so a repo can police every upstream it vendors from with one tool. |
| [`murderboard_roster.sh`](murderboard_roster.sh) | The coverage gate. **Derives** the role roster from `doc_review_process.md` (never recalled, so a new role propagates to every consumer for free) and checks that a finished review report accounts for **every** role — **0 all present · 1 one missing · 2 unknown**. It exists because "every role runs" was prose: a run that fired 7 of 11 roles and one that fired all 11 cleanly produced reports no reader could tell apart. |
| [`require_commit_before_message.sh`](require_commit_before_message.sh) | The durability gate. Refuses a cross-session message while the working tree is dirty — **0 allow · 2 block** — so a session may tell another session something only once that something exists in git. Messages between sessions are socket traffic: nothing persists them, and when a session exits its half of every conversation is gone. One estate lost a finding four sessions had established, and noticed only because someone asked whether the messages were committed. Wire it as a `PreToolUse` hook on the message-sending tool; vendor it to `.claude/hooks/`. `--selftest` proves every branch fires. |
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
   **If the repo vendors from more than one upstream, wire one freshness entry per family.**
   Staleness is not a murderboard-specific disease — it is a property of vendoring. Example,
   policing a vendored copy of another repo's files:
   ```
   bash tools/murderboard_freshness.sh --hook \
        --label session-protocol --slug <owner>/<repo> --clone ~/path/to/that/clone \
        --file docs/session_protocol.md --file .claude/hooks/session-start.sh
   ```
   Naming `--file` also **scopes** the cross-stamp check to that family, so the other
   family's files are not reported as wrongly stamped. Each family caches upstream HEAD
   under its own key — a shared cache would compare one family's HEAD against another's
   stamp and be confidently wrong in both directions.
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

## Who uses it, and what that shows

Three public repositories vendor the murderboard. They are the evidence base for what this
process does, and they are worth reading before adopting it — particularly the run record,
which is what the output actually looks like.

| repo | what it is | what it shows |
|---|---|---|
| [`syncytium2/colonel_kernel`](https://github.com/syncytium2/colonel_kernel) | research tool relating action-potential firing to calcium signals | [`ADR-0037`](https://github.com/syncytium2/colonel_kernel/blob/master/docs/adr/0037-adopt-murderboard-review-process.md) records the adoption decision and its reasoning; `dep-freshness.yml` runs the freshness gate on a weekly cron |
| [`syncytium2/bugarach`](https://github.com/syncytium2/bugarach) | coordination-detection port with an interactive viewer | a **[public run record](https://github.com/syncytium2/bugarach/blob/main/docs/reviews/pensub_export_validation_murderboard_2026-08-20.md)** — 11/11 roles, per-round severity table, stated deviation, six residual `⚠` |
| [`syncytium2/no_peak`](https://github.com/syncytium2/no_peak) | validated port of a pulse-detection algorithm | the full vendored set — process, skill, both gates, both hooks |

**What the evidence supports, and what it does not.** These are case reports, not a benchmark.
They show the process running end-to-end on real deliverables and catching defects that had
survived ordinary review. They do **not** establish a rate, and nothing here has been measured
against a baseline. Two claims are separable:

- **Mechanical, and checkable by inspection today** — you can verify from a finished report
  which roles ran (`murderboard_roster.sh check`), verify whether your vendored copy is stale
  (`murderboard_freshness.sh`), and the verify loop terminates by construction. The tests in
  CI demonstrate these.
- **Empirical, and not yet established** — that this finds more, or better, than some other
  approach. No such claim is made here.

The defect class it is built for is worth naming, because it is the one a text-only reviewer
cannot reach. From the bugarach run: the report claimed a retention figure *"restricted to
shared ROIs inside the declared regions."* The numbers were real; the restriction was not —
they had been computed over all events. Nothing inside the document contradicted itself. Only
opening the source that produced the number exposes that, and it is why the process insists on
the sources rather than the draft.

## Citing it

`CITATION.cff` in the repository root carries the metadata; GitHub's **Cite this repository**
button reads it. A Zenodo DOI is minted per release. Cite the **concept DOI**
[`10.5281/zenodo.22063835`](https://doi.org/10.5281/zenodo.22063835) for the project as a whole; it always resolves to the
latest release. If you vendored a specific commit, cite that release's own version DOI instead
(v0.1.0 is [`10.5281/zenodo.22063836`](https://doi.org/10.5281/zenodo.22063836)).

## Provenance

Extracted and generalized from a calcium-imaging analysis project (`interface2`), where it
grew out of real slop incidents — the appendix of the process doc records them, and the rules
in the core exist because of them rather than in anticipation of them.

**The sibling repos named in comments here are private**, so their names are attribution, not
links: `interface2` (origin and first consumer), `colonel_kernel` (which reported the
fail-open bug fixed in the no-heredoc hook), and `fireflies` (an `R` analysis app). You do not
need any of them. Everything murderboard needs to run is in this repo, and the session
protocol and both hooks are **canonical here** as of 2026-08-21 — adopted when this repo went
public, because a provenance stamp pointing into a private repo is a dead end for the reader
and makes `murderboard_freshness.sh` permanently answer `2` (unknown).

## License

[Apache-2.0](LICENSE). Vendor it, modify it, ship it in commercial work — keep the notices and
state your changes. If you carry a file into your own repo, stamp it
`vendored from syncytium2/murderboard @ <short-sha>` on line 1 or 2, which is what
`murderboard_freshness.sh` reads to tell you when your copy has gone stale.
