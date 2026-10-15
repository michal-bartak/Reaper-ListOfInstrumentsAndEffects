#!/usr/bin/env python3
"""Validate what the ReaPack manifest ships, and zip it for a manual install.

The file list comes from the manifest's @provides block, not from a second list
here, so the zip cannot drift from what ReaPack installs. Paths in the zip drop
the leading Reaper/, to unpack straight into the REAPER resource folder.

A port of the same script in the AutoColor repo. The differences: this manifest
uses `-- @tag` comment lines rather than a --[[ ]] header, and its file names
contain spaces.

  package.py --check     validate only
  package.py [OUT_DIR]   validate, then write
                         OUT_DIR/MXM_ListOfInstrumentsAndEffects-<version>.zip (default dist/)
  --root DIR             package the checkout in DIR instead of this one, to build a past
                         tag with the current script
"""
import re
import subprocess
import sys
import time
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAME = 'MXM_ListOfInstrumentsAndEffects'
MANIFEST = 'ReaPack/MXM_List of Instruments and Effects.lua'
ABOUT = f'Reaper/Scripts/{NAME}/lib/about.lua'
SCRIPTS = 'Reaper/Scripts/'
DATA = 'Reaper/Data/'
LIB = f'Reaper/Scripts/{NAME}/lib/'
EXTERNAL_MODULES = {'imgui'}  # ReaImGui's built-in, not ours

errors = []
warnings = []


def fail(msg):
    errors.append(msg)


def git(*args):
    return subprocess.run(['git', *args], cwd=ROOT, check=True,
                          capture_output=True, text=True).stdout


def glob_re(pattern):
    # ReaPack globs use FNM_PATHNAME: '*' and '?' never cross '/'.
    out = ''
    for ch in pattern:
        out += {'*': '[^/]*', '?': '[^/]'}.get(ch, re.escape(ch))
    return re.compile(out + r'\Z')


def parse_header(text):
    """The leading run of `--` lines: `-- @tag value`, then indented
    continuation lines (`--   ...`) belonging to the last tag seen."""
    tags, provides, current = {}, [], None
    lines = text.split('\n')
    for i, line in enumerate(lines):
        if not line.startswith('--'):
            # The header ends at the first line that is not a comment. An empty
            # line where a bare `--` was meant ends it EARLY, and reapack-index
            # says nothing: everything after it -- the rest of @about, all of
            # @changelog -- is silently dropped. A tag or an indented
            # continuation right after the gap is the sign.
            nxt = lines[i + 1] if i + 1 < len(lines) else ''
            if not line.strip() and re.match(r'--(\s*@\w|\s{2,}\S)', nxt):
                fail(f'{MANIFEST}:{i + 1}: empty line inside the header ends it; use "--"')
            break
        m = re.match(r'--\s*@(\w+)\s*(.*?)\s*$', line)
        if m:
            current = m.group(1)
            tags[current] = m.group(2)
        elif current == 'provides' and line[2:].strip():
            provides.append(line[2:].strip())
    if not tags:
        fail(f'{MANIFEST}: no -- @tag header')
    return tags, provides


def parse_provides(line):
    # Non-greedy source, and ' > ' with spaces around it: the script's own name
    # has spaces in it, so neither path can be matched as \S+.
    m = re.match(r'(?:\[([^\]]*)\]\s*)?(.+?)(?:\s+>\s+(.+))?$', line)
    if not m:
        fail(f'unparsable @provides line: {line}')
        return None
    opts, src, target = m.groups()
    return (opts or '').split(), src, target


def expected_target(opts, src):
    """The '>' target that reproduces the repo layout under Reaper/."""
    folder = src[:src.rfind('/') + 1].lstrip('/')
    if 'data' in opts:
        return folder[len(DATA):]
    return '../' + folder[len(SCRIPTS):]


def main():
    global ROOT
    args = sys.argv[1:]
    if '--root' in args:
        i = args.index('--root')
        ROOT = Path(args[i + 1]).resolve()
        del args[i:i + 2]
    check_only = '--check' in args
    out_args = [a for a in args if a != '--check']
    out_dir = Path(out_args[0]) if out_args else ROOT / 'dist'

    tracked = git('ls-files').split('\n')
    shipped_tree = [f for f in tracked if f.startswith('Reaper/')]
    tags, provides = parse_header((ROOT / MANIFEST).read_text())

    version = tags.get('version', '').strip()
    about = re.search(r"VERSION\s*=\s*'([^']+)'", (ROOT / ABOUT).read_text())
    if not version:
        fail(f'{MANIFEST}: no @version')
    if not about or about.group(1) != version:
        fail(f'{ABOUT} VERSION ({about and about.group(1)}) != manifest ({version})')
    if not provides:
        fail(f'{MANIFEST}: empty @provides')

    files = {}
    for line in provides:
        parsed = parse_provides(line)
        if not parsed:
            continue
        opts, src, target = parsed
        if not src.startswith('/Reaper/'):
            fail(f'source outside Reaper/: {src}')
            continue
        # A warning only: a manual install does not depend on where ReaPack
        # puts the files.
        if target != expected_target(opts, src):
            warnings.append(f'"{line}": target is not {expected_target(opts, src)}, '
                            'so the zip layout differs from the ReaPack install')
        rx = glob_re(src.lstrip('/'))
        matched = [f for f in shipped_tree if rx.match(f)]
        if not matched:
            fail(f'matches no tracked file: {src}')
        for f in matched:
            files[f] = f[len('Reaper/'):]

    for f in shipped_tree:
        if f not in files:
            fail(f'tracked under Reaper/ but not provided: {f}')

    lua = [f for f in files if f.endswith('.lua')]
    for f in lua:
        text = (ROOT / f).read_text()
        if re.search(r'(?m)^\s*(--\s*)?@version\b|^Version:\s', text):
            fail(f'{f}: carries a ReaPack version header, so becomes a package candidate')
        for mod in re.findall(r"require\s*\(?\s*['\"]([\w.]+)['\"]", text):
            path = LIB + mod.replace('.', '/') + '.lua'
            if mod not in EXTERNAL_MODULES and path not in files:
                fail(f'{f}: require "{mod}" -> {path} not provided')

    for w in warnings:
        print('WARNING: ' + w, file=sys.stderr)
    if errors:
        print('\n'.join('ERROR: ' + e for e in errors), file=sys.stderr)
        return 1
    print(f'{version}: {len(files)} files provided, all checks passed')
    if check_only:
        return 0

    # Commit time, not now, so the same commit always gives the same zip.
    stamp = int(git('log', '-1', '--format=%ct').strip())
    date_time = time.gmtime(stamp)[:6]
    out_dir.mkdir(parents=True, exist_ok=True)
    zip_path = out_dir / f'{NAME}-{version}.zip'
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for src in sorted(files):
            info = zipfile.ZipInfo(files[src], date_time)
            info.external_attr = 0o644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            z.writestr(info, (ROOT / src).read_bytes())
    print(zip_path)
    return 0


if __name__ == '__main__':
    sys.exit(main())
