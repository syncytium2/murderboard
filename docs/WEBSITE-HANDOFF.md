# Handoff — publish the murderboard explainer to a real website

**Written 2026-08-25.** For a session that is not this one. Everything below marked
"verified" was checked at that date; re-check anything load-bearing before acting on it.

---

## Why this exists

`docs/murderboard-explainer.html` merged to `main` in **#33**. GitHub renders `.html` as
**source**, so today a visitor who clicks it in the web UI gets a wall of markup. The page is
readable only by cloning the repo and opening it, or through a private Claude artifact link that
cannot be shared publicly. **The project's public explainer is currently unpublished.**

The owner has `tonydefazio.com` and wants a site. This is that job.

---

## Verified state, 2026-08-25

| Fact | Value | How checked |
|---|---|---|
| `origin/main` | `4294b2f` | `git log` |
| Open PRs | none | `gh pr list` |
| GitHub Pages on `syncytium2/murderboard` | **not enabled** | `gh api repos/.../pages` → 404 |
| Any Pages site on the account | none | `gh api users/syncytium2/repos` |
| `tonydefazio.com` A record | **none — does not resolve** | `dig +short tonydefazio.com A` (empty) |
| `www.tonydefazio.com` | **none** | `dig` (empty) |
| Nameservers | `arya.ns.cloudflare.com`, `clyde.ns.cloudflare.com` | `dig NS` |
| DNS control | **Cloudflare** | from the NS records |
| GitHub Pages IPv4 | `185.199.108-111.153`, `192.30.252.153/154` | `gh api meta --jq '.pages[]'` **on the day** — re-fetch, do not trust this table |

The domain is registered and delegated to Cloudflare with **no records at all**. Clean slate.

---

## Decision the OWNER must make first — do not guess

**Is `tonydefazio.com` a personal site with murderboard as a section, or is it the murderboard
site?** Everything downstream depends on it, and the answer is not in the repo.

**Recommendation: `murderboard.tonydefazio.com`, a subdomain.** Reasons:

- It leaves the apex free for a personal site later without a migration.
- A subdomain is a single `CNAME` → `syncytium2.github.io`. The apex needs either four A records
  or Cloudflare's CNAME flattening — more moving parts, more to get wrong.
- It decouples this repo's release cadence from anything personal.

If the owner wants the apex instead, the apex path is documented below too.

---

## The approach

Serve from **GitHub Pages, `main` branch, `/docs` folder** — the explainer already lives there,
so no build step and no second copy to drift.

### 1. Give the site an entry point

Pages serves `/docs/index.html` at the site root. The explainer must become that file. Prefer
`git mv docs/murderboard-explainer.html docs/index.html` over a copy: **two copies of this page
will drift, and this project has already had that exact failure** (the page went stale within an
hour of #31 landing — see the run record).

If any link to the old name must survive, add a redirect stub, do not duplicate the content.

### 2. Add `docs/.nojekyll`

Without it Pages runs the file through Jekyll, which will mangle anything that looks like Liquid
(`{{`, `{%`). Grep the page before assuming it is safe. One empty file; costs nothing.

### 3. Fix the HTML skeleton — REQUIRED, and it is a genuine conflict

The page starts at `<meta charset>`. It has **no `<!doctype html>`, no `<html lang>`, no
`<head>`** — verified. That is deliberate: the file was authored for a publisher that supplies
that skeleton at publish time. Served from Pages with no wrapper, **every browser enters quirks
mode**, where the gates table stops inheriting `font-family` and `line-height` from `body` and
renders in two different faces. This is already recorded as residual flag 2 in
`docs/reviews/explainer_murderboard_2026-08-25.md`.

So the file cannot serve both masters as-is. **Pick one and write down which:**

- **(a) Make the repo file a complete document** — add doctype, `<html lang="en">`, `<head>`.
  Simplest, correct for the web. Cost: the file is no longer directly publishable as a Claude
  artifact without stripping the skeleton.
- **(b) Keep the file skeleton-free and generate the published page** from it with a small
  script that wraps it. Cost: a build step, and a generated artifact that can drift — mitigate
  exactly as this repo already does for `PROMPT.md`, with a CI check that the published file
  matches its generator (`.github/workflows/ci.yml`, "PROMPT.md matches its generator").

**(a) is recommended.** The artifact was scaffolding to get the page reviewed; the website is
the real deliverable. Option (b) only earns its complexity if the owner wants to keep
republishing artifacts from the same source.

### 4. DNS, in Cloudflare

**Subdomain (recommended):**
`CNAME`  `murderboard`  →  `syncytium2.github.io`

**Apex, if chosen instead:** four `A` records to the GitHub Pages IPv4 addresses (re-fetch with
`gh api meta --jq '.pages[]'`; do not copy the table above), plus `AAAA` for the IPv6 pair, or
use Cloudflare's CNAME flattening at the apex.

> **Known trap, verify before declaring done.** Cloudflare's SSL/TLS mode must be **Full** or
> **Full (strict)**. On **Flexible**, Cloudflare talks HTTP to GitHub Pages while Pages forces
> HTTPS, and the result is a redirect loop that looks like a broken site with no obvious cause.
> If you proxy (orange cloud), also expect GitHub's certificate provisioning to fail until the
> record is temporarily set to DNS-only (grey cloud) so GitHub can validate the domain. Start
> grey, get the cert issued and "Enforce HTTPS" checked in repo settings, then decide about
> proxying.

### 5. Repo settings

- Settings → Pages → Source: **Deploy from a branch**, `main`, `/docs`.
- Custom domain: the chosen hostname. This writes `docs/CNAME` — commit it.
- Wait for the certificate, then tick **Enforce HTTPS**.

### 6. Point the repo at the site

Once it resolves: set the repo **homepage** field, and add the URL to `README.md`,
`START-HERE.md`, and the explainer's own footer links.

---

## Constraints you must not break

1. **Zero external resource requests.** The page loads no fonts, scripts, images or stylesheets,
   by design, and says so in a comment at the top. There is a CI-adjacent expectation and a
   murderboard finding behind it. Do not add a webfont, an analytics tag, or a CDN link. If the
   owner wants analytics, raise it as a decision — it breaks a stated property of the page.
2. **The page is a summary of `doc_review_process.md`, and that document is the authority.** The
   page's own footer says so. If you change what the page claims the process does, you are
   introducing drift; change the process document instead, or don't.
3. **Do not edit the run record** at `docs/reviews/explainer_murderboard_2026-08-25.md`, or the
   outside review beside it. They are dated records of a review that happened.
4. **`murderboard_roster.sh check` must still pass** on the run record if you touch anything it
   parses.
5. **Accessibility floor already met.** Every text colour clears WCAG AA 4.5:1 against every
   surface it can sit on, in both themes, computed — minimum 4.53:1. If you touch the palette,
   recompute; do not eyeball.

---

## Acceptance criteria

- [ ] The chosen hostname serves the explainer over **HTTPS**, with a valid certificate.
- [ ] `http://` redirects to `https://`, and there is **no redirect loop** (the Cloudflare trap).
- [ ] The page renders in **standards mode** — `document.compatMode === "CSS1Compat"`, not
      `BackCompat`. This is the check that proves the skeleton fix landed.
- [ ] The gates table renders in the same typeface as the body text.
- [ ] Page still issues **zero external resource requests** — confirm in devtools Network, not by
      reading the source.
- [ ] Renders correctly in **light and dark**, and on a **320px** viewport.
- [ ] There is exactly **one** copy of the explainer in the repo.
- [ ] `README.md` and the repo homepage field point at the live URL.

---

## Open questions for the owner

1. Apex or subdomain? (recommendation above)
2. Is this the murderboard's site, or a personal site that hosts it?
3. Analytics: yes and accept breaking the zero-requests property, or no?
4. Should `docs/reviews/*.md` be published too, or stay repo-only? They are readable on GitHub
   as markdown, so there is no strong reason to publish them, and the run record links from the
   page as a repo path.

## What NOT to do

Do not "fix" the explainer's prose while you are in there. It has been through a full eleven-role
murderboard and two blind rounds; its wording is the output of that, and the residual flags are
recorded. If you find a defect, file it the way the process asks rather than patching it in
passing — and note that the run is recorded as **UNCONVERGED at the round cap**, so finding
something is expected, not surprising.
