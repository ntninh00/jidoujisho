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

Text is laid out in dictionaries with Vietnamese definitions, and in the
English dictionaries english.py knows: English dictionaries use some of the
same characters for other things.

Definitions written as HTML in plain text, such as `<b>rosa f</b><ol><li>
rose</li></ol>`, are rewritten in any language: Yomitan shows text as text,
tags and all. So are inflected forms, `["strap", ["participle present"]]`,
which Yomitan follows to the word itself but the app has no way to show:
they become a link to that word.
"""

import hashlib
import json
import re
import shutil
import unicodedata
import zipfile
from dataclasses import dataclass, field
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import quote

from .checks import BANK

# The rules below, numbered: a dictionary laid out by older ones is laid out
# again from its original when the server starts.
# Each layout's rules have their own number, and so does finding a layout
# (`none`), so a new layout looks again only at dictionaries that had none.
VERSIONS = {
    "markup": 4, "babylon": 4, "prodict": 3, "html": 1,
    "jmarkup": 1, "javidic": 1, "mazii": 1, "forms": 2,
    "wordset": 1, "cambridge": 2, "noad": 1, "macmillan": 1, "mwald": 1, "none": 8,
}
# Layouts of dictionaries whose definitions are in Vietnamese.
_VIETNAMESE_LAYOUTS = {"markup", "babylon", "prodict", "jmarkup", "javidic", "mazii"}
# Layouts of English dictionaries' own text, in english.py.
ENGLISH_LAYOUTS = {"wordset", "cambridge", "noad", "macmillan", "mwald"}
_SUFFIX = re.compile(r"\+jdj\d+$")


def revision_suffix(layout: str) -> str:
    """Marks the revision of a dictionary [layout] rewrote, so copies
    installed before show as out of date, until its rules change again."""
    return f"+jdj{VERSIONS[layout]}"


# What the markup layouts mark revisions with.
REVISION_SUFFIX = revision_suffix("markup")


def stamp(layout: str | None) -> str:
    """What the catalog records: the layout, or `none`, and the rules' number."""
    name = layout or "none"
    return f"{name}@{VERSIONS[name]}"


def is_current(recorded: str | None) -> bool:
    name, _, number = (recorded or "").rpartition("@")
    return name in VERSIONS and number == str(VERSIONS[name])


def base_revision(revision: str) -> str:
    """The revision a dictionary was uploaded as."""
    return _SUFFIX.sub("", revision)

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
[data-sc-jdj="note"] {
  font-size: 0.9em;
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
  margin-top: 0.1em;
  margin-bottom: 0.2em;
}
[data-sc-jdj="han-viet"] {
  font-weight: bold;
  letter-spacing: 0.04em;
  margin-bottom: 0.25em;
}
[data-sc-jdj="refs"] {
  font-size: 0.9em;
  margin-top: 0.1em;
}
[data-sc-jdj="html-example"] {
  margin-top: 0.1em;
  margin-bottom: 0.3em;
  padding-left: 0.7em;
}
[data-sc-jdj="facts"] {
  font-size: 0.9em;
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
  margin-bottom: 0.25em;
}
[data-sc-jdj="form-labels"] {
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
}
[data-sc-jdj="grammar"] {
  font-size: 0.85em;
  font-weight: bold;
  color: color-mix(in srgb, var(--text-color) 60%, var(--background-color));
}
[data-sc-jdj="examples-plain"] {
  font-style: italic;
  color: color-mix(in srgb, var(--text-color) 78%, var(--background-color));
  margin-top: 0.1em;
  margin-bottom: 0.35em;
  padding-left: 1.2em;
}
[data-sc-jdj="pattern"] {
  font-weight: bold;
  font-style: normal;
}
[data-sc-jdj="subsenses"] {
  margin-top: 0.1em;
  margin-bottom: 0.1em;
  padding-left: 1.1em;
}
[data-sc-jdj="synonyms"] {
  font-size: 0.9em;
  margin-top: 0.1em;
}
[data-sc-jdj="syllables"] {
  font-weight: bold;
}
"""


@dataclass
class Example:
    text: str
    translation: str = ""
    # The pattern an English example shows, as `call for` before `A hiker
    # heard his calls for help.`
    pattern: str = ""


@dataclass
class Sense:
    gloss: str
    examples: list[Example] = field(default_factory=list)
    # Explanations of the meaning, set apart from it.
    notes: list[str] = field(default_factory=list)
    # Words to look up for this meaning, such as 態度 after "thái độ".
    refs: list[str] = field(default_factory=list)
    # Grammar or usage before the meaning, such as `[C] informal`.
    label: str = ""
    # Narrower meanings, as `1 a` and `1 b` under `1`.
    subsenses: list["Sense"] = field(default_factory=list)
    synonyms: list[str] = field(default_factory=list)


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
    # The Sino-Vietnamese reading of a Japanese word, as MIÊU for 猫.
    han_viet: str = ""
    # Facts about a character, such as its strokes and radical.
    facts: str = ""
    # The headword split into syllables, as `beau·ti·ful`.
    syllables: str = ""
    # What the headword is a form of, and which form: ("buttress", "past
    # simple").
    forms: list[tuple[str, str]] = field(default_factory=list)
    # Examples with no translation, as in a dictionary of one language.
    monolingual: bool = False


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

    def sense(self, gloss: str, label: str = "") -> None:
        self._current().senses.append(Sense(gloss, label=label))

    def subsense(self, gloss: str, label: str = "") -> None:
        """A narrower meaning of the sense above."""
        section = self._current()
        if not section.senses:
            section.senses.append(Sense(""))
        section.senses[-1].subsenses.append(Sense(gloss, label=label))

    def target(self) -> Sense:
        """The meaning examples and notes join: the last one, or its last
        narrower meaning. A bare one opens when the source puts an example
        before any meaning."""
        section = self._current()
        if not section.senses:
            section.senses.append(Sense(""))
        sense = section.senses[-1]
        return sense.subsenses[-1] if sense.subsenses else sense

    def example(self, example: Example) -> None:
        self.target().examples.append(example)

    def note(self, text: str) -> None:
        """An explanation of the meaning above."""
        self.target().notes.append(text)

    def ref(self, word: str) -> None:
        """A word to look up for the meaning above."""
        self.target().refs.append(word)

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
            section.senses = [sense for sense in section.senses if _says_something(sense)]
            for sense in section.senses:
                sense.subsenses = [sub for sub in sense.subsenses if _says_something(sub)]
        # Idioms and headings may stand alone, before what belongs to them.
        self.body.sections = [
            section for section in self.body.sections
            if section.senses or section.kind in ("idiom", "heading")
        ]
        return self.body


def _says_something(sense: Sense) -> bool:
    return bool(
        sense.gloss or sense.examples or sense.notes or sense.refs or sense.label
        or sense.subsenses or sense.synonyms
    )


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


# Word classes and registers, as Chinese dictionaries mark them on a line of
# their own, in Vietnamese.
_CHINESE_CLASSES = {
    "名": "danh từ", "动": "động từ", "形": "tính từ", "副": "phó từ", "副词": "phó từ",
    "连": "liên từ", "连词": "liên từ", "代": "đại từ", "代词": "đại từ", "数": "số từ",
    "量": "lượng từ", "助": "trợ từ", "叹": "thán từ", "叹词": "thán từ", "介": "giới từ",
    "介词": "giới từ", "书": "văn viết", "方": "phương ngữ", "口": "khẩu ngữ",
    "成": "thành ngữ", "古": "từ cổ", "谚语": "tục ngữ",
}
# A reading in pinyin, which opens each reading's part of a Babylon entry.
_PINYIN = re.compile(r"\[([A-Za-zÀ-ɏḀ-ỿ' ]{1,40})\]")


def _chinese(line: str) -> bool:
    """Written in Chinese more than in letters."""
    han = len(_HAN.findall(line))
    return han > 0 and han >= sum(ch.isalpha() and not _HAN.match(ch) for ch in line)


def _meaning(text: str) -> tuple[str, str]:
    """`tốt; lành; hay。优点多的` as the meaning and its explanation in
    Chinese, which some entries set off with a full stop instead."""
    stop = re.search(r"。|\.\s+(?=[㐀-䶿一-鿿])", text)
    if stop and stop.start() > 0 and not _chinese(text[:stop.start()]) and _HAN.search(text[stop.end():]):
        return text[:stop.start()].strip(), text[stop.end():].strip()
    return text.rstrip("。").strip(), ""


def parse_babylon(definitions: list[str]) -> Body:
    """Babylon exports open with the headword's reading in brackets. Chinese
    ones then give a character's traditional form, radical, strokes and
    Sino-Vietnamese reading, word classes on lines of their own, numbered
    meanings with an explanation in Chinese after `。`, pairs of lines that
    are an example and its translation, notes, and compounds to look up.
    A character with more readings has a part for each, opening with the
    reading in brackets, often straight after the last line of the part
    before."""
    builder = _Builder()
    facts: dict[str, str] = {}
    readings = 0
    compounds = False
    for definition in definitions:
        marked = _PINYIN.sub(lambda match: f"\n\0{match.group(1)}\n", definition)
        lines = [line.strip() for line in marked.split("\n")]
        lines = [line for line in lines if line and not _PLACEHOLDER.match(line)]
        at = 0
        while at < len(lines):
            line = lines[at]
            at += 1
            if line.startswith("\0"):
                readings += 1
                compounds = False
                if readings > 1:
                    builder.section(line[1:], "idiom")
                continue
            field, _, value = line.partition(":")
            field, value = field.strip(), value.strip()
            if field == "Hán Việt" and value:
                if readings > 1 and builder.body.sections:
                    builder.body.sections[-1].label += f" · {value}"
                else:
                    builder.body.han_viet = builder.body.han_viet or value
                continue
            if field in ("Bộ", "Số nét", "Từ phồn thể"):
                if readings <= 1:
                    radical = re.match(r"^(.+?)\s*(?:-\s*|\()\s*([^()]+?)\)?$", value)
                    if field == "Số nét":
                        facts[field] = f"{value} nét"
                    elif field == "Bộ":
                        facts[field] = f"bộ {radical.group(2).lower()} {radical.group(1)}" if radical else f"bộ {value}"
                    else:
                        facts[field] = f"phồn thể {value.strip('()')}"
                continue
            if field == "Từ ghép":
                builder.section("Từ ghép", "compounds")
                compounds = True
                if value:
                    lines.insert(at, value)
                continue
            if field in ("Ghi chú", "Chú ý", "Xem") and (value or at < len(lines)):
                compounds = False
                if not value:
                    value = lines[at]
                    at += 1
                builder.note(value.replace("另见", "xem thêm "))
                continue
            if compounds:
                for word in re.split(r"\s*[;；]\s*", line):
                    if word:
                        builder.ref(word)
                continue
            if line in _CHINESE_CLASSES:
                builder.section(_CHINESE_CLASSES[line], "pos")
                continue
            numbered = re.match(r"^\d+\.\s*(.*)$", line)
            # A meaning may be followed by a longer explanation in Chinese.
            if numbered or not _chinese(line.split("。", 1)[0]):
                gloss, explanation = _meaning(numbered.group(1) if numbered else line)
                builder.sense(gloss)
                if explanation:
                    builder.note(explanation)
                continue
            # An example, with its translation on the next line.
            section = builder._current()
            if not section.senses:
                builder.note(line)
                continue
            translation = ""
            if at < len(lines) and not _chinese(lines[at]) and not lines[at].startswith("\0") \
                    and not re.match(r"^\d+\.", lines[at]) and ":" not in lines[at][:12]:
                translation = lines[at]
                at += 1
            builder.example(Example(line, translation))
    body = builder.finish()
    body.facts = " · ".join(facts[field] for field in ("Số nét", "Bộ", "Từ phồn thể") if field in facts)
    return body


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


def _prodict_segment(
    segment: str, vocabulary: set[str], term: str
) -> tuple[str, list[Example], str | None]:
    """A meaning and the phrases run on after it:
    `hãngbusiness house: hãng buônhouse flag: cờ hãng` is `hãng` with
    `business house` (hãng buôn) and `house flag` (cờ hãng). A phrase run on
    at the very end has its translation in the next part, after a no-break
    space instead of a colon; it comes back on its own."""
    pieces = segment.split(": ")
    trailing = None
    at = _english_tail(pieces[-1], vocabulary, term)
    if at:
        trailing = pieces[-1][at:].strip()
        pieces[-1] = pieces[-1][:at]
    if len(pieces) == 1:
        return pieces[0].strip(), [], trailing
    at = _english_tail(pieces[0], vocabulary, term)
    if at is None:
        return ": ".join(pieces).strip(), [], trailing
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
    return gloss, examples, trailing


def parse_prodict(definitions: list[str], term: str, vocabulary: set[str] | None = None) -> Body:
    """Prodict marks lines with codes: `1` repeats the headword and `4` gives
    the field, then its meanings separated by no-break spaces. Phrases with
    their translations run straight on after a meaning, with nothing between
    one translation and the next phrase, and so do a further field
    (`Lĩnh vực:`) and an explanation (`Giải thích VN:`, `Giải thích EN:`)."""
    vocabulary = vocabulary or set()
    builder = _Builder()
    for definition in definitions:
        for code, text in re.findall(r"`(\d+)`([^`]*)", definition):
            if code == "1":
                continue
            text = re.sub(r"(Lĩnh vực:|Giải thích (?:VN|EN):)", "\xa0\\1", text)
            parts = [part.strip() for part in text.split("\xa0") if part.strip()]
            # A phrase whose translation is the next part.
            pending: str | None = None
            for part in parts:
                label = part.startswith(("Lĩnh vực:", "Giải thích VN:", "Giải thích EN:"))
                if pending is not None and label:
                    builder.example(Example(pending))
                    pending = None
                if part.startswith("Lĩnh vực:"):
                    builder.section(part.removeprefix("Lĩnh vực:").strip(), "domain")
                    continue
                explanation = re.match(r"^Giải thích (?:VN|EN):\s*(.*)$", part, re.S)
                if explanation:
                    if explanation.group(1).strip():
                        builder.note(explanation.group(1).strip())
                    continue
                lead, examples, trailing = _prodict_segment(part, vocabulary, term)
                if pending is not None:
                    builder.example(Example(pending, lead))
                elif lead:
                    builder.sense(lead)
                for example in examples:
                    builder.example(example)
                pending = trailing
            if pending is not None:
                builder.example(Example(pending))
    return builder.finish()


_HTML_TAG = re.compile(
    r"</?(b|i|u|s|em|strong|small|sup|sub|ol|ul|li|br|div|span|p|a|table|tr|td|th)\b[^<>]*>", re.I
)
# Tags kept as they are: what Yomitan's structured content allows.
_KEPT_TAGS = {
    "br", "ruby", "rt", "rp", "table", "thead", "tbody", "tfoot", "tr", "td", "th",
    "span", "div", "ol", "ul", "li", "details", "summary",
}
# The rest, as a span or div with the look the tag gives.
_STYLED_TAGS = {
    "b": ("span", {"fontWeight": "bold"}),
    "strong": ("span", {"fontWeight": "bold"}),
    "i": ("span", {"fontStyle": "italic"}),
    "em": ("span", {"fontStyle": "italic"}),
    "cite": ("span", {"fontStyle": "italic"}),
    "u": ("span", {"textDecorationLine": "underline"}),
    "s": ("span", {"textDecorationLine": "line-through"}),
    "del": ("span", {"textDecorationLine": "line-through"}),
    "small": ("span", {"fontSize": "0.85em"}),
    "sup": ("span", {"verticalAlign": "super", "fontSize": "0.75em"}),
    "sub": ("span", {"verticalAlign": "sub", "fontSize": "0.75em"}),
    "p": ("div", {}),
    "blockquote": ("div", {}),
    "dl": ("div", {}),
    "dd": ("div", {}),
    "dt": ("div", {"fontWeight": "bold"}),
    **{f"h{level}": ("div", {"fontWeight": "bold"}) for level in range(1, 7)},
}
_VOID_TAGS = {"br", "img", "hr", "wbr", "input", "meta", "link", "source", "col", "area"}


class _HtmlReader(HTMLParser):
    """HTML as structured content. Unknown tags give way to their contents;
    pictures, which the dictionary does not carry, are left out."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.root: dict = {"tag": None, "content": []}
        self.open: list[dict] = [self.root]

    def handle_starttag(self, tag: str, attrs: list) -> None:
        if tag in _VOID_TAGS:
            if tag == "br":
                self.open[-1]["content"].append({"tag": "br"})
            return
        if tag in _KEPT_TAGS:
            node: dict = {"tag": tag}
        elif tag in _STYLED_TAGS:
            name, style = _STYLED_TAGS[tag]
            node = {"tag": name, **({"style": dict(style)} if style else {})}
        elif tag == "a":
            href = dict(attrs).get("href") or ""
            node = {"tag": "a", "href": href} if href.startswith(("http", "?")) else {"tag": "span"}
        else:
            node = {"tag": None}
        node["source"] = tag
        node["content"] = []
        self.open[-1]["content"].append(node)
        self.open.append(node)

    def handle_startendtag(self, tag: str, attrs: list) -> None:
        if tag in _VOID_TAGS:
            self.handle_starttag(tag, attrs)

    def handle_endtag(self, tag: str) -> None:
        for at in range(len(self.open) - 1, 0, -1):
            if self.open[at].get("source") == tag:
                del self.open[at:]
                return

    def handle_data(self, data: str) -> None:
        content = self.open[-1]["content"]
        if content and isinstance(content[-1], str):
            content[-1] += data
        else:
            content.append(data)


def _examples(content: list) -> list:
    """Wiktionary's `meaning<br><i>example</i> — translation` as an example
    under its meaning, with the translation beneath it."""
    out: list = []
    at = 0
    while at < len(content):
        item = content[at]
        following = content[at + 1] if at + 1 < len(content) else None
        if (
            isinstance(item, dict) and item.get("tag") == "br"
            and isinstance(following, dict) and following.get("source") in ("i", "em")
        ):
            example: list = [{**_node("div", "example", following["content"]), "style": {"fontStyle": "italic"}}]
            at += 2
            rest = content[at] if at < len(content) else None
            if isinstance(rest, str) and re.match(r"^\s*[—–-]\s", rest):
                translation = re.sub(r"^\s*[—–-]\s*", "", rest).strip()
                if translation:
                    example.append(_node("div", "translation", translation))
                at += 1
            out.append(_node("div", "html-example", example))
            continue
        out.append(item)
        at += 1
    return out


_BLOCK_TAGS = {"div", "ol", "ul", "table", "details"}


def _blocks(content: list) -> list:
    """Text beside blocks, such as a meaning before its examples, in a block
    of its own, so it does not sit beside them."""
    if not any(isinstance(item, dict) and item.get("tag") in _BLOCK_TAGS for item in content):
        return content
    out: list = []
    run: list = []

    def close() -> None:
        while run and (run[-1] == {"tag": "br"} or (isinstance(run[-1], str) and not run[-1].strip())):
            run.pop()
        while run and (run[0] == {"tag": "br"} or (isinstance(run[0], str) and not run[0].strip())):
            run.pop(0)
        if run:
            out.append({"tag": "div", "content": run[0] if len(run) == 1 else list(run)})
        run.clear()

    for item in content:
        if isinstance(item, dict) and item.get("tag") in _BLOCK_TAGS:
            close()
            out.append(item)
        else:
            run.append(item)
    close()
    return out


def _tidy_html(nodes: list) -> list:
    """The nodes read as Yomitan wants them: unknown tags unwrapped and
    empty elements dropped. Italics keep their source tag for [_examples]."""
    out: list = []
    for node in nodes:
        if isinstance(node, str):
            if node:
                out.append(node)
            continue
        content = _tidy_html(node.get("content", []))
        if node.get("source") == "li":
            content = _blocks(_examples(content))
        if node.get("tag") is None:
            out.extend(content)
            continue
        element = {key: value for key, value in node.items() if key not in ("content", "source")}
        if node["tag"] != "br":
            if not content:
                continue
            element["content"] = content[0] if len(content) == 1 else content
        if node.get("source") in ("i", "em"):
            element["source"] = node["source"]
        out.append(element)
    return out


def _without_sources(node: object) -> object:
    if isinstance(node, list):
        return [_without_sources(item) for item in node]
    if isinstance(node, dict):
        return {key: _without_sources(value) for key, value in node.items() if key != "source"}
    return node


def parse_html(text: str) -> dict | None:
    """A definition written as HTML, as structured content, or None when it
    has no tags."""
    if not _HTML_TAG.search(text):
        return None
    reader = _HtmlReader()
    reader.feed(text)
    reader.close()
    content = _without_sources(_blocks(_tidy_html(reader.root["content"])))
    if not content:
        return None
    return {"type": "structured-content", "content": content}


# JMdict's word classes, as Japanese-Vietnamese dictionaries tag their
# meanings, named in Vietnamese.
_WORD_CLASSES = {
    "n": "danh từ", "pn": "đại từ", "num": "số từ", "ctr": "từ đếm",
    "v": "động từ", "v1": "động từ nhóm 2", "vk": "động từ bất quy tắc",
    "vs": "động từ する", "vs-i": "động từ する", "vs-s": "động từ する", "vz": "động từ",
    "vt": "tha động từ", "vi": "tự động từ",
    "adj": "tính từ", "adj-i": "tính từ đuôi い", "adj-ix": "tính từ đuôi い",
    "adj-na": "tính từ đuôi な", "adj-no": "tính từ の", "adj-pn": "liên thể từ",
    "adj-t": "tính từ đuôi たる", "adj-f": "tính từ", "adv": "phó từ", "adv-to": "phó từ と",
    "aux": "trợ từ", "aux-v": "trợ động từ", "aux-adj": "trợ tính từ",
    "conj": "liên từ", "cop": "hệ từ", "exp": "cụm từ", "int": "thán từ", "prt": "trợ từ",
    "pref": "tiền tố", "suf": "hậu tố", "n-adv": "danh từ phó từ", "n-suf": "hậu tố",
    "n-pref": "tiền tố", "n-t": "danh từ chỉ thời gian", "unc": "chưa phân loại",
}
_CJK_WORD = re.compile(r"^[\u3005\u3040-\u30ff\u3400-\u9fff\uf900-\ufaff〜～・]+$")
_JAPANESE = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]")


def _word_class(code: str) -> str | None:
    code = code.strip().lower()
    if re.fullmatch(r"v5[a-z\-]*|v4[a-z]*|v2[a-z\-]*", code):
        return "động từ nhóm 1" if code.startswith("v5") else "động từ"
    return _WORD_CLASSES.get(code)


def word_classes(label: str) -> str | None:
    """A label of JMdict word classes, such as `v1, vt`, in Vietnamese; None
    when it is something else."""
    codes = [code for code in re.split(r"[,\s]+", label.strip()) if code]
    names = [_word_class(code) for code in codes]
    if not codes or None in names:
        return None
    return ", ".join(dict.fromkeys(names))


def _clean(text: str) -> str:
    """Without the stray full stop some exports end an entry with."""
    return re.sub(r"\s+\.$", "", text.strip())


def japanese_touches(body: Body) -> Body:
    """For dictionaries of Japanese words: word classes named in Vietnamese,
    meanings that are only a Japanese word made words to look up, and
    stray full stops gone."""
    for section in body.sections:
        if section.kind == "pos":
            section.label = word_classes(section.label) or section.label
        senses: list[Sense] = []
        for sense in section.senses:
            sense.gloss = _clean(sense.gloss)
            for example in sense.examples:
                example.text, example.translation = _clean(example.text), _clean(example.translation)
            if _CJK_WORD.match(sense.gloss) and senses:
                senses[-1].refs.append(sense.gloss)
                senses[-1].refs.extend(sense.refs)
                continue
            if _CJK_WORD.match(sense.gloss):
                sense.refs.insert(0, sense.gloss)
                sense.gloss = ""
            senses.append(sense)
        section.senses = senses
    return body


def parse_javidic(definitions: list[str]) -> Body:
    """Javidic's text: the reading in 「」, word classes as 〘n〙 or `v1, vt`,
    meanings one a line, examples as a Japanese line ending in a colon
    with the translation below, Japanese words to look up on lines of
    their own, and idioms and notes."""
    builder = _Builder()
    for definition in definitions:
        lines = [line.strip() for line in definition.splitlines() if line.strip()]
        at = 0
        while at < len(lines):
            line = _clean(lines[at])
            at += 1
            if line.startswith("「") and line.endswith("」"):
                continue
            bracketed = re.fullmatch(r"〘(.+)〙", line)
            if bracketed or word_classes(line):
                builder.section(bracketed.group(1) if bracketed else line, "pos")
            elif line.endswith(":") and _JAPANESE.search(line) and at < len(lines):
                builder.example(Example(line[:-1].strip(), _clean(lines[at])))
                at += 1
            elif re.match(r"^\*?\s*(Thành ngữ|Cụm từ hay dùng|Lưu ý)\s*:", line):
                builder.note(line.lstrip("* ").strip())
            elif _CJK_WORD.match(line):
                builder.ref(line)
            else:
                builder.sense(line)
    return japanese_touches(builder.finish())


def parse_mazii(definitions: list[str]) -> Body:
    """Mazii's text: the Sino-Vietnamese reading in capitals, then numbered
    meanings."""
    builder = _Builder()
    han_viet = ""
    for definition in definitions:
        for number, line in enumerate(line.strip() for line in definition.splitlines()):
            if not line:
                continue
            if number == 0 and _HAN_VIET_LINE.match(line):
                han_viet = line
                continue
            line = _clean(re.sub(r"^\d+\.\s*", "", line))
            if _CJK_WORD.match(line):
                builder.ref(line)
            elif line:
                builder.sense(line)
    body = japanese_touches(builder.finish())
    body.han_viet = han_viet
    return body


_HAN_VIET_LINE = re.compile(r"^[A-ZÀ-ỸĐ][A-ZÀ-ỸĐ\s,]*$")


def _ref(word: str) -> dict:
    return {"tag": "a", "href": f"?query={quote(word)}&wildcards=off", "content": word}


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


def _links(words: list[str]) -> list:
    links: list = []
    for number, word in enumerate(words):
        links += [", "] if number else []
        links.append(_ref(word))
    return links


def _item(sense: Sense, section: Section, body: Body) -> list:
    """A meaning: its grammar, gloss, notes, words to look up, examples and
    narrower meanings."""
    item: list = []
    if sense.label:
        label = {"tag": "span", "data": {"jdj": "grammar"}, "content": sense.label}
        item.append(_node("div", "gloss", [label, " ", _gloss(sense.gloss)] if sense.gloss else label))
    elif sense.gloss:
        item.append(_node("div", "gloss", _gloss(sense.gloss)))
    for note in sense.notes:
        item.append(_node("div", "note", note))
    if sense.refs:
        links = _links(sense.refs)
        item.append(_node("div", "refs", links if section.kind == "compounds" else ["→ ", *links]))
    if sense.synonyms:
        label = {"tag": "span", "data": {"jdj": "grammar"}, "content": "SYN"}
        item.append(_node("div", "synonyms", [label, " ", *_links(sense.synonyms)]))
    if sense.examples:
        lines = []
        for example in sense.examples:
            text: object = example.text
            if example.pattern:
                pattern = {"tag": "span", "data": {"jdj": "pattern"}, "content": example.pattern}
                text = [pattern, " ", example.text] if example.text else pattern
            lines.append({"tag": "li", "content": [
                _node("div", "example", text),
                *([_node("div", "translation", example.translation)] if example.translation else []),
            ]})
        item.append(_node("ul", "examples-plain" if body.monolingual else "examples", lines))
    if sense.subsenses:
        item.append(_node("ul", "subsenses", [
            {"tag": "li", "content": _item(sub, section, body)} for sub in sense.subsenses
        ]))
    return item


def to_structured(body: Body) -> dict | None:
    """The entry as Yomitan structured content, or None when nothing was
    understood."""
    if not body.sections and not body.forms:
        return None
    content: list = []
    if body.han_viet:
        content.append(_node("div", "han-viet", body.han_viet))
    if body.facts:
        content.append(_node("div", "facts", body.facts))
    if body.syllables:
        line: list = [{"tag": "span", "data": {"jdj": "syllables"}, "content": body.syllables}]
        if body.pronunciation:
            line.append(f"  /{body.pronunciation}/")
        content.append(_node("div", "ipa", line))
    elif body.pronunciation:
        content.append(_node("div", "ipa", f"/{body.pronunciation}/"))
    for word, kind in body.forms:
        line = ["→ ", _ref(word)]
        if kind:
            line += [" ", {"tag": "span", "data": {"jdj": "form-labels"}, "content": kind}]
        content.append(_node("div", "form-of", line))
    for section in body.sections:
        parts: list = []
        if section.label:
            parts.append(_node("div", "idiom" if section.kind == "idiom" else "label", section.label))
        items = [_item(sense, section, body) for sense in section.senses]
        if len(items) == 1 or section.kind == "heading":
            # Notes under a heading, as a dictionary's synonyms, are not
            # numbered.
            for item in items:
                parts.extend(item)
        elif items:
            parts.append(_node("ol", "senses", [{"tag": "li", "content": item} for item in items]))
        content.append(_node("div", "section", parts))
    return {"type": "structured-content", "content": content}


def _is_text(item: object) -> bool:
    """A definition in plain text: a string, or Yomitan's text object."""
    return isinstance(item, str) or (
        isinstance(item, dict) and item.get("type") == "text" and isinstance(item.get("text"), str)
    )


def _texts(row: list) -> list[str]:
    if len(row) <= 5 or not isinstance(row[5], list):
        return []
    return [item if isinstance(item, str) else item["text"] for item in row[5] if _is_text(item)]


def _is_form(definition: object) -> bool:
    """An inflected form's pointer to its word: `["strap", ["participle present"]]`."""
    return (
        isinstance(definition, list) and len(definition) == 2 and isinstance(definition[0], str)
        and isinstance(definition[1], list) and all(isinstance(label, str) for label in definition[1])
    )


# The words of Wiktionary's grammatical labels, in Vietnamese.
_GRAMMAR = {
    "singular": "số ít", "plural": "số nhiều", "first-person": "ngôi thứ nhất",
    "second-person": "ngôi thứ hai", "third-person": "ngôi thứ ba",
    "first/second-person": "ngôi thứ nhất/hai", "first/third-person": "ngôi thứ nhất/ba",
    "second/third-person": "ngôi thứ hai/ba", "first/second/third-person": "ngôi thứ nhất/hai/ba",
    "masculine": "giống đực", "feminine": "giống cái", "neuter": "giống trung",
    "all-gender": "mọi giống", "nominative": "chủ cách", "accusative": "đối cách",
    "genitive": "sở hữu cách", "dative": "tặng cách", "instrumental": "công cụ cách",
    "prepositional": "giới cách", "locative": "vị trí cách", "vocative": "hô cách",
    "partitive": "bộ phận cách", "all-case": "mọi cách",
    "present": "hiện tại", "past": "quá khứ", "future": "tương lai", "future-i": "tương lai I",
    "future-ii": "tương lai II", "perfect": "hoàn thành", "pluperfect": "quá khứ hoàn thành",
    "preterite": "quá khứ", "imperfect": "quá khứ chưa hoàn thành", "historic": "đơn",
    "anterior": "trước", "simple": "đơn", "indicative": "trình bày", "subjunctive": "giả định",
    "subjunctive-i": "giả định I", "subjunctive-ii": "giả định II", "imperative": "mệnh lệnh",
    "conditional": "điều kiện", "infinitive": "nguyên mẫu", "participle": "phân từ",
    "gerund": "danh động từ", "comparative": "so sánh hơn", "superlative": "so sánh nhất",
    "degree": "", "strong": "mạnh", "weak": "yếu", "mixed": "hỗn hợp",
    "with-article": "có mạo từ", "without-article": "không mạo từ", "definite": "xác định",
    "indefinite": "bất định", "subordinate-clause": "mệnh đề phụ", "predicative": "vị ngữ",
    "dependent": "phụ thuộc", "rare": "hiếm", "uncommon": "ít dùng", "formal": "trang trọng",
    "informal": "thân mật", "colloquial": "khẩu ngữ", "regional": "địa phương",
    "nonstandard": "không chuẩn", "reflexive": "phản thân", "active": "chủ động",
    "passive": "bị động", "perfective": "hoàn thành thể", "imperfective": "chưa hoàn thành thể",
    "alternative": "dạng khác", "diminutive": "giảm nhẹ", "augmentative": "tăng nghĩa",
    "endearing": "âu yếm", "animate": "hữu sinh", "inanimate": "vô sinh",
    "short-form": "dạng ngắn", "adverbial": "trạng ngữ", "irregular": "bất quy tắc",
    "variant": "biến thể", "abbreviation": "viết tắt", "US": "Mỹ", "UK": "Anh",
    "female": "giống cái", "equivalent": "tương đương", "agent": "chủ thể", "noun": "danh từ",
    "adjective": "tính từ", "infinitive-zu": "nguyên mẫu với zu", "zu-infinitive": "nguyên mẫu với zu",
    "I": "I", "II": "II",
}
# English labels Wiktionary's tags put in an unusual order.
_ENGLISH_LABELS = {
    "participle past": "past participle", "participle present": "present participle",
    "present singular third-person": "third-person singular present",
}


def _form_label(label: str, vietnamese: bool) -> str:
    if not vietnamese:
        return _ENGLISH_LABELS.get(label, label)
    words = []
    for word in label.split():
        if word in _GRAMMAR:
            words.append(_GRAMMAR[word])
        elif "/" in word and all(part in _GRAMMAR for part in word.split("/")):
            words.append("/".join(_GRAMMAR[part] for part in word.split("/")))
        else:
            words.append(word)
    return " ".join(word for word in words if word)


def _forms(definitions: list, vietnamese: bool) -> dict:
    """Inflected forms' pointers as links to their words, each with what
    kind of form it is: the same kind once, however its tags are ordered."""
    labels: dict[str, list[str]] = {}
    seen: dict[str, set] = {}
    for word, tags in definitions:
        kinds, known = labels.setdefault(word, []), seen.setdefault(word, set())
        for tag in tags:
            key = frozenset(tag.split())
            if key and key not in known:
                known.add(key)
                kinds.append(_form_label(tag, vietnamese))
    content = []
    for word, kinds in labels.items():
        line: list = ["→ ", _ref(word)]
        if kinds:
            line += [" ", {"tag": "span", "data": {"jdj": "form-labels"}, "content": "; ".join(kinds)}]
        content.append(_node("div", "form-of", line))
    return {"type": "structured-content", "content": content}


def _only_forms(row: list) -> bool:
    """A row that is only inflected forms' pointers. Jitendex gives its
    redirects a pointer beside a link of its own, which stays as it is."""
    return len(row) > 5 and isinstance(row[5], list) and bool(row[5]) and all(_is_form(item) for item in row[5])


def _forms_share(rows: list) -> float:
    rows = [row for row in rows if isinstance(row, list) and len(row) > 5 and isinstance(row[5], list)]
    if not rows:
        return 0
    return sum(_only_forms(row) for row in rows) / len(rows)


def detect(rows: list) -> str | None:
    """Which layout a dictionary's term rows call for, if any: judged on a
    sample. Text is laid out only in Vietnamese dictionaries, and HTML
    written as text in any; a dictionary with none of that but with
    inflected forms has those rewritten alone."""
    layout = _text_layout(rows)
    if layout is None and _forms_share(rows) >= 0.02:
        return "forms"
    return layout


def _text_layout(rows: list) -> str | None:
    texts = [text for row in rows if isinstance(row, list) for text in _texts(row)]
    if not texts:
        return None
    if sum(bool(_HTML_TAG.search(text)) for text in texts) / len(texts) >= 0.5:
        return "html"
    vietnamese = sum(any(ch in _VIETNAMESE_ONLY for ch in text) for text in texts)
    if vietnamese / len(texts) < 0.05:
        # english.py lays out text of its own; imported here, as it builds
        # on what this module defines.
        from . import english

        return english.detect(texts)
    if sum(bool(_CODE.search(text)) for text in texts) / len(texts) > 0.5:
        return "prodict"
    if sum(bool(re.match(r"^\s*\[[^\]]+\]", text)) for text in texts) / len(texts) > 0.5:
        return "babylon"
    if sum(bool(re.match(r"^[A-ZÀ-ỸĐ][A-ZÀ-ỸĐ ,]*\n1\. ", text)) for text in texts) / len(texts) > 0.5:
        return "mazii"
    if sum(bool(re.match(r"^「[^」\n]+」\n", text)) for text in texts) / len(texts) > 0.5:
        return "javidic"
    marked = sum(bool(_MARKER.search(text)) or bool(re.search(r"^ {2,}\S", text, re.M)) for text in texts)
    if marked / len(texts) >= 0.1:
        words = [row[0] for row in rows if isinstance(row, list) and row and isinstance(row[0], str)]
        japanese = sum(bool(_JAPANESE.search(word)) for word in words)
        return "jmarkup" if words and japanese / len(words) > 0.5 else "markup"
    return None


def _says_nothing(texts: list[str], term: str) -> bool:
    """Text that only repeats the headword, as `@дом\nдом`: a meaning lost
    on the way to Yomitan."""
    lines = [line.strip() for text in texts for line in text.split("\n")]
    lines = [line for line in lines if line and not line.startswith("@")]
    return bool(lines) and all(line == term for line in lines)


def rewrite_row(row: list, layout: str, vocabulary: set[str] | None = None) -> list | None:
    """[row] with its text definitions laid out, or as it was when nothing in
    them was understood, and inflected forms' pointers made links. Other
    definitions, such as structured content, stay as they are. None for a
    row that says nothing."""
    if _only_forms(row):
        row = [*row[:5], [_forms(row[5], layout in _VIETNAMESE_LAYOUTS)], *row[6:]]
    if layout == "forms":
        return row
    # Letters written as a base and a separate accent, as some exports do,
    # are joined so every font draws them.
    texts = [unicodedata.normalize("NFC", text) for text in _texts(row)]
    if not texts:
        return row
    term = row[0] if isinstance(row[0], str) else ""
    if layout == "markup" and len(texts) == len(row[5]) and _says_nothing(texts, term):
        return None
    if layout == "html":
        laid_out = [
            (parse_html(unicodedata.normalize("NFC", item)) or item) if isinstance(item, str) else item
            for item in row[5]
        ]
        return [*row[:5], laid_out, *row[6:]]
    if layout in ENGLISH_LAYOUTS:
        from . import english

        if english.says_nothing(layout, texts) and len(texts) == len(row[5]):
            return None
        body = english.parse(layout, texts, term)
    elif layout == "prodict":
        body = parse_prodict(texts, term, vocabulary)
    elif layout == "babylon":
        body = parse_babylon(texts)
    elif layout == "javidic":
        body = parse_javidic(texts)
    elif layout == "mazii":
        body = parse_mazii(texts)
    elif layout == "jmarkup":
        body = japanese_touches(parse_markup(texts))
    else:
        body = parse_markup(texts)
    structured = to_structured(body)
    if structured is None:
        return row
    others = [item for item in row[5] if not _is_text(item)]
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


# The most a rewritten bank holds, well under the server's own limit:
# laying out makes text larger.
BANK_BYTES = 32 << 20


def _banks(rows: list) -> list[bytes]:
    """[rows] as one bank, or as several when one would be too large."""
    banks: list[bytes] = []
    chunk: list = []
    size = 0
    for row in rows:
        encoded = len(json.dumps(row, ensure_ascii=False, separators=(",", ":")).encode())
        if chunk and size + encoded > BANK_BYTES:
            banks.append(json.dumps(chunk, ensure_ascii=False, separators=(",", ":")).encode())
            chunk, size = [], 0
        chunk.append(row)
        size += encoded + 1
    banks.append(json.dumps(chunk, ensure_ascii=False, separators=(",", ":")).encode())
    return banks


def _repeated(row: object, layout: str, seen: set[bytes]) -> bool:
    """Whether a row only repeats one before it, as many exports do. Babylon
    ones give each reading of a character the whole entry again, every
    reading in it."""
    if not isinstance(row, list) or len(row) < 6:
        return False
    key = [row[0], row[5]] if layout == "babylon" else [row[0], row[1], row[2], row[5]]
    digest = hashlib.blake2b(json.dumps(key, ensure_ascii=False).encode(), digest_size=16).digest()
    if digest in seen:
        return True
    seen.add(digest)
    return False


def _original(zip_path: Path) -> Path:
    """The file as uploaded: kept beside a dictionary that was rewritten."""
    original = zip_path.with_name("original.zip")
    return original if original.exists() else zip_path


def uploaded(zip_path: Path) -> Path:
    """The file as uploaded, of a dictionary at [zip_path]."""
    return _original(zip_path)


def layout_of(zip_path: Path) -> str | None:
    with zipfile.ZipFile(_original(zip_path)) as archive:
        return detect(_sample_rows(archive))


def apply(zip_path: Path) -> tuple[str | None, bool]:
    """Rewrites the dictionary at [zip_path] from the file as uploaded when
    its definitions have a layout this understands, keeping that file
    beside it as `original.zip`. Returns the layout, or None, and whether
    [zip_path] changed."""
    original = zip_path.with_name("original.zip")
    layout = layout_of(zip_path)
    if layout is None:
        if original.exists():
            # The rules no longer apply: back to the file as uploaded.
            shutil.move(original, zip_path)
            return None, True
        return None, False
    temp = zip_path.with_name("tidy.zip")
    seen: set[bytes] = set()
    with zipfile.ZipFile(_original(zip_path)) as source, zipfile.ZipFile(temp, "w", zipfile.ZIP_DEFLATED) as target:
        names = set(source.namelist())
        vocabulary = _vocabulary(source) if layout == "prodict" else None
        # Banks that grew too large go on in banks numbered after the last.
        numbers = [int(match.group(2)) for name in names if (match := BANK.match(name)) and match.group(1) == "term"]
        next_bank = max(numbers, default=0) + 1
        for info in source.infolist():
            data = source.read(info)
            match = BANK.match(info.filename)
            if match and match.group(1) == "term":
                rows = json.loads(data.decode("utf-8-sig"))
                rows = [rewrite_row(row, layout, vocabulary) if isinstance(row, list) else row for row in rows]
                rows = [row for row in rows if row is not None and not _repeated(row, layout, seen)]
                first, *rest = _banks(rows)
                data = first
                for more in rest:
                    target.writestr(f"term_bank_{next_bank}.json", more)
                    next_bank += 1
            elif info.filename == "index.json":
                index = json.loads(data.decode("utf-8-sig"))
                index["revision"] = f"{base_revision(str(index.get('revision', '')))}{revision_suffix(layout)}"
                data = json.dumps(index, ensure_ascii=False, indent=2).encode()
            elif info.filename == "styles.css":
                data = data + b"\n" + STYLES.encode()
            target.writestr(info.filename, data)
        if "styles.css" not in names:
            target.writestr("styles.css", STYLES)
    if not original.exists():
        shutil.move(zip_path, original)
    shutil.move(temp, zip_path)
    return layout, True
