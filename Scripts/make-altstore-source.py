#!/usr/bin/env python3
"""Add an iPhone and iPad release to the AltStore source, website/public/altstore.json.

  Scripts/make-altstore-source.py <version> [--ipa <file>]

AltStore and SideStore users add https://yingxia.getmegaportal.com/altstore.json as a source, then install and
update Yingxia from it. Run this after the iOS IPA is built (default build/release-apple/<version>/
Yingxia-<version>-ios.ipa) and the version's entry with an `ios` link is in releases.json. AltStore refuses a
download whose size, SHA-256 or permissions differ from the source, so run it on the IPA you upload, then deploy
the website with the release.
"""
import argparse
import hashlib
import json
import plistlib
import re
import sys
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "website/public/altstore.json"
FEED = ROOT / "website/public/releases.json"
DOWNLOAD = "https://download.getmegaportal.com/yingxia/{0}/Yingxia-{0}-ios.ipa"
KEEP = 5  # versions listed; AltStore installs the first one the device's iOS supports


def fail(message):
    sys.exit(f"make-altstore-source: {message}")


def version_key(version):
    return [int(part) for part in re.findall(r"\d+", version)]


def read_app(ipa):
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        plists = [n for n in names if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n)]
        if len(plists) != 1:
            fail(f"{ipa} has no single Payload/*.app/Info.plist")
        bundle = plists[0].removesuffix("Info.plist")
        # AltStore checks the app's entitlements against the source. The release IPA is unsigned, so it has
        # none; AltStore adds its own when it signs. A signed IPA would need its entitlements listed here.
        if bundle + "_CodeSignature/CodeResources" in names:
            fail(f"{ipa} is signed; publish the unsigned release IPA")
        return plistlib.loads(archive.read(plists[0]))


def notes(entry):
    features = [f for f in entry.get("features", []) if "ios" in f.get("platforms", ["ios"])]
    blocks = ["\n".join("• " + f["title"][language] for f in features) for language in ("zh-Hans", "en")]
    return "\n\n".join(block for block in blocks if block) or f"Yingxia {entry['version']}"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("version")
    parser.add_argument("--ipa", type=Path)
    args = parser.parse_args()
    version = args.version
    ipa = args.ipa or ROOT / f"build/release-apple/{version}/Yingxia-{version}-ios.ipa"
    if not ipa.is_file():
        fail(f"missing {ipa}")

    info = read_app(ipa)
    if info.get("CFBundleShortVersionString") != version:
        fail(f"{ipa} is version {info.get('CFBundleShortVersionString')}, not {version}")
    entry = next((r for r in json.loads(FEED.read_text())["releases"] if r["version"] == version), None)
    if entry is None or "ios" not in entry.get("links", {}):
        fail(f"releases.json has no {version} entry with an ios link")

    source = json.loads(SOURCE.read_text())
    app = source["apps"][0]
    if app["bundleIdentifier"] != info["CFBundleIdentifier"]:
        fail(f"{ipa} is {info['CFBundleIdentifier']}, the source lists {app['bundleIdentifier']}")
    data = ipa.read_bytes()
    release = {
        "version": version,
        "buildVersion": info["CFBundleVersion"],
        "date": entry["date"],
        "localizedDescription": notes(entry),
        "downloadURL": DOWNLOAD.format(version),
        "size": len(data),
        "sha256": hashlib.sha256(data).hexdigest(),
        "minOSVersion": info["MinimumOSVersion"],
    }
    versions = [v for v in app["versions"] if version_key(v["version"]) != version_key(version)] + [release]
    app["versions"] = sorted(versions, key=lambda v: version_key(v["version"]), reverse=True)[:KEEP]
    # The newest version's permissions; AltStore refuses an app that asks for more than the source lists.
    if app["versions"][0] is release:
        app["appPermissions"] = {
            "entitlements": [],
            "privacy": {key: value for key, value in sorted(info.items()) if key.endswith("UsageDescription")},
        }
    SOURCE.write_text(json.dumps(source, ensure_ascii=False, indent=2) + "\n")
    print(f"{version} ({release['buildVersion']}, {release['size']} bytes) in {SOURCE.relative_to(ROOT)}: "
          + ", ".join(v["version"] for v in app["versions"]))


if __name__ == "__main__":
    main()
