#!/usr/bin/env python3
"""Pin the invariants of the published page, because breaking them fails SILENTLY.

`docs/index.html` is served to the public by GitHub Pages. Three of its properties
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

`<a href>` is navigation, not a fetch, and is excluded on purpose — as is
`rel="canonical"`, which is metadata the browser never requests. The distinction is
the whole point: a check that flagged every URL would be noise, and noise gets
switched off.

No network. Pure string analysis over the repo's own files.
"""
import pathlib
import re
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
    """Full check for the explainer: structure, plus its stamp and its form."""
    return check_document(src) + check_stamp(src) + check_form(src)


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


# The day the site first served to the public. A LITERAL on purpose: a born-on
# date that can be quietly edited is not a born-on date, it is just another
# mutable field. If it ever legitimately changes, changing it here is the
# deliberate act that should be.
BORN = "2026-08-25"

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
    ]
    for name, mutate in controls:
        if not check(mutate(src)):
            failures.append("NEGATIVE CONTROL NOT CAUGHT: %s" % name)

    if failures:
        print("FAIL (%d)" % len(failures))
        for f in failures:
            print("  - %s" % f)
        return 1

    print("ok — docs/index.html is a complete document, fetches nothing external, "
          "is Jekyll-safe, balanced, and every internal reference resolves")
    print("ok — %d negative controls all caught" % len(controls))
    return 0


if __name__ == "__main__":
    sys.exit(main())
