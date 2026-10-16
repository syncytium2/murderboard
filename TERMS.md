# Terms, and what they mainly say about money

**Last updated: 2026-09-08.**

The short version, and it is the whole point of this document:

> **Practical guidance first, because it is more useful than the disclaimer:** a run fans out
> one agent per reviewer role, so it is never cheap. **Known good: Claude Opus 5.** Other
> current models are likely fine. **Fable is blocked by default** — one run there spent a
> two-day allowance and returned no review. Now the disclaimer.
>
> ## ⚠ YOU PAY FOR EVERY TOKEN THIS SOFTWARE CAUSES YOU TO SPEND.
>
> **Under no circumstances are the authors or contributors of the murderboard responsible
> or liable for any token, API, subscription, usage, overage, or other cost you incur by
> running it** — including runs that fail, runs that produce nothing, runs that exhaust a
> usage allowance or rate limit, and runs you did not intend to start. No refund, credit,
> reimbursement, or compensation will be provided by us under any circumstances. If that is
> not acceptable to you, **do not run this software.**

This is not a new promise or a separate agreement. It is [the Apache License,
Version 2.0](LICENSE) — under which this project is released — stated in language you can
act on. See §7 (Disclaimer of Warranty) and §8 (Limitation of Liability) of that licence,
which are the operative legal terms.

---

## 1. Why this notice exists at all, specifically

Most software cannot cost you money by running. This can, and the amount is not small
or bounded by anything we control.

The murderboard is a **fan-out**. A single run spawns one reviewer role per role in the
roster — eleven at the time of writing — and **every role runs on every deliverable**.
Scaling the process to the stakes changes *how* the roles run, never *which* ones, so
there is no cheap murderboard: the smallest legitimate run is still the whole roster,
and each role reads your artifact plus a large process document.

On an expensive model, one invocation can consume a substantial share of a usage
allowance, or exhaust one outright. **When that happens you do not get a partial review
for a partial price — you get no review and the full bill.** That is not a hypothetical:
on **2026-09-07** a single run under an expensive model spent a two-day usage limit and
produced no review at all.

We are telling you this as plainly as we know how, in advance, because it is the
foreseeable consequence of using the thing as designed.

## 2. No liability for your costs — any of them, ever

To the maximum extent permitted by applicable law, and in addition to and without
limiting §8 of the Apache-2.0 licence:

The authors and contributors are **not liable** to you or to anyone else for any cost,
charge, fee, loss, or damage of any kind arising from or connected to your use of this
software, including but not limited to:

- **token, inference, or API charges** billed by any model provider;
- **subscription, plan, seat, or credit consumption**, and any overage charges;
- **exhaustion of a usage allowance or rate limit**, and the loss of access, time,
  productivity, or opportunity that follows from it;
- costs incurred by **runs that fail, error, hang, are interrupted, or produce no usable
  output**;
- costs incurred by **runs started unintentionally**, by automation, by an AI agent
  acting on your behalf, by a hook, by a scheduled job, or by another person with access
  to your environment;
- costs incurred **while a safeguard in this software was disabled, overridden,
  misconfigured, absent, or failed to operate**;
- **any consequential, incidental, indirect, special, exemplary, or punitive damages**,
  even if we have been advised of the possibility of them.

This applies regardless of the legal theory advanced — contract, tort, negligence,
strict liability or otherwise — and regardless of whether the cost was foreseeable.

**You are solely responsible for every charge incurred under your accounts, credentials,
API keys, and plans**, whether you incurred it deliberately, accidentally, or through an
agent or automation you configured.

## 3. The cost gate is a safeguard, not a guarantee — and definitely not a spending cap

This project ships `murderboard_model_gate.sh`, which reads the model a session is
running on and blocks a murderboard call-up on models configured as too expensive to
spend here. **We built it because we think it is the right thing to do, and you must
not rely on it as a financial control.** Specifically, and without limiting §2:

- **It is not a spending cap, budget, quota, or billing control.** It does not know your
  plan, your balance, your remaining allowance, or any price. It blocks a call-up; it
  cannot meter, limit, or stop spending generally.
- **It is deliberately overridable.** `MURDERBOARD_ALLOW_EXPENSIVE_MODEL=1` bypasses it,
  and `MURDERBOARD_BLOCKED_MODELS` re-aims it. Anyone or anything with access to your
  environment can set either.
- **It only fires where it is installed and wired.** It is a hook. If you vendored this
  project without wiring it, if the hook is not registered, if a host or tool does not
  run hooks, or if you invoke the process by hand from the document, **nothing stops
  you.**
- **Its blocklist is a claim about prices at a moment in time**, carries a review-by
  date, and can be out of date, wrong, or simply not name the model that is expensive
  for *you*. Model names, pricing, and plan limits change without notice and are not
  ours to know.
- **It can fail.** It is software. It is tested — including against the case where it
  cannot determine the model, where it blocks rather than allows — but a passing test is
  not a promise about your machine.

**Set your own limits with your provider.** Spend controls, budget alerts, and hard caps
offered by whoever bills you are the only things that actually cap spending. Nothing in
this repository can, and nothing in this repository claims to.

## 4. No affiliation with any model provider

This project is independent. It is **not affiliated with, endorsed by, sponsored by, or
acting on behalf of Anthropic or any other model, API, or platform provider.** Product
and model names are used descriptively to identify what the software interacts with.

Your relationship with your model provider — pricing, usage limits, plan terms, billing,
refunds, and enforcement — is **entirely between you and them**, governed by their terms,
and is not something we participate in, influence, or can help you with. If a run cost
you more than you expected, that is a conversation with your provider, not with us.

## 5. Review output is not a warranty of correctness

The murderboard is an adversarial review process. It is designed to *surface* unchecked
claims, bad citations, contradictions and filler. **It does not certify that a document is
accurate, complete, publishable, compliant, or fit for any purpose**, and a clean run is
not evidence that a document is correct.

The process runs on AI models, which produce errors, miss defects, and can assert things
confidently and wrongly — a failure mode this project exists to fight and does not claim
to have solved. **Every output remains yours to check before you rely on it**, and the
consequences of publishing, submitting, or acting on a reviewed document are yours alone.

Nothing here is legal, medical, financial, scientific, regulatory, or professional advice,
and nothing here should be relied on as a substitute for the human review your context
requires.

## 6. The website

<https://murderboard.tonydefazio.com/> is published from this repository as a single
static page. It is provided **as is**, for information, with no guarantee of availability,
accuracy, or currency, and it may change or disappear without notice.

The page **loads nothing over the network** — no fonts, scripts, analytics, trackers, or
CDN assets — and this is enforced by a test in CI. Accordingly it **sets no cookies and
collects no personal data**. Requests to it are served by GitHub Pages, whose own logging
and terms apply and are outside our control.

Links to third-party sites are provided for convenience. We do not control them and are
not responsible for their content, practices, or availability.

## 7. Relationship to the licence, and which one wins

This software is licensed to you under the [Apache License, Version 2.0](LICENSE). **That
licence is the operative legal instrument, and this document does not add conditions or
restrictions to the rights it grants you.** Where anything here conflicts with the
licence as it applies to the software, **the licence governs.**

This document exists to state the warranty and liability position in plain language,
because §7 and §8 of a licence file are, in practice, read by almost nobody — and the
specific risk here is a bill.

If any provision of this document is held unenforceable, the remainder continues in
effect, and the unenforceable provision is limited to the minimum extent necessary rather
than struck out.

## 8. Contributions

Contributions are accepted under the Apache-2.0 licence, per §5 of that licence, unless
you state otherwise in writing. See [CONTRIBUTING.md](CONTRIBUTING.md).

## 9. Changes

These terms may change. The version in force is the one in this repository at the time
you use the software, and the date at the top of this file records when it last moved.
Material changes will be visible in this repository's history, which is public.

---

## What this document is, and what it is not

This is a **plain-language notice** written to be read, not a bespoke legal instrument.
The enforceable terms for the software are in [LICENSE](LICENSE). It was written by the
project's maintainer with AI assistance and **has not been reviewed by a lawyer**. It is
not legal advice, and if your situation involves real exposure you should get advice
from someone qualified to give it rather than relying on this page.

Questions: open an issue at <https://github.com/syncytium2/murderboard>.
