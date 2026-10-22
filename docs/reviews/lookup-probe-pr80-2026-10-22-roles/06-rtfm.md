> **Redacted for a public repository.** Local paths were replaced mechanically: `<worktree>`, `<scratch>`, `<session transcript>`, `<consumer repo>`, `<home>`, `<consumer machine>`. Everything else is verbatim. The unredacted original is kept outside the repository.

GRANT 6 MISMATCH — missing Grep, Glob; holds no forbidden tools (I have Read, Bash, WebSearch, WebFetch, plus the SubagentHandback harness tool)

This mismatch does not affect the check: I grepped through Bash. It still belongs in the run record's `roles:` line as a fallback-path grant.

**Summary:** both selftests pass under macOS `/bin/bash` 3.2.57 (roster 72/0, subagents 19/0), and every factual claim about DOI and NCBI behavior checks out live. But the probe can be passed by a model answering from memory or from search snippets, and the probe does not test what role 6 needs. The `--lookup` scanner raises false blockers on scoped rules and stays silent on several real ones. I edited nothing in the repo; scratch files are in <scratch>/mb/scratch/role-6/

## Findings (location · issue · severity · suggested fix · verified against a source?)

1. **skills/murderboard/SKILL.md, the lookup probe prompt**
   - **Issue:** a model with no route at all can pass the probe from memory.
     - The known DOI is arguably the most-cited paper of its kind, and its title is in any model's training data.
     - The made-up DOI's suffix literally reads `murderboard-probe-0000`, so NOT FOUND can be guessed.
     - That is exactly the "reasoning from memory" failure the process forbids. The required "route" line is self-reported.
     - A WebSearch-only agent passes the same way, via a title snippet and "no results". That is the 2026-09-15 snippet case the appendix itself records, and it does not resolve the identifier.
   - **Severity:** high
   - **Fix:** require a datum only live resolution yields, and vary the inputs.
     - Ask for the doi.org redirect target (I got `https://dx.plos.org/10.1371/journal.pmed.0020124`, HTTP 302) or the handle API `responseCode` (1 vs 100).
     - Draw the real DOI from a small rotating set of unremarkable papers.
     - Generate the fake suffix at random per run, e.g. `10.1000/<random hex>`, with no word "probe" in it.
   - **Verified:** yes for the resolver outputs (live curl, 2026-10-22). The memory risk is reasoning, not a test.

2. **SKILL.md ("Roles 2 and 6 share a grant… so one probe answers for both") and doc_review_process.md ("for roles 2 and 6… reading a documentation page")**
   - **Issue:** the probe only tests DOI resolution.
     - A run whose passing route is a PubMed or bioRxiv connector passes the probe and is recorded `Lookup: live`.
     - But such a connector cannot read tool or API documentation, which is role 6's source.
     - The appendix's own 2026-09-15 case was a deliverable whose sources were documentation pages.
     - Sharing a grant is not the same as sharing a route.
   - **Severity:** medium-high
   - **Fix:** add a second half for role 6: fetch one known documentation URL and return a quoted line that cannot be guessed. Otherwise state that a connector-only `live` covers role 2 and not role 6.
   - **Verified:** yes. Rows 2 and 6 in doc_review_process.md (lines 969 and 973) are identical, and the probe text names only DOIs.

3. **murderboard_subagents.sh `--lookup`: the regex `^(webfetch|websearch)\b|^bash\(\s*(curl|wget)\b` (false positives)**
   - **Issue:** it raises BLOCK on rules that do not block the lookup. Tested in scratch:
     - `WebFetch(domain:facebook.com)` → BLOCK, exit 1. Per the docs, a scoped WebFetch deny blocks only that domain.
     - `Bash(curl -X POST *)` → BLOCK, exit 1. That rule blocks only POSTs.
     - A bare `WebSearch` deny → BLOCK ("role 2 may not be able to resolve a citation"). WebSearch is not a resolution route, and finding 1 argues it should not count as one.
     - The selftest only asserts the `domain:doi.org` case, so this over-breadth is untested.
   - **Severity:** medium. It trains people to ignore the scan, which the script's own comments warn about.
   - **Fix:** use BLOCK only for:
     - bare `WebFetch` or `WebFetch(domain:*)`;
     - a `domain:` deny covering a resolver host (doi.org, dx.doi.org, api.crossref.org, *.ncbi.nlm.nih.gov, plus publisher hosts if wanted);
     - bare `Bash(curl…)`, `Bash(curl *)` or `Bash(curl:*)`.

     Downgrade other scoped rules and WebSearch to WARN, and add selftests for an unrelated domain and an argument-scoped curl.
   - **Verified:** yes, against https://code.claude.com/docs/en/permissions ("`WebFetch(domain:example.com)` matches requests to `example.com` only"; scoped rules "leave the tool available and block matching calls").

4. **murderboard_subagents.sh `--lookup` (false negatives)**
   - **Issue:** it exits 0 with "no lookup blocker found" on documented blockers. Tested:
     - deny `"*"`: per the docs, this glob removes every tool, WebFetch included.
     - deny `"Web*"`: a glob in the tool-name position, which deny rules accept.
     - `permissions.defaultMode: "dontAsk"` with no WebFetch or curl allow: WebFetch needs approval by default outside the preapproved documentation domains, and dontAsk "auto-denies every call that would otherwise prompt".
     - `sandbox.network.deniedDomains: ["doi.org"]`: blocks sandboxed curl.
     - `Bash(/usr/bin/curl *)`.
     - `PowerShell(Invoke-WebRequest *)`: PowerShell rules canonicalize aliases, and `curl` is one on Windows.
     - deny `mcp__*`: removes the connector route.
   - **Severity:** medium. The caveat already says a clean scan is not proof, but dontAsk and the sandbox are file-recorded and readable.
   - **Fix:**
     - Match tool-name globs with fnmatch against "WebFetch".
     - Read `permissions.defaultMode == "dontAsk"` and BLOCK unless an allow rule covers WebFetch, a resolver domain, or curl.
     - Read `sandbox.network.deniedDomains` and `allowedDomains` for resolver hosts.
     - Optionally WARN on `mcp__*`.
   - **Verified:** yes. permissions page sections "Deny and ask rules also accept glob patterns in the tool-name position… `"*"` matches every tool", the dontAsk mode row, and "How permissions interact with sandboxing"; the settings reference for `sandbox.network.deniedDomains`.

5. **murderboard_subagents.sh, the allow-list comment and lookup exemption**
   - **Issue:** the new lookup exemption is correct, but for the wrong stated reason ("a literature connector is a third route").
     - Per the docs, `permissions.allow` only pre-approves ("let Claude Code use the specified tool without manual approval"). It does not exclude unlisted tools.
     - An allow list becomes restrictive only in effect, under `dontAsk`.
     - So the pre-existing subagent-mode BLOCK "an allow-list… that does not include Task", and its comment "naming any tool excludes the rest", contradict the docs.
     - The PR keeps that premise and adds a second justification beside it.
   - **Severity:** low-medium (the false premise is in pre-existing code, but this PR reasons from it).
   - **Fix:** restate the exemption as "allow does not restrict outside dontAsk", and file the subagent-mode BLOCK as a separate defect. Its correct condition is dontAsk plus an allow list without Agent or Task.
   - **Verified:** yes, against the permissions page "Manage permissions" and the dontAsk row.

6. **murderboard_subagents.sh scan_json: reads `allowedTools` and `disallowedTools` as settings.json keys**
   - **Issue:** the settings reference lists these only as CLI flags (`--allowedTools`, `--disallowedTools`), not as settings keys. The surface is harmless but probably dead.
   - **Severity:** low (pre-existing; the lookup mode inherits it).
   - **Fix:** note in the comment that these are CLI or SDK options a file normally won't carry, or drop them.
   - **Verified:** partly. I read only the first 100k characters of https://code.claude.com/docs/en/settings-reference, and they show no such key.

7. **doc_review_process.md ("Claude Code's subagent `tools:` field takes a whole-server entry, `mcp__<server>__*`")**
   - **Issue:** the claim is correct, and so is the premise that an explicit list excludes MCP tools. Two naming forms consumers will actually hit are missing:
     - plugin servers: `mcp__plugin_<plugin>_<server>__*`;
     - claude.ai connectors: `mcp__claude_ai_<server>__*`.

     The PubMed and bioRxiv routes in issue #74 look like plugin or claude.ai connectors. In this session the bioRxiv server is `plugin:bio-research:biorxiv`.
   - **Severity:** low
   - **Fix:** add both forms in one clause.
   - **Verified:** yes. https://code.claude.com/docs/en/sub-agents says of its read-only example "The subagent can't edit files, write files, or use any MCP tools" and gives `mcp__github__*` in `tools`. The permissions page "MCP" section gives the plugin and claude_ai forms.

8. **murderboard_roster.sh `lookup_line`: first-match-wins over the whole report, fences included**
   - **Issue:** a report that quotes an example `Lookup:` line before its real one is parsed on the example.
     - Tested: a fenced `Lookup: unavailable — example` followed by a real `Lookup: live` → `unavailable`.
     - The reverse case lets a quoted `live` mask a real `unavailable`.
     - The skill's own template line, `Lookup: live | not needed   # from step 4a's probe`, parses as unrecognized if pasted verbatim. That fails closed, which is fine.
   - **Severity:** low (Execution: has the same design)
   - **Fix:** skip fenced blocks, or require the line inside the run-record block.
   - **Verified:** yes, by test.

9. **SKILL.md probe text: "The second sits under `10.1000`, the DOI Foundation's own prefix… `doi.org` answers it with a 404"**
   - **Issue:** none; this is correct.
     - The handle API returns `{"responseCode":100}` with HTTP 404 for `10.1000/murderboard-probe-0000`, and proxy GET returns 404.
     - The DOI resolution documentation says "100 : Handle Not Found. (HTTP 404 Not Found)".
     - 10.1000 is the IDF's prefix: `0.NA/10.1000` exists, and 10.1000/182 is the DOI Handbook.
     - CSL-JSON content negotiation and Crossref `/works/` each give 200 with the exact title "Why Most Published Research Findings Are False" for the real DOI, and 404 for the fake one. Either is a sound FOUND-with-title check.
   - **Caveat:** a 404 means "not registered with the DOI system", and it can't be told apart from a route error unless the agent reports the status code. The FOUND half is what discriminates, which is why the pair matters. Finding 1 is about making that half unguessable.
   - **Severity:** none
   - **Verified:** yes.

10. **doc_review_process.md and agents/02-doi-or-die.md: the NCBI ID converter example**
    - **Issue:** none; this is correct, verified live 2026-10-22.
      - The idconv API (v1.0 now 301-redirects to `pmc.ncbi.nlm.nih.gov/tools/idconv/api/v1/articles/`) returns `"errmsg":"Identifier not found in PMC"` for `10.1210/endocr/bqad150`.
      - PubMed esummary for PMID 37793082 gives "Fasting Modulates GABAergic Synaptic Transmission to Arcuate Kisspeptin Neurons in Female Mice", Endocrinology, 2023 Sep 23, DOI matches, no PMC id. Crossref agrees.
      - NCBI's documentation says: "The PMC ID Converter API will only return related IDs if the article is in PubMed Central (PMC)."
    - **Optional wording:** "searches PubMed Central only" could become "returns IDs only for articles in PMC", which matches the documentation's own sentence.
    - **Severity:** none
    - **Verified:** yes.

11. **Shell portability (murderboard_roster.sh and murderboard_subagents.sh, new code)**
    - **Issue:** no portability defect found.
      - Both selftests pass under `/bin/bash` 3.2.57.
      - `token_head` gives identical results under `LC_ALL=C` and `en_US.UTF-8`: em-dash, en-dash and bold forms work, case is folded by `tr`.
      - `grep -iE` with `[[:space:]]` brackets and `sed` with a `]`-first bracket class are both POSIX and work on BSD and GNU.
      - `printf "${L}…"` in the selftests uses fixed strings with no `%`, so it is safe. It would break if a future test string contained `%`; `printf '%b…'` or `printf '%s\n'` would be more robust.
      - `Lookup: live (WebFetch)` and `Lookup: live; …` are refused as unrecognized. That is consistent with the strict-token design, but worth one line in the skill: only a dash or colon ends the token.
    - **Severity:** low (advice only)
    - **Verified:** yes, by test.

## What I checked
- **Docs read:**
  - https://code.claude.com/docs/en/permissions: rule syntax, `:*` vs space-`*`, deny/ask/allow order, glob denies, WebFetch domain rules, MCP naming, dontAsk, sandbox interaction, Bash rule limits.
  - https://code.claude.com/docs/en/sub-agents: `tools` and `disallowedTools`, MCP wildcards, background filter keeps WebFetch.
  - https://code.claude.com/docs/en/settings and https://code.claude.com/docs/en/settings-reference (partial).
  - https://pmc.ncbi.nlm.nih.gov/tools/id-converter-api/
  - https://www.doi.org/the-identifier/resources/factsheets/doi-resolution-documentation
  - DOI Handbook: https://doi.org/10.1000/182
- **Live resolution:** doi.org, the handle API, CSL content negotiation, Crossref, NCBI idconv and PubMed esummary.
- **Scanner:** 12 settings shapes run against `--lookup`.
- **Parser:** 5 report shapes under 2 locales.

Sources:
- [Claude Code permissions](https://code.claude.com/docs/en/permissions)
- [Claude Code subagents](https://code.claude.com/docs/en/sub-agents)
- [Claude Code settings](https://code.claude.com/docs/en/settings)
- [Claude Code settings reference](https://code.claude.com/docs/en/settings-reference)
- [PMC ID Converter API](https://pmc.ncbi.nlm.nih.gov/tools/id-converter-api/)
- [DOI resolution documentation](https://www.doi.org/the-identifier/resources/factsheets/doi-resolution-documentation)
- [DOI Handbook](https://doi.org/10.1000/182)
- [Digital object identifier (Wikipedia)](https://en.wikipedia.org/wiki/Digital_object_identifier)
