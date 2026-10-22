> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 2 MISMATCH — missing Grep, Glob; holds Edit, Write, Agent, Artifact, Skill, and NotebookEdit (deferred, loadable on demand). My granted tools Read, Bash, WebFetch and WebSearch are present; I loaded WebFetch and the PubMed tools on demand. I edited, wrote and deleted nothing.

1. `10.1016/j.jnutbio.2017.08.013` — FOUND "[title replaced by its key: 8158b24485a47382]". PMID 29032081, from a PubMed search on the DOI. doi.org returned HTTP 302 to linkinghub.elsevier.com/retrieve/pii/S0955286316307458, and the Crossref API returned 200 with the same title.

2. `10.1000/7652153ccbdc` — NOT FOUND. doi.org returned HTTP 404, the Crossref API returned HTTP 404 ("Resource not found."), and a PubMed search on the DOI returned 0 hits. Three independent routes all missed, so this is a real non-resolution and not just a gap in one route's coverage.

3. `created.date-time` = `2017-09-04T03:45:43Z`, taken from the page as fetched by WebFetch. The curl fetch of the same Crossref URL agreed.

Routes used: doi.org resolver (curl, HTTP status and redirect); Crossref REST API api.crossref.org/works (curl and WebFetch); PubMed through the bio-research PubMed connector (search_articles with a DOI query). A direct NCBI E-utilities esearch call by curl came back non-JSON and I did not count it. I used no search engine.
