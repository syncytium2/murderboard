#!/usr/bin/env python3
"""What one murderboard round actually costs, read from the harness's own records.

A review round fans eleven roles out as subagents. Claude Code writes one transcript
per subagent and stamps every assistant turn with a `usage` block; this reads those
blocks and sums them per role. Nothing here estimates anything -- if a number is not
in a transcript it is not in the output.

Why this exists as a tool rather than a number in a document: a cost figure quoted in
prose cannot be checked, and this repo has already had a per-role token table asserted
as "measured" that no measurement produces (see metrics/README.md). Run the tool.

    python3 metrics/measure_review_cost.py                       # human-readable
    python3 metrics/measure_review_cost.py --csv metrics/review_cost.csv

Transcripts live under ~/.claude/projects/<project>/<session>/subagents/ and are local
and impermanent -- the harness prunes them. A run not captured here before it ages out
is not recoverable, which is the same reason metrics/traffic.csv exists.

Stdlib only, like everything else a consumer has to be able to drop in and run.
"""

import argparse
import csv
import glob
import json
import os
import re
import sys

# The string every compiled and inline murderboard role prompt opens with. A subagent
# transcript that does not contain it was some other agent and is skipped.
MARKER = 'murderboard review team'

DEFAULT_ROOT = os.path.expanduser('~/.claude/projects')


def role_of(prompt):
    """Role number and slug, when the prompt names a compiled agent file.

    Runs predating the compiler pasted the role's block inline and named no file. Those
    roles are genuinely unidentifiable from the transcript: they come back (None, ''),
    and the caller reports them as unknown rather than guessing an order.
    """
    m = re.search(r'agents/(\d+)-([a-z0-9-]+)\.md', prompt)
    if m:
        return int(m.group(1)), m.group(2)
    return None, ''


def scan(path):
    """Sum the usage blocks in one subagent transcript."""
    a = dict(inp=0, out=0, cc=0, cr=0, think=0, turns=0)
    prompt = ''
    started = None
    for line in open(path, encoding='utf-8', errors='replace'):
        try:
            d = json.loads(line)
        except ValueError:
            continue
        if started is None:
            started = d.get('timestamp')
        msg = d.get('message') or {}
        content = msg.get('content')
        if not prompt:
            texts = []
            if isinstance(content, str):
                texts = [content]
            elif isinstance(content, list):
                texts = [c['text'] for c in content
                         if isinstance(c, dict) and c.get('type') == 'text']
            for t in texts:
                if MARKER in t:
                    prompt = t
                    break
        u = msg.get('usage') or {}
        if not u:
            continue
        a['turns'] += 1
        a['inp'] += u.get('input_tokens', 0)
        a['out'] += u.get('output_tokens', 0)
        a['cc'] += u.get('cache_creation_input_tokens', 0)
        a['cr'] += u.get('cache_read_input_tokens', 0)
        a['think'] += (u.get('output_tokens_details') or {}).get('thinking_tokens', 0)
    return prompt, started, a


def project_label(flattened):
    """Drop the operator's home directory out of the harness's flattened project name.

    Claude Code names a project directory after its cwd with the separators replaced,
    so the raw value is `-Users-<someone>-Developer-<repo>`. This repo is public and
    that string is a machine layout with a username in it; the repo name is the only
    part that means anything to a reader, so the home prefix comes off before anything
    reaches metrics/review_cost.csv.
    """
    home = os.path.expanduser('~').replace(os.sep, '-')
    if flattened.startswith(home):
        return flattened[len(home):].lstrip('-') or flattened
    return flattened


def runs(root):
    """Every session directory holding murderboard role transcripts, oldest first."""
    out = []
    for d in sorted(glob.glob(os.path.join(root, '*', '*', 'subagents'))):
        rows = []
        for f in sorted(glob.glob(os.path.join(d, 'agent-*.jsonl'))):
            prompt, started, a = scan(f)
            if not prompt:
                continue
            rows.append(dict(role=role_of(prompt), started=started, agent=os.path.basename(f), **a))
        if not rows:
            continue
        parts = d.split(os.sep)
        out.append(dict(project=project_label(parts[-3]), session=parts[-2],
                        started=min(r['started'] for r in rows if r['started']),
                        rows=sorted(rows, key=lambda r: (r['role'][0] is None, r['role'][0], r['agent']))))
    return sorted(out, key=lambda r: r['started'])


# input + output + cache_creation. Cache READS are reported separately and deliberately
# not folded in: they are billed at a fraction and they are an artifact of how many turns
# a role took, not of how much work it did. Quoting either number alone misleads, so the
# tool prints both and the CSV carries both.
def billable(r):
    return r['inp'] + r['out'] + r['cc']


HDR = '%-3s %-24s %9s %9s %11s %13s %11s'


def main(argv=None):
    p = argparse.ArgumentParser(description=__doc__,
                                formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument('--root', default=DEFAULT_ROOT,
                   help='transcript root (default: %(default)s)')
    p.add_argument('--csv', metavar='PATH', help='also write per-role rows to PATH')
    args = p.parse_args(argv)

    found = runs(args.root)
    if not found:
        print('no murderboard role transcripts under %s' % args.root, file=sys.stderr)
        return 1

    csv_rows = []
    for run in found:
        print('=' * 84)
        print('%s  session %s  --  %d roles, first agent %s'
              % (run['project'], run['session'][:8], len(run['rows']), run['started']))
        print(HDR % ('#', 'role', 'output', 'thinking', 'new input', 'cache read', 'billable'))
        tot = dict(out=0, think=0, cc=0, cr=0, bill=0)
        for r in run['rows']:
            n, slug = r['role']
            print(HDR % (n if n else '?', slug or '(inline, unidentified)',
                         format(r['out'], ','), format(r['think'], ','),
                         format(r['cc'], ','), format(r['cr'], ','),
                         format(billable(r), ',')))
            tot['out'] += r['out']
            tot['think'] += r['think']
            tot['cc'] += r['cc']
            tot['cr'] += r['cr']
            tot['bill'] += billable(r)
            csv_rows.append(dict(
                project=run['project'], session=run['session'], started=run['started'],
                role_n=n if n else '', role=slug, turns=r['turns'],
                output_tokens=r['out'], thinking_tokens=r['think'],
                new_input_tokens=r['cc'], cache_read_tokens=r['cr'],
                billable_tokens=billable(r)))
        print(HDR % ('', 'TOTAL', format(tot['out'], ','), format(tot['think'], ','),
                     format(tot['cc'], ','), format(tot['cr'], ','), format(tot['bill'], ',')))

    if args.csv:
        cols = ['project', 'session', 'started', 'role_n', 'role', 'turns',
                'output_tokens', 'thinking_tokens', 'new_input_tokens',
                'cache_read_tokens', 'billable_tokens']
        with open(args.csv, 'w', newline='', encoding='utf-8') as fh:
            w = csv.DictWriter(fh, fieldnames=cols)
            w.writeheader()
            for row in csv_rows:
                w.writerow(row)
        print('\nwrote %d rows to %s' % (len(csv_rows), args.csv))
    return 0


if __name__ == '__main__':
    sys.exit(main())
