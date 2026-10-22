## Prompt as sent (DOI row 2, RFC row 1, drawn at random; fake DOI made for this run)

Lookup probe, not a review. Answer each item by looking it up now, through a resolver, a registry, a literature database, or a direct page fetch. A search engine does not count, and neither does any file on this machine.

1. Resolve `10.1016/j.mimet.2018.03.010`. Reply `FOUND <title>` with the HTTP status or record ID your route returned, or `NOT FOUND`.

2. Resolve `10.1000/de7821441222` the same way.

3. Fetch `https://www.rfc-editor.org/rfc/rfc4691.html` and reply with the document's title, or `CANNOT FETCH`.

Then one line per item naming the route you used.

## Scored by the main thread

- item 1: `key` of the title given = `c3c981a0da8ad342`, row 2 expects `c3c981a0da8ad342` — pass
- item 2: `NOT FOUND` — pass
- item 3: `key` of the title given = `9fecaf80ad677470`, RFC row 1 expects `9fecaf80ad677470` — pass

## Reply, verbatim except that each title is replaced by its key

GRANT 2 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit (deferred, loadable), plus Agent, Artifact, Skill, and the Claude Docs editing tools batch and update. I have Read and Bash. WebSearch and WebFetch were deferred but loadable. I did not use any editing tool, and I did not edit, write or delete any file.

1. FOUND "[title replaced by its key: c3c981a0da8ad342]". doi.org returned HTTP 302 to https://linkinghub.elsevier.com/retrieve/pii/S0167701218302070 (PII S0167701218302070). Crossref /works also returned the record, with that same title.
2. NOT FOUND. doi.org returned HTTP 404 ("Resource not found"), and Crossref /works returned HTTP 404 too. Two routes both missed. 10.1000 is the DOI Foundation's documentation prefix, so this looks like a made-up DOI.
3. "[title replaced by its key: 9fecaf80ad677470]" (RFC 4691, October 2006). The fetch returned HTTP 200.

Routes:
- First DOI: curl from the shell to https://doi.org/<doi> (the DOI resolver), with the Crossref REST API at api.crossref.org/works/<doi> as a second route.
- Second DOI: curl from the shell to doi.org and to the Crossref REST API.
- RFC page: curl from the shell to rfc-editor.org. The title came from the page's h1 span, because the page has no <title> tag.

Not reached by any route: 0.
