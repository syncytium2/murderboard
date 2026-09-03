#!/usr/bin/env python3
"""Pin the invariants of the published page, because breaking them fails SILENTLY.

`docs/index.html` is served to the public by GitHub Pages. Four of its properties
are load-bearing and none of them announce themselves when broken:

1. **It is a complete document.** The page was authored for a publisher that supplies
   `<!doctype>`/`<html>`/`<head>` at publish time, so it shipped without them. Served
   raw, every browser enters QUIRKS MODE, where the gates table stops inheriting
   font-family and line-height from body and renders in a different face than the
   prose around it. Nothing errors. The page just looks wrong, and only in a browser
   — which is why reading the source cannot catch it.

2. **It issues zero external resource requests.** The page says so in a comment at
   its own top: it renders the same opened from disk, air-gapped, or behind a
   captive portal. One webfont link makes that claim false in the one case that
   matters, and the page keeps rendering fine on the machine of whoever added it.

3. **Jekyll must not touch it.** Pages runs files through Jekyll unless `.nojekyll`
   is present, and Jekyll eats anything resembling Liquid (`{{`, `{%`).

4. **The prompt printed on the page is the prompt the generator emits.** The page
   carries the whole paste-ready prompt inline, because an assistant sent one hop
   away to fetch it has been observed searching instead, failing, and offering to
   reconstruct the review from memory. Inline, it cannot be missed — but it is now
   a SECOND COPY of a role list whose entire point is that it is derived and cannot
   drift, and this repo has already had the two-copies failure once. So the block
   is generated (`murderboard_prompt.sh --sync-page`) and diffed here. A page that
   listed nine of eleven roles would review with nine of eleven roles, look
   completely normal, and tell nobody.

`<a href>` is navigation, not a fetch, and is excluded on purpose — as is
`rel="canonical"`, which is metadata the browser never requests. The distinction is
the whole point: a check that flagged every URL would be noise, and noise gets
switched off.

No network. String analysis over the repo's own files, plus one subprocess: the
prompt generator, which reads `doc_review_process.md` and touches nothing else.
"""
import pathlib
import re
import subprocess
import sys
from html.parser import HTMLParser

ROOT = pathlib.Path(__file__).resolve().parent.parent
DOCS = ROOT / "docs"
PAGE = DOCS / "index.html"

VOID = {"area", "base", "br", "col", "embed", "hr", "img", "input", "link",
        "meta", "param", "source", "track", "wbr"}
# rel values that are metadata, not a resource the browser goes and gets.
NON_FETCHING_REL = {"canonical", "alternate"}


def check(src):
    """Full check for the explainer: structure, stamp, form, and findability."""
    return (check_document(src) + check_stamp(src) + check_form(src)
            + check_findability(src))


def check_document(src):
    """The properties every page served from docs/ must hold, whatever it is.

    Split out from check() so thanks.html can be held to the structural rules --
    standards mode, nothing fetched, Jekyll-safe, balanced, references resolve --
    without being asked for a version stamp or a contact form it has no business
    carrying.
    """
    bad = []

    # 1. Complete document -> standards mode.
    if not src.lstrip().lower().startswith("<!doctype html>"):
        bad.append("no <!doctype html> first — browsers will use quirks mode")
    for tag in ('<html lang="en">', "<head>", "</head>", "<body>", "</body>", "</html>"):
        if tag not in src:
            bad.append("missing %s" % tag)

    # 2. Zero external resource requests.
    for tag, attrs in re.findall(r"<(?!a\b|/)([a-zA-Z]+)([^>]*)>", src):
        for attr in ("src", "srcset", "data-src", "poster"):
            m = re.search(r'\b%s\s*=\s*["\']([^"\']*)' % attr, attrs)
            if m:
                bad.append("<%s %s=%s> fetches" % (tag, attr, m.group(1)))
        if tag.lower() == "link":
            rel = re.search(r'\brel\s*=\s*["\']([^"\']*)', attrs)
            rels = set((rel.group(1) if rel else "").lower().split())
            href = re.search(r'\bhref\s*=\s*["\']([^"\']*)', attrs)
            if href and not rels <= NON_FETCHING_REL:
                bad.append("<link rel=%s href=%s> fetches"
                           % ("+".join(sorted(rels)) or "?", href.group(1)))
    if re.search(r"@import", src):
        bad.append("CSS @import fetches")
    # url(#frag) is a same-document SVG reference; url(data:...) is inline.
    for m in re.finditer(r"url\(\s*['\"]?(?!data:|#)([^)'\"]+)", src):
        bad.append("CSS url(%s) fetches" % m.group(1).strip())
    if re.search(r"<script\b", src, re.I):
        bad.append("<script> present")

    # 3. Jekyll safety.
    for tok in ("{{", "{%"):
        if tok in src:
            bad.append("Liquid token %s — Jekyll would mangle this" % tok)

    # 4. Tag balance.
    class P(HTMLParser):
        def __init__(self):
            HTMLParser.__init__(self, convert_charrefs=True)
            self.stack, self.errs = [], []

        def handle_starttag(self, tag, attrs):
            if tag not in VOID:
                self.stack.append((tag, self.getpos()[0]))

        def handle_endtag(self, tag):
            if tag in VOID:
                return
            if not self.stack:
                self.errs.append("stray </%s> line %d" % (tag, self.getpos()[0]))
            elif self.stack[-1][0] != tag:
                self.errs.append("</%s> line %d closes <%s> from line %d"
                                 % (tag, self.getpos()[0], self.stack[-1][0],
                                    self.stack[-1][1]))
                self.stack.pop()
            else:
                self.stack.pop()

    p = P()
    p.feed(src)
    bad += p.errs
    bad += ["unclosed <%s> from line %d" % t for t in p.stack]

    # 5. Every same-document reference resolves.
    ids = set(re.findall(r'\bid\s*=\s*["\']([^"\']+)', src))
    for frag in sorted(set(re.findall(r'href\s*=\s*["\']#([^"\']+)', src))):
        if frag not in ids:
            bad.append("dead anchor #%s" % frag)
    for frag in sorted(set(re.findall(r'url\(\s*["\']?#([^)"\']+)', src))):
        if frag not in ids:
            bad.append("dead url(#%s) — an SVG marker/gradient that does not exist" % frag)

    return bad


# The only endpoint this page may POST to. A form is the one construct here that
# talks to a third party, so the destination is pinned: swapping the relay
# silently would send visitors' messages somewhere else while every other check
# in this file still passed.
RELAY = "https://api.web3forms.com/submit"

STALE_CLAIM = "No external requests."
HONEST_CLAIM = "only if you send the form"


def check_form(src):
    """A form is allowed. A form the page lies about is not.

    This page's whole argument is that a claim must match the thing it describes,
    so the moment it gained a network request, its own header comment and colophon
    had to change with it. This ties the two together: add a form and the honest
    wording becomes mandatory; remove the form and the wording is free to go back.
    """
    forms = re.findall(r"<form\b[^>]*>", src)
    if not forms:
        # No form, no third-party request: the page may claim it fetches nothing.
        return []

    bad = []
    for f in forms:
        action = re.search(r'\baction\s*=\s*["\']([^"\']*)', f)
        if not action:
            bad.append("<form> has no action")
        elif action.group(1) != RELAY:
            bad.append("form posts to %s, not the pinned relay %s"
                       % (action.group(1), RELAY))
        if not re.search(r'\bmethod\s*=\s*["\']post["\']', f, re.I):
            bad.append("form is not method=POST — a GET would put the message in the URL")

    if 'name="botcheck"' not in src:
        bad.append("form has no botcheck honeypot")
    if 'name="redirect"' not in src:
        bad.append("form has no redirect, so a sender lands on the relay's own page")
    # Collapse whitespace before looking for prose. Both claims wrap across source
    # lines, and a literal substring search silently misses a sentence that is
    # present but broken by an indent -- which is a check that fails open the day
    # someone reflows a paragraph.
    flat = re.sub(r"\s+", " ", src)
    if re.sub(r"\s+", " ", STALE_CLAIM) in flat:
        bad.append('page carries a form but still claims "%s"' % STALE_CLAIM)
    if re.sub(r"\s+", " ", HONEST_CLAIM) not in flat:
        bad.append('page carries a form but never says the request is send-only '
                   '(expected the phrase "%s")' % HONEST_CLAIM)
    return bad


# The date of this repository's FIRST COMMIT, 4a92748. A LITERAL on purpose: a
# born-on date that can be quietly edited is not a born-on date, it is just
# another mutable field. If it ever legitimately changes, changing it here is the
# deliberate act that should be.
#
# IT HAS CHANGED ONCE, AND THIS IS THAT DELIBERATE ACT. Until 2026-09-03 this read
# 2026-08-25 and the comment above it said "the day the site first served to the
# public" -- which was a true description of the value and an answer to the wrong
# question. Across this author's published repositories two conventions are in
# use and both are used correctly: colonel_kernel (2026-06-21) and no_peak
# (2026-08-07) say "Born" and mean their first commit -- no_peak's src/version.ts
# states that definition in its own prose -- while bugarach and short-course say
# "First published" and mean page birth. This page said "Born" against a
# page-birth value, so it was the only stamp of the five agreeing with neither
# convention. The word stays; the date moves to match the word.
#
# KNOWN AND ACCEPTED: 4a92748 is "murderboard v1 -- generalized from interface2",
# so this is the day the repo was split out, not the day the work began. It is a
# proxy, and so is every other "Born" in the estate -- each is its repo's first
# commit regardless of what preceded it, which is the property that makes them
# comparable at all.
BORN = "2026-07-20"

BORN_RE = re.compile(
    r'Born\s*<time datetime="(\d{4}-\d{2}-\d{2})">(\d{4}-\d{2}-\d{2})</time>')
VERSION_RE = re.compile(r'Version\s*<b>(\d+\.\d+\.\d+)</b>')
UPDATED_RE = re.compile(
    r'Updated\s*<time datetime="(\d{4}-\d{2}-\d{2})">(\d{4}-\d{2}-\d{2})</time>')


def check_stamp(src):
    """The page must carry born-on, version and updated, and they must agree.

    A stamp is only worth having if it cannot rot unnoticed. An `updated` older
    than `born`, or a <time> whose machine-readable attribute disagrees with the
    text beside it, is worse than no stamp at all: it looks maintained.

    Searched document-wide ON PURPOSE. An earlier version required the stamp to
    sit inside a particular element, and moving it from the footer to the
    masthead broke the gate rather than the property — a gate that fails when
    you rearrange the furniture teaches people to edit the gate.
    """
    bad = []
    b, v, u = BORN_RE.search(src), VERSION_RE.search(src), UPDATED_RE.search(src)
    if not b:
        bad.append("stamp has no well-formed Born <time> (YYYY-MM-DD)")
    if not v:
        bad.append("stamp has no well-formed Version <b>N.N.N</b>")
    if not u:
        bad.append("stamp has no well-formed Updated <time> (YYYY-MM-DD)")
    if not (b and v and u):
        return bad

    # A <time> whose datetime disagrees with its visible text is the defect a
    # reader cannot see and a machine reads the wrong way round.
    if b.group(1) != b.group(2):
        bad.append("Born datetime=%s but text reads %s" % (b.group(1), b.group(2)))
    if u.group(1) != u.group(2):
        bad.append("Updated datetime=%s but text reads %s" % (u.group(1), u.group(2)))

    if b.group(1) != BORN:
        bad.append("Born date changed: page says %s, the site was born %s"
                   % (b.group(1), BORN))
    if u.group(1) < b.group(1):
        bad.append("Updated (%s) is before Born (%s)" % (u.group(1), b.group(1)))

    return bad


# ---------------------------------------------------------------------------
# FINDABILITY. Everything below fails silently and invisibly-to-the-author, which
# is this file's whole remit. A page with no description still renders. A sitemap
# with a stale lastmod still validates. A canonical pointing at the wrong host
# still looks right in the source. The failure appears months later as "nobody can
# find it", by which time nobody remembers what changed.
#
# The one hard cross-check: docs/CNAME is the single source of truth for the
# domain, and canonical, og:url, robots.txt and sitemap.xml must all agree with it.
# Moving the site would otherwise leave four stale absolute URLs in four files, each
# of which looks fine on its own.


def site_origin():
    """https://<domain>/ — from CNAME, which is what Pages actually serves."""
    return "https://%s/" % (DOCS / "CNAME").read_text(encoding="utf-8").strip()


META_RE = re.compile(
    r'<meta\s+(?:name|property)\s*=\s*["\']([^"\']+)["\']\s+content\s*=\s*["\']([^"\']*)',
    re.I)


def check_findability(src):
    """Title, description, canonical and og: must exist, be specific, and agree."""
    bad = []
    origin = site_origin()
    metas = dict(META_RE.findall(src))

    t = re.search(r"<title>([^<]*)</title>", src)
    title = t.group(1).strip() if t else ""
    if not title:
        bad.append("no <title>")
    elif len(title) < 25:
        # "The Murderboard" alone loses to a Wikipedia article, two other GitHub
        # repos and a Roblox script pack. A bare product name is not a title.
        bad.append("<title> is %d chars (%r) — too generic to distinguish this "
                   "page from everything else called murderboard" % (len(title), title))

    desc = metas.get("description", "").strip()
    if not desc:
        bad.append("no <meta name=description>")
    elif not 120 <= len(desc) <= 320:
        bad.append("meta description is %d chars — want 120-320" % len(desc))

    # The subject of this page is AI-assisted review. If the two fields a search
    # engine reads do not contain the word, the page cannot be found by anyone
    # searching for the problem rather than for its name.
    if "ai" not in re.findall(r"[a-z]+", (title + " " + desc).lower()):
        bad.append("neither <title> nor the meta description contains the word "
                   "'AI' — the one term someone searching for this would use")

    can = re.search(r'<link\s+rel=["\']canonical["\']\s+href=["\']([^"\']+)', src, re.I)
    if not can:
        bad.append("no <link rel=canonical>")
    elif can.group(1) != origin:
        bad.append("canonical is %s but CNAME says %s" % (can.group(1), origin))

    for key in ("og:type", "og:title", "og:description", "og:url"):
        if key not in metas:
            bad.append("missing <meta property=%s> — link previews fall back to "
                       "a bare URL" % key)
    if metas.get("og:url") and metas["og:url"] != origin:
        bad.append("og:url is %s but CNAME says %s" % (metas["og:url"], origin))
    if metas.get("og:title") and t and metas["og:title"] != title:
        bad.append("og:title disagrees with <title>")
    if metas.get("og:description") and desc and metas["og:description"] != desc:
        bad.append("og:description disagrees with the meta description")

    return bad


def check_crawl_files(page_src):
    """robots.txt and sitemap.xml: present, pointing here, and not stale."""
    bad = []
    origin = site_origin()

    robots = DOCS / "robots.txt"
    if not robots.exists():
        bad.append("docs/robots.txt is missing")
    else:
        r = robots.read_text(encoding="utf-8")
        if re.search(r"^\s*Disallow:\s*/\s*$", r, re.M):
            bad.append("robots.txt disallows the whole site")
        sm = re.search(r"^\s*Sitemap:\s*(\S+)", r, re.M)
        if not sm:
            bad.append("robots.txt names no Sitemap")
        elif sm.group(1) != origin + "sitemap.xml":
            bad.append("robots.txt points at %s, not %ssitemap.xml"
                       % (sm.group(1), origin))

    sitemap = DOCS / "sitemap.xml"
    if not sitemap.exists():
        bad.append("docs/sitemap.xml is missing")
        return bad

    s = sitemap.read_text(encoding="utf-8")
    loc = re.search(r"<loc>([^<]+)</loc>", s)
    if not loc:
        bad.append("sitemap.xml lists no <loc>")
    elif loc.group(1) != origin:
        bad.append("sitemap <loc> is %s but CNAME says %s" % (loc.group(1), origin))

    # lastmod must equal the page's own Updated stamp. A sitemap that says
    # "unchanged since <wrong date>" is the only line in that file that can
    # actively cost something, and nothing else would ever notice.
    lm = re.search(r"<lastmod>(\d{4}-\d{2}-\d{2})</lastmod>", s)
    u = UPDATED_RE.search(page_src)
    if not lm:
        bad.append("sitemap.xml has no well-formed <lastmod>")
    elif u and lm.group(1) != u.group(1):
        bad.append("sitemap lastmod is %s but the page stamp says Updated %s"
                   % (lm.group(1), u.group(1)))

    # noindex and "please index this" are contradictory instructions about the
    # same URL, and a crawler resolves the contradiction by trusting neither.
    # Checked against the <loc> entries, not the file text: the first version of
    # this grepped the whole file and fired on the COMMENT explaining why
    # thanks.html is deliberately absent — a check that failed on being documented.
    if any("thanks" in u for u in re.findall(r"<loc>([^<]+)</loc>", s)):
        bad.append("sitemap.xml lists thanks.html, which is marked noindex")

    return bad


# The markers murderboard_prompt.sh --sync-page splices between. Each must close
# its own HTML comment on its own line: the splice keeps the marker line and drops
# everything up to the end marker, so a begin comment that wrapped would lose its
# `-->` and swallow the prompt into a comment. The page would still be balanced,
# still pass every other check here, and simply stop showing the prompt.
PROMPT_BEGIN = "BEGIN GENERATED PROMPT"
PROMPT_END = "END GENERATED PROMPT"

GENERATOR = ["bash", str(ROOT / "murderboard_prompt.sh"), "--html"]


def generated_prompt_block():
    """What the block SHOULD be, straight from the generator. (block, error)."""
    try:
        r = subprocess.run(GENERATOR, capture_output=True, text=True, cwd=str(ROOT))
    except OSError as e:                                     # no bash, no answer
        return None, "cannot run murderboard_prompt.sh --html: %s" % e
    if r.returncode != 0:
        return None, ("murderboard_prompt.sh --html failed (exit %d): %s"
                      % (r.returncode, r.stderr.strip() or "no message"))
    if not r.stdout.strip():
        return None, "murderboard_prompt.sh --html produced nothing"
    return r.stdout, None


def extract_prompt_block(src):
    """The page's copy: everything between the two marker comment lines."""
    i = src.find(PROMPT_BEGIN)
    if i < 0:
        return None
    close = src.find("-->", i)
    if close < 0:
        return None
    nl = src.find("\n", close)
    if nl < 0:
        return None
    j = src.find(PROMPT_END, nl)
    if j < 0:
        return None
    return src[nl + 1:src.rfind("\n", nl, j) + 1]


def check_prompt_block(src, expected):
    """The page's copy must be the generator's output, byte for byte.

    Not "contains the roles" or "looks about right": equality. A weaker check is
    one someone can satisfy by hand, and a hand-satisfied copy is the thing being
    guarded against.
    """
    got = extract_prompt_block(src)
    if got is None:
        return ["the generated prompt block is gone, or a marker no longer closes "
                "its own comment (%s / %s)" % (PROMPT_BEGIN, PROMPT_END)]
    if got != expected:
        return ["the prompt block on the page has drifted from its generator — "
                "regenerate with: bash murderboard_prompt.sh --sync-page  "
                "(page has %d chars, generator emits %d)" % (len(got), len(expected))]
    return []


def main():
    failures = []

    # The deployment files Pages needs. Absent .nojekyll, item 3 above is unenforced.
    for name in (".nojekyll", "CNAME"):
        if not (DOCS / name).exists():
            failures.append("docs/%s is missing" % name)
    if not PAGE.exists():
        print("FAIL docs/index.html does not exist")
        return 1

    src = PAGE.read_text(encoding="utf-8")

    # There must be exactly ONE copy of the explainer. Two copies drift, and this
    # repo has already had that failure: the page went stale within an hour of
    # #31. thanks.html is a different page, not a copy — it is where the contact
    # form lands a sender — so it is named here rather than silently tolerated.
    # Anything else appearing in docs/ is a stray until someone says otherwise.
    KNOWN = {PAGE.name, "thanks.html"}
    strays = [p for p in DOCS.rglob("*.html") if p.name not in KNOWN]
    for s in strays:
        failures.append("unexpected page in docs/: %s" % s.relative_to(DOCS))

    failures += check(src)
    failures += check_crawl_files(src)

    # The crawl files live outside the page, so their controls mutate the FILES,
    # not the HTML. Each is written to a temp copy, checked, and put back.
    crawl_controls = [
        ("robots.txt missing", "robots.txt", None),
        ("robots.txt disallows everything", "robots.txt",
         "User-agent: *\nDisallow: /\n\nSitemap: %ssitemap.xml\n" % site_origin()),
        ("robots.txt names no sitemap", "robots.txt", "User-agent: *\nAllow: /\n"),
        ("sitemap.xml missing", "sitemap.xml", None),
        ("sitemap lastmod left stale after a page update", "sitemap.xml",
         '<?xml version="1.0" encoding="UTF-8"?>\n<urlset>\n<url>\n'
         '<loc>%s</loc>\n<lastmod>2001-01-01</lastmod>\n</url>\n</urlset>\n'
         % site_origin()),
        ("sitemap points at a different host", "sitemap.xml",
         '<?xml version="1.0" encoding="UTF-8"?>\n<urlset>\n<url>\n'
         '<loc>https://example.com/</loc>\n<lastmod>2026-09-01</lastmod>\n'
         '</url>\n</urlset>\n'),
    ]
    for name, fname, content in crawl_controls:
        target = DOCS / fname
        original = target.read_text(encoding="utf-8") if target.exists() else None
        try:
            if content is None:
                target.unlink()
            else:
                target.write_text(content, encoding="utf-8")
            if not check_crawl_files(src):
                failures.append("NEGATIVE CONTROL NOT CAUGHT: %s" % name)
        finally:
            if original is None:
                if target.exists():
                    target.unlink()
            else:
                target.write_text(original, encoding="utf-8")

    # The landing page is not the explainer — no stamp, no jump nav, no form — but
    # it is served to the public from the same directory, so the properties that
    # make a page publishable at all still apply to it.
    thanks = DOCS / "thanks.html"
    if thanks.exists():
        tsrc = thanks.read_text(encoding="utf-8")
        for problem in check_document(tsrc):
            failures.append("thanks.html: %s" % problem)
    else:
        failures.append("docs/thanks.html is missing — the form's redirect lands nowhere")

    # NEGATIVE CONTROLS. A fixture that cannot fail proves nothing, so each mutation
    # below must be caught. If one stops being caught, the check has rotted open and
    # this test says so instead of passing quietly.
    controls = [
        ("doctype removed",
         lambda s: s.replace("<!doctype html>\n", "", 1)),
        ("webfont stylesheet added",
         lambda s: s.replace("<head>",
                             '<head>\n<link rel="stylesheet" '
                             'href="https://fonts.googleapis.com/css?family=X">', 1)),
        ("analytics script added",
         lambda s: s.replace("</head>",
                             '<script src="https://example.com/a.js"></script></head>', 1)),
        ("CSS @import added",
         lambda s: s.replace("<style>", "<style>\n@import url(https://x.example/y.css);", 1)),
        ("background image URL added",
         lambda s: s.replace("<style>", "<style>\nbody{background:url(https://x.example/b.png)}", 1)),
        ("Liquid token introduced",
         lambda s: s.replace("</body>", "<p>{{ site.title }}</p></body>", 1)),
        ("dead internal anchor",
         lambda s: s.replace('href="#limits"', 'href="#no-such-section"', 1)),
        ("html element unclosed",
         lambda s: s.replace("</html>", "", 1)),
        # The stamp rots in more ways than it is missing.
        # Markup-agnostic, like the check itself: strip the three fields wherever
        # they live rather than assuming the element that wraps them.
        ("stamp removed entirely",
         lambda s: UPDATED_RE.sub("", VERSION_RE.sub("", BORN_RE.sub("", s)))),
        ("born date silently changed",
         lambda s: s.replace('Born <time datetime="%s">%s' % (BORN, BORN),
                             'Born <time datetime="2020-01-01">2020-01-01', 1)),
        ("time datetime disagrees with its visible text",
         lambda s: s.replace('<time datetime="%s">%s</time>' % (BORN, BORN),
                             '<time datetime="%s">2019-05-05</time>' % BORN, 1)),
        ("version malformed (not N.N.N)",
         lambda s: VERSION_RE.sub("Version <b>v0.1</b>", s, 1)),
        # Rewrites whatever Updated CURRENTLY says, via the same regex the check uses.
        # It used to substitute the literal BORN date, which worked only while the page
        # had never been updated -- Born and Updated were both 2026-08-25 at the time it
        # was written. The first real bump (0.9.0, 2026-08-26) made the replace a no-op,
        # so the mutation was never injected. It failed loudly rather than passing
        # vacuously, which is why this was caught, but a negative control that expires
        # the first time the thing it guards is used is not a control.
        ("updated older than born",
         lambda s: UPDATED_RE.sub(
             'Updated <time datetime="2001-01-01">2001-01-01</time>', s, 1)),
        # The form is the only thing on the page that talks to a third party, so
        # every way it can quietly change has to be a failure.
        ("form relay swapped for another host",
         lambda s: s.replace(RELAY, "https://evil.example/collect", 1)),
        ("form downgraded to GET (message would land in the URL)",
         lambda s: s.replace('method="POST"', 'method="GET"', 1)),
        ("honeypot removed",
         lambda s: s.replace('name="botcheck"', 'name="notacheck"', 1)),
        ("redirect removed, sender lands on the relay's page",
         lambda s: s.replace('name="redirect"', 'name="notaredirect"', 1)),
        ("page reverts to claiming it requests nothing",
         lambda s: s.replace("Nothing is requested on load.", STALE_CLAIM, 1)),
        # Regex, not str.replace: the phrase wraps across source lines in both
        # places it appears, so a literal mutation would change nothing and the
        # control would "pass" by doing nothing at all.
        ("page drops the send-only wording while keeping the form",
         lambda s: re.sub(r"only\s+if\s+you\s+send\s+the\s+form", "never", s)),
        # FINDABILITY. Every one of these renders a perfect-looking page.
        ("title reverted to the bare product name",
         lambda s: re.sub(r"<title>[^<]*</title>",
                          "<title>The Murderboard</title>", s, count=1)),
        ("meta description removed",
         lambda s: re.sub(r'<meta name="description"[^>]*>', "", s, count=1)),
        ("description stops mentioning AI at all",
         lambda s: re.sub(r'(<meta name="description" content=")[^"]*',
                          r"\1A review process for catching unchecked claims in "
                          r"documents, with eleven roles and a fixed output format "
                          r"that says what was checked.", s, count=1)),
        ("canonical points at another host",
         lambda s: s.replace('rel="canonical" href="https://murderboard.tonydefazio.com/"',
                             'rel="canonical" href="https://example.com/"', 1)),
        ("og:url drifts from the canonical",
         lambda s: s.replace('<meta property="og:url" content="https://murderboard.tonydefazio.com/">',
                             '<meta property="og:url" content="https://old.example/">', 1)),
        ("og:title drifts from <title>",
         lambda s: re.sub(r'(<meta property="og:title" content=")[^"]*',
                          r"\1Something Else", s, count=1)),
        ("og tags removed entirely",
         lambda s: re.sub(r'<meta property="og:[^>]*>', "", s)),
    ]
    for name, mutate in controls:
        if not check(mutate(src)):
            failures.append("NEGATIVE CONTROL NOT CAUGHT: %s" % name)

    # THE PROMPT BLOCK. Kept out of check() on purpose: check() is pure string
    # analysis and gets run ~20 more times by the mutation loop above, and paying
    # for a subprocess on each would buy nothing. Its controls are its own.
    prompt_controls = []
    expected, err = generated_prompt_block()
    if err:
        failures.append(err)
    else:
        failures += check_prompt_block(src, expected)
        # Every mutation below is applied THROUGH `expected`, so it is guaranteed to
        # land inside the block. Mutating the raw page by substring does not: the
        # roles are also named in the prose of the panel section further up, and the
        # first attempt at these controls silently edited that instead and "passed"
        # while changing nothing the check looks at.
        def in_block(f):
            return lambda s: s.replace(expected, f(expected), 1)

        # NAME NO ROLE HERE. The first draft of these mutated the literal string
        # "Reinventing the Wheel", and renaming that role upstream turned the
        # mutation into a no-op: the control stopped injecting anything and passed
        # by doing nothing, on exactly the edit it exists to catch. Same shape as
        # the "updated older than born" control above, which expired the first time
        # the page was updated. So these match the SHAPE of a role line -- a number,
        # a dot, a title -- and survive any rewording of the roster.
        ROLE_LINE = r"\n *\d+\. [^\n]*"

        prompt_controls = [
            # The page keeps a stale copy after a role is added or reworded upstream.
            # This is the whole reason the check exists: it looks like nothing.
            ("a role reworded on the page but not in the process file",
             in_block(lambda b: re.sub(r"(\n *\d+\. )", r"\1EDITED ", b, count=1))),
            ("a role dropped from the page's copy of the list",
             in_block(lambda b: re.sub(ROLE_LINE, "", b, count=1))),
            # Someone "tidies" the escaping and a placeholder becomes a live tag.
            ("escaping undone (a raw < would parse as markup)",
             in_block(lambda b: b.replace("&lt;", "<", 1))),
            ("the whole block emptied",
             lambda s: s.replace(expected, "", 1)),
            # Lose a marker and the block is unfindable -- which must read as a
            # failure, not as "no block to check, nothing to report".
            ("begin marker removed",
             lambda s: s.replace(PROMPT_BEGIN, "WAS THE BEGIN MARKER", 1)),
            ("end marker removed",
             lambda s: s.replace(PROMPT_END, "WAS THE END MARKER", 1)),
        ]
        for name, mutate in prompt_controls:
            if not check_prompt_block(mutate(src), expected):
                failures.append("NEGATIVE CONTROL NOT CAUGHT: %s" % name)

    if failures:
        print("FAIL (%d)" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1

    print("ok — docs/index.html is a complete document, fetches nothing external, "
          "is Jekyll-safe, balanced, and every internal reference resolves")
    print("ok — the prompt printed on the page is byte-identical to "
          "murderboard_prompt.sh --html")
    print("ok — %d negative controls all caught"
          % (len(controls) + len(prompt_controls) + len(crawl_controls)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
