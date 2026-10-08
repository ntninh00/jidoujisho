"""Lays out dictionaries whose definitions are text with markup in it.

Many Vietnamese dictionaries reached Yomitan as plain text that carries its
own structure, which a popup shows as a wall of punctuation:

    @house /haus/
    * danh từ, số nhiều houses
    - nhà ở, căn nhà, toà nhà
    =the house of God+ nhà thờ
    !to keep house
    - quản lý việc nhà

That is a pronunciation, parts of speech, numbered meanings, idioms and worked
examples with their translations. This rewrites such a dictionary's entries
into Yomitan's structured content, with a small stylesheet, so the app, the
preview here and Yomitan itself lay them out. The rules come from Cluebook's
`lib/vocab/parse.ts`, which studied these exports first.

Only dictionaries with Vietnamese definitions are touched: English
dictionaries use some of the same characters for other things.
"""

import json
import re
import shutil
import unicodedata
import zipfile
from dataclasses import dataclass, field
from pathlib import Path

from .checks import BANK

# Marks the revision of a rewritten dictionary, so copies installed before
# show as out of date.
REVISION_SUFFIX = "+jdj1"

_VIETNAMESE_ONLY = set("ăđơưĂĐƠƯ") | {chr(code) for code in range(0x1EA0, 0x1EFA)}
_PLACEHOLDER = re.compile(r"^\?+$")
_CODE = re.compile(r"`(\d+)`")
_HAN = re.compile(r"[㐀-䶿一-鿿]")
_MARKER = re.compile(r"^\s*([-*=═@!▫•→]|Ex:)", re.M)

STYLES = """/* Laid out by jidoujisho's dictionary server from the dictionary's own
   text markup. Colours follow the popup's theme. */
[data-sc-jdj="ipa"] {
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
  margin-bottom: 0.25em;
}
[data-sc-jdj="label"] {
  font-size: 0.8em;
  font-weight: bold;
  text-transform: uppercase;
  color: color-mix(in srgb, var(--text-color) 60%, var(--background-color));
  margin-top: 0.5em;
  margin-bottom: 0.15em;
}
[data-sc-jdj="idiom"] {
  font-weight: bold;
  font-style: italic;
  margin-top: 0.5em;
  margin-bottom: 0.1em;
}
[data-sc-jdj="senses"] {
  margin-top: 0;
  margin-bottom: 0;
  padding-left: 1.4em;
}
[data-sc-jdj="examples"] {
  list-style-type: none;
  margin-top: 0.1em;
  margin-bottom: 0.35em;
  padding-left: 0.7em;
}
[data-sc-jdj="translation"], [data-sc-jdj="via"] {
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
}
[data-sc-jdj="via"] {
  font-style: italic;
}
"""


@dataclass
class Example:
    text: str
    translation: str = ""


@dataclass
class Sense:
    gloss: str
    examples: list[Example] = field(default_factory=list)


@dataclass
class Section:
    label: str
    # "pos", "domain", "idiom" or "general".
    kind: str
    senses: list[Sense] = field(default_factory=list)


@dataclass
class Body:
    pronunciation: str = ""
    sections: list[Section] = field(default_factory=list)


class _Builder:
    """Lines arrive one at a time, and each belongs to whichever sense and
    section came before it."""

    def __init__(self) -> None:
        self.body = Body()

    def section(self, label: str, kind: str) -> None:
        self.body.sections.append(Section(label, kind))

    def _current(self) -> Section:
        if not self.body.sections:
            self.section("", "general")
        return self.body.sections[-1]

    def sense(self, gloss: str) -> None:
        self._current().senses.append(Sense(gloss))

    def example(self, example: Example) -> None:
        """Joins the sense above, opening a bare one when the source puts an
        example before any meaning."""
        section = self._current()
        if not section.senses:
            section.senses.append(Sense(""))
        section.senses[-1].examples.append(example)

    def last_example(self) -> Example | None:
        if self.body.sections and self.body.sections[-1].senses:
            examples = self.body.sections[-1].senses[-1].examples
            return examples[-1] if examples else None
        return None

    def carry_on(self, text: str) -> None:
        """Adds to the open meaning, for sources that wrap one across lines."""
        if self.body.sections and self.body.sections[-1].senses:
            sense = self.body.sections[-1].senses[-1]
            if not sense.examples:
                sense.gloss = f"{sense.gloss} {text}".strip()
                return
        self.sense(text)

    def finish(self) -> Body:
        for section in self.body.sections:
            section.senses = [sense for sense in section.senses if sense.gloss or sense.examples]
        self.body.sections = [
            section for section in self.body.sections if section.senses or section.kind == "idiom"
        ]
        return self.body


def _split_example(body: str) -> Example:
    """`the house of God+ nhà thờ`, or two spaces between the halves as some
    exports write it. Kept whole when neither is there: no rule finds where
    an untranslated phrase ends."""
    if "+" in body:
        text, translation = body.split("+", 1)
        return Example(text.strip(), translation.strip())
    halves = re.split(r"\s{2,}", body.strip(), maxsplit=1)
    if len(halves) == 2:
        return Example(halves[0].strip(), halves[1].strip())
    return Example(body.strip())


def parse_markup(definitions: list[str]) -> Body:
    """The OVDP grammar and its relatives.

    `@` opens the headword line, which carries the pronunciation, and also a
    subject heading, told apart by the slashes. `*` is a part of speech, `!`
    an idiom whose meanings follow, `-` a meaning, and `=` an example with
    `+` before its translation. Other exports write the same grammar with
    other glyphs: `═` for `=`; `▫` and `•` for examples and idioms; `•` alone
    for meanings when there are no `-` lines; `Ex:` with the translation in
    braces; `→` with the translation on the next line; an indented example
    with the translation on the next line.
    """
    builder = _Builder()
    raw = "\n".join(definitions).split("\n")
    bullets_are_idioms = any(line.lstrip().startswith("-") for line in raw)
    awaiting = False

    for line in raw:
        text = line.strip()
        if not text or _PLACEHOLDER.match(text):
            continue

        if awaiting:
            awaiting = False
            example = builder.last_example()
            if example is not None and not _MARKER.match(text) and not line[:2].isspace():
                example.translation = text
                continue

        if text.startswith("@"):
            rest = text[1:].strip()
            ipa = re.search(r"/([^/]+)/\s*$", rest)
            if ipa:
                builder.body.pronunciation = builder.body.pronunciation or ipa.group(1).strip()
            elif rest:
                builder.section(rest, "domain")
            continue
        if text.startswith("*"):
            label = text[1:].strip()
            if label:
                builder.section(label, "pos")
            continue
        if text.startswith("!") or (text.startswith("•") and bullets_are_idioms):
            label = text[1:].strip()
            if label:
                builder.section(label, "idiom")
            continue
        if text.startswith(("=", "═")):
            builder.example(_split_example(text.lstrip("=═")))
            continue
        if text.startswith("▫"):
            builder.example(Example(text[1:].strip()))
            continue
        if text.startswith("Ex:"):
            body = text[3:].strip()
            match = re.match(r"^(.*?)\s*\{([^{}]*)\}\s*$", body)
            builder.example(Example(match.group(1), match.group(2)) if match else _split_example(body))
            continue
        if text.startswith("→"):
            builder.example(Example(text[1:].strip()))
            awaiting = True
            continue
        if text.startswith(("-", "•")):
            gloss = text[1:].strip()
            if gloss:
                builder.sense(gloss)
            continue
        bare = re.fullmatch(r"/([^/]+)/", text)
        if bare:
            builder.body.pronunciation = builder.body.pronunciation or bare.group(1).strip()
            continue
        domain = re.fullmatch(r"\(([^()]+)\)", text)
        if domain and not builder.body.sections:
            builder.section(domain.group(1).strip(), "domain")
            continue
        if line[:2].isspace() and builder.body.sections:
            builder.example(Example(text))
            awaiting = True
            continue
        builder.carry_on(text)

    return builder.finish()


def parse_babylon(definitions: list[str]) -> Body:
    """Babylon exports open with the headword or its reading in brackets,
    which the popup shows already. Chinese ones then give the meaning, and
    pairs of lines: an example in Chinese and its translation."""
    builder = _Builder()
    for definition in definitions:
        lines = [line.strip() for line in re.sub(r"^\s*\[[^\]]*\]\s*", "", definition).split("\n")]
        lines = [line for line in lines if line and not _PLACEHOLDER.match(line)]
        if not lines:
            continue
        builder.sense(lines[0])
        rest = lines[1:]
        if all(_HAN.search(line) for line in rest[0::2]) and not any(_HAN.search(line) for line in rest[1::2]):
            for at in range(0, len(rest), 2):
                translation = rest[at + 1] if at + 1 < len(rest) else ""
                builder.example(Example(rest[at], translation))
        else:
            for line in rest:
                builder.carry_on(line)
    return builder.finish()


_WORD = re.compile(r"[A-Za-z]+")


def _english_tail(text: str, vocabulary: set[str], term: str) -> int | None:
    """Where an English phrase starts at the end of [text], which Prodict ran
    straight on from Vietnamese: `nhà bằng trebasement house` holds `basement
    house`. The phrase is the longest tail that starts where two words were
    run together and whose words are all English, as the dictionary's own
    headwords spell them, and that has the headword in it."""
    last_vietnamese = max((at for at, ch in enumerate(text) if ord(ch) > 0x7F), default=-1)
    for at in range(last_vietnamese + 1, len(text)):
        if not text[at].isalnum():
            continue
        before = text[at - 1] if at else " "
        if at and (before.isspace() or before.isdigit()):
            continue
        tail = text[at:]
        if term and term.lower() not in tail.lower():
            continue
        # `nhà tắm (công cộng)block of house` holds `block of house`, not
        # `ng)block of house`: a phrase closes only brackets it opened.
        if tail.count("(") != tail.count(")"):
            continue
        words = re.findall(r"[A-Za-z0-9]+", tail)
        if not words or (len(words[0]) < 2 and not words[0].isdigit()):
            continue
        if all(any(ch.isdigit() for ch in word) or word.lower() in vocabulary for word in words):
            return at
    return None


def _prodict_segment(segment: str, vocabulary: set[str], term: str) -> tuple[str, list[Example]]:
    """A meaning and the phrases run on after it:
    `hãngbusiness house: hãng buônhouse flag: cờ hãng` is `hãng` with
    `business house` (hãng buôn) and `house flag` (cờ hãng)."""
    pieces = segment.split(": ")
    if len(pieces) == 1:
        return segment, []
    at = _english_tail(pieces[0], vocabulary, term)
    if at is None:
        return segment, []
    gloss, phrase = pieces[0][:at].strip(), pieces[0][at:].strip()
    examples = []
    for piece in pieces[1:-1]:
        at = _english_tail(piece, vocabulary, term)
        if at is None:
            # The next phrase can't be told from this translation: keep
            # them together rather than split in the wrong place.
            phrase = f"{phrase}: {piece}"
            continue
        examples.append(Example(phrase, piece[:at].strip()))
        phrase = piece[at:].strip()
    examples.append(Example(phrase, pieces[-1].strip()))
    return gloss, examples


def parse_prodict(definitions: list[str], term: str, vocabulary: set[str] | None = None) -> Body:
    """Prodict marks lines with codes: `1` repeats the headword and `4` gives
    the field, then its meanings separated by no-break spaces. Phrases with
    their translations run straight on after a meaning, with nothing between
    one translation and the next phrase."""
    vocabulary = vocabulary or set()
    builder = _Builder()
    for definition in definitions:
        for code, text in re.findall(r"`(\d+)`([^`]*)", definition):
            if code == "1":
                continue
            parts = [part.strip() for part in text.split("\xa0") if part.strip()]
            if parts and parts[0].startswith("Lĩnh vực:"):
                builder.section(parts.pop(0).removeprefix("Lĩnh vực:").strip(), "domain")
            for part in parts:
                gloss, examples = _prodict_segment(part, vocabulary, term)
                if gloss:
                    builder.sense(gloss)
                for example in examples:
                    builder.example(example)
    return builder.finish()


def _gloss(text: str) -> object:
    """A meaning, with a leading `{English}` that some exports go through
    set apart."""
    match = re.match(r"^\{([^{}]+)\}\s*(.*)$", text)
    if not match:
        return text
    rest = match.group(2)
    via = {"tag": "span", "data": {"jdj": "via"}, "content": match.group(1)}
    return [via, " " + rest] if rest else via


def _node(tag: str, kind: str, content: object) -> dict:
    return {"tag": tag, "data": {"jdj": kind}, "content": content}


def to_structured(body: Body) -> dict | None:
    """The entry as Yomitan structured content, or None when nothing was
    understood."""
    if not body.sections:
        return None
    content: list = []
    if body.pronunciation:
        content.append(_node("div", "ipa", f"/{body.pronunciation}/"))
    for section in body.sections:
        parts: list = []
        if section.label:
            parts.append(_node("div", "idiom" if section.kind == "idiom" else "label", section.label))
        items = []
        for sense in section.senses:
            item: list = []
            if sense.gloss:
                item.append(_node("div", "gloss", _gloss(sense.gloss)))
            if sense.examples:
                item.append(_node("ul", "examples", [
                    {"tag": "li", "content": [
                        _node("div", "example", example.text),
                        *([_node("div", "translation", example.translation)] if example.translation else []),
                    ]}
                    for example in sense.examples
                ]))
            items.append(item)
        if len(items) == 1:
            parts.extend(items[0])
        elif items:
            parts.append(_node("ol", "senses", [{"tag": "li", "content": item} for item in items]))
        content.append(_node("div", "section", parts))
    return {"type": "structured-content", "content": content}


def _texts(row: list) -> list[str]:
    return [item for item in row[5] if isinstance(item, str)] if len(row) > 5 and isinstance(row[5], list) else []


def detect(rows: list) -> str | None:
    """Which layout a dictionary's term rows call for, if any: judged on a
    sample, and only for definitions written in Vietnamese."""
    texts = [text for row in rows if isinstance(row, list) for text in _texts(row)]
    if not texts:
        return None
    vietnamese = sum(any(ch in _VIETNAMESE_ONLY for ch in text) for text in texts)
    if vietnamese / len(texts) < 0.05:
        return None
    if sum(bool(_CODE.search(text)) for text in texts) / len(texts) > 0.5:
        return "prodict"
    if sum(bool(re.match(r"^\s*\[[^\]]+\]", text)) for text in texts) / len(texts) > 0.5:
        return "babylon"
    marked = sum(bool(_MARKER.search(text)) or bool(re.search(r"^ {2,}\S", text, re.M)) for text in texts)
    if marked / len(texts) >= 0.1:
        return "markup"
    return None


def rewrite_row(row: list, layout: str, vocabulary: set[str] | None = None) -> list:
    """[row] with its text definitions laid out, or as it was when nothing in
    them was understood. Other definitions, such as structured content or
    an inflected form's pointer, stay as they are."""
    # Letters written as a base and a separate accent, as some exports do,
    # are joined so every font draws them.
    texts = [unicodedata.normalize("NFC", text) for text in _texts(row)]
    if not texts:
        return row
    term = row[0] if isinstance(row[0], str) else ""
    if layout == "prodict":
        body = parse_prodict(texts, term, vocabulary)
    elif layout == "babylon":
        body = parse_babylon(texts)
    else:
        body = parse_markup(texts)
    structured = to_structured(body)
    if structured is None:
        return row
    others = [item for item in row[5] if not isinstance(item, str)]
    return [*row[:5], [structured, *others], *row[6:]]


def _sample_rows(archive: zipfile.ZipFile, limit: int = 600, banks: int = 8) -> list:
    """Rows from up to [banks] term banks spread through the dictionary, so
    one that opens with a different kind of entry is judged on all of it."""
    names = sorted(
        (name for name in archive.namelist() if (match := BANK.match(name)) and match.group(1) == "term"),
        key=lambda name: int(re.search(r"(\d+)", name).group(1)),
    )
    if len(names) > banks:
        names = [names[round(at * (len(names) - 1) / (banks - 1))] for at in range(banks)]
    per_bank = max(1, limit // max(1, len(names)))
    rows: list = []
    for name in names:
        try:
            bank = json.loads(archive.read(name).decode("utf-8-sig"))
        except (ValueError, zipfile.BadZipFile, OSError):
            continue
        if isinstance(bank, list):
            step = max(1, len(bank) // per_bank)
            rows.extend(bank[::step][:per_bank])
    return rows


def _vocabulary(archive: zipfile.ZipFile) -> set[str]:
    """The words of every headword in a dictionary, lower-cased: what counts
    as English in it."""
    words: set[str] = set()
    for name in archive.namelist():
        match = BANK.match(name)
        if match and match.group(1) == "term":
            for row in json.loads(archive.read(name).decode("utf-8-sig")):
                if isinstance(row, list) and row and isinstance(row[0], str):
                    words.update(word.lower() for word in _WORD.findall(row[0]))
    return words


def layout_of(zip_path: Path) -> str | None:
    with zipfile.ZipFile(zip_path) as archive:
        return detect(_sample_rows(archive))


def apply(zip_path: Path) -> str | None:
    """Rewrites the dictionary at [zip_path] when its definitions have a
    layout this understands, keeping the original beside it as
    `original.zip`. Returns the layout, or None when nothing was done."""
    layout = layout_of(zip_path)
    if layout is None:
        return None
    temp = zip_path.with_name("tidy.zip")
    with zipfile.ZipFile(zip_path) as source, zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as target:
        names = set(source.namelist())
        vocabulary = _vocabulary(source) if layout == "prodict" else None
        for info in source.infolist():
            data = source.read(info)
            match = BANK.match(info.filename)
            if match and match.group(1) == "term":
                rows = json.loads(data.decode("utf-8-sig"))
                rows = [rewrite_row(row, layout, vocabulary) if isinstance(row, list) else row for row in rows]
                data = json.dumps(rows, ensure_ascii=False, separators=(",", ":")).encode()
            elif info.filename == "index.json":
                index = json.loads(data.decode("utf-8-sig"))
                index["revision"] = f"{index.get('revision', '')}{REVISION_SUFFIX}"
                data = json.dumps(index, ensure_ascii=False, indent=2).encode()
            elif info.filename == "styles.css":
                data = data + b"\n" + STYLES.encode()
            target.writestr(info.filename, data)
        if "styles.css" not in names:
            target.writestr("styles.css", STYLES)
    original = zip_path.with_name("original.zip")
    shutil.move(zip_path, original)
    shutil.move(temp, zip_path)
    return layout
