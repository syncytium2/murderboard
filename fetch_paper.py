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
     paper already filed under a human name the cache can't see.) Keywords match the
     filename OR the text of the PDF's first two pages, so a paper saved under the name its
     publisher gave it ("elife-16246-v1.pdf") is still found by author or title word.

  2. PROMOTE WHAT'S USEFUL.  Fetched papers land in `<lit>/_autofetch/` under hash names —
     a scratch cache, not a library. When a fetched paper actually earns its place
     (verified a citation, grounded a method), copy it into the curated library:
         python3 fetch_paper.py --promote <url> --name "Author Year short title.pdf"
     Now the next session finds it via `--have` instead of downloading it again.

  3. FLAG WHAT YOU CAN'T GET.  A fetch a human could fix — a paywalled host, an access
     denial (401/403), a captcha / bot-check page — is auto-appended to `<lit>/_NEEDED.md`,
     a standing want-list. A human can get any PDF; surface that list rather than guessing
     at the paper's contents. A temporary failure (5xx, 429, timeout) or a wrong URL (404)
     is reported but NOT flagged: retry, or find the right route. Captcha pages are never
     cached as papers. To flag a paper you have only a citation for (no reachable URL):
         python3 fetch_paper.py --need "Smith et al 2020, J Neurosci — pulse gen"
     A run that is not working for the library's owner (a test, a review of someone else's
     paper) should pass `--no-flag` or set MURDERBOARD_NO_FLAG=1 so it does not write their
     want-list; `--have` still reads the library.

CONFIG (environment variables)
    MURDERBOARD_LIT     path to the curated literature library (dir of PDFs). Required for
                        --have / --promote / the want-list to be meaningful.
    MURDERBOARD_PAPERS  override the fetch cache dir (default: <lit>/_autofetch).
    MURDERBOARD_NO_FLAG set to 1 to stop automatic _NEEDED.md appends (same as --no-flag).
    (IF2_LIT / IF2_PAPERS are honored too, for the project this tool originated in.)

USAGE
    python3 fetch_paper.py <url> [<url> ...]
    python3 fetch_paper.py --chars 40000 <url>     # more text (default 25k)
    python3 fetch_paper.py --quiet <url>           # save only, print the path
    python3 fetch_paper.py --have <keyword> ...    # search the curated library FIRST
    python3 fetch_paper.py --promote <url|hash> [--name "name.pdf"]  # cache -> library
    python3 fetch_paper.py --need "<citation>"     # flag a paper for a human to get
    python3 fetch_paper.py --list                  # what the _autofetch cache holds
    python3 fetch_paper.py --no-flag <url>         # fetch without writing the want-list

Prints extracted text to stdout so an agent reads it directly from the tool result.
PDFs are extracted with pypdf if available, else `pdftotext`.
"""
import argparse
import glob
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
#
# WHAT MEMBERSHIP MEANS, AND WHAT IT DOES NOT. This list gates *where bytes may be
# fetched from*, so the tool cannot be pointed at a paywall and cannot be talked into
# scraping one. It is not a quality signal and never was a claim that the venue is
# peer-reviewed — most entries happen to be publishers, but zenodo.org is a
# self-deposit repository where anyone can upload anything and mint a DOI. Read an
# entry as "this host serves open files", not as "documents from this host are
# vouched for". Judging the document is the reader's job, and the murderboard's.
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
                                # Serves PDFs as application/octet-stream; see
                                # looks_like_pdf(), which is why that still works.
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
      3. a `01-lit/` dir under a synced Dropbox root — back-compat autodetect, by SHAPE.
    Returns None (NOT a /tmp fallback) when nothing is found: `--have`/`--promote`/the
    want-list are meaningless without a real library, and a stand-in would silently hide
    papers you actually have. `--have`/`--promote`/`--need` report the miss instead.

    THE AUTODETECT MATCHES A SHAPE, NEVER A NAME. Until 2026-09-10 it named a literal
    institution and a literal person — the back-compat convenience of the project this
    tool came from. That is fine to *keep* and fatal to *ship*: a consumer vendored this
    file into a public repo, its own secrets gate caught the two names only after they had
    merged to a public `main`, and it removed the whole file rather than patch a vendored
    one. Removing it dropped something that mattered with it — `_NEEDED.md`, the only
    channel by which a reviewer that cannot reach a paper asks a human for it — and a
    month later that repo drafted a proposal whose central mechanism was already refuted
    in a literature its shelf held none of. So the branch stays and the names go: the glob
    below finds the same directory on the machine this was written for, finds the
    equivalent one for any other institution or person, and carries nobody's name into a
    stranger's checkout.

    An autodetected hit is returned CANONICALIZED, and only an autodetected one — a path
    you set explicitly comes back exactly as you set it. A Dropbox root is routinely
    reachable under several names (the macOS client leaves symlinks in `$HOME` pointing at
    the real `Library/CloudStorage/…` mount, so the machine this was written for matches
    three of the patterns below and all three are one directory). Resolving the link makes
    those spellings collapse to one answer, which is what keeps `--have` hits, cache paths
    and `_NEEDED.md` from moving between runs. Where two *different* libraries still match,
    the first sorted one wins, and setting $MURDERBOARD_LIT is the answer to the ambiguity.
    """
    for var in ("MURDERBOARD_LIT", "IF2_LIT"):
        p = os.environ.get(var)
        if p:
            return p if os.path.isdir(p) else None
    # glob.escape, because the wildcards below must be OURS: a `[` or `*` in the home
    # directory's own name would otherwise be read as a pattern and match nothing.
    home = glob.escape(os.path.expanduser("~"))
    for pattern in (
        # "<home>/Dropbox/01-lit", "<home>/<Org> Dropbox/<Member>/01-lit", and the macOS
        # CloudStorage mounts of both. A `*` stands where a name used to be spelled out.
        os.path.join(home, "*Dropbox*", "01-lit"),
        os.path.join(home, "*Dropbox*", "*", "01-lit"),
        os.path.join(home, "Library", "CloudStorage", "Dropbox*", "01-lit"),
        os.path.join(home, "Library", "CloudStorage", "Dropbox*", "*", "01-lit"),
    ):
        for lit in sorted(glob.glob(pattern)):
            if os.path.isdir(lit):
                return os.path.realpath(lit)
    return None


def cache_dir():
    """Where fetched papers are cached.

    Beside the curated library (`<lit>/_autofetch/`), NOT /tmp: /tmp is ephemeral and
    machine-local, so the cache dies at session end and the same paper gets pulled again by
    a later session or another machine. A synced library dir (Dropbox, a network share)
    keeps a paper fetched once available everywhere.

    Sits BESIDE the curated library, never in it: these are machine-fetched copies with
    hashed names, and mixing them into a hand-organized library would wreck it. Promote the
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


def autoflag_off(cli_off=False):
    """Is AUTOMATIC flagging to _NEEDED.md switched off for this run?

    On by default, and it should stay on: the want-list is how a reviewer that cannot reach
    a paper asks a human for it. But a run that is not working FOR the library's owner — a
    private test, a cost measurement, a review of someone else's paper — has no business
    writing that owner's to-do list, and before this switch it could not avoid it: every
    refused or failed fetch appended a line, whatever the caller intended. (2026-11-03: a
    cost-assessment run told "do not use --need" still added a request for a paper the
    library already held.) `--no-flag` or MURDERBOARD_NO_FLAG=1 turns the automatic append
    off; an explicit `--need` is a deliberate act and still writes.
    """
    return cli_off or os.environ.get("MURDERBOARD_NO_FLAG", "").strip() not in ("", "0")


def auto_flag(url, reason, off):
    """Flag a URL we could not fetch, unless auto-flagging is off. Returns the line to print."""
    if off:
        return "NOT FLAGGED (auto-flagging is off for this run)."
    path = flag_needed(url, url=url, reason=reason)
    return "FLAGGED -> %s" % (path or "(library not found; nothing written)")


# A challenge page is a successful HTTP response whose body is not the document. PMC serves a
# Google reCAPTCHA to automated clients after a few requests; Cloudflare-fronted hosts serve
# "Just a moment...". Saved as-is, one of these becomes a cache entry that answers every later
# request for that URL with ~165 characters of nothing — and the run reports it as fetched.
_BOT_CHECK = re.compile(
    r"g-recaptcha|recaptcha/api|hcaptcha\.com|cf-challenge|challenge-platform|"
    r"checking your browser|verify (that )?you are (a )?human|are you a robot|"
    r"<title>\s*just a moment",
    re.I)


def looks_like_bot_check(raw, is_pdf, text):
    """Is this response a bot-check / captcha page rather than the paper?

    Two conditions, both required, so a real paper that merely DISCUSSES captchas is safe:
    a challenge marker in the markup, and almost no readable text. A genuine article page or
    full-text XML runs to tens of thousands of characters; the PMC challenge page extracts to
    a few hundred. See tests/fetch_paper_fetch_errors_test.py.
    """
    if is_pdf or len(text or "") > 5000:
        return False
    return bool(_BOT_CHECK.search(raw[:200000].decode("utf-8", "ignore")))


def classify_fetch_error(e):
    """Sort a fetch exception into what a human should do about it: (kind, detail).

      denied     401/402/403/451 — the host refused access. A human with a library login can
                 usually get it, so it belongs on the want-list.
      transient  429, any 5xx, a timeout or a connection failure — try again later or by
                 another route. NOT flagged: Europe PMC answers fullTextXML for many NIH
                 author manuscripts with HTTP 500, and flagging those filled the want-list
                 with papers that were one retry, or one other URL, away.
      missing    404/410 and other 4xx — this URL is wrong, which is not a paper a human
                 needs to fetch. Not flagged; `--need` the citation if no route works.
    """
    import socket
    import urllib.error
    if isinstance(e, urllib.error.HTTPError):
        c = e.code
        if c in (401, 402, 403, 451):
            return "denied", "HTTP %d" % c
        if c == 429 or c >= 500:
            return "transient", "HTTP %d" % c
        return "missing", "HTTP %d" % c
    if isinstance(e, (socket.timeout, TimeoutError, ConnectionError)):
        return "transient", type(e).__name__
    if isinstance(e, urllib.error.URLError):
        return "transient", "URLError: %s" % getattr(e, "reason", e)
    return "transient", type(e).__name__


def _pdf_head_text(path, pages=2):
    """The first pages of a PDF as text, for --have. Empty if no extractor is available."""
    try:
        from pypdf import PdfReader
        r = PdfReader(path)
        return "\n".join((r.pages[i].extract_text() or "") for i in range(min(pages, len(r.pages))))
    except Exception:
        pass
    import subprocess
    try:
        out = subprocess.run(["pdftotext", "-f", "1", "-l", str(pages), path, "-"],
                             capture_output=True, text=True, encoding="utf-8",
                             errors="replace", timeout=60)
        if out.returncode == 0:
            return out.stdout
    except Exception:
        pass
    return ""


# macOS marks a file whose bytes live only in the cloud (Dropbox / iCloud "online-only") with
# SF_DATALESS. Reading such a file DOWNLOADS it. A search must never do that: on the library
# this was written against, 104 of 274 PDFs were online-only, and the first version of the
# content index pulled them down one by one inside what was supposed to be a lookup.
_SF_DATALESS = 0x40000000


def _online_only(st):
    return sys.platform == "darwin" and bool(getattr(st, "st_flags", 0) & _SF_DATALESS)


def _norm(s):
    s = re.sub(r"-\s*\n\s*", "", (s or "").lower())       # rejoin words hyphenated at a line end
    return re.sub(r"\s+", " ", s)


def have_search(keywords):
    """List curated-library PDFs that match ALL keywords (case-insensitive), by filename OR by
    the text of their first two pages. Excludes the _autofetch cache — scratch, not library.

    WHY THE CONTENTS TOO. Filename-only matching misses every PDF saved under the name the
    publisher gave it — "Received 18 Mar 2016 _ Accepted 9 Jun 2016 _ Published 19 Jul
    2016.pdf", "elife-16246-v1 (1).pdf" — and a miss here is not harmless: the caller is told
    it is "safe to fetch", fetches a worse copy or none, and reviews the paper from an
    abstract while the full text sits in the library. (2026-11-03: a reviewer checked MLspike
    against its abstract because `--have deneux` could not see the library's copy.)

    Online-only files (macOS SF_DATALESS: Dropbox / iCloud placeholders) are matched by
    filename only and never read, because reading one downloads it; the output says how many.

    The first pages are extracted once per file and kept in `<cache>/_have_index.json`, keyed
    by size and mtime. Each query spends at most MURDERBOARD_HAVE_BUDGET seconds (default 15)
    extracting new files and reports how many it has not reached yet, so a large library is
    indexed over several queries instead of stalling one. That index lives in the machine
    cache this tool owns, never in the library itself.
    """
    lit = _lit_root()
    print("=" * 78)
    if not lit:
        print("LIBRARY NOT FOUND: set $MURDERBOARD_LIT to your literature library directory.")
        return 3
    kw = [k.lower() for k in keywords]
    ipath = os.path.join(cache_dir(), "_have_index.json")
    try:
        with open(ipath) as f:
            hidx = json.load(f)
    except Exception:
        hidx = {}
    pdfs = []
    for root, dirs, files in os.walk(lit):
        dirs[:] = [d for d in dirs if d != "_autofetch"]   # skip the machine cache
        for fn in files:
            if fn.lower().endswith(".pdf"):
                pdfs.append(os.path.join(root, fn))
    stale, online_only = [], 0
    for full in pdfs:
        try:
            st = os.stat(full)
        except OSError:
            continue
        rel = os.path.relpath(full, lit)
        e = hidx.get(rel)
        if e and e.get("sig") == [st.st_size, int(st.st_mtime)]:
            continue
        if _online_only(st):          # never download a file just to search it
            online_only += 1
            continue
        stale.append((rel, full, st))
    # A TIME BUDGET, not "index everything now". Extracting a few hundred PDFs takes minutes,
    # and on a synced drive with online-only files each read can force a download — neither
    # is acceptable inside a lookup an agent runs before every fetch. So each query indexes
    # what it can in the budget, saves it, and says how much of the library it could not yet
    # read; the next query continues where this one stopped.
    budget = float(os.environ.get("MURDERBOARD_HAVE_BUDGET", "15") or 0)
    unindexed = 0
    if stale:
        t0 = time.time()
        done = 0
        for rel, full, st in stale:
            if time.time() - t0 > budget:
                break
            hidx[rel] = {"sig": [st.st_size, int(st.st_mtime)],
                         "head": _norm(_pdf_head_text(full))[:6000]}
            done += 1
        unindexed = len(stale) - done
        try:
            tmp = ipath + ".tmp"
            with open(tmp, "w") as f:
                json.dump(hidx, f)
            os.replace(tmp, ipath)
        except OSError:
            pass
    name_hits, text_hits = [], []
    for full in pdfs:
        rel = os.path.relpath(full, lit)
        fn = os.path.basename(full).lower()
        try:
            sz = os.path.getsize(full)
        except OSError:
            continue
        if all(k in fn for k in kw):
            name_hits.append((rel, sz))
        elif all(k in fn or k in (hidx.get(rel) or {}).get("head", "") for k in kw):
            text_hits.append((rel, sz))
    print("curated library: %s   query: %s" % (lit, " ".join(kw)))
    if online_only:
        print("NOTE: %d of %d PDFs are online-only (stored in the cloud, not on this disk), so "
              "only their FILENAMES were searched — reading them would download them. Make "
              "them available offline to have their contents searched too."
              % (online_only, len(pdfs)))
    if unindexed:
        print("NOTE: %d of %d PDFs are not yet content-indexed, so only their FILENAMES were "
              "searched. Each --have indexes more (budget %ss, MURDERBOARD_HAVE_BUDGET); "
              "repeat the query before concluding the library lacks a paper."
              % (unindexed, len(pdfs), budget))
    if not name_hits and not text_hits:
        if unindexed:
            print("NO MATCH YET — but the search was incomplete (see NOTE). Not yet safe to "
                  "conclude the paper is missing.")
            return 1
        print("NO MATCH in the curated library — safe to fetch (then --promote if it's a keeper).")
        return 1
    print("ALREADY HAVE %d — Read these, do NOT download:" % (len(name_hits) + len(text_hits)))
    for rel, sz in sorted(name_hits):
        print("  %s   (%.1f MB)" % (rel, sz / 1e6))
    for rel, sz in sorted(text_hits):
        print("  %s   (%.1f MB)   [matched on its first pages, not its filename — "
              "check it IS the paper, not one citing it]" % (rel, sz / 1e6))
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


def looks_like_pdf(ctype, raw, url):
    """Is this response a PDF? Three independent signals, any of which suffices.

    The declared content-type is the WEAKEST of the three, and it is the one a
    reader is tempted to trust: Zenodo — where ReScience C and JOSS live — serves
    PDFs as `application/octet-stream`, so trusting the header alone would file
    every one of those as `.txt` and hand the raw bytes to the HTML text
    extractor. The magic-bytes sniff is what actually saves that case.

    Named and tested rather than inlined, because the failure is silent: the
    fetch still "succeeds", the cache still fills, and what is wrong is only the
    extracted text. See tests/fetch_paper_pdf_detect_test.py.
    """
    return ("pdf" in (ctype or "").lower()
            or raw[:5] == b"%PDF-"
            or (url or "").lower().endswith(".pdf"))


def pdf_to_text(path):
    try:
        from pypdf import PdfReader
        return "\n".join((pg.extract_text() or "") for pg in PdfReader(path).pages)
    except Exception:
        pass
    import subprocess
    try:
        # `pdftotext` emits UTF-8; `text=True` alone would decode it with the machine's
        # LOCALE codec (cp1252 on a default Windows install), turning every em-dash, curly
        # quote and accented author name into mojibake. Worse than in murderboard_revendor,
        # because the `except` below swallows a decode error and returns "" — a paper that
        # extracts fine on macOS yields NO TEXT AT ALL on Windows, and the caller sees an
        # empty PDF rather than a failure. `errors="replace"` for the same reason: one bad
        # byte should cost a character, not the whole paper.
        out = subprocess.run(["pdftotext", path, "-"], capture_output=True, text=True,
                             encoding="utf-8", errors="replace", timeout=120)
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
    ap.add_argument("--no-flag", action="store_true",
                    help="do not auto-append failed/refused fetches to <lit>/_NEEDED.md "
                         "(also: MURDERBOARD_NO_FLAG=1). For runs that are not working for "
                         "the library's owner. An explicit --need still writes.")
    a = ap.parse_args()
    noflag = autoflag_off(a.no_flag)

    idx = load_index()

    if a.have:
        return have_search(a.have)

    if a.promote:
        # A bare filename after --promote lands in `urls` and is silently dropped: the
        # paper is then filed under the cached title, which is not what the operator
        # typed and not what --have will be searched for later. Three places in this file
        # taught that form. Refuse it loudly instead of guessing.
        if a.urls:
            ap.error("--promote takes one reference; give the filename with --name.\n"
                     "  did you mean:  --promote %s --name %s"
                     % (a.promote, json.dumps(a.urls[0])))
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
                cached_raw = open(path, "rb").read()
                is_pdf_hit = path.endswith(".pdf")
                text = pdf_to_text(path) if is_pdf_hit else html_to_text(cached_raw)
                if looks_like_bot_check(cached_raw, is_pdf_hit, text):
                    # Written by an earlier version that cached challenge pages as papers.
                    # The file is ours (it is in our index, in our cache), so discard it and
                    # treat this as a miss rather than serve the captcha again.
                    print("CACHED COPY IS A BOT-CHECK PAGE, not the paper — discarding it.")
                    idx.pop(url, None)
                    save_index(idx)
                    try:
                        os.remove(path)
                    except OSError:
                        pass
                    hit = None
            if hit and os.path.exists(path):
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
            msg = auto_flag(url, "paywalled / non-OA host %s" % h, noflag)
            print("REFUSED: host %r is not on the open-access allowlist.\n"
                  "Allowed: %s\n"
                  "%s\n"
                  "Check --have first: the library may already hold this paper. "
                  "Or use the OA copy (PMC/EuropePMC/arXiv/bioRxiv) if one exists." %
                  (h, ", ".join(sorted(ALLOWED_HOSTS)), msg))
            rc = 2
            continue
        try:
            raw, ctype = fetch(url)
        except Exception as e:
            kind, detail = classify_fetch_error(e)
            if kind == "denied":
                print("ACCESS DENIED (%s): %s\n%s" % (detail, e, auto_flag(
                    url, "access denied: %s" % detail, noflag)))
            elif kind == "transient":
                print("FETCH FAILED, PROBABLY TEMPORARY (%s): %s\n"
                      "Not flagged — retry later, or try another route to the same paper "
                      "(e.g. Europe PMC vs PMC). If none works, --need the citation." % (detail, e))
            else:
                print("NOT FOUND AT THIS URL (%s): %s\n"
                      "Not flagged — the URL is wrong, which a human cannot fix by fetching. "
                      "Find the right URL, or --need the citation." % (detail, e))
            rc = 1
            continue

        name = hashlib.sha1(url.encode()).hexdigest()[:12]
        is_pdf = looks_like_pdf(ctype, raw, url)
        text_pre = "" if is_pdf else html_to_text(raw)
        if looks_like_bot_check(raw, is_pdf, text_pre):
            # Do NOT cache it and do NOT try to get past it: a challenge page is the host
            # saying no to automation. Report it as what it is.
            print("BOT CHECK: %s answered with a captcha / challenge page, not the paper.\n"
                  "Not cached. Do not try to get around it — use another route (Europe PMC "
                  "fullTextXML, the publisher's OA copy) or ask a human.\n%s"
                  % (h, auto_flag(url, "bot check at %s" % h, noflag)))
            rc = 1
            continue
        path = os.path.join(cache_dir(), name + (".pdf" if is_pdf else ".txt"))
        with open(path, "wb") as f:
            f.write(raw)

        text = pdf_to_text(path) if is_pdf else text_pre

        # Record it so the NEXT session (or the other machine) does not re-download.
        # Queries are not documents — their results change, so they are never cached.
        if not is_query:
            idx[url] = {"path": path, "fetched": time.strftime("%Y-%m-%dT%H:%M:%S"),
                        "title": guess_title(text, is_pdf), "content_type": ctype,
                        "bytes": len(raw)}
            save_index(idx)

        print("content-type: %s | %d bytes | saved: %s" % (ctype, len(raw), path))
        if is_pdf and not is_query:
            print("(keeper? promote it: fetch_paper.py --promote %s --name \"Author Year title.pdf\")" % url)
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
