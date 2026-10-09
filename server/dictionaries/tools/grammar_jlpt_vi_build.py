"""Builds 「Ngữ pháp tiếng Nhật N5–N1」 from hanabira.org's JLPT grammar
(github.com/tristcoil/hanabira.org, MIT) and a model's Vietnamese for it,
made with tools/grammar_vi_batches.py and checked with grammar_vi_check.py.

Each point is laid out as dictserver/grammar.py lays out the others: its
pattern and level, meaning, formation, explanation, and its examples in
Japanese with their Vietnamese. It is looked up by the forms the model
gave; points looked up the same way share an entry. Points not translated
yet are left out, and so are the few found only by a kana that begins
too many other words.

    python tools/grammar_jlpt_vi_build.py HANABIRA_JSON_DIR BATCHES_DIR REPLIES_DIR OUT.zip [REVISION]
"""

from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
sys.path.insert(0, str(Path(__file__).resolve().parent))

from dictserver import grammar  # noqa: E402
from grammar_vi_batches import points  # noqa: E402
from grammar_vi_build import reading_of, rules_of  # noqa: E402
from grammar_vi_check import translated  # noqa: E402

TITLE = "Ngữ pháp tiếng Nhật N5–N1"
# Lookup forms that begin too many other words (くれる, さん, した): a tap on
# any of those would bring the point up. Particles stay: tapping one to see
# its grammar is what a beginner wants.
_TOO_COMMON = {"く", "さ", "つ", "し"}
# A sentence the translation kept from the English source about how to
# say the pattern in English, which says nothing to a Vietnamese reader.
_ABOUT_ENGLISH = re.compile(r"tiếng Anh", re.IGNORECASE)
# The English words of hanabira's titles, in the notation of Vietnamese books.
_NOTATION = [
    (r"い-Adjective", "Aい"), (r"な-Adjective", "Aな"), (r"\bAdjective\b", "A"),
    (r"\bVerb\b", "V"), (r"\bNoun\b", "N"),
]


def title_of(title: str) -> str:
    for english, notation in _NOTATION:
        title = re.sub(english, notation, title)
    return title


def keys_of(answer: dict) -> list[str]:
    return [key for key in dict.fromkeys(answer["k"]) if key not in _TOO_COMMON]


def explanation_of(text: str) -> str:
    """The explanation without its sentences about English."""
    sentences = re.split(r"(?<=[.!?…])\s+", text.strip())
    return " ".join(sentence for sentence in sentences if not _ABOUT_ENGLISH.search(sentence))


def point_of(source: dict, answer: dict) -> grammar.Point:
    keys = keys_of(answer)
    point = grammar.Point(title=title_of(source["t"]), level=source["id"].split("-")[0])
    point.meanings.append(answer["m"].strip())
    point.add("Cấu trúc", "forms", [grammar.Form(form.strip()) for form in answer["f"].split(";") if form.strip()])
    explanation = explanation_of(answer["l"])
    point.add("Giải thích", "text", [explanation] if explanation else [])
    point.add("Ví dụ", "examples", [
        grammar.Example(grammar.marked(japanese, keys), vietnamese.strip())
        for (japanese, _), vietnamese in zip(source["ex"], answer["ex"])
    ])
    return point


def build(sources: list[dict], answers: dict[str, dict], out: Path, revision: str) -> tuple[int, int]:
    entries: dict[str, list] = {}
    built = 0
    for source in sources:
        answer = answers.get(source["id"])
        if answer is None or not keys_of(answer):
            continue
        structured = grammar.to_structured(point_of(source, answer))
        built += 1
        for key in keys_of(answer):
            entries.setdefault(key, []).append(structured)
    rows = [
        [key, reading_of(key), "", rules_of(key), 0, definitions, number, ""]
        for number, (key, definitions) in enumerate(entries.items(), 1)
    ]
    index = {
        "title": TITLE,
        "revision": revision,
        "format": 3,
        "sequenced": True,
        "author": "hanabira.org",
        "url": "https://github.com/tristcoil/hanabira.org",
        "description": f"{built} mẫu ngữ pháp JLPT từ N5 đến N1: ý nghĩa, cấu trúc, giải thích và ví dụ có dịch tiếng Việt.",
        "attribution": "hanabira.org, MIT License; bản dịch tiếng Việt",
        "sourceLanguage": "ja",
        "targetLanguage": "vi",
    }
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("index.json", json.dumps(index, ensure_ascii=False, indent=2))
        archive.writestr("term_bank_1.json", json.dumps(rows, ensure_ascii=False))
        archive.writestr("styles.css", grammar.STYLES)
    return built, len(rows)


if __name__ == "__main__":
    source, batches, replies, target = (Path(argument) for argument in sys.argv[1:5])
    revision = sys.argv[5] if len(sys.argv) > 5 else "jlptvi.1"
    built, rows = build(points(source), translated(batches, replies), target, revision)
    print(f"{built} points under {rows} entries -> {target}")
