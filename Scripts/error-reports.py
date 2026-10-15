#!/usr/bin/env python3
"""Summarize the app's error reports (Services/error-reports) for the last N days, worst first.

Usage: Scripts/error-reports.py [days=1] [--json] [--signature <sig>]
NEW marks groups first reported inside the window. --signature lists that group's recent reports;
a crash's or hang's app frames get code lines from the release's saved dSYM (build/release-*/<v>/dSYMs).
One full scan of a table that keeps 30 days, well inside D1's free reads.
"""
import argparse
import json
import pathlib
import re
import subprocess
import time

root = pathlib.Path(__file__).resolve().parents[1]
service = root / "Services/error-reports"
wrangler = root / "website/node_modules/.bin/wrangler"

parser = argparse.ArgumentParser()
parser.add_argument("days", nargs="?", type=float, default=1)
parser.add_argument("--json", action="store_true")
parser.add_argument("--signature")
args = parser.parse_args()
since = int(time.time() - args.days * 86400)


def symbolicate(platform, message):
    """Appends file:line to each "TVBox-iOS+0x1a2b" frame of the version named by "app=1.6.5 (16)"."""
    version = re.search(r"^app=(\S+) ", message, re.M) or re.search(r" app=(\S+) ", message)
    if not version:
        return message
    folder = root / ("build/release-mac" if platform == "macos" else "build/release-apple") / version.group(1) / "dSYMs"
    lines = message.split("\n")
    for index, line in enumerate(lines):
        frame = re.fullmatch(r"(TVBox-(?:iOS|tvOS|macOS))\+0x([0-9a-f]+)", line)
        dwarf = frame and folder / f"{frame.group(1)}.app.dSYM/Contents/Resources/DWARF/{frame.group(1)}"
        if dwarf and dwarf.exists():
            # Main executables load their text at 0x100000000; MetricKit's offset is from there.
            address = hex(0x100000000 + int(frame.group(2), 16))
            found = subprocess.run(["atos", "-o", str(dwarf), "-l", "0x100000000", address], capture_output=True, text=True)
            lines[index] = f"{line}  {found.stdout.strip()}"
        elif dwarf:
            lines[index] = f"{line}  (no dSYM in {folder.relative_to(root)})"
    return "\n".join(lines)


if args.signature:
    if not args.signature.isalnum():
        raise SystemExit("bad signature")
    sql = f"""SELECT datetime(received, 'unixepoch') AS received, platform, os, app, build, country, count,
        model, lang, substr(install, 1, 8) AS install, message FROM reports
        WHERE signature = '{args.signature}' AND received >= {since} ORDER BY received DESC LIMIT 30"""
else:
    sql = f"""SELECT signature, category,
        COUNT(DISTINCT CASE WHEN received >= {since} THEN install END) AS installs,
        SUM(CASE WHEN received >= {since} THEN count ELSE 0 END) AS events,
        group_concat(DISTINCT CASE WHEN received >= {since} THEN platform END) AS platforms,
        group_concat(DISTINCT CASE WHEN received >= {since} THEN app END) AS versions,
        datetime(MAX(last), 'unixepoch') AS last_seen,
        MIN(received) >= {since} AS new,
        MAX(message) AS sample
        FROM reports GROUP BY signature HAVING events > 0
        ORDER BY installs DESC, events DESC LIMIT 60"""

out = subprocess.run([str(wrangler), "d1", "execute", "yingxia-reports", "--remote", "--json", "--command", " ".join(sql.split())],
                     cwd=service, capture_output=True, text=True)
if out.returncode:
    raise SystemExit(out.stdout + out.stderr)
rows = json.loads(out.stdout)[0]["results"]
if args.json:
    print(json.dumps(rows, ensure_ascii=False, indent=1))
elif args.signature:
    for row in rows:
        print(f"{row['received']}  {row['platform']} {row['os']} {row['model']} {row['lang']}  {row['app']} ({row['build']})  "
              f"{row['country']}  x{row['count']}  {row['install']}")
        print("   ", symbolicate(row["platform"], row["message"]).replace("\n", "\n    "))
else:
    print(f"{len(rows)} error groups in the last {args.days:g} day(s)")
    for row in rows:
        flag = "NEW " if row["new"] else ""
        print(f"\n{flag}{row['signature']}  {row['category']}  installs={row['installs']} events={row['events']}  "
              f"{row['platforms']}  v{row['versions']}  last={row['last_seen']}")
        print("   ", row["sample"].split("\n")[0][:300])
