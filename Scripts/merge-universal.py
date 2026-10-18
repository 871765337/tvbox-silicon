#!/usr/bin/env python3
"""Merge an arm64 tree and an x86_64 tree of the same program into one universal tree.

Usage: Scripts/merge-universal.py <arm64-dir> <x86_64-dir> <out-dir> [--keep-arm64 <glob>]...
Mach-O files at the same path are joined with lipo. Every other file both trees have must be identical,
except paths matching a --keep-arm64 glob (build metadata such as Python's sysconfigdata), where the arm64
copy wins. A file only one tree has is copied as is: some wheels name their native modules per architecture.
"""
import argparse
import filecmp
import fnmatch
import os
import pathlib
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser()
parser.add_argument('arm64', type=pathlib.Path)
parser.add_argument('x86_64', type=pathlib.Path)
parser.add_argument('out', type=pathlib.Path)
parser.add_argument('--keep-arm64', action='append', default=[], metavar='GLOB')
args = parser.parse_args()


def is_macho(path):
    with open(path, 'rb') as f:
        head = f.read(8)
    if head[:4] in (b'\xcf\xfa\xed\xfe', b'\xfe\xed\xfa\xcf'):
        return True
    # A fat header shares 0xCAFEBABE with Java class files; its next word is a small slice count.
    return head[:4] == b'\xca\xfe\xba\xbe' and int.from_bytes(head[4:8], 'big') < 20


def archs(path):
    return set(subprocess.run(['lipo', '-archs', path], check=True, capture_output=True, text=True).stdout.split())


def thin(path, arch, scratch):
    if archs(path) == {arch}:
        return path
    out = os.path.join(scratch, arch)
    subprocess.run(['lipo', path, '-thin', arch, '-output', out], check=True)
    return out


def walk(root):
    """Files and symlinks (to files or directories) under root, without following directory links."""
    found = set()
    for parent, dirs, files in os.walk(root):
        base = pathlib.Path(parent).relative_to(root)
        found.update(str(base / n) for n in files)
        found.update(str(base / n) for n in dirs if os.path.islink(os.path.join(parent, n)))
    return found


arm_files, x86_files = walk(args.arm64), walk(args.x86_64)
if args.out.exists():
    shutil.rmtree(args.out)
lipoed, kept, only_arm, only_x86, errors = 0, [], [], [], []
for rel in sorted(arm_files | x86_files):
    a, x, o = args.arm64 / rel, args.x86_64 / rel, args.out / rel
    o.parent.mkdir(parents=True, exist_ok=True)
    if rel not in x86_files or rel not in arm_files:
        (only_arm if rel in arm_files else only_x86).append(rel)
        source = a if rel in arm_files else x
        if source.is_symlink():
            o.symlink_to(os.readlink(source))
        else:
            shutil.copy2(source, o)
        continue
    if a.is_symlink() or x.is_symlink():
        if not (a.is_symlink() and x.is_symlink() and os.readlink(a) == os.readlink(x)):
            errors.append(f'symlink differs: {rel}')
        o.symlink_to(os.readlink(a))
        continue
    if is_macho(a) and is_macho(x):
        if {'arm64', 'x86_64'} <= archs(a):
            shutil.copy2(a, o)
            continue
        with tempfile.TemporaryDirectory() as scratch:
            subprocess.run(['lipo', '-create', thin(a, 'arm64', scratch), thin(x, 'x86_64', scratch), '-output', o], check=True)
        shutil.copymode(a, o)
        lipoed += 1
        continue
    shutil.copy2(a, o)
    if not filecmp.cmp(a, x, shallow=False):
        if any(fnmatch.fnmatch(rel, g) for g in args.keep_arm64):
            kept.append(rel)
        else:
            errors.append(f'differs: {rel}')

print(f'{args.out}: {lipoed} Mach-O merged, {len(kept)} arm64 copies kept, '
      f'{len(only_arm)} arm64-only and {len(only_x86)} x86_64-only files')
for rel in only_arm[:20]:
    print(f'  arm64 only: {rel}')
for rel in only_x86[:20]:
    print(f'  x86_64 only: {rel}')
if errors:
    print('\n'.join(errors[:200]), file=sys.stderr)
    sys.exit(f'{len(errors)} files differ between the architectures; check them, then pass --keep-arm64')
