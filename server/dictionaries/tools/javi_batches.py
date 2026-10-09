"""Batches of JMdict's common words for a model to translate into Vietnamese.

The Japanese-Vietnamese dictionaries in circulation (Mazii, JDict, Javidic)
share one old source whose meanings are in alphabetical order, mixed with
word classes and stray cross-references. JMdict has its meanings in order of
use, each with its word class. This writes its common words, most used
first, as batches of JSON lines for a model to translate, each word with the
old Vietnamese meanings as hints:

    {"id": 1259290, "w": "見る", "r": "みる",
     "s": ["[v1 vt] to see; to look; to watch; to view; to observe", ...],
     "vi": "coi | ngắm | ngó | nhìn thấy | ..."}

The model answers `{"1259290": ["nhìn; xem; ...", ...], ...}`, one
Vietnamese string for each meaning, in order.

    python tools/javi_batches.py JMDICT.zip MAZII.zip OUT_DIR [--frequency JPDB.zip]
"""

from __future__ import annotations

import argparse
import json
import re
import zipfile
from collections import defaultdict
from pathlib import Path

_CJK_ONLY = re.compile(r"^[\s　-ヿ㐀-鿿豈-﫿＀-￯]+$")
_NUMBERED = re.compile(r"^\d+\.\s*")
_HAN_VIET = re.compile(r"^[A-ZÀ-Ỹ\s]+$")


def rows_of(path: Path) -> list[list]:
    rows: list[list] = []
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if name.startswith("term_bank_"):
                rows.extend(json.loads(archive.read(name)))
    return rows


def _glosses(node: object, out: list[str], inside: bool = False) -> None:
    """The glossary items of a JMdict sense, without its examples."""
    if isinstance(node, list):
        for item in node:
            _glosses(item, out, inside)
    elif isinstance(node, dict):
        if node.get("type") == "structured-content":
            _glosses(node.get("content"), out, inside)
            return
        kind = (node.get("data") or {}).get("content")
        if kind == "examples":
            return
        here = inside or kind == "glossary"
        if here and node.get("tag") == "li":
            out.append(_text(node.get("content")))
            return
        _glosses(node.get("content"), out, here)


def _text(node: object) -> str:
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "".join(_text(item) for item in node)
    if isinstance(node, dict):
        return _text(node.get("content"))
    return ""


def _english(line: str) -> bool:
    """Whether a meaning without accents is English, as some were filled
    in from it: Vietnamese words end in a vowel or c, ch, m, n, ng, nh, p
    or t, and have no f, j, w or z."""
    if not line.isascii():
        return False
    words = re.findall(r"[a-z]+", line.lower())
    return len(words) >= 3 or any(
        re.search("[fjwz]", word)
        or not (word[-1] in "aeiouy" or word.endswith(("c", "ch", "m", "n", "ng", "nh", "p", "t")))
        for word in words
    )


def hint_of(definitions: list) -> str:
    """Mazii's meanings, one per line after its Sino-Vietnamese line, without
    numbers, stray full stops, lines that are only kanji, and those it took
    from English."""
    meanings = []
    for definition in definitions:
        if not isinstance(definition, str):
            continue
        for line in definition.splitlines():
            line = line.strip()
            if not line or _HAN_VIET.match(line):
                continue
            line = _NUMBERED.sub("", line).rstrip(" .").strip()
            if line and not _english(line) and not _CJK_ONLY.match(line):
                meanings.append(line)
    return " | ".join(meanings)


def ranks_of(path: Path) -> dict[str, int]:
    """Each word's place in a frequency list, 1 for the most used, by
    spelling and by spelling and reading."""
    ranks: dict[str, int] = {}
    with zipfile.ZipFile(path) as archive:
        for name in archive.namelist():
            if not name.startswith("term_meta_bank_"):
                continue
            for term, mode, data in json.loads(archive.read(name)):
                if mode != "freq" or not isinstance(data, dict):
                    continue
                reading = data.get("reading")
                value = data.get("frequency", data)
                value = value.get("value") if isinstance(value, dict) else value
                if not isinstance(value, (int, float)):
                    continue
                for key in (term, f"{term}	{reading}" if reading else None):
                    if key and (key not in ranks or value < ranks[key]):
                        ranks[key] = int(value)
    return ranks


def words(jmdict: Path, mazii: Path, frequency: Path | None = None) -> list[dict]:
    """JMdict's common words, most used first, with Mazii's meanings."""
    ranks = ranks_of(frequency) if frequency else {}
    by_sequence: dict[int, list[list]] = defaultdict(list)
    for row in rows_of(jmdict):
        by_sequence[row[6]].append(row)
    hints: dict[tuple[str, str], str] = {}
    hints_by_term: dict[str, str] = {}
    for row in rows_of(mazii):
        hint = hint_of(row[5])
        if hint:
            hints.setdefault((row[0], row[1]), hint)
            hints_by_term.setdefault(row[0], hint)

    found = []
    for sequence, rows in by_sequence.items():
        if not any("⭐" in row[7].split() for row in rows):
            continue
        first = rows[0]
        senses = []
        for row in rows:
            if (row[0], row[1]) != (first[0], first[1]):
                continue
            glosses: list[str] = []
            for definition in row[5]:
                _glosses(definition, glosses)
            if not glosses:
                continue
            kinds = " ".join(tag for tag in row[2].split() if not tag.isdigit())
            senses.append(f"[{kinds}] " + "; ".join(glosses) if kinds else "; ".join(glosses))
        if not senses:
            continue
        word = {"id": sequence, "w": first[0], "r": first[1], "s": senses}
        hint = hints.get((first[0], first[1])) or hints_by_term.get(first[0])
        if hint:
            word["vi"] = hint[:240]
        rank = min(
            (ranks.get(f"{row[0]}	{row[1]}") or ranks.get(row[0]) or 10**9 for row in rows),
            default=10**9,
        )
        found.append(((rank, -max(row[4] for row in rows), sequence), word))
    found.sort(key=lambda item: item[0])
    return [word for _, word in found]


def write_batches(found: list[dict], out: Path, size: int) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    batches: list[list[str]] = [[]]
    length = 0
    for word in found:
        line = json.dumps(word, ensure_ascii=False, separators=(",", ":"))
        if batches[-1] and length + len(line) + 1 > size:
            batches.append([])
            length = 0
        batches[-1].append(line)
        length += len(line) + 1
    paths = []
    for number, lines in enumerate(batches, start=1):
        path = out / f"batch-{number:03d}.txt"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("jmdict", type=Path)
    parser.add_argument("mazii", type=Path)
    parser.add_argument("out", type=Path)
    parser.add_argument("--frequency", type=Path, help="a Yomitan frequency list to order words by")
    parser.add_argument("--size", type=int, default=30000, help="most characters in one batch")
    arguments = parser.parse_args()
    found = words(arguments.jmdict, arguments.mazii, arguments.frequency)
    paths = write_batches(found, arguments.out, arguments.size)
    with_hint = sum(1 for word in found if "vi" in word)
    print(f"{len(found)} words ({with_hint} with hints) in {len(paths)} batches")
