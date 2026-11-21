#!/usr/bin/env python3
"""fetch_paper.py must tell a paper from a captcha, a human's problem from a retry, and a run
working for the library's owner from one that is not.

WHY THIS FILE EXISTS. Three cost-assessment reviews on 2026-11-03 found four defects, each one
silent — the tool reported success, or wrote something, and nothing looked wrong:

  1. PMC served a Google reCAPTCHA page; it was cached as the paper ("extracted 165 chars")
     and every later request for that URL got the captcha back from the cache.
  2. Every refused or failed fetch was appended to the owner's `_NEEDED.md`, with no way to
     stop it — a run told not to use `--need` still requested a paper the library held.
  3. Europe PMC's HTTP 500 for author manuscripts was flagged like a paywall: the want-list
     filled with papers that were one retry or one other URL away.
  4. `--have` matched filenames only, so a PDF saved under its publisher's name was invisible
     and a reviewer checked a claim against an abstract while the full text sat on disk.

Offline: fetch() is replaced, temp dirs only, no network, no writes outside tempfile.
"""
import io
import json
import os
import socket
import sys
import tempfile
import urllib.error
from contextlib import redirect_stdout
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
import fetch_paper  # noqa: E402

FAILURES = []


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


CAPTCHA = (b'<html><head><title>Preparing to download ...</title>'
           b'<script src="https://www.google.com/recaptcha/api.js"></script></head>'
           b'<body><div class="g-recaptcha" data-sitekey="x"></div>'
           b'<p>Please verify you are a human.</p></body></html>')
CLOUDFLARE = b"<html><head><title>Just a moment...</title></head><body>cf-challenge</body></html>"
# A real article that happens to be ABOUT captchas: long, and mentions the markers.
ARTICLE = (b"<html><body><h1>On reCAPTCHA usability</h1>"
           + b"<p>We studied g-recaptcha widgets and whether users verify you are a human.</p>" * 200
           + b"</body></html>")


def http_error(code):
    return urllib.error.HTTPError("https://europepmc.org/x", code, "err", {}, None)


def run_main(argv, env, fetch_impl=None):
    """Run fetch_paper.main() with argv/env controlled and fetch() replaced. -> (rc, stdout)."""
    saved_env = {k: os.environ.get(k) for k in env}
    saved_argv, saved_fetch = sys.argv, fetch_paper.fetch
    try:
        for k, v in env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v
        sys.argv = ["fetch_paper.py"] + argv
        if fetch_impl:
            fetch_paper.fetch = fetch_impl
        buf = io.StringIO()
        with redirect_stdout(buf):
            rc = fetch_paper.main()
        return rc, buf.getvalue()
    finally:
        sys.argv, fetch_paper.fetch = saved_argv, saved_fetch
        for k, v in saved_env.items():
            if v is None:
                os.environ.pop(k, None)
            else:
                os.environ[k] = v


def raiser(exc):
    def f(url, timeout=60):
        raise exc
    return f


def returner(raw, ctype):
    def f(url, timeout=60):
        return raw, ctype
    return f


def needed_lines(lit):
    p = os.path.join(lit, "_NEEDED.md")
    if not os.path.exists(p):
        return []
    return [l for l in open(p, encoding="utf-8") if l.startswith("- [ ]")]


print("bot-check detection")
check("PMC reCAPTCHA page is a bot check",
      fetch_paper.looks_like_bot_check(CAPTCHA, False, fetch_paper.html_to_text(CAPTCHA)))
check("Cloudflare 'Just a moment...' is a bot check",
      fetch_paper.looks_like_bot_check(CLOUDFLARE, False, fetch_paper.html_to_text(CLOUDFLARE)))
check("a long article ABOUT captchas is not a bot check",
      not fetch_paper.looks_like_bot_check(ARTICLE, False, fetch_paper.html_to_text(ARTICLE)))
check("a PDF is never a bot check",
      not fetch_paper.looks_like_bot_check(b"%PDF-1.4 recaptcha", True, ""))

print("error classification")
for code, want in ((500, "transient"), (503, "transient"), (429, "transient"),
                   (403, "denied"), (401, "denied"), (402, "denied"), (451, "denied"),
                   (404, "missing"), (410, "missing"), (400, "missing")):
    got = fetch_paper.classify_fetch_error(http_error(code))[0]
    check("HTTP %d -> %s" % (code, want), got == want, "got %s" % got)
check("URLError -> transient",
      fetch_paper.classify_fetch_error(urllib.error.URLError("dns"))[0] == "transient")
check("timeout -> transient",
      fetch_paper.classify_fetch_error(socket.timeout("t"))[0] == "transient")

print("auto-flag switch")
saved = os.environ.pop("MURDERBOARD_NO_FLAG", None)
check("default: auto-flagging on", fetch_paper.autoflag_off() is False)
check("--no-flag turns it off", fetch_paper.autoflag_off(True) is True)
os.environ["MURDERBOARD_NO_FLAG"] = "1"
check("MURDERBOARD_NO_FLAG=1 turns it off", fetch_paper.autoflag_off() is True)
os.environ["MURDERBOARD_NO_FLAG"] = "0"
check("MURDERBOARD_NO_FLAG=0 leaves it on", fetch_paper.autoflag_off() is False)
os.environ.pop("MURDERBOARD_NO_FLAG", None)
if saved is not None:
    os.environ["MURDERBOARD_NO_FLAG"] = saved

print("end to end (offline)")
URL = "https://europepmc.org/api/fulltextRepo?pprId=1"
with tempfile.TemporaryDirectory() as td:
    lit = os.path.join(td, "lit")
    os.makedirs(lit)
    cache = os.path.join(td, "cache")
    base = {"MURDERBOARD_LIT": lit, "MURDERBOARD_PAPERS": cache, "IF2_LIT": None,
            "IF2_PAPERS": None, "MURDERBOARD_NO_FLAG": None}

    rc, out = run_main([URL], base, raiser(http_error(500)))
    check("HTTP 500 is reported as temporary", "PROBABLY TEMPORARY" in out and rc == 1)
    check("HTTP 500 is NOT flagged", needed_lines(lit) == [])

    rc, out = run_main([URL], base, raiser(http_error(404)))
    check("HTTP 404 is NOT flagged", needed_lines(lit) == [] and "NOT FOUND AT THIS URL" in out)

    rc, out = run_main([URL], dict(base, MURDERBOARD_NO_FLAG="1"), raiser(http_error(403)))
    check("HTTP 403 with MURDERBOARD_NO_FLAG=1 is NOT flagged",
          needed_lines(lit) == [] and "NOT FLAGGED" in out)

    rc, out = run_main(["--no-flag", "https://doi.org/10.1/x"], base)
    check("refused host with --no-flag is NOT flagged", needed_lines(lit) == [] and rc == 2)

    rc, out = run_main([URL], base, raiser(http_error(403)))
    check("HTTP 403 by default IS flagged", len(needed_lines(lit)) == 1, out.splitlines()[-1])

    rc, out = run_main(["--no-flag", "--need", "Smith 2020"], base)
    check("explicit --need still writes under --no-flag", len(needed_lines(lit)) == 2)

    url2 = "https://pmc.ncbi.nlm.nih.gov/articles/PMC1/"
    rc, out = run_main(["--no-flag", url2], base, returner(CAPTCHA, "text/html"))
    idx = json.load(open(os.path.join(cache, "index.json"))) if os.path.exists(
        os.path.join(cache, "index.json")) else {}
    check("captcha response is reported as a bot check", "BOT CHECK" in out and rc == 1)
    check("captcha response is NOT cached", url2 not in idx)

    # A cache entry written by the old version: a captcha stored as the paper.
    poisoned = os.path.join(cache, "poisoned.txt")
    open(poisoned, "wb").write(CAPTCHA)
    json.dump({url2: {"path": poisoned, "fetched": "2026-11-03T00:00:00", "title": ""}},
              open(os.path.join(cache, "index.json"), "w"))
    rc, out = run_main(["--no-flag", url2], base,
                       returner(b"<html><body>" + b"real text " * 2000 + b"</body></html>",
                                "text/html"))
    idx = json.load(open(os.path.join(cache, "index.json")))
    check("a poisoned cache entry is discarded and re-fetched",
          "BOT-CHECK PAGE" in out and not os.path.exists(poisoned)
          and idx.get(url2, {}).get("path") != poisoned)

print("--have searches first pages, not only filenames")
with tempfile.TemporaryDirectory() as td:
    lit = os.path.join(td, "lit")
    os.makedirs(lit)
    for fn in ("Received 18 Mar 2016 _ Accepted 9 Jun 2016.pdf", "smith 2020 pulse gen.pdf"):
        open(os.path.join(lit, fn), "wb").write(b"%PDF-1.4 stub")
    heads = {"Received 18 Mar 2016 _ Accepted 9 Jun 2016.pdf":
             "A database and inference algorithm\nThomas Deneux, Attila Kaszas, Gergely Szalay",
             "smith 2020 pulse gen.pdf": "Smith J. Pulse generator"}
    calls = []

    def fake_head(path, pages=2):
        calls.append(path)
        return heads[os.path.basename(path)]

    saved_head = fetch_paper._pdf_head_text
    fetch_paper._pdf_head_text = fake_head
    env = {"MURDERBOARD_LIT": lit, "MURDERBOARD_PAPERS": os.path.join(td, "cache"),
           "IF2_LIT": None, "IF2_PAPERS": None}
    try:
        # Out of budget before indexing anything: the search must SAY it was incomplete, and
        # must not tell the caller the paper is missing.
        rc, out = run_main(["--have", "deneux"], dict(env, MURDERBOARD_HAVE_BUDGET="-1"))
        check("an exhausted budget is reported, not hidden",
              rc == 1 and "not yet content-indexed" in out and "NO MATCH YET" in out
              and "safe to fetch" not in out)
        check("nothing was extracted with no budget", calls == [], "%d extractions" % len(calls))
        rc, out = run_main(["--have", "deneux"], env)
        check("a PDF named by its publisher is found by author", rc == 0 and "Received 18 Mar" in out)
        check("a content-only hit is labeled as one", "matched on its first pages" in out)
        rc, out = run_main(["--have", "smith", "pulse"], env)
        check("a filename hit is still a plain hit", rc == 0 and "smith 2020" in out
              and "matched on its first pages" not in out)
        check("first pages are extracted once, then read from the index", len(calls) == 2,
              "%d extractions" % len(calls))
        rc, out = run_main(["--have", "nobody"], env)
        check("no match is still reported as no match", rc == 1 and "NO MATCH" in out)
        check("the index lives in the cache, not the library",
              not os.path.exists(os.path.join(lit, "_have_index.json")))

        # An online-only (cloud placeholder) file must never be read: reading downloads it.
        open(os.path.join(lit, "cloud copy.pdf"), "wb").write(b"%PDF-1.4 stub")
        heads["cloud copy.pdf"] = "Zhang Q. Placeholder"
        saved_oo = fetch_paper._online_only
        target = os.path.join(lit, "cloud copy.pdf")
        fetch_paper._online_only = lambda st, _t=os.stat(target): (
            st.st_ino == _t.st_ino and st.st_dev == _t.st_dev)
        before = len(calls)
        try:
            rc, out = run_main(["--have", "zhang"], env)
        finally:
            fetch_paper._online_only = saved_oo
        check("an online-only PDF is not read", len(calls) == before,
              "%d new extractions" % (len(calls) - before))
        check("online-only files are reported as filename-only", "online-only" in out)
        rc, out = run_main(["--have", "cloud"], env)
        check("an online-only PDF is still found by filename", rc == 0 and "cloud copy" in out)
    finally:
        fetch_paper._pdf_head_text = saved_head

print()
if FAILURES:
    print("FAILED: %d" % len(FAILURES))
    sys.exit(1)
print("all passed")
