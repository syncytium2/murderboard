> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 2 MISMATCH — missing Grep, Glob; holds Edit, Write, NotebookEdit (deferred, loadable) — plus other tools the grant doesn't include: Agent, Artifact, Skill, ToolSearch, SubagentHandback, the Claude Docs/Dropbox/Gmail/bio-research MCP tools, and Monitor/SendMessage/EnterWorktree and others (deferred). Of the granted set, Read, Bash, WebSearch and WebFetch (deferred) are held. I edited, wrote and deleted nothing.

10.1371/journal.pmed.0020124 FOUND Why Most Published Research Findings Are False
10.1000/murderboard-probe-0000 NOT FOUND

Route: a `curl` call through Bash to two places. The first was the doi.org handle API (`https://doi.org/api/handles/<doi>`). The PLOS DOI returned HTTP 200 with responseCode 1 and pointed to dx.plos.org. The probe DOI returned HTTP 404 with responseCode 100, meaning the handle does not exist. The second was the Crossref works API (`https://api.crossref.org/works/<doi>`). It gave the title for the PLOS DOI and returned HTTP 404 "Resource not found." for the probe DOI. Both routes agree, so the NOT FOUND result is confirmed by two independent sources. The doi.org handle registry covers every registration agency, so its 404 is decisive on its own.
