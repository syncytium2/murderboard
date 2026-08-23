#!/usr/bin/env python3
"""Fetch an open-access paper, cache it, and print its text — the murderboard's lit tool.

WHY THIS EXISTS
---------------
An agent that needs a paper reaches for `curl`/`wget`/`WebFetch`, which may be denied by
the permission system, unavailable, or blocked per-agent — so a fan-out of research agents
each rediscovers the wall, prompts the human, and dies without the paper. Meanwhile plain
`python3` + `urllib` goes straight through. So: ONE tool, ONE allow rule, with the host
allowlist enforced HERE in code rather than in a brittle shell-prefix permission pattern
that any flag reordering defeats.

SCOPE: open-access scholarly hosts only (see ALLOWED_HOSTS). This is NOT a general
downloader, and it will not fetch paywalled publisher HTML (ScienceDirect/Nature/Wiley) —
those block bots and there is no license to scrape them. Use it for the OA copy (PMC,
EuropePMC, arXiv, bioRxiv), or flag the paper so a human drops the PDF in the library.

LITERATURE CACHE
----------------
Point the tool at your literature library with the MURDERBOARD_LIT environment variable
(a directory of PDFs); fetched papers are cached under `<lit>/_autofetch/`. Three rules so
the murderboard stops re-downloading what you already have, and flags what it can't reach:

  1. CHECK THE LIBRARY FIRST.  The curated library likely already holds the PDF. Before
     fetching, search it by author/keyword:
         python3 fetch_paper.py --have <author> <keyword> <keyword>
     A hit means the PDF is on disk already — Read it, do NOT download it. (The URL-keyed
     `_autofetch/` cache prevents re-fetching the SAME url; `--have` prevents re-fetching a
     paper already filed under a human name the cache can't see.)

  2. PROMOTE WHAT'S USEFUL.  Fetched papers land in `<lit>/_autofetch/` under hash names —
     a scratch cache, not a library. When a fetched paper actually earns its place
     (verified a citation, grounded a method), copy it into the curated library:
         python3 fetch_paper.py --promote <url> "Author Year short title.pdf"
     Now the next session finds it via `--have` instead of downloading it again.

  3. FLAG WHAT YOU CAN'T GET.  Any fetch that FAILS or is REFUSED (paywalled host) is
     auto-appended to `<lit>/_NEEDED.md` — a standing want-list. A human can get any PDF;
     surface that list rather than guessing at the paper's contents. To flag a paper you
     have only a citation for (no reachable URL):
         python3 fetch_paper.py --need "Smith et al 2020, J Neurosci — pulse gen"

CONFIG (environment variables)
    MURDERBOARD_LIT     path to the curated literature library (dir of PDFs). Required for
                        --have / --promote / the want-list to be meaningful.
    MURDERBOARD_PAPERS  override the fetch cache dir (default: <lit>/_autofetch).
    (IF2_LIT / IF2_PAPERS are honored too, for the project this tool originated in.)

USAGE
    python3 fetch_paper.py <url> [<url> ...]
    python3 fetch_paper.py --chars 40000 <url>     # more text (default 25k)
    python3 fetch_paper.py --quiet <url>           # save only, print the path
    python3 fetch_paper.py --have <keyword> ...    # search the curated library FIRST
    python3 fetch_paper.py --promote <url|hash> ["name.pdf"]   # cache -> library
    python3 fetch_paper.py --need "<citation>"     # flag a paper for a human to get
    python3 fetch_paper.py --list                  # what the _autofetch cache holds

Prints extracted text to stdout so an agent reads it directly from the tool result.
PDFs are extracted with pypdf if available, else `pdftotext`.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import sys
import time
import urllib.request
from urllib.parse import urlparse

# Open-access scholarly hosts ONLY. A host matches if it equals an entry or is a
# subdomain of it — substring matching would let "evil-arxiv.org.attacker.com" through.
ALLOWED_HOSTS = {
    "arxiv.org",
    "www.arxiv.org",
    "pmc.ncbi.nlm.nih.gov",
    "www.ncbi.nlm.nih.gov",
    "pubmed.ncbi.nlm.nih.gov",
    "www.ebi.ac.uk",            # EuropePMC REST (fullTextXML) — cleanest OA route
    "europepmc.org",
    "www.biorxiv.org",
    "www.medrxiv.org",
    "journals.plos.org",
    "elifesciences.org",
    "www.jneurosci.org",
    "direct.mit.edu",           # Network Neuroscience (OA)
    "www.frontiersin.org",
    "zenodo.org",               # CERN open-access repository — ReScience C, JOSS,
                                # and most archived research software live here.
                                # Serves PDFs as application/octet-stream, so the
                                # content-type check below must not assume a PDF
                                # mimetype.
}

UA = "Mozilla/5.0 (compatible; murderboard-litreview/1.0; +academic use)"


def host_allowed(url):
    h = (urlparse(url).hostname or "").lower()
    return any(h == a or h.endswith("." + a) for a in ALLOWED_HOSTS), h


def _lit_root():
    """The curated literature library (a directory of PDFs), or None if not configured.

    Resolution order:
      1. $MURDERBOARD_LIT           — the portable way to point at your library.
      2. $IF2_LIT                   — back-compat for the project this tool originated in.
      3. a `01-lit/` dir under a known Dropbox root — back-compat autodetect.
    Returns None (NOT a /tmp fallback) when nothing is found: `--have`/`--promote`/the
    want-list are meaningless without a real library, and a stand-in would silently hide
    papers you actually have. `--have`/`--promote`/`--need` report the miss instead.
    """
    for var in ("MURDERBOARD_LIT", "IF2_LIT"):
        p = os.environ.get(var)
        if p:
            return p if os.path.isdir(p) else None
    home = os.path.expanduser("~")
    for cand in (
        os.path.join(home, "University of Michigan Dropbox", "Richard DeFazio"),
        os.path.join(home, "Library", "CloudStorage",
                     "Dropbox-UniversityofMichigan", "Richard DeFazio"),
    ):
        lit = os.path.join(cand, "01-lit")
        if os.path.isdir(lit):
            return lit
    return None


def cache_dir():
    """Where fetched papers are cached.

    Beside the curated library (`<lit>/_autofetch/`), NOT /tmp: /tmp is ephemeral and
    machine-local, so the cache dies at session end and the same paper gets pulled again by
    a later session or another machine. A synced library dir (Dropbox, a network share)
    keeps a paper fetched once available everywhere.

    Sits BESIDE the curated library, never in it: these are machine-fetched copies with
    hashed names, and mixing them into a hand-organised library would wreck it. Promote the
    keepers with `--promote`.

    Override with $MURDERBOARD_PAPERS (or $IF2_PAPERS). Falls back to /tmp only when no
    library is configured, so this still runs anywhere.
    """
    p = os.environ.get("MURDERBOARD_PAPERS") or os.environ.get("IF2_PAPERS")
    if not p:
        lit = _lit_root()
        if lit:
            p = os.path.join(lit, "_autofetch")
    if not p:
        p = os.path.join(os.path.expanduser("~"), ".murderboard_papers")
    os.makedirs(p, exist_ok=True)
    readme = os.path.join(p, "README.md")
    if not os.path.exists(readme):
        try:
            with open(readme, "w") as f:
                f.write(
                    "# _autofetch — papers pulled by fetch_paper.py\n\n"
                    "Machine-written cache. Files are named by a hash of their URL; "
                    "`index.json` maps URL -> file, title and fetch date.\n\n"
                    "This is NOT a curated library — it sits beside the curated library "
                    "precisely so it does not pollute it. Safe to delete entirely; it will "
                    "refill on demand.\n\n"
                    "Keep it under a synced/shared dir so a paper fetched once is not "
                    "re-downloaded by the next session or another machine. Promote the "
                    "keepers into the library with `fetch_paper.py --promote`.\n"
                )
        except OSError:
            pass
    return p


def _index_path():
    return os.path.join(cache_dir(), "index.json")


def load_index():
    try:
        with open(_index_path()) as f:
            return json.load(f)
    except Exception:
        return {}


def save_index(idx):
    try:
        tmp = _index_path() + ".tmp"
        with open(tmp, "w") as f:
            json.dump(idx, f, indent=1, sort_keys=True)
        os.replace(tmp, _index_path())   # atomic: Dropbox must never see a half-written index
    except OSError:
        pass


def _needed_path():
    """The want-list a human works from. Lives at the ROOT of the curated library so it is
    impossible to miss, not buried in the machine-written _autofetch cache."""
    lit = _lit_root()
    return os.path.join(lit, "_NEEDED.md") if lit else None


def flag_needed(citation, url="", reason=""):
    """Append a paper we could not fetch to <lit>/_NEEDED.md. Idempotent on (url or
    citation) so a retried fetch does not stack duplicate lines. Returns the path (or None
    if the library is unreachable, in which case the caller still prints the flag to stdout).
    """
    path = _needed_path()
    if not path:
        return None
    key = (url or citation).strip()
    try:
        existing = open(path, encoding="utf-8").read() if os.path.exists(path) else ""
    except OSError:
        existing = ""
    if not existing:
        existing_header = (
            "# _NEEDED — papers the murderboard could not download\n\n"
            "Auto-appended by `fetch_paper.py` when a fetch fails or hits a "
            "paywalled host, or by `--need` for a citation with no reachable URL. A human "
            "can get any of these — grab the PDF, drop it in the library, and delete the line.\n\n"
        )
        try:
            with open(path, "w", encoding="utf-8") as f:
                f.write(existing_header)
            existing = existing_header
        except OSError:
            return None
    if key and key in existing:          # already flagged — do not duplicate
        return path
    stamp = time.strftime("%Y-%m-%d")
    bits = [b for b in (citation.strip(), reason.strip() and "(%s)" % reason.strip(), url.strip()) if b]
    line = "- [ ] %s — %s\n" % (stamp, "  ".join(bits) if bits else "(no detail)")
    try:
        with open(path, "a", encoding="utf-8") as f:
            f.write(line)
    except OSError:
        return None
    return path


def have_search(keywords):
    """List curated-library PDFs whose filename matches ALL keywords (case-insensitive).
    Excludes the _autofetch cache — that is scratch, not the library."""
    lit = _lit_root()
    print("=" * 78)
    if not lit:
        print("LIBRARY NOT FOUND: set $MURDERBOARD_LIT to your literature library directory.")
        return 3
    kw = [k.lower() for k in keywords]
    hits = []
    for root, dirs, files in os.walk(lit):
        dirs[:] = [d for d in dirs if d != "_autofetch"]   # skip the machine cache
        for fn in files:
            if not fn.lower().endswith(".pdf"):
                continue
            if all(k in fn.lower() for k in kw):
                full = os.path.join(root, fn)
                rel = os.path.relpath(full, lit)
                hits.append((rel, os.path.getsize(full)))
    print("curated library: %s   query: %s" % (lit, " ".join(kw)))
    if not hits:
        print("NO MATCH in the curated library — safe to fetch (then --promote if it's a keeper).")
        return 1
    print("ALREADY HAVE %d — Read these, do NOT download:" % len(hits))
    for rel, sz in sorted(hits):
        print("  %s   (%.1f MB)" % (rel, sz / 1e6))
    return 0


def _resolve_cached(ref, idx):
    """Map a --promote argument to a cached file path. Accepts a URL (looked up in the
    index), a bare hash / filename in the cache dir, or a direct path."""
    if ref in idx and idx[ref].get("path"):
        return idx[ref]["path"], idx[ref].get("title", "")
    if os.path.isfile(ref):
        return ref, ""
    cand = os.path.join(cache_dir(), ref)
    if os.path.isfile(cand):
        return cand, ""
    for ext in (".pdf", ".txt"):
        if os.path.isfile(cand + ext):
            return cand + ext, ""
    return None, ""


def promote(ref, name, idx):
    """Copy a cached, useful paper into the curated library under a human name."""
    print("=" * 78)
    lit = _lit_root()
    if not lit:
        print("LIBRARY NOT FOUND: cannot promote — set $MURDERBOARD_LIT to your library dir.")
        return 3
    src, title = _resolve_cached(ref, idx)
    if not src:
        print("NOT IN CACHE: %r — fetch it first, or pass the cached file's path/hash." % ref)
        return 2
    if not (src.lower().endswith(".pdf") or open(src, "rb").read(5) == b"%PDF-"):
        print("NOT A PDF: %s\nThe curated library holds paper PDFs. This looks like an HTML "
              "capture (a paywalled/JS page). Get the real PDF, or --need it." % src)
        return 2
    if not name:
        name = (title or os.path.basename(src)).strip()
    name = re.sub(r'[<>:"/\\|?*]', "_", name)      # keep it a legal filename
    if not name.lower().endswith(".pdf"):
        name += ".pdf"
    dest = os.path.join(lit, name)
    if os.path.exists(dest):
        print("ALREADY IN LIBRARY: %s (not overwritten)." % name)
        return 0
    try:
        shutil.copy2(src, dest)
    except Exception as e:
        print("PROMOTE FAILED: %s: %s" % (type(e).__name__, e))
        return 1
    print("PROMOTED -> %s   (%.1f MB)\nFuture sessions will find it with --have." %
          (name, os.path.getsize(dest) / 1e6))
    return 0


def guess_title(text, is_pdf):
    for line in text[:4000].splitlines():
        s = line.strip()
        if 25 <= len(s) <= 200 and " " in s:
            return s
    return ""


def fetch(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": UA, "Accept": "*/*"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.headers.get("Content-Type", "")


def pdf_to_text(path):
    try:
        from pypdf import PdfReader
        return "\n".join((pg.extract_text() or "") for pg in PdfReader(path).pages)
    except Exception:
        pass
    import subprocess
    try:
        out = subprocess.run(["pdftotext", path, "-"], capture_output=True, text=True, timeout=120)
        if out.returncode == 0:
            return out.stdout
    except Exception:
        pass
    return ""


def html_to_text(raw):
    s = raw.decode("utf-8", "ignore")
    s = re.sub(r"(?is)<(script|style|nav|footer|header)[^>]*>.*?</\1>", " ", s)
    s = re.sub(r"(?s)<[^>]+>", " ", s)          # XML (EuropePMC fullTextXML) falls out here too
    s = re.sub(r"&(nbsp|#160);", " ", s)
    s = re.sub(r"&amp;", "&", s)
    s = re.sub(r"&lt;", "<", s)
    s = re.sub(r"&gt;", ">", s)
    return re.sub(r"[ \t]*\n\s*\n\s*", "\n\n", re.sub(r"[ \t]+", " ", s)).strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("urls", nargs="*")
    ap.add_argument("--chars", type=int, default=25000, help="max chars printed per doc")
    ap.add_argument("--quiet", action="store_true", help="save only; print the path")
    ap.add_argument("--refresh", action="store_true", help="ignore the cache and re-download")
    ap.add_argument("--list", action="store_true", help="list what is already cached, and exit")
    ap.add_argument("--have", nargs="+", metavar="KW",
                    help="search the curated library by keyword, and exit (check BEFORE fetching)")
    ap.add_argument("--promote", metavar="REF",
                    help="copy a cached paper (URL / hash / path) into the library, and exit")
    ap.add_argument("--name", metavar="NAME.pdf", help="filename for --promote (default: cached title)")
    ap.add_argument("--need", metavar="CITATION",
                    help="flag a paper for a human to fetch (adds to <lit>/_NEEDED.md), and exit")
    ap.add_argument("--url", default="", help="optional URL to record with --need")
    ap.add_argument("--reason", default="", help="optional reason to record with --need")
    a = ap.parse_args()

    idx = load_index()

    if a.have:
        return have_search(a.have)

    if a.promote:
        return promote(a.promote, a.name, idx)

    if a.need:
        path = flag_needed(a.need, a.url, a.reason)
        print("FLAGGED -> %s" % (path or "(library not found; set $MURDERBOARD_LIT)"))
        print("  %s%s" % (a.need, (" <%s>" % a.url) if a.url else ""))
        return 0

    if a.list:
        print("cache: %s  (%d papers)" % (cache_dir(), len(idx)))
        for u, m in sorted(idx.items(), key=lambda kv: kv[1].get("fetched", "")):
            print("  %s  %s\n      %s" % (m.get("fetched", "?")[:10], m.get("title", "")[:70], u))
        return 0

    if not a.urls:
        ap.error("give a URL to fetch, or use --have / --promote / --need / --list")

    rc = 0
    for url in a.urls:
        ok, h = host_allowed(url)
        print("=" * 78)
        print("URL: %s" % url)

        # CACHE HIT — the whole point. Search endpoints are excluded: they are queries, not
        # documents, and their results change.
        hit = idx.get(url)
        is_query = "webservices/rest/search" in url
        if hit and not a.refresh and not is_query:
            path = hit.get("path", "")
            if os.path.exists(path):
                text = pdf_to_text(path) if path.endswith(".pdf") else \
                       html_to_text(open(path, "rb").read())
                print("CACHED (fetched %s): %s" % (hit.get("fetched", "?")[:10], path))
                if hit.get("title"):
                    print("title: %s" % hit["title"])
                if a.quiet:
                    print("%d chars -> %s" % (len(text), path))
                    continue
                print("-" * 78)
                print(text[:a.chars])
                if len(text) > a.chars:
                    print("\n[... truncated %d of %d chars. Re-run with --chars, or Read %s ...]"
                          % (len(text) - a.chars, len(text), path))
                continue

        if not ok:
            # Refuse loudly and name the reason, so an agent reports the block instead of
            # silently substituting half-remembered content for the paper. Paywalled hosts
            # are exactly what a human can fetch by hand, so flag it to the want-list.
            flag_needed(url, url=url, reason="paywalled / non-OA host %s" % h)
            print("REFUSED: host %r is not on the open-access allowlist.\n"
                  "Allowed: %s\n"
                  "FLAGGED -> <lit>/_NEEDED.md (a human can get the paywalled PDF).\n"
                  "Or use the OA copy (PMC/EuropePMC/arXiv/bioRxiv) if one exists." %
                  (h, ", ".join(sorted(ALLOWED_HOSTS))))
            rc = 2
            continue
        try:
            raw, ctype = fetch(url)
        except Exception as e:
            flag_needed(url, url=url, reason="fetch failed: %s" % type(e).__name__)
            print("FETCH FAILED: %s: %s\nFLAGGED -> <lit>/_NEEDED.md." % (type(e).__name__, e))
            rc = 1
            continue

        name = hashlib.sha1(url.encode()).hexdigest()[:12]
        is_pdf = "pdf" in ctype.lower() or raw[:5] == b"%PDF-" or url.lower().endswith(".pdf")
        path = os.path.join(cache_dir(), name + (".pdf" if is_pdf else ".txt"))
        with open(path, "wb") as f:
            f.write(raw)

        text = pdf_to_text(path) if is_pdf else html_to_text(raw)

        # Record it so the NEXT session (or the other machine) does not re-download.
        # Queries are not documents — their results change, so they are never cached.
        if not is_query:
            idx[url] = {"path": path, "fetched": time.strftime("%Y-%m-%dT%H:%M:%S"),
                        "title": guess_title(text, is_pdf), "content_type": ctype,
                        "bytes": len(raw)}
            save_index(idx)

        print("content-type: %s | %d bytes | saved: %s" % (ctype, len(raw), path))
        if is_pdf and not is_query:
            print("(keeper? promote it: fetch_paper.py --promote %s \"Author Year title.pdf\")" % url)
        if not text.strip():
            print("NOTE: no text extracted (scanned PDF, or JS-rendered page). "
                  "Read the saved file directly with the Read tool.")
            continue
        if a.quiet:
            print("extracted %d chars -> %s" % (len(text), path))
            continue
        print("-" * 78)
        print(text[:a.chars])
        if len(text) > a.chars:
            print("\n[... truncated %d of %d chars. Re-run with --chars, or Read %s ...]"
                  % (len(text) - a.chars, len(text), path))
    return rc


if __name__ == "__main__":
    sys.exit(main())
