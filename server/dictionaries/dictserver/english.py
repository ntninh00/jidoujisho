"""Lays out English dictionaries written as plain text, each in a format of
its own, into the entries tidy.py turns into structured content:

- Wordset: `1. pos: noun` before each meaning, then `ex:` and `syn:` lines.
- Cambridge: blocks of a word class with its grammar, `[ C ] · formal`, a
  meaning and `·` examples, sometimes under a phrase.
- NOAD: the headword in syllables with two pronunciations run together,
  word classes, numbered meanings with `•` narrower ones and examples after
  `:  `, then PHRASES, DERIVATIVES and ORIGIN; wrapped at 78 characters.
- MacMillan: a `US /…/` pronunciation, word classes in capitals, numbered
  meanings (`1.`, `1a.`) with grammar in capitals, and `·` examples, often
  after the pattern they show.
- MWALD: lines indented by what they are: pronunciation and word class,
  meanings (`1 a : …`), examples. Its cross-references reached Yomitan
  without their targets (`↑<>`) and are left out.
"""

from __future__ import annotations

import re

from .tidy import Body, Example, _Builder


def detect(texts: list[str]) -> str | None:
    """Which of these dictionaries a sample of definitions comes from."""

    def share(pattern: str, flags: int = re.M) -> float:
        compiled = re.compile(pattern, flags)
        return sum(bool(compiled.search(text)) for text in texts) / len(texts)

    if share(r"\A\d+\. pos: ") > 0.5:
        return "wordset"
    if share(r"^\t· ") > 0.2 and share(r"^\t[^\s·]") > 0.5:
        return "cambridge"
    if share(r"^(?:US|UK) /") > 0.3 and share(r"^\d+[a-z]?\. ") > 0.5:
        return "macmillan"
    if share(r"\A[^\n]*\| [^|\n]* \|") > 0.3 and share(r"^(?:ORIGIN|DERIVATIVES)$") > 0.1:
        return "noad"
    if share(r"^ {4}(?:\d+(?: [a-z])?)? *:") > 0.4 and share(r"^ {6}\S") > 0.3:
        return "mwald"
    return None


def parse(layout: str, texts: list[str], term: str) -> Body:
    body = {
        "wordset": parse_wordset,
        "cambridge": parse_cambridge,
        "noad": parse_noad,
        "macmillan": parse_macmillan,
        "mwald": parse_mwald,
    }[layout](texts, term)
    body.monolingual = True
    return body


def _lines(text: str) -> list[str]:
    return [line.strip() for line in text.split("\n") if line.strip()]


# ---------- Wordset ----------

def parse_wordset(texts: list[str], term: str = "") -> Body:
    builder = _Builder()
    for text in texts:
        for line in _lines(text):
            head = re.match(r"^\d+\.\s*pos:\s*(.*)$", line)
            if head:
                label = head.group(1).strip()
                sections = builder.body.sections
                if not sections or sections[-1].label != label:
                    builder.section(label, "pos")
                builder.sense("")
            elif line.startswith("ex:"):
                builder.example(Example(line[3:].strip()))
            elif line.startswith("syn:"):
                builder.target().synonyms += [word.strip() for word in line[4:].split(",") if word.strip()]
            else:
                sense = builder.target()
                sense.gloss = f"{sense.gloss} {line}".strip()
    return builder.finish()


# ---------- Cambridge ----------

_CAMBRIDGE_CLASSES = (
    r"(?:noun|verb|adjective|adverb|preposition|conjunction|pronoun|determiner|predeterminer"
    r"|exclamation|suffix|prefix|number|ordinal number|auxiliary verb|modal verb|phrasal verb"
    r"|plural noun|noun plural|combining form|abbreviation|symbol|short form|idiom|interjection)"
)
_CAMBRIDGE_CLASS = re.compile(
    rf"^({_CAMBRIDGE_CLASSES}(?:,\s*{_CAMBRIDGE_CLASSES})*)\s*((?:\[[^\]]*\]\s*)*)(?:·\s*(.*))?$"
)
# `past simple and past participle of buttress`, as a row of its own.
_CAMBRIDGE_FORM = re.compile(
    r"^((?:past simple|past participle|present participle|plural|superlative|comparative|short form)"
    r"(?:(?:,| and) (?:past simple|past participle))*) of (\S.*?)(?:\s{2,}.*)?$"
)


def _grammar(brackets: str, usage: str | None) -> str:
    """`[ C ]` and `informal` as `[C] informal`."""
    codes = re.sub(r"\[\s*(.*?)\s*\]", r"[\1]", brackets.strip())
    return " ".join(part for part in (codes, (usage or "").strip()) if part)


def parse_cambridge(texts: list[str], term: str = "") -> Body:
    builder = _Builder()
    for text in texts:
        blocks: list[list[str]] = [[]]
        for line in text.split("\n"):
            if line.strip():
                blocks[-1].append(line.strip())
            elif blocks[-1]:
                blocks.append([])
        for number, lines in enumerate(block for block in blocks if block):
            form = _CAMBRIDGE_FORM.match(lines[0]) if number == 0 else None
            if form:
                builder.body.forms.append((form.group(2).strip(), form.group(1)))
                lines = lines[1:]
            at, label = 0, ""
            # A phrase, as `shortly after/before sth`, before its word class.
            if len(lines) > 1 and _CAMBRIDGE_CLASS.match(lines[1]) and not _CAMBRIDGE_CLASS.match(lines[0]) \
                    and not lines[0].startswith(("·", "→")):
                builder.section(lines[0], "idiom")
                at = 1
            if at < len(lines) and (word_class := _CAMBRIDGE_CLASS.match(lines[at])):
                label = _grammar(word_class.group(2), word_class.group(3))
                if at:
                    label = f"{word_class.group(1)} {label}".strip()
                else:
                    sections = builder.body.sections
                    if not sections or sections[-1].kind != "pos" or sections[-1].label != word_class.group(1):
                        builder.section(word_class.group(1), "pos")
                at += 1
            opened = False
            for line in lines[at:]:
                if line.startswith("·"):
                    builder.example(Example(line[1:].strip()))
                elif line.startswith("→"):
                    builder.ref(line[1:].strip(" \xa0:"))
                elif line == "Term is not in the Cambridge Dictionary yet.":
                    builder.note(line)
                elif not opened or builder.target().examples:
                    builder.sense(line.rstrip(" :"), label)
                    opened = True
                else:
                    sense = builder.target()
                    sense.gloss = f"{sense.gloss} {line.rstrip(' :')}".strip()
    return builder.finish()


# ---------- NOAD ----------

_NOAD_CLASS = re.compile(
    r"^(?:noun|verb|adjective|adverb|abbreviation|plural noun|combining form|preposition"
    r"|conjunction|pronoun|exclamation|prefix|suffix|determiner|predeterminer|contraction|symbol"
    r"|number|cardinal number|ordinal number|modal verb|auxiliary verb|possessive determiner"
    r"|possessive pronoun|interjection|article|infinitive particle)\b(?!.*:  )"
)
_NOAD_HEADINGS = {"PHRASES", "PHRASAL VERBS", "DERIVATIVES", "ORIGIN", "USAGE"}
_PHRASE_HEADINGS = {"PHRASES", "PHRASAL VERBS"}
_WIDTH = 78
# Letters NOAD's own respelling uses and IPA does not, and the other way.
_RESPELLING_ONLY = set("äāēīōôūȯ͝͞ABCDEFGHIJKLMNOPQRSTUVWXYZ")
_IPA_ONLY = set("ɑɪʊθŋʃʒɛɔæʌɡɜɝɚɹðɒɐʤʧɫɾʔ")


def _common_start(a: str, b: str) -> int:
    count = 0
    for x, y in zip(a, b):
        if x != y:
            break
        count += 1
    return count


def noad_ipa(pronunciation: str) -> str:
    """NOAD gives its own respelling and IPA run together, as
    `änˈsämbəlɑnˈsɑmbəl`: the IPA, or all of it when they can't be told
    apart. The IPA starts after the respelling's last letter of its own and
    by IPA's first; where that leaves a choice, both halves start alike and
    are about as long."""
    text = pronunciation.strip()
    last = max((at for at, ch in enumerate(text) if ch in _RESPELLING_ONLY), default=-1)
    first = next((at for at, ch in enumerate(text) if ch in _IPA_ONLY), len(text))
    candidates = [at for at in range(last + 1, first + 1) if 0 < at < len(text)]
    if not candidates or last > first:
        return text
    split = max(
        candidates,
        key=lambda at: (_common_start(text[:at], text[at:]), -abs(len(text[:at]) - len(text[at:]))),
    )
    ipa = text[split:].strip()
    return ipa if len(ipa) >= 2 else text


def _noad_marker(line: str) -> bool:
    """A line that starts something: never the rest of a wrapped one."""
    return bool(
        re.match(r"^(\d+ |•)", line) or line in _NOAD_HEADINGS or (_NOAD_CLASS.match(line) and len(line) < 60)
    )


def _noad_meaning(text: str) -> tuple[str, list[str]]:
    """`a group of musicians:  a Bulgarian folk ensemble |  a jazz one` as the
    meaning and its examples."""
    gloss, _, examples = text.replace("\\+", "+").partition(":  ")
    found = [example.strip() for example in re.split(r"\s+\|\s+", examples) if example.strip()]
    return gloss.strip().rstrip(":"), found


def parse_noad(texts: list[str], term: str = "") -> Body:
    builder = _Builder()
    for text in texts:
        # Lines are joined where the source wrapped them: where the next
        # word would not have fitted. Never onto the headword's line, nor a
        # phrase in PHRASES, nor a meaning there that ended with a full
        # stop: the line after a phrase is its meaning, and the line after
        # a meaning is the next phrase.
        lines: list[tuple[str, bool]] = []
        state = None
        last_length = 0
        for raw in text.split("\n"):
            line = raw.rstrip()
            stripped = line.strip()
            if stripped in _NOAD_HEADINGS:
                state = stripped
            phrases = state in _PHRASE_HEADINGS and stripped not in _NOAD_HEADINGS
            previous, is_phrase = lines[-1] if lines else ("", False)
            wrapped = (
                len(lines) > 1 and previous and stripped and not is_phrase and not _noad_marker(stripped)
                and last_length + 1 + len(stripped.split(" ")[0]) > _WIDTH
                and not (phrases and previous.endswith("."))
            )
            if wrapped:
                lines[-1] = (previous + ("  " if previous.endswith(":") else " ") + stripped, False)
            else:
                after_phrase = bool(lines) and lines[-1][1]
                lines.append((stripped, phrases and bool(stripped) and not _noad_marker(stripped) and not after_phrase))
            last_length = len(line)

        state = None
        for number, (line, is_phrase) in enumerate(lines):
            if not line:
                continue
            if number == 0:
                head = re.match(r"^(.*?)\s*\|\s*([^|]*?)\s*\|\s*(.*)$", line)
                if head:
                    builder.body.syllables = head.group(1) if "·" in head.group(1) else ""
                    builder.body.pronunciation = noad_ipa(head.group(2))
                    continue
                if "·" in line or line.lower() == term.lower():
                    builder.body.syllables = line
                    continue
            if line in _NOAD_HEADINGS:
                state = line
                builder.section(line, "heading")
                continue
            if state in ("ORIGIN", "USAGE"):
                builder.note(line.replace("\\+", "+"))
                continue
            if state == "DERIVATIVES":
                derived = re.match(r"^(.*?)\s*\|\s*([^|]*?)\s*\|\s*(.*)$", line)
                if derived:
                    builder.sense(f"{derived.group(1)}  /{noad_ipa(derived.group(2))}/  {derived.group(3)}".strip())
                else:
                    # A derived word's class on a line of its own.
                    sense = builder.target()
                    sense.gloss = f"{sense.gloss}  {line}".strip()
                continue
            if _NOAD_CLASS.match(line) and len(line) < 60:
                builder.section(line, "pos")
                continue
            if is_phrase:
                builder.section(line, "idiom")
                continue
            numbered = re.match(r"^\d+\s+(.*)$", line)
            bullet = line.startswith("•")
            gloss, examples = _noad_meaning(numbered.group(1) if numbered else line.lstrip("• ") if bullet else line)
            if bullet:
                builder.subsense(gloss)
            else:
                builder.sense(gloss)
            for example in examples:
                builder.example(Example(example))
    return builder.finish()


# ---------- MacMillan ----------

_MACMILLAN_CLASS = re.compile(
    r"^(?:NOUN|VERB|ADJECTIVE|ADVERB|PHRASE|PHRASAL VERB|ABBREVIATION|INTERJECTION|PREPOSITION"
    r"|CONJUNCTION|PRONOUN|DETERMINER|NUMBER|PREFIX|SUFFIX|MODAL VERB|AUXILIARY VERB"
    r"|PREDETERMINER|QUANTIFIER|ORDINAL NUMBER|SHORT FORM|SYMBOL)\b[A-Z /,'()-]*$"
)
_CAPITALS = re.compile(r"^[A-Z][A-Z /,'()-]*$")


def _pattern(text: str) -> Example:
    """`call for: A hiker heard his calls for help.` as the pattern and the
    example."""
    match = re.match(r"^([a-z][^:]{0,60}?):\s+(\S.*)$", text)
    if match:
        return Example(match.group(2), pattern=match.group(1))
    return Example(text)


def parse_macmillan(texts: list[str], term: str = "") -> Body:
    builder = _Builder()
    for text in texts:
        for line in _lines(text):
            ipa = re.match(r"^(?:US|UK)\s*/(.+)/$", line)
            if ipa:
                builder.body.pronunciation = builder.body.pronunciation or ipa.group(1).strip()
                continue
            if line in ("US", "UK"):
                continue
            if _MACMILLAN_CLASS.match(line):
                builder.section(line.lower(), "pos")
                continue
            sense = re.match(r"^\d+([a-z]?)\.\s*(.*)$", line)
            if sense:
                rest = re.sub(r"\s+-\s+from Open Dictionary$", "", sense.group(2).strip())
                label, gloss = (rest.lower(), "") if _CAPITALS.match(rest) else ("", rest)
                if sense.group(1):
                    builder.subsense(gloss, label)
                else:
                    builder.sense(gloss, label)
                continue
            if line.startswith("·"):
                builder.example(_pattern(line[1:].strip()))
                continue
            target = builder.target()
            if not target.gloss and not target.examples:
                target.gloss = line
            elif not target.label and not target.examples:
                # A phrase, or a field such as `Capital`, then its meaning.
                target.label, target.gloss = target.gloss, line
            else:
                builder.sense(line)
    return builder.finish()


# ---------- MWALD ----------

_MWALD_CLASS = re.compile(
    r"^(?:noun|verb|adj|adv|abbr|prep|pronoun|conj|interj|det|article|prefix|suffix|adj suffix"
    r"|noun suffix|verb suffix|phrasal verb|plural noun|noun plural|auxiliary verb|modal verb"
    r"|trademark|biographical name|geographical name)\b"
)
_LOST_REF = re.compile(r"\s*:?\s*↑<>(?:,\s*\d+)*")


def _mwald_clean(line: str) -> str:
    """Without the cross-references that lost their targets: `— see also
    ↑<>` goes, as does the `: ↑<>` after a meaning, and `<>PRETTY<>` is
    PRETTY."""
    if "↑<>" in line and re.match(r"^(?:—\s*)?(?:see|compare)\b", line):
        return ""
    if "↑<>" in line:
        line = _LOST_REF.sub("", line)
        line = re.sub(r"\s+of$", "", line)
        line = re.sub(r"\s*—\s*(?:see also|see|compare)[\s,.]*$", "", line)
    return line.replace("<>", "").strip()


def says_nothing(layout: str, texts: list[str]) -> bool:
    """MWALD entries that were only cross-references, all lost."""
    return layout == "mwald" and not any(
        _mwald_clean(line.strip()) for text in texts for line in text.split("\n")
        if not re.fullmatch(r"\s*(?:[IVX]+|—+)\s*", line)
    )


def parse_mwald(texts: list[str], term: str = "") -> Body:
    builder = _Builder()
    for text in texts:
        sense_indent: int | None = None
        top: str | None = None
        notes_mode = False
        for number, raw in enumerate(text.split("\n")):
            if not raw.strip():
                continue
            indent = len(raw) - len(raw.lstrip(" "))
            line = _mwald_clean(raw.strip())
            if not line or re.fullmatch(r"[IVX]+|—+|•( •)*", line) or line.startswith("Main Entry"):
                continue
            if number == 0 and indent == 0 and "·" in line:
                builder.body.syllables = line
                continue
            if line.startswith("—"):
                builder.note(line.lstrip("— ").strip())
                continue
            # The pronunciation and word class, sometimes after other
            # spellings: `(also Brit am·or·tise) /ˈæmɚˌtaız/ verb`.
            head = re.match(r"^(\(.*\))?\s*/([^/]+)/\s*(.*)$", line)
            if head and indent <= 2:
                builder.body.pronunciation = builder.body.pronunciation or head.group(2).strip()
                label = " ".join(part for part in (head.group(3).strip().rstrip(","), head.group(1)) if part)
                if label:
                    builder.section(label, "pos")
                sense_indent, top, notes_mode = None, None, False
                continue
            if indent <= 2 and line in ("synonyms", "usage"):
                builder.section(line, "heading")
                sense_indent, top, notes_mode = indent, None, True
                continue
            if indent == 0 and sense_indent is not None:
                # Some examples lost their indent.
                builder.example(Example(line.rstrip(" /")))
                continue
            if indent <= 2 and not notes_mode:
                builder.section(line, "pos" if _MWALD_CLASS.match(line) else "idiom")
                sense_indent, top = None, None
                continue
            if line.startswith(": ") and top is not None and not notes_mode:
                # The meaning of a phrase above, indented as an example.
                target = builder.target()
                if target.gloss or target.examples:
                    builder.sense(line[2:].strip())
                else:
                    target.gloss = line[2:].strip()
                continue
            if sense_indent is not None and indent > sense_indent:
                builder.example(Example(line.rstrip(" /")))
                continue
            sense_indent = indent
            if not (line[0].isdigit() or line.startswith(":")):
                phrase = re.match(r"^(.*?)\s+:\s+(.*)$", line)
                if notes_mode:
                    builder.sense(line)
                elif phrase:
                    # `flip open or flip (something) open : to open …`
                    builder.sense(phrase.group(2), phrase.group(1))
                else:
                    # A run-on word, as `prodding noun`, with examples below.
                    builder.sense("", line)
                continue
            digits, rest = re.match(r"^(\d*)\s*(.*)$", line).groups()
            # `1 a : …` and `1 a old-fashioned : …` are under `1`; `3 a lot`
            # is not lettered.
            letter = None
            if re.match(r"^[a-z](?:$|\s*:|\s+[^:]*\s:)", rest):
                letter, rest = rest[0], rest[1:].strip()
            if rest.startswith(":"):
                label, gloss = "", rest[1:].strip()
            elif split := re.match(r"^(.*?)\s*:\s+(.*)$", rest):
                label, gloss = split.group(1), split.group(2)
            else:
                label, gloss = rest.rstrip(" :"), ""
            if letter and digits == top:
                builder.subsense(gloss, label)
            elif letter:
                # `2 a` with no `2` above it leads its group.
                builder.sense(gloss, label)
                top = digits
            else:
                builder.sense(gloss, label)
                top = digits
    return builder.finish()
