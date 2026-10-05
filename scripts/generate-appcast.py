#!/usr/bin/env python3
"""Generate a Sparkle appcast.xml from this repo's GitHub Releases.

Usage:
    SPARKLE_ED_PRIVATE_KEY=<base64> python3 scripts/generate-appcast.py [out.xml]

If SPARKLE_ED_PRIVATE_KEY is unset, entries are emitted *without*
sparkle:edSignature attributes. Sparkle 2.x will refuse to install
unsigned updates, which is the safe default — until the secret is
configured, the appcast simply won't drive any installs.

Requires:
    - `gh` CLI authenticated (provided automatically inside GitHub
      Actions via env $GH_TOKEN).
    - `sign_update` binary on PATH if signing is desired (downloaded
      from a Sparkle release in the wrapper workflow).
"""

import json
import os
import shutil
import subprocess
import sys
import tempfile
import urllib.request
from datetime import datetime, timezone
from xml.sax.saxutils import escape

REPO = "ryouka0731/KeepingYouAwake-Amphetamine"
TAG_PREFIX = "v"
TAG_SUFFIX = "amphetamine."
APPCAST_TITLE = "KeepingYouAwake (Amphetamine)"
APPCAST_LINK = "https://ryouka0731.github.io/KeepingYouAwake-Amphetamine/appcast.xml"
DESCRIPTION = "A community fork of KeepingYouAwake with Amphetamine-style features."
MIN_SYSTEM_VERSION = "10.13"


def gh(*args):
    return subprocess.check_output(["gh", *args]).decode()


def list_releases():
    raw = gh(
        "release", "list",
        "--repo", REPO,
        "--limit", "100",
        "--json", "tagName,name,publishedAt,isDraft,isPrerelease",
    )
    releases = json.loads(raw)
    return [r for r in releases
            if not r["isDraft"]
            and not r.get("isPrerelease", False)
            and TAG_SUFFIX in r["tagName"]]


def fetch_release_assets(tag):
    raw = gh(
        "release", "view", tag,
        "--repo", REPO,
        "--json", "assets,publishedAt,body",
    )
    return json.loads(raw)


def find_dmg_asset(assets):
    for a in assets:
        if a["name"].endswith(".dmg"):
            return a
    return None


def parse_short_version(tag):
    return tag[len(TAG_PREFIX):] if tag.startswith(TAG_PREFIX) else tag


def build_number(major, minor, patch, suffix):
    """CFBundleVersion for vMAJOR.MINOR.PATCH-amphetamine.SUFFIX.

    major * 1_000_000 + minor * 10_000 + patch * 100 + suffix, e.g.
    v1.7.0-amphetamine.5 → 1070005. Must match CURRENT_PROJECT_VERSION in
    Configuration.xcconfig. Arithmetic (not digit concatenation) keeps the
    order right past amphetamine.9: concatenating gave 10700010 for .10,
    which outranks v1.7.1-amphetamine.1. Identical to the old scheme for
    every release so far (patch 0, suffix < 10).

    Raises ValueError when minor, patch or suffix is outside 0..99, where
    the encoding would collide (v1.100.0 == v2.0.0); publishing a feed with
    a wrong order is worse than failing the workflow.
    """
    for name, value in (("minor", minor), ("patch", patch), ("suffix", suffix)):
        if not 0 <= value <= 99:
            raise ValueError(f"{name}={value} out of range 0..99 for the build-number encoding")
    return str(major * 1_000_000 + minor * 10_000 + patch * 100 + suffix)


def parse_build_number(tag, body):
    short = parse_short_version(tag)
    import re
    m = re.match(r"(\d+)\.(\d+)\.(\d+)-amphetamine\.(\d+)", short)
    if m:
        return build_number(*(int(g) for g in m.groups()))
    return "1000000"


def sign_dmg(url, name):
    """Download the dmg and run sign_update; return base64 EdDSA signature."""
    if not os.environ.get("SPARKLE_ED_PRIVATE_KEY"):
        return None, None
    if not shutil.which("sign_update"):
        print("warning: sign_update not on PATH; skipping signature", file=sys.stderr)
        return None, None

    with tempfile.NamedTemporaryFile(suffix=".dmg", delete=False) as tmp:
        urllib.request.urlretrieve(url, tmp.name)
        size = os.path.getsize(tmp.name)
        try:
            output = subprocess.check_output(
                ["sign_update", "-f", "-", tmp.name],
                input=os.environ["SPARKLE_ED_PRIVATE_KEY"].encode(),
            ).decode().strip()
            # sign_update prints: sparkle:edSignature="..." length="..."
            return output, size
        finally:
            os.unlink(tmp.name)


def render_item(release):
    tag = release["tagName"]
    detail = fetch_release_assets(tag)
    asset = find_dmg_asset(detail["assets"])
    if asset is None:
        return None
    short = parse_short_version(tag)
    build = parse_build_number(tag, detail.get("body", ""))
    pub = release["publishedAt"] or datetime.now(timezone.utc).isoformat()
    pubdate = datetime.fromisoformat(pub.replace("Z", "+00:00")).strftime("%a, %d %b %Y %H:%M:%S %z")

    sig_attr, signed_size = sign_dmg(asset["url"], asset["name"])
    size = signed_size if signed_size else asset["size"]

    notes_link = f"https://github.com/{REPO}/releases/tag/{tag}"
    enclosure = (
        f'<enclosure url="{escape(asset["url"])}" '
        f'length="{size}" '
        f'type="application/octet-stream"'
    )
    if sig_attr:
        # sign_update prints raw attributes already; splice them in.
        enclosure += " " + sig_attr.replace('length="' + str(size) + '"', "").strip()
    enclosure += "/>"

    return f"""        <item>
            <title>{escape(short)}</title>
            <pubDate>{pubdate}</pubDate>
            <sparkle:version>{escape(build)}</sparkle:version>
            <sparkle:shortVersionString>{escape(short)}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>{MIN_SYSTEM_VERSION}</sparkle:minimumSystemVersion>
            <sparkle:releaseNotesLink>{escape(notes_link)}</sparkle:releaseNotesLink>
            {enclosure}
        </item>"""


def main():
    out_path = sys.argv[1] if len(sys.argv) > 1 else "appcast.xml"
    releases = list_releases()
    items = []
    for r in releases:
        rendered = render_item(r)
        if rendered:
            items.append(rendered)

    body = "\n".join(items)
    xml = f"""<?xml version="1.0" standalone="yes"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
    <channel>
        <title>{escape(APPCAST_TITLE)}</title>
        <link>{escape(APPCAST_LINK)}</link>
        <description>{escape(DESCRIPTION)}</description>
        <language>en</language>
{body}
    </channel>
</rss>
"""
    with open(out_path, "w", encoding="utf-8") as f:
        f.write(xml)
    print(f"wrote {out_path} ({len(items)} item{'s' if len(items) != 1 else ''})")


if __name__ == "__main__":
    main()
