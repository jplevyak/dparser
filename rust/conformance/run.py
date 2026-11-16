#!/usr/bin/env python3
"""Run the C grammar tests (../tests/*.test.g) through the Rust runtime.

For each input, compares the parse statistics and tree printed by the Rust
conformance driver with the C runtime's expected output (.check), ignoring
output printed by the grammars' C actions (which the Rust runtime can't run).
Inputs of grammars whose C actions may decide the parse are reported
separately rather than as failures.

usage: run.py [-v] [grammar ...]
"""
import glob
import os
import re
import subprocess
import sys
import tempfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', '..'))
TESTS = os.path.join(ROOT, 'tests')
MAKE_DPARSER = os.path.join(ROOT, 'make_dparser')
STATS = re.compile(r'\d+ states \d+ scans')
# C code that can change the parse: speculative actions, scopes, external scanners
SEMANTIC = re.compile(r'\]\s*[{;|]|\[[^\]]*\$\{(scope|reject)\}|return\s+-?1|\$\{scan')


def driver():
    subprocess.run(['cargo', 'build', '-q', '--release', '-p', 'conformance'],
                   cwd=os.path.join(ROOT, 'rust'), check=True)
    return os.path.join(ROOT, 'rust', 'target', 'release', 'conformance')


def result(lines):
    """The stats line and tree, or None for a failed parse."""
    for i, line in enumerate(lines):
        m = STATS.search(line)
        if m:
            # C actions may have printed text without a newline before the stats
            return [line[m.start():]] + lines[i + 1:]
    return None


ERROR = re.compile(r':(\d+): (syntax error.*)$')


def errors(lines):
    """The syntax errors reported, without the file name (C takes it from #line directives)."""
    return [m.groups() for m in (ERROR.search(line) for line in lines) if m]


def read_flags(path):
    return open(path).read().split() if os.path.exists(path) else []


def main():
    verbose = '-v' in sys.argv
    names = [a for a in sys.argv[1:] if a != '-v']
    exe = driver()
    grammars = names or sorted(os.path.basename(g) for g in glob.glob(os.path.join(TESTS, '*.test.g')))
    passed, failed, skipped = 0, [], []
    tmp = tempfile.mkdtemp()
    for g in grammars:
        path = os.path.join(TESTS, g)
        src = open(path, errors='replace').read()
        tables = os.path.join(tmp, g + '.bin')
        r = subprocess.run([MAKE_DPARSER, '-B', '-X', 'bin', '-o', tables] + read_flags(path + '.flags') + [g],
                           cwd=TESTS, capture_output=True, text=True)
        if r.returncode:
            skipped.append((g, 'make_dparser -B failed: ' + r.stderr.strip()[:100]))
            continue
        semantic = bool(SEMANTIC.search(src))
        for inp in sorted(glob.glob(path + '.*')):
            if not re.search(r'\.\d+$', inp) or not os.path.exists(inp + '.check'):
                continue
            name = os.path.basename(inp)
            cmd = [exe] + read_flags(inp + '.flags') + read_flags(path + '.parse_flags') + [tables, name]
            r = subprocess.run(cmd, cwd=TESTS, capture_output=True, text=True, errors='replace')
            if 'with_actions' in r.stderr:
                skipped.append((name, 'external scanner or whitespace function (see integration_tests)'))
                continue
            check = open(inp + '.check', errors='replace').read().splitlines()
            got = (result(r.stdout.splitlines()), errors(r.stderr.splitlines()))
            want = (result(check), errors(check))
            if got == want:
                passed += 1
            elif semantic:
                skipped.append((name, 'C actions may decide the parse'))
                if verbose:
                    print(name, 'differs (C actions)\n  want', want, '\n  got ', got, '\n ', r.stderr[-300:])
            else:
                failed.append(name)
                print(name, 'FAILED\n  want', want, '\n  got ', got, '\n ', r.stderr.strip()[-500:])
    print('%d passed, %d failed, %d skipped' % (passed, len(failed), len(skipped)))
    for s in skipped:
        print('  skipped', *s)
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
