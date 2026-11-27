#!/usr/bin/env python3
"""Rebuild the bundled catalog from Unicode Emoji and English CLDR annotations."""

import json
import re
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path


EMOJI_VERSION = "17.0"
CLDR_RELEASE = "48"
TONE = re.compile(r"[🏻-🏿]")
TONE_NAME = re.compile(r"(?:, |: )(?:light|medium-light|medium|medium-dark|dark) skin tone")
NEUTRAL_COUPLES = {
    "couple with heart: person: person": "couple with heart",
    "kiss: person: person": "kiss",
}


def download(url):
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8")


def key(glyph):
    return glyph.replace("\ufe0f", "")


def build_catalog(emoji_test, annotations):
    entries = {}
    for line in emoji_test.splitlines():
        if line.startswith("# group: "):
            group = line.removeprefix("# group: ")
        if "; fully-qualified" not in line:
            continue
        glyph, version, name = line.split("#", 1)[1].split(maxsplit=2)
        if TONE.search(glyph):
            base_name = TONE_NAME.sub("", name).replace(",", ":")
            entries[NEUTRAL_COUPLES.get(base_name, base_name)][-1].append([glyph, name])
        else:
            tags = annotations.get(key(glyph), [])
            base_name = name.replace(",", ":")
            if base_name in entries:
                raise ValueError(f"Duplicate emoji name {name}")
            entries[base_name] = [glyph, name, group, version[1:], tags, []]
    return entries.values()


def main():
    target = Path(__file__).resolve().parent
    cldr = f"https://raw.githubusercontent.com/unicode-org/cldr/release-{CLDR_RELEASE}/common"
    tags = {}
    for folder in ("annotations", "annotationsDerived"):
        for annotation in ET.fromstring(download(f"{cldr}/{folder}/en.xml")).iter("annotation"):
            if annotation.get("type") is None and annotation.text:
                tags[key(annotation.attrib["cp"])] = annotation.text.split(" | ")

    source = download(f"https://www.unicode.org/Public/{EMOJI_VERSION}.0/emoji/emoji-test.txt")
    entries = build_catalog(source, tags)
    # One emoji per line so Unicode updates remain reviewable.
    with (target / "emoji.json").open("w", encoding="utf-8") as catalog:
        catalog.write('{"version": ' + json.dumps(EMOJI_VERSION) + ', "emoji": [\n')
        catalog.write(",\n".join(json.dumps(entry, ensure_ascii=False) for entry in entries))
        catalog.write("\n]}\n")
    (target / "UNICODE-LICENSE.txt").write_text(
        download("https://www.unicode.org/license.txt"), encoding="utf-8"
    )


if __name__ == "__main__":
    main()
