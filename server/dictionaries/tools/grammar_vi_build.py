"""Builds 「Ngữ pháp tiếng Nhật N3」 from the grammar.json of
github.com/emgaimua123/japanese-n3-learning (MIT): 151 N3 patterns with
their meaning, forms and notes in Vietnamese, examples, and practice
sentences with their Vietnamese.

Each pattern is a grammar point laid out as dictserver/grammar.py lays out
the others, looked up by each way it is written: ～こともある / ～ことがある
under both. A pattern with a gap, as ～ば～ほど, is looked up by its longest
piece. Patterns written the same way share an entry, one meaning each.

    python tools/grammar_vi_build.py GRAMMAR.json OUT.zip [REVISION]
"""

from __future__ import annotations

import json
import re
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from dictserver import grammar  # noqa: E402

TITLE = "Ngữ pháp tiếng Nhật N3"
# Patterns the source wrote short or with a gap no piece of says much.
KEYS = {
    "～ば～ほど": ["ほど"],
    "～も〜ば、〜も": ["も"],
    "～ないことは ( も": ["ないことはない", "ないこともない"],
    "～というより ( も": ["というより", "というよりも"],
    "～をもとに ( して": ["をもとに", "をもとにして"],
    "～を通して / ～を通": ["を通して", "を通じて"],
    "～くらい / ほど～はない": ["くらい", "ほど"],
    "～ほど～ない": ["ほど"],
    "～など～なんか～なんて": ["など", "なんか", "なんて"],
    "～から～にかけて": ["にかけて"],
    "〜さえ～ば": ["さえ"],
    "ちっとも～ない": ["ちっとも"],
}
_OPTIONAL = re.compile(r"\s*[（(]\s*([^）)]*?)\s*(?:[）)]|$)")


def keys_of(pattern: str) -> list[str]:
    """What a pattern is looked up by."""
    if pattern in KEYS:
        return KEYS[pattern]
    keys: list[str] = []
    for written in re.split(r"\s*[/／]\s*", pattern):
        written = re.sub(r"^V\s+", "", written.strip())
        optional = _OPTIONAL.search(written)
        forms = [written]
        if optional:
            before, after = written[: optional.start()], written[optional.end():]
            forms = [before + after, before + optional.group(1) + after]
        for form in forms:
            pieces = [piece.strip() for piece in re.split(r"[～〜]", form) if piece.strip()]
            if pieces:
                key = max(pieces, key=len)
                if key not in keys:
                    keys.append(key)
    return keys


def rules_of(key: str) -> str:
    """How the pattern inflects, for the app to find it conjugated: する and
    くる by their own rules, ない and adjectives as い adjectives, and verbs
    by their last sound; one ending in る after an i or e sound may be
    either kind. Particles that only look like endings, as だろう, don't."""
    if key.endswith("する"):
        return "vs"
    if key.endswith("くる"):
        return "vk"
    if key.endswith(("ない", "たい", "っぽい", "がたい", "らしい", "いい")):
        return "adj-i"
    if key.endswith(("いう", "思う", "おく", "いく", "す", "つ", "む", "ぶ", "ぬ", "ぐ")):
        return "v5"
    if key.endswith("る"):
        before = key[-2] if len(key) > 1 else ""
        if before in "いきぎしじちぢにひびぴみりえけげせぜてでねへべぺめれ":
            return "v1 v5"
        return "v5"
    return ""


# Readings of the kanji in the patterns, so text written in kana finds them.
READINGS = {
    "中心": "ちゅうしん", "対して": "たいして", "従って": "したがって", "関して": "かんして",
    "一方": "いっぽう", "最中": "さいちゅう", "代わり": "かわり", "途中": "とちゅう",
    "以来": "いらい", "何か": "なにか", "違い": "ちがい", "相違": "そうい", "比べて": "くらべて",
    "込めて": "こめて", "通して": "とおして", "通じて": "つうじて", "言われて": "いわれて",
    "決まって": "きまって", "限らない": "かぎらない", "限る": "かぎる", "思った": "おもった",
    "上で": "うえで", "点で": "てんで", "続ける": "つづける", "直す": "なおす",
}


def reading_of(key: str) -> str:
    for written, reading in READINGS.items():
        key = key.replace(written, reading)
    return key


def point_of(item: dict, keys: list[str]) -> grammar.Point:
    point = grammar.Point(title=item["pattern"], level="N3")
    if item.get("meaning"):
        point.meanings.append(item["meaning"])
    point.add("Cấu trúc", "forms", [grammar.Form(form) for form in item.get("forms", []) if form.strip()])
    point.add("Giải thích", "text", [note for note in item.get("notes", []) if note.strip()])
    examples = [grammar.Example(grammar.marked(example["jp"], keys)) for example in item.get("examples", []) if example.get("jp")]
    examples += [
        grammar.Example(grammar.marked(drill["jp"], keys), drill.get("vi", ""))
        for drill in item.get("drills", []) if drill.get("jp")
    ]
    point.add("Ví dụ", "examples", examples)
    return point


def build(items: list[dict], out: Path, revision: str) -> int:
    entries: dict[str, list] = {}
    for item in items:
        keys = keys_of(item["pattern"])
        structured = grammar.to_structured(point_of(item, keys))
        for key in keys:
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
        "author": "emgaimua123",
        "url": "https://github.com/emgaimua123/japanese-n3-learning",
        "description": "151 mẫu ngữ pháp JLPT N3: cấu trúc, ý nghĩa, giải thích và ví dụ có dịch tiếng Việt.",
        "attribution": "japanese-n3-learning, MIT License",
        "sourceLanguage": "ja",
        "targetLanguage": "vi",
    }
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as archive:
        archive.writestr("index.json", json.dumps(index, ensure_ascii=False, indent=2))
        archive.writestr("term_bank_1.json", json.dumps(rows, ensure_ascii=False))
        archive.writestr("styles.css", grammar.STYLES)
    return len(rows)


if __name__ == "__main__":
    source, target = Path(sys.argv[1]), Path(sys.argv[2])
    revision = sys.argv[3] if len(sys.argv) > 3 else "n3vi.1"
    count = build(json.loads(source.read_text(encoding="utf-8")), target, revision)
    print(f"{count} entries -> {target}")
