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
    """Return a list of problems. Empty list means the page is publishable."""
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

    # There must be exactly ONE copy of the page. Two copies drift, and this repo
    # has already had that failure: the page went stale within an hour of #31.
    strays = [p for p in DOCS.rglob("*.html") if p != PAGE]
    for s in strays:
        failures.append("second copy of the page: docs/%s" % s.relative_to(DOCS))

    failures += check(src)

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
