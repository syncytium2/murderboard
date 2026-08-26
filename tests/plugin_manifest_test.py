#!/usr/bin/env python3
"""The plugin must actually be installable, and its parts must actually be there.

WHY THIS IS A GATE AND NOT A HABIT. Every failure below is silent on the machine of
whoever causes it, because nothing in this repo loads the plugin -- a contributor working
in the checkout uses the files directly. The manifests are only ever exercised on a
STRANGER's machine, at install time, after a push to main. That is the same shape as
docs/index.html (published straight from main, invisible locally) and it gets the same
treatment.

Four classes of failure, all observed to be possible:

  1. The manifests disagree. `/plugin install <name>@<marketplace>` resolves the name from
     marketplace.json; plugin.json names it again. A mismatch installs nothing, or installs
     under a name the docs never mention.

  2. A declared component is missing. Claude Code discovers skills/ and hooks/hooks.json by
     convention. Rename or move one and the plugin still installs, still reports success,
     and simply has no skill in it.

  3. The SessionStart hook names a script or a FLAG that is not there. The hook runs on a
     stranger's session start; a bad path or a dropped option prints an error into their
     startup, or -- worse, given the gate's contract -- fails in a way that reads as "no
     news". `--plugin` in particular is new, and a future edit to the gate could drop it
     without anything here noticing.

  4. The skill cannot find its own files when installed. The skill resolves tools relative
     to the plugin root; if a tool moves in this repo, the vendored path list gets updated
     (there is a test for that) and the plugin path list does not.

Offline: reads files in this repo and runs the gate with --plugin against a nonexistent
path. No network, no install.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FAILURES = []


def check(label, ok, detail=""):
    print(("  PASS  " if ok else "  FAIL  ") + label + (("   " + detail) if detail else ""))
    if not ok:
        FAILURES.append(label)


def load(rel):
    p = ROOT / rel
    if not p.is_file():
        return None
    try:
        return json.loads(p.read_text(encoding="utf-8"))
    except json.JSONDecodeError as e:
        print(f"        {rel}: {e}")
        return None


print("plugin manifest")

plugin = load(".claude-plugin/plugin.json")
market = load(".claude-plugin/marketplace.json")

check("plugin.json is valid JSON", plugin is not None)
check("marketplace.json is valid JSON", market is not None)

if plugin is None or market is None:
    print("\nFAILED: a manifest is missing or unparseable")
    sys.exit(1)

# --- 1. the two manifests agree -------------------------------------------------
entries = market.get("plugins") or []
check("the marketplace lists a plugin", len(entries) > 0, f"({len(entries)})")

entry = next((e for e in entries if e.get("name") == plugin.get("name")), None)
check("marketplace.json names the same plugin as plugin.json", entry is not None,
      "" if entry else f"plugin.json says {plugin.get('name')!r}, "
                       f"marketplace lists {[e.get('name') for e in entries]!r}")

if entry is not None:
    check("the two manifests agree on version",
          entry.get("version") == plugin.get("version"),
          f"(marketplace {entry.get('version')!r} vs plugin {plugin.get('version')!r})")

    # source "./" means the plugin IS this repo. Anything else points somewhere that must
    # exist, and a relative path that does not resolve installs an empty plugin.
    src = entry.get("source", "./")
    if isinstance(src, str) and not src.startswith(("http", "git@")):
        check("the plugin source path exists", (ROOT / src).is_dir(), f"(source={src!r})")

# Required by the installer. A missing version is not a warning -- the install path is
# keyed by it (~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/).
for field in ("name", "version", "description"):
    check(f"plugin.json has {field}", bool(plugin.get(field)))

if plugin.get("version"):
    check("the version is semver-shaped",
          bool(re.fullmatch(r"\d+\.\d+\.\d+", str(plugin["version"]))),
          f"({plugin['version']!r})")

# --- 2. declared components exist ------------------------------------------------
# Discovered by convention from the plugin root, which for source "./" is the repo root.
check("the skill ships", (ROOT / "skills/murderboard/SKILL.md").is_file())
check("hooks/hooks.json ships", (ROOT / "hooks/hooks.json").is_file())

# --- 3. the hook's command is runnable -------------------------------------------
hooks = load("hooks/hooks.json")
check("hooks.json is valid JSON", hooks is not None)

hook_cmds = []
if hooks:
    for _event, blocks in (hooks.get("hooks") or {}).items():
        for block in blocks or []:
            for h in block.get("hooks") or []:
                if h.get("type") == "command" and h.get("command"):
                    hook_cmds.append(h["command"])

check("hooks.json declares at least one command", len(hook_cmds) > 0, f"({len(hook_cmds)})")

# Every ${CLAUDE_PLUGIN_ROOT}/<path> the hooks name must exist in this repo. That variable
# expands to the plugin root at run time, and the plugin root is this directory.
named = set()
for cmd in hook_cmds:
    named.update(re.findall(r"\$\{CLAUDE_PLUGIN_ROOT\}/([A-Za-z0-9_./-]+)", cmd))
check("the hooks name at least one shipped script", len(named) > 0, f"({sorted(named)})")
for rel in sorted(named):
    check(f"hook script exists: {rel}", (ROOT / rel).is_file())

# THE FLAG, not just the file. A hook that calls a gate with an option the gate no longer
# has fails at a stranger's session start, and this one fails toward silence.
if any("--plugin" in c for c in hook_cmds):
    out = subprocess.run(
        ["bash", str(ROOT / "murderboard_freshness.sh"),
         "--plugin", str(ROOT / "no-such-install-dir"), "--verbose"],
        capture_output=True, text=True,
    )
    blob = (out.stdout + out.stderr).lower()
    check("the gate still accepts --plugin", "unknown option" not in blob,
          "" if "unknown option" not in blob else f"({blob.strip()[:80]})")
    # ...and answers the contract: a path that is not an install is UNDETERMINED (2),
    # never a silent 0. A false "current" is the one verdict the gate promises never to
    # produce, and the hook is where it would be least visible.
    check("an absent install is undetermined, not current", out.returncode == 2,
          f"(rc={out.returncode}, want 2)")

# --- 4. the skill can find its tools when installed -------------------------------
# In installed mode the skill resolves these relative to the plugin root. Vendored layouts
# are covered by vendored_set_agrees_test.py; this is the other half.
skill = (ROOT / "skills/murderboard/SKILL.md").read_text(encoding="utf-8")
for rel in ("doc_review_process.md", "murderboard_freshness.sh", "murderboard_roster.sh"):
    check(f"the plugin root carries {rel}", (ROOT / rel).is_file())
    check(f"the skill resolves {rel} from the plugin root", f'$MB/{rel}' in skill)

print()
if FAILURES:
    print("FAILED: " + "; ".join(FAILURES))
    sys.exit(1)
print("all checks pass")
