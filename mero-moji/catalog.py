import json
import re
import unicodedata
from dataclasses import dataclass
from pathlib import Path


def normalize(text):
    decomposed = unicodedata.normalize("NFKD", text.casefold())
    return " ".join(re.findall(r"[a-z0-9]+", "".join(
        char for char in decomposed if not unicodedata.combining(char)
    )))


@dataclass
class Emoji:
    glyph: str
    name: str
    group: str
    version: str
    tags: list[str]
    variants: list[list[str]]

    def __post_init__(self):
        self.name_key = normalize(self.name)
        self.tag_keys = tuple(map(normalize, self.tags))
        self.words = tuple(set(" ".join((self.name_key, *self.tag_keys)).split()))


def load_catalog():
    catalog = json.loads(Path(__file__).with_name("emoji.json").read_text(encoding="utf-8"))
    return catalog["version"], [Emoji(*entry) for entry in catalog["emoji"]]


def search(entries, query):
    if not query.strip():
        return entries

    phrase = normalize(query)
    terms = phrase.split()
    matches = []
    for entry in entries:
        if query.strip().replace("\ufe0f", "") == entry.glyph.replace("\ufe0f", ""):
            score = -1
        elif not terms:
            continue
        elif phrase == entry.name_key:
            score = 0
        elif phrase in entry.tag_keys:
            score = 1
        elif entry.name_key.startswith(phrase):
            score = 2
        elif phrase in entry.name_key:
            score = 3
        elif all(any(word.startswith(term) for word in entry.words) for term in terms):
            score = 4
        elif all(any(term in word for word in entry.words) for term in terms):
            score = 5
        else:
            continue
        matches.append((score, entry))

    return [entry for _, entry in sorted(matches, key=lambda match: match[0])]
