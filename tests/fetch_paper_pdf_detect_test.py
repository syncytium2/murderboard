#!/usr/bin/env python3
"""Pin PDF detection, because getting it wrong fails SILENTLY.

Zenodo — where ReScience C publishes and JOSS archives — serves PDFs as
`application/octet-stream`. If `looks_like_pdf()` ever regresses to trusting the
declared content-type, nothing raises: the fetch succeeds, the byte count is
right, the cache fills, the file is merely saved as `.txt` and run through the
HTML text extractor instead of the PDF one. What the agent then reads is not the
paper. That is the exact defect class this repo exists to catch, so it gets a
test rather than a comment.

No network. The three signals are checked as a pure function on literal inputs,
which is the whole reason `looks_like_pdf()` was pulled out of the fetch loop.
"""
import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TARGET = ROOT / "fetch_paper.py"

PDF = b"%PDF-1.7\n%\xe2\xe3\xcf\xd3\n"
HTML = b"<!doctype html><html><body>not a paper</body></html>"

# (name, ctype, raw, url, expected)
CASES = [
    # The case this exists for: Zenodo's mimetype is a lie, the bytes are not.
    ("zenodo octet-stream + PDF bytes",
     "application/octet-stream", PDF, "https://zenodo.org/records/1/files/article", True),
    # An honest publisher.
    ("declared application/pdf",
     "application/pdf", PDF, "https://arxiv.org/pdf/2401.00001", True),
    # Header alone, bytes unavailable (streamed/truncated read).
    ("declared pdf, no bytes yet",
     "application/pdf", b"", "https://example.org/x", True),
    # URL alone — some hosts declare nothing useful at all.
    ("bare .pdf url, no ctype",
     "", b"", "https://www.biorxiv.org/content/10.1101/2024.01.01.000001v1.full.pdf", True),
    ("uppercase .PDF url",
     "", b"", "https://zenodo.org/records/1/files/ARTICLE.PDF", True),
    # Landing pages must NOT be taken for papers, or they get parsed as PDFs.
    ("html landing page",
     "text/html; charset=utf-8", HTML, "https://zenodo.org/records/1", False),
    ("json api response",
     "application/json", b'{"ok": true}', "https://europepmc.org/api/x", False),
    # Missing/absent header must not crash — fetch() defaults it to "".
    ("no content-type at all, html bytes",
     "", HTML, "https://example.org/page", False),
    ("None content-type, pdf bytes",
     None, PDF, "https://zenodo.org/records/1/files/a", True),
]


def main():
    spec = importlib.util.spec_from_file_location("fetch_paper", TARGET)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)

    failed = 0
    for name, ctype, raw, url, expected in CASES:
        got = bool(mod.looks_like_pdf(ctype, raw, url))
        if got is expected:
            print("ok   %s" % name)
        else:
            print("FAIL %s -> expected %s, got %s" % (name, expected, got), file=sys.stderr)
            failed += 1

    # Zenodo must still be reachable at all -- the detection above is moot if the
    # host gate refuses the fetch before a single byte arrives.
    ok, host = mod.host_allowed("https://zenodo.org/records/1/files/a.pdf")
    if ok:
        print("ok   zenodo.org passes the host allowlist")
    else:
        print("FAIL zenodo.org is not allowlisted (host=%r)" % host, file=sys.stderr)
        failed += 1

    # And the gate must still be able to REFUSE, or allowlisting Zenodo quietly
    # disabled the check instead of extending it.
    ok, host = mod.host_allowed("https://www.sciencedirect.com/science/article/pii/X")
    if not ok:
        print("ok   a non-allowlisted host is still refused")
    else:
        print("FAIL the allowlist accepted %r -- the gate can no longer fire" % host, file=sys.stderr)
        failed += 1

    # The subdomain rule, since the comment above ALLOWED_HOSTS makes a security
    # claim about it and nothing was checking that claim.
    ok, _ = mod.host_allowed("https://zenodo.org.attacker.example/records/1")
    if not ok:
        print("ok   suffix-spoofed host is refused")
    else:
        print("FAIL 'zenodo.org.attacker.example' was accepted", file=sys.stderr)
        failed += 1

    print("\n%d case(s) failed" % failed if failed else "\nall pdf-detection cases pass")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
