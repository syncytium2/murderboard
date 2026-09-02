#!/usr/bin/env python3
# instrument: verification
# vendored from armory @ 9e62f10 -- do NOT edit here; edit the canonical original (armory .claude/hooks/send-goes-nowhere.py) and re-copy.
"""PostToolUse gate. A file sent to the user is answered with the fact that it arrived nowhere.

WHY THIS EXISTS
    `SendUserFile` does not deliver in the VS Code extension, and it RETURNS SUCCESS ANYWAY.
    Probed directly 2026-09-01: `display=render` with an SVG and `display=attach` with plain
    text were both sent, both returned "1 file delivered to user.", and neither produced a
    card or an inline preview. Upstream anthropics/claude-code#76739 -- open, `has repro`,
    labelled macos + windows + vscode, filed at CLI 2.1.207, still failing at 2.1.252.

    The failure is undetectable from inside the session, so every convention resting on the
    channel is unfalsifiable. The session briefing's rule -- "a visual finding? render the
    figure and show it" -- was satisfied every time by a call that did nothing. A bugarach
    session narrated SIX figures as shown across a working day; the user found out by
    opening a deployed site himself.

WHY A HOOK AND NOT A LINE IN A DOC. It is written down -- interface2
docs/verification_gotchas.md, "A file-send tool that returns success and delivers nothing".
That is tier 0: it must be REMEMBERED, by a session that does not know the channel is
broken. armory's instrument_ledger measures what that is worth across this estate --
hand-invoked instruments average 1.1 copies, registered ones 2.3. So the register entry
names this hook as its own missing half, and this is that half.

WHY PostToolUse AND NOT PreToolUse. The same argument dragnet-before-absence.py makes: the
call itself is not a mistake. Sending a file is a reasonable thing to do, and on a client
where the channel works it is the right thing. The mistake happens one step later, when the
success return is read as delivery. So the trigger is the CALL HAVING HAPPENED, not the
arguments -- and unlike a blocking gate this costs a session nothing it can lose.

IT ANSWERS, IT DOES NOT ONLY WARN. A hook saying "that may not have arrived" leaves the
session where it was. This one names the remedy: tools/show.py, located from this file's own
path, with the exact command including the file that was just sent.

WHAT IT DOES NOT KNOW. The payload carries no client identity, so this hook CANNOT tell
whether the session is attached to the VS Code extension (where delivery is confirmed
broken) or a terminal (where it may work). It therefore does not claim the send failed. It
states what is confirmed, and points at a delivery that is verifiable on every client --
which is better than a working send regardless, because a printed path is a claim the user
can contradict and a success return is not.

RETIRING IT. verification_gotchas rule 7: retire a probe in the same commit that retires its
subject. When #76739 closes and delivery is confirmed on this machine, delete this file and
the register entry together -- a gate that fires about a fixed bug is noise, and noise is how
an alarm stops being read.

SELF-CONFIGURING. show.py is located from this file's own path, so this hook and tools/show.py
can be copied into any repo unchanged.

EXIT  0 always. This gate never blocks.
      python3 .claude/hooks/send-goes-nowhere.py --selftest   to check it still fires.
"""
import json
import sys
from pathlib import Path

SHOW = Path(__file__).resolve().parents[2] / "tools" / "show.py"

# The tool names that mean "hand this artefact to the user". Kept as a set rather than one
# literal because the estate has seen this surface under more than one name; an unknown
# tool must never be matched, or the gate becomes the noise it is meant to prevent.
SEND_TOOLS = {"SendUserFile"}


def _paths(tool_input):
    """Whatever this call was trying to deliver, for naming it back in the remedy."""
    out = []
    for key in ("file_path", "path", "file", "files", "paths"):
        v = tool_input.get(key)
        if isinstance(v, str) and v.strip():
            out.append(v.strip())
        elif isinstance(v, list):
            out += [str(x).strip() for x in v if str(x).strip()]
    seen, uniq = set(), []
    for p in out:
        if p not in seen:
            seen.add(p)
            uniq.append(p)
    return uniq[:4]


def run(payload):
    """Returns the additionalContext string, or '' to stay silent."""
    if payload.get("tool_name", "") not in SEND_TOOLS:
        return ""

    files = _paths(payload.get("tool_input", {}) or {})
    show_here = SHOW.is_file()

    if files:
        arg = " ".join('"%s"' % f if " " in f else f for f in files)
        remedy = ("python3 %s %s" % (SHOW, arg)) if show_here else \
                 ("copy %s into <dropbox>/darkroom/<project>/ and print the absolute path"
                  % arg)
    else:
        remedy = ("python3 %s <file>" % SHOW) if show_here else \
                 "copy the file into <dropbox>/darkroom/<project>/ and print the absolute path"

    lines = [
        "THAT SEND MAY HAVE REACHED NOBODY, AND ITS RETURN VALUE CANNOT TELL YOU.",
        "",
        "SendUserFile does not deliver in the VS Code extension and returns success anyway.",
        "Probed 2026-09-01: display=render (SVG) and display=attach (text) both returned",
        '"1 file delivered to user." and neither appeared on screen. Upstream',
        "anthropics/claude-code#76739 -- open, has repro, macos + windows + vscode.",
        "",
        "This hook cannot see which client is attached, so it is not claiming your call",
        "failed. It is telling you the success you just got is not evidence that it worked.",
        "",
        "DELIVER IT A WAY THE USER CAN CONTRADICT:",
        "    " + remedy,
        "",
        "That writes the file to the darkroom -- the folder Tony already reviews from on",
        "either machine -- and prints its absolute path. Put that path in your reply. `open`",
        "returning 0 proves only that a launcher started, exactly as little as",
        '"1 file delivered" proved; the difference is the artefact is still there afterwards.',
        "",
        "NEVER report a figure as shown on the strength of a call that returned success.",
        "Full entry: interface2 docs/verification_gotchas.md, 'A file-send tool that returns",
        "success and delivers nothing'.",
    ]
    return "\n".join(lines)


def selftest():
    bad = []

    def check(cond, why):
        if not cond:
            bad.append(why)
        print("  %s  %s" % ("ok " if cond else "FAIL", why))

    fired = run({"hook_event_name": "PostToolUse", "tool_name": "SendUserFile",
                 "tool_input": {"file_path": "/tmp/fig.png"},
                 "tool_response": "1 file delivered to user."})
    check(bool(fired), "fires on SendUserFile")
    check("/tmp/fig.png" in fired, "names the file that was sent, in the remedy")
    check("76739" in fired, "cites the upstream issue")
    check("not claiming your call" in fired, "does NOT assert the send failed -- it cannot know")

    # The success return is the whole defect, so a successful response must not silence it.
    check(bool(run({"tool_name": "SendUserFile", "tool_input": {},
                    "tool_response": "1 file delivered to user."})),
          "a SUCCESSFUL response does not silence it -- success is the defect")

    # And it must be able to stay quiet, or it is noise on every tool call.
    for tool in ("Write", "Bash", "Read", "Grep"):
        if run({"tool_name": tool, "tool_input": {"file_path": "/tmp/fig.png"}}):
            bad.append("stayed silent on %s" % tool)
    check(not any(b.startswith("stayed silent") for b in bad),
          "silent on every other tool")

    check(not run({"tool_name": "", "tool_input": {}}), "silent on a malformed payload")

    # Multi-file and unnamed calls must both produce a usable command.
    multi = run({"tool_name": "SendUserFile",
                 "tool_input": {"paths": ["/tmp/a b.png", "/tmp/c.pdf"]}})
    check('"/tmp/a b.png"' in multi and "/tmp/c.pdf" in multi,
          "quotes a path containing a space, and carries every file")
    check("<file>" in run({"tool_name": "SendUserFile", "tool_input": {}}),
          "still gives a runnable remedy when no path is in the payload")

    check(SHOW.is_file(), "found tools/show.py from its own path (%s)" % SHOW.name)

    print("selftest:", "PASS" if not bad else "RED")
    return 0 if not bad else 1


def main():
    if "--selftest" in sys.argv:
        return selftest()
    try:
        payload = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        return 0
    try:
        ctx = run(payload)
    except Exception:                                  # noqa: BLE001 -- never break a session
        return 0
    if ctx:
        json.dump({"hookSpecificOutput": {"hookEventName": "PostToolUse",
                                          "additionalContext": ctx},
                   "systemMessage": "send-goes-nowhere: that file may not have arrived — "
                                    "deliver it as a darkroom path"}, sys.stdout)
    return 0


if __name__ == "__main__":
    sys.exit(main())
