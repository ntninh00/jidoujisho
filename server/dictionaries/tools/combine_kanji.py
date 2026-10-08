"""Gives KanjiDictVN's 「Từ điển Hán Nôm」 the Japanese readings it leaves out,
laid out for the popup.

KanjiDictVN (https://github.com/trungnt2910/KanjiDictVN) keeps KANJIDIC's
characters but puts the Sino-Vietnamese reading where on'yomi go and leaves
kun'yomi empty. Its release also carries the KANJIDIC it was built from, so
each character takes its on'yomi, kun'yomi and tags from there.

Kanji banks hold meanings as plain strings, so the result is a term bank
with structured content and a stylesheet instead: one entry per character
with its Sino-Vietnamese, on and kun readings, the meanings grouped by
Sino-Vietnamese reading, and its strokes, radical and shape. A character
with no Vietnamese meaning gets KANJIDIC's English ones, marked as such.

    python tools/combine_kanji.py KANJIDIC_vietnamese.zip KANJIDIC_english.zip out.zip
"""

from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

# Marks the revision, so copies of the release as it was show as out of date.
REVISION_SUFFIX = "+onkun"

# KANJIDIC's tags kept on each entry, described in Vietnamese.
TAGS = {
    "jouyou": "Chữ Hán thường dùng (Jōyō kanji)",
    "jinmeiyou": "Chữ Hán dùng trong tên người (Jinmeiyō kanji)",
}

STYLES = """/* Laid out by jidoujisho's tools/combine_kanji.py. Colours follow the
   popup's theme. */
[data-sc-jdj="readings"] {
  margin-bottom: 0.35em;
}
[data-sc-jdj="pill"] {
  font-size: 0.75em;
  font-weight: bold;
  padding: 0.05em 0.5em;
  border-radius: 0.7em;
  margin-right: 0.4em;
  color: color-mix(in srgb, var(--text-color) 72%, var(--background-color));
  background-color: color-mix(in srgb, var(--text-color) 12%, var(--background-color));
}
[data-sc-jdj="han-viet"] {
  font-weight: bold;
}
[data-sc-jdj="okurigana"], [data-sc-jdj="facts"], [data-sc-jdj="label"] {
  color: color-mix(in srgb, var(--text-color) 58%, var(--background-color));
}
[data-sc-jdj="group"] {
  font-weight: bold;
  margin-top: 0.3em;
}
[data-sc-jdj="label"] {
  font-size: 0.8em;
  font-weight: bold;
  margin-top: 0.3em;
}
[data-sc-jdj="senses"] {
  margin-top: 0;
  margin-bottom: 0;
  padding-left: 1.4em;
}
[data-sc-jdj="facts"] {
  font-size: 0.85em;
  margin-top: 0.4em;
}
"""

_PREFIX = re.compile(r"^\[([^\]]+)\]\s*(.*)$", re.S)
# Ideographic description characters, such as ⿰ in ⿰⺨苗, which few fonts draw.
_LAYOUT_MARKS = re.compile("[⿰-⿿㇯]")


def _read(path: Path) -> tuple[dict, dict[str, list], list[list]]:
    """The index, the characters in order, and the tags."""
    characters: dict[str, list] = {}
    tags: list[list] = []
    with zipfile.ZipFile(path) as archive:
        index = json.loads(archive.read("index.json"))
        for name in sorted(archive.namelist(), key=lambda name: int(re.sub(r"\D", "", name) or 0)):
            if name.startswith("kanji_bank_"):
                for row in json.loads(archive.read(name)):
                    characters.setdefault(row[0], row)
            elif name.startswith("tag_bank_"):
                tags.extend(json.loads(archive.read(name)))
    return index, characters, tags


def _node(tag: str, kind: str, content: object) -> dict:
    return {"tag": tag, "data": {"jdj": kind}, "content": content}


def _row(label: str, readings: list[object], separator: str = "、") -> dict:
    parts: list = [_node("span", "pill", label)]
    for number, reading in enumerate(readings):
        if number:
            parts.append(separator)
        parts.append(reading)
    return {"tag": "div", "content": parts}


def _kun(reading: str) -> object:
    """`い.く` as い with く, its okurigana, set apart."""
    stem, dot, okurigana = reading.partition(".")
    if not dot:
        return reading
    return [stem, _node("span", "okurigana", okurigana)]


def _senses(meanings: list[str]) -> dict:
    if len(meanings) == 1:
        return {"tag": "div", "content": meanings[0]}
    return _node("ol", "senses", [{"tag": "li", "content": meaning} for meaning in meanings])


def _groups(meanings: list[str]) -> list[tuple[list[str], list[str]]]:
    """The meanings under each Sino-Vietnamese reading, as `[đang] nên`
    gives them. Readings with the same meanings share a group."""
    by_reading: dict[str, list[str]] = {}
    for meaning in meanings:
        match = _PREFIX.match(meaning)
        reading, text = (match.group(1), match.group(2)) if match else ("", meaning)
        by_reading.setdefault(reading, []).append(text)
    groups: list[tuple[list[str], list[str]]] = []
    for reading, texts in by_reading.items():
        for readings, same in groups:
            if same == texts:
                readings.append(reading)
                break
        else:
            groups.append(([reading], texts))
    return groups


def entry_content(vietnamese: list, english: list | None) -> list:
    """The structured content for one character."""
    _, han_viet, _, _, meanings, stats = (vietnamese + [None] * 6)[:6]
    meanings = list(meanings or [])
    stats = dict(stats or {})
    content: list = []

    readings = [
        row for row in (
            _row(
                "Hán Việt",
                [_node("span", "han-viet", reading) for reading in (han_viet or "").split()],
                ", ",
            ),
            _row("On", (english[1] if english else "").split()),
            _row("Kun", [_kun(reading) for reading in (english[2] if english else "").split()]),
        )
        if len(row["content"]) > 1
    ]
    if readings:
        content.append(_node("div", "readings", readings))

    if meanings:
        groups = _groups(meanings)
        for readings_of, texts in groups:
            if len(groups) > 1 and any(readings_of):
                content.append(_node("div", "group", ", ".join(reading for reading in readings_of if reading)))
            content.append(_senses(texts))
    elif english and english[4]:
        content.append(_node("div", "label", "Nghĩa tiếng Anh"))
        content.append(_senses(list(english[4])))

    facts = []
    if stats.get("Strokes"):
        facts.append(f"{stats['Strokes']} nét")
    if stats.get("Radical"):
        facts.append(f"bộ {stats['Radical']}")
    parts = list(_LAYOUT_MARKS.sub("", stats.get("Shape") or ""))
    if len(parts) > 1:
        facts.append(" + ".join(parts))
    if facts:
        content.append(_node("div", "facts", " · ".join(facts)))
    return content


def combine(vietnamese_zip: Path, english_zip: Path, out_zip: Path) -> int:
    """Writes the combined dictionary; returns how many characters it has."""
    index, vietnamese, _ = _read(vietnamese_zip)
    english_index, english, english_tags = _read(english_zip)

    rows = []
    for character, row in vietnamese.items():
        known = english.get(character)
        tags = " ".join(tag for tag in (known[3] if known else "").split() if tag in TAGS)
        content = entry_content(row, known)
        if content:
            rows.append([
                character, "", "", "", 0,
                [{"type": "structured-content", "content": content}], 0, tags,
            ])
    tags = [[tag[0], tag[1], tag[2], TAGS[tag[0]], tag[4]] for tag in english_tags if tag[0] in TAGS]

    index = {
        key: value for key, value in index.items()
        # The release's own update links would bring back the copy without readings.
        if key not in ("isUpdatable", "indexUrl", "downloadUrl")
    }
    index["revision"] = str(index.get("revision", "")) + REVISION_SUFFIX
    index["sourceLanguage"] = "ja"
    index["targetLanguage"] = "vi"
    index["description"] = ". ".join(
        part for part in (
            index.get("description"),
            "Âm On, âm Kun và nghĩa tiếng Anh (cho chữ chưa có nghĩa tiếng Việt) lấy từ KANJIDIC2.",
        ) if part
    )
    index["attribution"] = " ".join(
        part if part.rstrip().endswith((".", "/")) else part.rstrip() + "."
        for part in (index.get("attribution"), english_index.get("attribution")) if part
    )

    with zipfile.ZipFile(out_zip, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("index.json", json.dumps(index, ensure_ascii=False))
        archive.writestr("tag_bank_1.json", json.dumps(tags, ensure_ascii=False))
        archive.writestr("styles.css", STYLES)
        size = 2000
        for number, start in enumerate(range(0, len(rows), size), start=1):
            archive.writestr(
                f"term_bank_{number}.json", json.dumps(rows[start:start + size], ensure_ascii=False)
            )
    return len(rows)


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    count = combine(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
    print(f"{count} characters written to {sys.argv[3]}")
