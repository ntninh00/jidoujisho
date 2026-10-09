"""Grammar dictionaries laid out as grammar points.

Each entry of a grammar dictionary explains one pattern, such as 〜に関して:
its meaning, how it is formed, an explanation and examples. Every source
writes these its own way (DoJG's `[接続]` in plain text, 絵でわかる日本語's
`【例文】` in structured content); each is read into a Point and drawn the
same way, styled by STYLES.
"""

from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import dataclass, field
from urllib.parse import quote

# The layouts here, by the dictionary they read: the Dictionary of Japanese
# Grammar, どんなときどう使う 日本語表現文型辞典 and 絵でわかる日本語.
LAYOUTS = {"dojg", "bunkei", "edewakaru"}

# A colour of their own for grammar, mixed into the popup's theme.
_TINT = "#1f8a70"

STYLES = f"""/* Grammar points, laid out by jidoujisho's dictionary server. */
[data-sc-jdj="g-head"] {{
  margin-bottom: 0.35em;
}}
[data-sc-jdj="g-level"] {{
  font-size: 0.75em;
  font-weight: bold;
  color: color-mix(in srgb, {_TINT} 85%, var(--text-color));
  background-color: color-mix(in srgb, {_TINT} 16%, var(--background-color));
  padding-left: 0.45em;
  padding-right: 0.45em;
  margin-right: 0.5em;
}}
[data-sc-jdj="g-title"] {{
  font-weight: bold;
}}
[data-sc-jdj="g-image"] {{
  margin-bottom: 0.4em;
}}
[data-sc-jdj="g-meaning"] {{
  font-weight: bold;
}}
[data-sc-jdj="g-also"] {{
  color: color-mix(in srgb, var(--text-color) 68%, var(--background-color));
}}
[data-sc-jdj="g-label"] {{
  font-size: 0.78em;
  font-weight: bold;
  text-transform: uppercase;
  color: color-mix(in srgb, {_TINT} 70%, var(--text-color));
  margin-top: 0.75em;
  margin-bottom: 0.2em;
}}
[data-sc-jdj="g-forms"] {{
  background-color: color-mix(in srgb, var(--text-color) 7%, var(--background-color));
  padding-top: 0.35em;
  padding-bottom: 0.35em;
  padding-left: 0.6em;
  padding-right: 0.6em;
}}
[data-sc-jdj="g-form-ex"] {{
  font-size: 0.92em;
  color: color-mix(in srgb, var(--text-color) 65%, var(--background-color));
  padding-left: 0.9em;
}}
[data-sc-jdj="g-text"] {{
  margin-bottom: 0.3em;
}}
[data-sc-jdj="g-text-2"] {{
  margin-bottom: 0.3em;
  color: color-mix(in srgb, var(--text-color) 68%, var(--background-color));
}}
[data-sc-jdj="g-examples"] {{
  list-style-type: none;
  padding-left: 0;
  margin-top: 0;
  margin-bottom: 0;
}}
[data-sc-jdj="g-ex"] {{
  margin-top: 0.35em;
}}
[data-sc-jdj="g-ex-tr"], [data-sc-jdj="g-ex-note"] {{
  color: color-mix(in srgb, var(--text-color) 62%, var(--background-color));
}}
[data-sc-jdj="g-ex-note"] {{
  font-size: 0.92em;
}}
[data-sc-jdj="g-em"] {{
  font-weight: bold;
  color: color-mix(in srgb, {_TINT} 80%, var(--text-color));
}}
[data-sc-jdj="g-see"] {{
  margin-top: 0.2em;
}}
"""

_KANA = re.compile(r"[぀-ヿ]")
_JAPANESE = re.compile(r"[぀-ヿ㐀-鿿]")


@dataclass
class Form:
    """A line of how a pattern is formed, or an example of that line."""

    text: str
    gloss: str = ""
    example: bool = False


@dataclass
class Example:
    # Strings and highlighted spans.
    text: list
    translation: str = ""
    # What the example says in other words, as 絵でわかる日本語's `→ …`.
    notes: list[str] = field(default_factory=list)


@dataclass
class Part:
    label: str
    # "forms", "text" or "examples".
    kind: str
    items: list = field(default_factory=list)
    # Text in the definitions' second language, set apart from the first.
    second: bool = False


@dataclass
class Point:
    # The pattern as the source writes it, as 〜に関して・〜に関する＋N.
    title: str = ""
    # Its level, as N3 or Intermediate.
    level: str = ""
    # The source's illustration, as structured content's image.
    image: dict | None = None
    meanings: list = field(default_factory=list)
    # Meanings in a second language, as 文型辞典's English under its Japanese.
    also: list[str] = field(default_factory=list)
    parts: list[Part] = field(default_factory=list)
    # Patterns to look up instead, for an entry that only points to one.
    see: list[str] = field(default_factory=list)

    def add(self, label: str, kind: str, items: list, second: bool = False) -> None:
        if items:
            self.parts.append(Part(label, kind, items, second))


def _node(tag: str, kind: str, content: object) -> dict:
    return {"tag": tag, "data": {"jdj": kind}, "content": content}


def _link(word: str) -> dict:
    return {"tag": "a", "href": f"?query={quote(word)}&wildcards=off", "content": word}


def marked(text: str, patterns: list[str]) -> list:
    """[text] with the pattern it shows in bold, where it is written as the
    headword or its reading. Single characters, as て, are left alone: they
    turn up everywhere."""
    for pattern in patterns:
        pattern = pattern.strip("〜～ ")
        if len(pattern) >= 2 and pattern in text:
            pieces: list = []
            for number, piece in enumerate(text.split(pattern)):
                if number:
                    pieces.append(_node("span", "g-em", pattern))
                if piece:
                    pieces.append(piece)
            return pieces
    return [text]


def to_structured(point: Point) -> dict | None:
    """The point as structured content, or None when nothing was read."""
    content: list = []
    head: list = []
    if point.level:
        head.append(_node("span", "g-level", point.level))
    if point.title:
        head.append(_node("span", "g-title", point.title))
    if head:
        content.append(_node("div", "g-head", head))
    if point.image:
        content.append(_node("div", "g-image", point.image))
    for meaning in point.meanings:
        content.append(_node("div", "g-meaning", meaning))
    for meaning in point.also:
        content.append(_node("div", "g-also", meaning))
    for part in point.parts:
        # Each part in a block of its own: the app draws a tinted box in the
        # line it is in, and what follows it would otherwise join that line.
        block: list = []
        if part.label:
            block.append(_node("div", "g-label", part.label))
        if part.kind == "forms":
            lines = []
            for form in part.items:
                text: object = form.text
                if form.gloss:
                    text = [form.text, " — ", form.gloss]
                lines.append(_node("div", "g-form-ex" if form.example else "g-form", text))
            block.append(_node("div", "g-forms", lines))
        elif part.kind == "examples":
            items = []
            for example in part.items:
                item: list = [_node("div", "g-ex", example.text)]
                if example.translation:
                    item.append(_node("div", "g-ex-tr", example.translation))
                item += [_node("div", "g-ex-note", note) for note in example.notes]
                items.append({"tag": "li", "content": item})
            block.append(_node("ul", "g-examples", items))
        else:
            kind = "g-text-2" if part.second else "g-text"
            block += [_node("div", kind, paragraph) for paragraph in part.items]
        content.append(_node("div", "g-part", block))
    if point.see:
        links: list = ["→ "]
        for number, word in enumerate(point.see):
            links += [", "] if number else []
            links.append(_link(word))
        content.append(_node("div", "g-see", links))
    if not content:
        return None
    return {"type": "structured-content", "content": content}


def _plain(node: object) -> str:
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "".join(_plain(item) for item in node)
    if isinstance(node, dict):
        return _plain(node.get("content", ""))
    return ""


def _lines(content: object) -> list[list]:
    """Structured content as lines of strings and inline nodes: bold text
    stays bold, links to look things up stay links, links out and images
    are left out."""
    lines: list[list] = [[]]

    def walk(node: object) -> None:
        if isinstance(node, str):
            first, *rest = node.replace("\r", "").split("\n")
            if first:
                lines[-1].append(first)
            for piece in rest:
                lines.append([piece] if piece else [])
        elif isinstance(node, list):
            for item in node:
                walk(item)
        elif isinstance(node, dict):
            tag = node.get("tag")
            if tag == "img" or node.get("type") == "image":
                return
            if tag == "br":
                lines.append([])
            elif tag == "a":
                href = str(node.get("href", ""))
                text = _plain(node)
                if href.startswith("?") and text:
                    lines[-1].append({"tag": "a", "href": href, "content": text})
            elif tag == "span" and (node.get("style") or {}).get("fontWeight") == "bold":
                text = _plain(node)
                if text:
                    lines[-1].append(_node("span", "g-em", text))
            else:
                walk(node.get("content"))

    walk(content)
    return lines


def _line_text(line: list) -> str:
    return _plain(line).strip()


def _paragraphs(lines: list[str]) -> list[str]:
    """Lines as paragraphs: a blank line ends one, and lines within one are
    joined."""
    paragraphs: list[str] = []
    current: list[str] = []
    for line in lines + [""]:
        if line.strip():
            current.append(line.strip())
        elif current:
            paragraphs.append(" ".join(current))
            current = []
    return paragraphs


# ---- Dictionary of Japanese Grammar ------------------------------------------

_DOJG_HEAD = re.compile(r"^文法項目\s*\|\s*(.*?)\s*\|\s*(\S*)")
_DOJG_MARK = re.compile(r"^\s*\[(解説|意味|例文A|例文B|接続)\]\s*$")
_DOJG_EXAMPLE = re.compile(r"^\s*\(([a-z]{1,4})\)\.\s*(.*)$")
_DOJG_LEVELS = {"基本": "Basic", "中級編": "Intermediate", "上級編": "Advanced"}
# A word run into the Japanese after it, as `Vnegativeない`.
_RUN_ON = re.compile(r"(?<=[A-Za-z])(?=[぀-ヿ㐀-鿿])")


def _dojg_examples(lines: list[str], patterns: list[str]) -> list[Example]:
    examples: list[Example] = []
    japanese, translation = None, []
    for line in lines + ["(zz). "]:
        match = _DOJG_EXAMPLE.match(line)
        if match:
            if japanese:
                examples.append(Example(marked(japanese, patterns), " ".join(translation)))
            japanese, translation = match.group(2).strip(), []
        elif line.strip() and japanese is not None:
            # A sentence the source carried onto the next line is still
            # Japanese until its translation starts.
            if not translation and _KANA.search(line) and not re.search(r"[A-Za-z]{3}", line):
                japanese += line.strip()
            else:
                translation.append(line.strip())
    return examples


def _dojg_sentences(label: str, lines: list[str], patterns: list[str], point: Point) -> None:
    """Examples, or for the few entries that list words instead of
    sentences, those lines as they are."""
    examples = _dojg_examples(lines, patterns)
    if examples:
        point.add(label, "examples", examples)
    else:
        point.add(label, "text", [line.strip() for line in lines if line.strip()])


def _dojg_formation(lines: list[str]) -> list[Form]:
    """DoJG's formation table: a pattern's row, then rows of examples of it,
    which open with `|`."""
    forms: list[Form] = []
    for line in lines:
        if "|" not in line:
            continue
        cells = [_RUN_ON.sub(" ", cell.strip()) for cell in line.split("|")]
        cells = [cell for cell in cells if cell]
        if not cells:
            continue
        if line.strip().startswith("|"):
            forms.append(Form(cells[0], " ".join(cells[1:]), example=True))
        else:
            forms.append(Form(" ".join(cells)))
    return forms


def parse_dojg(text: str, term: str, reading: str, title: str = "") -> Point:
    point = Point(title=title)
    text = text.replace("\r", "")
    # A mark with its text run on after it starts a line of its own, and one
    # entry's examples, written into its meaning after a rule, get theirs.
    text = re.sub(r"(\[(?:解説|意味|例文A|例文B|接続)\])[ \t]*(?=\S)", "\\1\n", text)
    text = re.sub(r"\n\s*-{5,}\s*〖example〗:?", "\n[例文A]\n", text)
    blocks: dict[str, list[str]] = {}
    current = None
    for line in text.split("\n"):
        head = _DOJG_HEAD.match(line.strip())
        if head:
            point.title = point.title or head.group(1).strip()
            point.level = _DOJG_LEVELS.get(head.group(2), head.group(2))
            continue
        mark = _DOJG_MARK.match(line)
        if mark:
            current = mark.group(1)
            blocks.setdefault(current, [])
        elif current:
            blocks[current].append(line)
    patterns = [term, reading]
    meaning = " ".join(line.strip() for line in blocks.get("意味", []) if line.strip())
    if meaning:
        point.meanings.append(meaning)
    point.add("", "text", _paragraphs(blocks.get("解説", [])))
    point.add("Formation", "forms", _dojg_formation(blocks.get("接続", [])))
    _dojg_sentences("Key sentences", blocks.get("例文A", []), patterns, point)
    _dojg_sentences("Examples", blocks.get("例文B", []), patterns, point)
    return point


# ---- どんなときどう使う 日本語表現文型辞典 -----------------------------------------

_CIRCLED = re.compile(r"^\s*[❶-❿⓫-⓴]\s*")
# Where an entry's links out begin.
_BUNKEI_LINKS = ("google.com/search", "itazuraneko.neocities.org")
# The headword some English notes end with, run into their last sentence.
_TRAILING_TERM = re.compile(r"(?<=[.!?)\"”’])\s*[぀-ヿ㐀-鿿〜～・／/〈〉（）()]+\s*$")


def _mostly_latin(text: str) -> bool:
    """English that quotes Japanese, as `Negative form becomes そうもない`."""
    return len(re.findall(r"[A-Za-z]", text)) > len(_JAPANESE.findall(text))


def _blocks(lines: list[list]) -> list[list[list]]:
    blocks: list[list[list]] = [[]]
    for line in lines:
        if _line_text(line):
            blocks[-1].append(line)
        elif blocks[-1]:
            blocks.append([])
    return [block for block in blocks if block]


def _stripped(line: list) -> list:
    """A line without the spaces around it."""
    line = list(line)
    while line and isinstance(line[0], str) and not line[0].strip():
        line.pop(0)
    if line and isinstance(line[0], str):
        line[0] = line[0].lstrip()
    while line and isinstance(line[-1], str) and not line[-1].strip():
        line.pop()
    if line and isinstance(line[-1], str):
        line[-1] = line[-1].rstrip()
    return line


def _marked_line(line: list, patterns: list[str]) -> list:
    pieces: list = []
    for piece in line:
        pieces += marked(piece, patterns) if isinstance(piece, str) else [piece]
    return pieces


def parse_bunkei(content: object, term: str, reading: str) -> Point:
    lines = _lines(content)
    texts = [_line_text(line) for line in lines]
    end = next((at for at, text in enumerate(texts) if text.startswith(_BUNKEI_LINKS)), len(lines))
    lines = lines[:end]
    blocks = _blocks(lines)
    if not blocks:
        return Point()
    head = blocks[0]
    point = Point(title=_line_text(head[0]))
    if any("➡" in _line_text(line) for line in head):
        point.see = [
            piece["content"] for line in head for piece in line
            if isinstance(piece, dict) and piece.get("tag") == "a"
        ] or [_line_text(line).split("➡", 1)[1].strip() for line in head if "➡" in _line_text(line)]
        return point
    for line in head[1:]:
        text = _line_text(line)
        (point.meanings if _JAPANESE.search(text) else point.also).append(text)
    patterns = [term, reading]
    notes: list[str] = []
    english: list[str] = []
    for block in blocks[1:]:
        first = _line_text(block[0])
        if _CIRCLED.match(first):
            examples: list[Example] = []
            for line in block:
                text = _line_text(line)
                if _CIRCLED.match(text):
                    text = _CIRCLED.sub("", text)
                    examples.append(Example(marked(text, patterns) if text else []))
                elif examples:
                    # The sentence may start on the line after its number.
                    examples[-1].text += (["\n"] if examples[-1].text else []) + marked(text, patterns)
            point.add("例文", "examples", examples)
        elif first == "接続":
            point.add("接続", "forms", [Form(_line_text(line)) for line in block[1:]])
        else:
            for line in block:
                text = _line_text(line)
                (english if _mostly_latin(text) else notes).append(text)
    if english:
        english[-1] = _TRAILING_TERM.sub("", english[-1]).strip()
    point.add("解説", "text", [note for note in notes if note])
    point.add("English", "text", [note for note in english if note], second=True)
    return point


# ---- 絵でわかる日本語 ----------------------------------------------------------------

_EDE_HEADING = re.compile(r"^【(.+?)】$")
_EDE_EXAMPLE = re.compile(r"^[①-⑳㉑-㉟]\s*")
_EDE_LEVEL = re.compile(r"N\s*([1-5])")
# What the blog put after every post.
_EDE_LEFTOVERS = ("語学(日本語)ランキング", "にほんブログ村", "――以上――", "edewakaru link", "詳細")


def _without_leftovers(line: list) -> list:
    """A line without the blog's links run on at its end."""
    line = list(line)
    if line and isinstance(line[-1], str):
        for leftover in _EDE_LEFTOVERS:
            if line[-1].rstrip().endswith(leftover):
                line[-1] = line[-1].rstrip()[: -len(leftover)]
    return line


def _image_of(nodes: list) -> dict | None:
    for node in nodes:
        if isinstance(node, dict):
            inner = node.get("content")
            if isinstance(inner, dict) and inner.get("tag") == "img":
                return inner
            if node.get("tag") == "img":
                return node
    return None


def _top_nodes(content: object) -> list:
    """The nodes of [content], out of the lists they come in."""
    if isinstance(content, list):
        return [node for item in content for node in _top_nodes(item)]
    return [content]


def parse_edewakaru(content: object, term: str, reading: str, tags: str = "") -> Point:
    nodes = _top_nodes(content)
    image = _image_of(nodes)
    rest = [
        node for node in nodes
        if not (isinstance(node, dict) and ((node.get("data") or {}).get("name") == "header" or _image_of([node])))
    ]
    lines = [_without_leftovers(line) for line in _lines(rest)]
    lines = [line for line in lines if _line_text(line) not in _EDE_LEFTOVERS]
    point = Point(image=image)
    texts = [_line_text(line) for line in lines]
    start = next((at for at, text in enumerate(texts) if text), None)
    if start is None:
        return point
    title, _, about = texts[start].partition("｜")
    point.title = title.strip()
    level = _EDE_LEVEL.search(unicodedata.normalize("NFKC", about))
    if level:
        point.level = f"N{level.group(1)}"
    else:
        known = re.search(r"(初級|中級|上級)", tags)
        point.level = known.group(1) if known else ""
    patterns = [term, reading]
    label, gathered = "", []

    def close() -> None:
        if label == "意味":
            point.meanings.extend(_line_text(line) for line in gathered if _line_text(line))
        elif label == "接続":
            point.add(label, "forms", [Form(_line_text(line)) for line in gathered if _line_text(line)])
        elif label == "例文":
            examples: list[Example] = []
            for line in gathered:
                text = _line_text(line)
                if not text:
                    continue
                if _EDE_EXAMPLE.match(text):
                    first = _stripped(line)
                    if first and isinstance(first[0], str):
                        first[0] = _EDE_EXAMPLE.sub("", first[0])
                    examples.append(Example(_marked_line(first, patterns)))
                elif not examples:
                    continue
                elif text.startswith(("→", "［", "[", "＝", "（復習")):
                    examples[-1].notes.append(text)
                else:
                    examples[-1].text += ["\n", *_stripped(line)]
            point.add(label, "examples", examples)
        else:
            paragraphs: list[list] = []
            current: list = []
            for line in gathered + [[]]:
                if _line_text(line):
                    current += (["\n"] if current else []) + _stripped(line)
                elif current:
                    paragraphs.append(current)
                    current = []
            point.add(label, "text", paragraphs)

    for line in lines[start + 1:]:
        heading = _EDE_HEADING.match(_line_text(line))
        if heading:
            close()
            label, gathered = heading.group(1), []
        else:
            gathered.append(line)
    close()
    return point


# ---- Detecting and rewriting --------------------------------------------------------


def _flat(definition: object) -> str:
    return json.dumps(definition, ensure_ascii=False) if isinstance(definition, dict) else ""


def detect(rows: list) -> str | None:
    """Which grammar dictionary [rows] come from, if any, judged on their
    definitions' own marks."""
    definitions = [
        item for row in rows
        if isinstance(row, list) and len(row) > 5 and isinstance(row[5], list)
        for item in row[5]
    ]
    if not definitions:
        return None

    def share(test) -> float:
        return sum(1 for item in definitions if test(item)) / len(definitions)

    if share(lambda item: isinstance(item, str) and item.lstrip().startswith("文法項目")) >= 0.5:
        return "dojg"
    if share(lambda item: "itazuraneko.neocities.org/grammar/donnatoki" in _flat(item)) >= 0.5:
        return "bunkei"
    if share(lambda item: '"jp-edewakaru"' in _flat(item) or '"jp-kotowaza"' in _flat(item)) >= 0.5:
        return "edewakaru"
    return None


def rewrite_row(row: list, layout: str) -> list:
    """[row] as one grammar point. Its tags, which these dictionaries fill
    with the pattern's other spellings and the book it is from, are left
    out: the point shows those itself."""
    term = row[0] if isinstance(row[0], str) else ""
    reading = row[1] if len(row) > 1 and isinstance(row[1], str) else ""
    tags = row[7] if len(row) > 7 and isinstance(row[7], str) else ""
    spelled = row[2] if len(row) > 2 and isinstance(row[2], str) else ""
    definitions = row[5] if len(row) > 5 and isinstance(row[5], list) else []
    if layout == "dojg":
        text = "\n".join(item if isinstance(item, str) else _plain(item) for item in definitions)
        point = parse_dojg(text, term, reading, spelled)
    else:
        content = [item.get("content") for item in definitions if isinstance(item, dict)]
        if layout == "bunkei":
            point = parse_bunkei(content, term, reading)
        else:
            point = parse_edewakaru(content, term, reading, tags)
    structured = to_structured(point)
    if structured is None:
        return row
    return [term, reading, "", *row[3:5], [structured], *row[6:7], ""]
