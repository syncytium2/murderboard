# Outside review — `docs/murderboard-explainer.html` @ `fd1114b`

**From another session, 2026-08-24, before your murderboard run — so these can go into it
rather than arrive after.** You asked for an outside pass on role 8 specifically; that request
was correct, and item 2 is what it finds.

---

## B1 — The page is not self-contained, and the commit message says it is

> Self-contained — no build step, no assets, opens from disk.

It loads three families from Google Fonts via `<link rel="stylesheet">`:
`fonts.googleapis.com` (×2 incl. preconnect), `fonts.gstatic.com`. Opened from disk with no
network — or on a guest wifi that blocks it — the body stack falls back:

```
--f-body: "Source Serif 4", Georgia, "Times New Roman", serif
```

**It renders in Times New Roman.** This is not hypothetical: it is how the page was first seen
by the person who will present it, and the reaction was *"that font is laugh out loud
GHASTLY."* The design never reached the reader.

Two fixes. Embed the faces as data URIs — true self-containment, larger file. Or drop to a
system stack that never phones home. **For a page whose stated selling point is "opens from
disk", the system stack is the honest choice**, and it renders identically on every machine
instead of only on cooperative ones.

Either way the commit message's claim needs to change or become true. It is currently a
verifiable overclaim in a document about not making those.

## B2 — The stated reader and the actual reader are different people

> An onboarding explainer for a reader who has never heard of any of this

The page opens with *"how to put it in your own **repo**"* and then uses, undefined in visible
text: **repo** (6×), **vendored stamp**, **upstream commit**, **session start**, **hook**,
**gate** (14×), **exit codes**, **shell**.

That is a **technical adopter who has not heard of the murderboard** — a real and useful
audience, and the page serves it well. It is not *"never heard of any of this."* The concrete
case that prompted this review is a curious non-specialist who does not know what a repo is,
and this page loses them in its first paragraph.

Not a defect in the page so much as a mismatch between the page and its own commit message.
Either narrow the claimed audience to "someone evaluating whether to adopt it", or write the
second page. They are different documents with different jobs.

## M3 — Role 2 is described in the exact words that shipped the wrong attribution

The page:

> Confirms every reference exists and is correctly attributed.

That is the half-check **#30 was written to fix**, four commits before this one, after a
release blocker in which every citation resolved and the document still credited the wrong
laboratory by nineteen years. **The word "origin" appears zero times in the page's visible
text.**

**But the page is faithful to its source, and that is the real finding.**
`doc_review_process.md`'s own role-2 headline (line 274) still reads *"confirm the work exists
and is correctly attributed"*, with origin-tracing added by #30 as a **sub-bullet**. Any
summariser reading the top line reproduces the pre-fire version. The page did exactly that,
correctly.

So: fix the headline upstream, not only here. A rule that survives only if the reader reaches
the sub-bullets is the same species of problem as a rule that depends on being remembered —
which is the framing this page itself calls the part most worth stealing. Raised on **#31**,
which is open and touching that role.

---

## Verified good — stated because a review that only lists defects misreports the artifact

- **The calibration line is reproduced in full**, with its own section, in a page whose purpose
  is to make the process look good. That is the hardest sentence to keep in a pitch and it was
  kept. The commit says this was deliberate; it was the right call.
- `murderboard_revendor.py` is named, and named correctly ("rather than hand-editing the
  stamp"), so the vendoring section is **not** stale after #29.
- **Role count matches the roster**: page says eleven, `murderboard_roster.sh count` derives 11.
- The commit message names **two claims cut rather than shipped unverified** (a vendored-set
  file count; "no dependencies" for the lit tool). That is the behaviour the process asks for
  and it is visible in the record.

## Method

Claims checked against `doc_review_process.md` and the roster at `5e6b299`; external requests
enumerated from the raw HTML; jargon counted on visible text only, with word boundaries, after
stripping tags — a first pass without boundaries returned `PR` ×70 and `CI` ×29 from substring
matches inside CSS, which is the kind of noise that discredits a check, so it was discarded
rather than reported.

**Not a murderboard run.** One reviewer, four findings, no role ledger, no blind pass. Treat it
as input to yours, not as coverage.
