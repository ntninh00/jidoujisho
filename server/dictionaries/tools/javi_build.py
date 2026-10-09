"""Builds 「Từ điển Nhật - Việt (JMdict)」 from JMdict and the Vietnamese
translations of its common words, made with tools/javi_batches.py.

Each sense of a translated word keeps JMdict's layout, examples, notes and
cross-references, with its English meanings replaced by the Vietnamese and
the cross-references' English glosses left out. The first sense of each
spelling opens with the word's Sino-Vietnamese reading: Mazii's for the
word where it has one, otherwise each kanji's first reading in KanjiDictVN.
Words not translated are left out; older dictionaries cover them.

    python tools/javi_build.py JMDICT.zip MAZII.zip KANJIDIC_VIETNAMESE.zip \\
        BATCHES_DIR REPLIES_DIR OUT.zip
"""

from __future__ import annotations

import copy
import json
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from dictserver.tidy import word_classes  # noqa: E402
from javi_batches import _glosses, rows_of  # noqa: E402
from javi_check import check  # noqa: E402

STYLES = """/* Built by jidoujisho's tools/javi_build.py. */
[data-sc-jdj="han-viet"] {
  font-weight: bold;
  letter-spacing: 0.04em;
  margin-bottom: 0.2em;
}
"""
_KANJI = re.compile(r"[㐀-鿿豈-﫿]")
_HAN_VIET_LINE = re.compile(r"^[A-ZÀ-ỸĐ][A-ZÀ-ỸĐ\s,]*$")


def translations(batches: Path, replies: Path) -> dict[str, list[str]]:
    """Every good translation, by JMdict sequence: later replies, such as
    those to redo batches, win."""
    found: dict[str, list[str]] = {}
    for batch in sorted(batches.glob("*.txt")):
        reply = replies / batch.name
        if reply.exists():
            good, _, _ = check(batch, reply)
            found.update(good)
    return found


def english_senses(batches: Path) -> dict[str, list[str]]:
    """The English meanings each word was translated from, in order, as the
    batches give them without their word classes."""
    senses: dict[str, list[str]] = {}
    for batch in sorted(batches.glob("batch-*.txt")):
        for line in batch.read_text(encoding="utf-8").splitlines():
            if line.strip():
                word = json.loads(line)
                senses[str(word["id"])] = [re.sub(r"^\[[^\]]*\]\s*", "", sense) for sense in word["s"]]
    return senses


def han_viet_readings(mazii: Path, kanjidic: Path) -> tuple[dict[str, str], dict[str, str]]:
    """Mazii's Sino-Vietnamese line for each word, and the first reading of
    each kanji."""
    words: dict[str, str] = {}
    for row in rows_of(mazii):
        for definition in row[5]:
            if isinstance(definition, str):
                first = definition.strip().splitlines()[0].strip() if definition.strip() else ""
                if _HAN_VIET_LINE.match(first):
                    words.setdefault(row[0], first)
    kanji: dict[str, str] = {}
    with zipfile.ZipFile(kanjidic) as archive:
        for name in archive.namelist():
            if name.startswith("kanji_bank_"):
                for row in json.loads(archive.read(name)):
                    if row[1].split():
                        kanji.setdefault(row[0], row[1].split()[0])
    return words, kanji


def han_viet_of(term: str, words: dict[str, str], kanji: dict[str, str]) -> str:
    if not _KANJI.search(term):
        return ""
    if term in words:
        return words[term]
    readings = [kanji[character] for character in term if character in kanji]
    if len(readings) != len(_KANJI.findall(term)):
        return ""
    return " ".join(readings).upper()


def _split(text: str) -> list[str]:
    """Glosses separated by semicolons, not those inside brackets."""
    parts, depth, current = [], 0, ""
    for character in text:
        depth += character == "("
        depth -= character == ")" and depth > 0
        if character == ";" and depth == 0:
            parts.append(current.strip())
            current = ""
        else:
            current += character
    parts.append(current.strip())
    return [part for part in parts if part]


def _vietnamese(node: object, meanings: str) -> object:
    """JMdict's structured content for a sense, in Vietnamese."""
    if isinstance(node, list):
        return [item for item in (_vietnamese(item, meanings) for item in node) if item is not None]
    if not isinstance(node, dict):
        return node
    kind = (node.get("data") or {}).get("content")
    if kind == "glossary":
        node = {**node, "lang": "vi", "content": [{"tag": "li", "content": gloss} for gloss in _split(meanings)]}
        return node
    if kind == "refGlosses":
        return None
    node = dict(node)
    content = node.get("content")
    if isinstance(content, list) and content and content[0] == "see: ":
        content = ["xem: ", *content[1:]]
    if "content" in node:
        node["content"] = _vietnamese(content, meanings)
    if kind == "references" and node.get("lang") == "en":
        node["lang"] = "vi"
    return node


def build(jmdict: Path, mazii: Path, kanjidic: Path, batches: Path, replies: Path, out: Path) -> dict:
    vietnamese = translations(batches, replies)
    english = english_senses(batches)
    words, kanji = han_viet_readings(mazii, kanjidic)

    with zipfile.ZipFile(jmdict) as archive:
        index = json.loads(archive.read("index.json"))
        tags = json.loads(archive.read("tag_bank_1.json"))

    rows_out, left_out, opened = [], 0, set()
    for row in rows_of(jmdict):
        key = str(row[6])
        if key not in vietnamese:
            continue
        glosses: list[str] = []
        for definition in row[5]:
            _glosses(definition, glosses)
        if not glosses:
            # A row without meanings, such as a table of forms, stays.
            rows_out.append(row)
            continue
        try:
            sense = english[key].index("; ".join(glosses))
        except ValueError:
            # A meaning of another spelling only, not translated.
            left_out += 1
            continue
        content = _vietnamese(copy.deepcopy(row[5]), vietnamese[key][sense])
        spelling = (row[0], row[1])
        if spelling not in opened:
            opened.add(spelling)
            han_viet = han_viet_of(row[0], words, kanji)
            if han_viet and content and isinstance(content[0], dict):
                first = content[0]
                first["content"] = [
                    {"tag": "div", "data": {"jdj": "han-viet"}, "content": han_viet},
                    *(first["content"] if isinstance(first["content"], list) else [first["content"]]),
                ]
        rows_out.append([*row[:5], content, *row[6:]])

    for tag in tags:
        named = word_classes(tag[0])
        if named:
            tag[3] = named
    index = {
        "title": "Từ điển Nhật - Việt (JMdict)",
        "format": 3,
        "revision": f"jmdict-vi.{index.get('revision', '')}.1",
        "sequenced": True,
        "author": "EDRDG; jidoujisho",
        "sourceLanguage": "ja",
        "targetLanguage": "vi",
        "description": (
            "Các từ thông dụng của JMdict, nghĩa theo thứ tự hay dùng, dịch sang tiếng Việt "
            "(dịch máy, có tham khảo nghĩa của các từ điển Nhật - Việt cũ), kèm âm Hán Việt."
        ),
        "attribution": (
            "JMdict, Electronic Dictionaries Research Group (http://www.edrdg.org/), CC BY-SA 4.0. "
            "Vietnamese meanings machine-translated from JMdict's English. Sino-Vietnamese readings "
            "from Mazii and KanjiDictVN."
        ),
    }
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("index.json", json.dumps(index, ensure_ascii=False))
        archive.writestr("tag_bank_1.json", json.dumps(tags, ensure_ascii=False))
        archive.writestr("styles.css", STYLES)
        size = 10000
        for number, start in enumerate(range(0, len(rows_out), size), start=1):
            archive.writestr(
                f"term_bank_{number}.json",
                json.dumps(rows_out[start:start + size], ensure_ascii=False, separators=(",", ":")),
            )
    return {"words": len(vietnamese), "rows": len(rows_out), "left out": left_out, "spellings": len(opened)}


if __name__ == "__main__":
    if len(sys.argv) != 7:
        sys.exit(__doc__)
    sys.stdout.reconfigure(encoding="utf-8")
    print(build(*(Path(argument) for argument in sys.argv[1:])))
