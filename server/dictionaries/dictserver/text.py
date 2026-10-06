"""Text helpers: the search key a term is stored under, and a guess at the
language of a sample of text from its writing system."""

import re
import unicodedata
from collections import Counter


def fold_kana(text: str) -> str:
    """Katakana as hiragana, so ネコ and ねこ meet."""
    return "".join(
        chr(ord(ch) - 0x60) if "ァ" <= ch <= "ヶ" else ch for ch in text
    )


def search_key(text: str) -> str:
    """How terms and queries are compared: width and case folded, kana folded."""
    return fold_kana(unicodedata.normalize("NFKC", text).casefold().strip())


def _script(ch: str) -> str | None:
    code = ord(ch)
    if 0x3040 <= code <= 0x30FF or 0x31F0 <= code <= 0x31FF or 0xFF66 <= code <= 0xFF9D:
        return "kana"
    if 0x4E00 <= code <= 0x9FFF or 0x3400 <= code <= 0x4DBF or 0xF900 <= code <= 0xFAFF:
        return "han"
    if 0xAC00 <= code <= 0xD7AF or 0x1100 <= code <= 0x11FF or 0x3130 <= code <= 0x318F:
        return "hangul"
    if 0x0400 <= code <= 0x04FF:
        return "cyrillic"
    if 0x0600 <= code <= 0x06FF:
        return "arabic"
    if 0x0E00 <= code <= 0x0E7F:
        return "thai"
    if ch.isalpha() and code < 0x0250:
        return "latin"
    return None


# Letters only Vietnamese uses among Latin scripts: ă đ ơ ư, and the
# precomposed vowels with tone marks.
_VIETNAMESE_ONLY = set("ăđơưĂĐƠƯ") | {chr(code) for code in range(0x1EA0, 0x1EFA)}
# Accented letters Vietnamese shares with French, Spanish and others. They
# count as Vietnamese only in text that also has the letters above.
_VIETNAMESE_SHARED = set("àáâãèéêìíòóôõùúýÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝ")

_WORD = re.compile(r"[^\W\d_]+")

# Shares of Latin words carrying Vietnamese letters above which text is taken
# as Vietnamese. Vietnamese headwords sit near 0.75 and English ones at 0;
# Vietnamese definitions sit near 0.85, while English definitions quoting
# Vietnamese examples sit near 0.4.
_VIETNAMESE_TERMS = 0.3
_VIETNAMESE_TEXT = 0.6

_NAMES = {
    "japanese": "ja",
    "kana": "ja",
    "han": "zh",
    "hangul": "ko",
    "cyrillic": "ru",
    "arabic": "ar",
    "thai": "th",
}


def _latin_words(text: str) -> list[str]:
    return [
        word for word in _WORD.findall(text)
        if all(_script(ch) == "latin" or ch in _VIETNAMESE_ONLY for ch in word)
    ]


def vietnamese_share(text: str) -> float:
    """The share of Latin words in [text] that carry Vietnamese letters."""
    words = _latin_words(text)
    if not words:
        return 0.0
    only = sum(any(ch in _VIETNAMESE_ONLY for ch in word) for word in words)
    if only / len(words) < 0.01:
        return 0.0
    marked = _VIETNAMESE_ONLY | _VIETNAMESE_SHARED
    return sum(any(ch in marked for ch in word) for word in words) / len(words)


def _latin_language(text: str, vietnamese_above: float) -> str | None:
    """Vietnamese by its letters; plain Latin text is taken as English. Other
    accented text could be any of many languages, so it is left for an
    admin to name."""
    share = vietnamese_share(text)
    if share > vietnamese_above:
        return "vi"
    words = _latin_words(text)
    if not words:
        return None
    vietnamese = _VIETNAMESE_ONLY | _VIETNAMESE_SHARED if share else _VIETNAMESE_ONLY
    foreign = sum(
        any(0x7F < ord(ch) < 0x250 and ch not in vietnamese for ch in word) for word in words
    )
    if foreign / len(words) > 0.15:
        return None
    return "en"


def _scripts(samples: list[str]) -> Counter:
    counts: Counter[str] = Counter()
    for sample in samples:
        for ch in sample:
            script = _script(ch) or ("latin" if ch in _VIETNAMESE_ONLY else None)
            if script:
                counts[script] += 1
    return counts


def _majority(counts: Counter, samples: list[str], vietnamese_above: float) -> str | None:
    total = sum(counts.values())
    if not total:
        return None
    top, top_count = counts.most_common(1)[0]
    if top_count / total < 0.5:
        return None
    if top == "latin":
        return _latin_language(" ".join(samples), vietnamese_above)
    return _NAMES.get(top)


def guess_term_language(samples: list[str]) -> str | None:
    """The language of headwords and their readings. Any real share of kana
    means Japanese, since Japanese dictionaries give readings in kana."""
    counts = _scripts(samples)
    total = sum(counts.values())
    if total and counts["kana"] / total > 0.03:
        return "ja"
    return _majority(counts, samples, _VIETNAMESE_TERMS)


def guess_text_language(samples: list[str]) -> str | None:
    """The language definitions are written in: the script most of the text
    uses, so English definitions quoting Japanese examples count as
    English. Kanji with kana around them are Japanese."""
    counts = _scripts(samples)
    if counts["kana"]:
        counts["japanese"] = counts.pop("kana") + counts.pop("han", 0)
    return _majority(counts, samples, _VIETNAMESE_TEXT)


def plain_text(content: object, out: list[str], limit: int = 400) -> None:
    """Collects visible text from a glossary: plain strings, or Yomitan's
    structured content, up to [limit] characters in all."""
    if sum(len(part) for part in out) >= limit:
        return
    if isinstance(content, str):
        out.append(content[:limit])
    elif isinstance(content, list):
        for item in content:
            plain_text(item, out, limit)
    elif isinstance(content, dict):
        if content.get("type") == "image":
            return
        if "text" in content and isinstance(content["text"], str):
            out.append(content["text"][:limit])
        if "content" in content:
            plain_text(content["content"], out, limit)
