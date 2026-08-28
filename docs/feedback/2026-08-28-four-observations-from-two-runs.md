# Four observations from two runs — for the process to evaluate

**From:** a consumer of `doc_review_process.md` (the `short-course` / `bugarach` estate)
**Date:** 2026-08-28 · **Status:** proposals, none adopted · **Evidence:** two real runs, both green

Neither run was a failure of the process as written. Every role that was asked to run, ran;
the roster gate was green in both. **Three of the four observations below are about defects
that passed *between* correctly-executed roles**, and the fourth is about a run record
outliving the document it reviewed.

Filed here rather than fixed, because a role charter is yours to change and a consumer
inventing its own would be the thing vendoring exists to prevent.

---

## 1 · An attribution to a person in the room is not checked by any role

**What happened.** A sentence entered a session as an unsourced assertion in an unsigned
brief. It left as a **named, dated personal communication** in a committed document —
*"(Tony, 2026-08-27)"* — and it was the load-bearing argument of its section. The named
person had not said it, and the thing it asserted had not happened.

**Why the review did not catch it.** Two roles touched the sentence and both did their jobs:

| Role | Asked | Answered |
|---|---|---|
| 1 — Prove It | is this claim **true**? | unverifiable → flag it |
| 2 — DOI or Die | do the **citations resolve**? | no external citations → clean |

Neither asked *did the named person say this.* A personal attribution is not a fact to
check against data and not a bibliographic reference, so it fell between the two scopes and
**two correct outputs composed into a green run.**

**Proposal.** Extend role 2's charter: *an attribution to a named person is a citation and
is checked like one.* The process already tells reviewers to go and ask what the humans
hold; this is the converse — an attribution the draft **already contains**, which currently
nobody is told to verify.

**Why it is worth a charter change and not a checklist line.** The failure mode is
generative: an agent that formats well will supply the missing half of a citation. A brief
written in the user's register resolves *who says this* to the user, and the citation format
supplies the date. Provenance is normally assumed to degrade in transit. Here it was
manufactured.

---

## 2 · A partial flag reads as a receipt

**What happened.** The review **did not miss** the claim above. It caught it, searched two
repositories for corroboration, found none, and correctly demanded an unverified flag. The
flag it wrote even named the exact consequence of the claim being false:

> ⚠ Seventeen's circulation outside the repo is unverified. The document states it on
> Tony's word (2026-08-27) […] **This is the claim that decides seventeen over eighteen on
> non-arithmetic grounds** — if it is wrong, that argument goes away.

And it shipped. **The flag attached to the fact; the source rode through untouched.**
Marking the claim *unverified but attributed* told the reader which half to doubt, and they
doubted the wrong half.

**Proposal.** A flag names **which component** is unverified — the assertion, the
attribution, or the number — because a flag that names one component silently certifies the
others. An unflagged component inside a flagged sentence is currently indistinguishable from
a checked one.

**The general shape, offered for the process file's own appendix:** *a partial flag is more
dangerous than none, because it reads as evidence the item was examined.* Absent a flag, a
reader supplies their own suspicion. Given one, they spend it where they are pointed.

---

## 3 · Reviewer correlation is real, and the roster gate cannot see it

**The residual as it already stands in one of our reports:** *"All eleven roles ran on one
model in one context. Eleven seats buy coverage of angles, not independence. Nothing here
distinguishes a document with nothing left to find from one whose reviewer looked in the
same wrong place throughout."*

`murderboard_roster.sh` answers *did every role run?* — which was the right gate to build,
and it works. It cannot answer *were the eleven answers independent?*, and neither can any
count of findings.

**Proposal — cheap, and it is not a twelfth role.** Require that **at least one role per run
executes against the artifact rather than the text**: recompute a number from its source,
run the command, open the built file, resolve the path. One role, stated in the run record
as having done so.

**Evidence that it changes outcomes.** A report reaching us last night was checked by
recomputing from the source JSON rather than reading its table. Everything held — *and* the
check found the report had **understated its own problem** (it reported two conflicting
folder names; the pre-fix tree held four) and that one of the defects it claimed to fix was
still open. Neither is visible from the text. Both are visible in one command.

**This degrades worst under the single-pass scaling** the process permits for short
deliverables, where one reviewer walks every role in turn and inherits the drafter's blind
spots throughout. Observations 1 and 3 are both worse there, and the permission is
reasonable — but the run record should probably say which of the two modes produced it, at
the top rather than in an appendix.

---

## 4 · A run record outlives the document it reviewed, and nothing says so

**New, and found while merging rather than while reviewing.** Two independently written
case documents were merged into one on 2026-08-28. One of them carried a full 11-role run.
The merged file is now roughly twice the length, and **the run record still reads as
covering it.**

Nothing in the tooling notices. `murderboard_roster.sh` answers *did every role run?* and
the answer is still yes. The question it cannot ask is *over what text?*

We wrote the warning by hand, at the top, in bold — which works exactly once, in the
document whose author happened to think of it.

**Proposal.** The skill already fingerprints the artifact before and after a run. If the run
record carried that fingerprint, a freshness check could answer *this run predates the
current content* the same way `murderboard_freshness.sh` answers *this vendored copy is
behind upstream* — **0 current · 1 stale · 2 unknown**, never a false "current".

That would also catch the ordinary case, which is more common than a merge: a reviewed
document edited afterwards and shipped with its review badge intact.

---

## What we are not proposing

Nothing here argues the review was not worth running. The run that missed observation 1
found **14 real defects**, including one worth keeping: the document arguing that a
benchmark miscounts its own quantities **miscounted the documents it was about, in its first
sentence.** A doc about counting defects, with a counting defect in line one.

**Review is necessary and not sufficient**, and the process already says so in its own
words — a clean result is evidence the roles ran, not that the artifact is correct. Every
observation above is a case of that sentence being more literally true than it looks.
