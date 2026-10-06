"""Builds a dictionary's search database from its zip.

Each kind of row is kept as Yomitan's own JSON, in the newest format, next
to the key it is found by. Old format 1 rows are brought up to format 3 so
clients only ever see one shape.
"""

import json
import os
import sqlite3
import zipfile
from dataclasses import dataclass, field

from .checks import BANK, Checked, Rejected
from .text import guess_term_language, guess_text_language, plain_text, search_key

SCHEMA = """
CREATE TABLE terms (key TEXT NOT NULL, reading_key TEXT NOT NULL, score INTEGER NOT NULL, row TEXT NOT NULL);
CREATE TABLE kanji (key TEXT NOT NULL, row TEXT NOT NULL);
CREATE TABLE term_meta (key TEXT NOT NULL, mode TEXT NOT NULL, row TEXT NOT NULL);
CREATE TABLE kanji_meta (key TEXT NOT NULL, mode TEXT NOT NULL, row TEXT NOT NULL);
CREATE TABLE tags (name TEXT PRIMARY KEY, row TEXT NOT NULL);
CREATE TABLE media (path TEXT PRIMARY KEY);
"""

INDEXES = """
CREATE INDEX terms_key ON terms (key);
CREATE INDEX terms_reading ON terms (reading_key);
CREATE INDEX kanji_key ON kanji (key);
CREATE INDEX term_meta_key ON term_meta (key);
CREATE INDEX kanji_meta_key ON kanji_meta (key);
"""

MAX_KEY = 300


@dataclass
class Summary:
    """What indexing found: counts by kind, and the languages it guessed."""

    counts: dict[str, int] = field(default_factory=dict)
    kinds: list[str] = field(default_factory=list)
    source_language: str | None = None
    target_language: str | None = None


def _dump(row: list) -> str:
    return json.dumps(row, ensure_ascii=False, separators=(",", ":"))


def _term_row(row: list, version: int) -> list | None:
    """[term, reading, definitionTags, rules, score, glossary, sequence, termTags]."""
    if not isinstance(row, list) or len(row) < 5 or not isinstance(row[0], str):
        return None
    term = row[0]
    reading = row[1] if isinstance(row[1], str) else ""
    if not term or len(term) > MAX_KEY:
        return None
    score = row[4] if isinstance(row[4], (int, float)) else 0
    if version == 1:
        glossary = [item for item in row[5:] if isinstance(item, str)]
        return [term, reading, row[2] or "", row[3] or "", score, glossary, 0, ""]
    if len(row) < 6 or not isinstance(row[5], list):
        return None
    sequence = row[6] if len(row) > 6 and isinstance(row[6], int) else 0
    term_tags = row[7] if len(row) > 7 and isinstance(row[7], str) else ""
    return [term, reading, row[2] or "", row[3] or "", score, row[5], sequence, term_tags]


def _kanji_row(row: list, version: int) -> list | None:
    """[character, onyomi, kunyomi, tags, meanings, stats]."""
    if not isinstance(row, list) or len(row) < 4 or not isinstance(row[0], str) or not row[0]:
        return None
    if version == 1:
        meanings = [item for item in row[4:] if isinstance(item, str)]
        return [row[0], row[1] or "", row[2] or "", row[3] or "", meanings, {}]
    meanings = row[4] if len(row) > 4 and isinstance(row[4], list) else []
    stats = row[5] if len(row) > 5 and isinstance(row[5], dict) else {}
    return [row[0], row[1] or "", row[2] or "", row[3] or "", meanings, stats]


def _meta_row(row: list) -> list | None:
    """[term or character, mode, data]."""
    if (
        not isinstance(row, list) or len(row) < 3
        or not isinstance(row[0], str) or not row[0] or len(row[0]) > MAX_KEY
        or not isinstance(row[1], str)
    ):
        return None
    return [row[0], row[1], row[2]]


def _tag_row(row: list) -> list | None:
    """[name, category, order, notes, score]."""
    if not isinstance(row, list) or len(row) < 5 or not isinstance(row[0], str) or not row[0]:
        return None
    return row[:5]


def build(zip_path: str, out_path: str, checked: Checked) -> Summary:
    """Writes the search database to [out_path], or raises [Rejected]."""
    temp_path = out_path + ".building"
    if os.path.exists(temp_path):
        os.remove(temp_path)
    summary = Summary()
    counts = {"terms": 0, "kanji": 0, "termMeta": 0, "kanjiMeta": 0, "tags": 0, "media": len(checked.media)}
    meta_modes: set[str] = set()
    term_samples: list[str] = []
    gloss_samples: list[str] = []
    version = checked.index["format"]

    db = sqlite3.connect(temp_path)
    try:
        db.executescript(SCHEMA)
        with zipfile.ZipFile(zip_path) as archive:
            index = json.loads(archive.read("index.json").decode("utf-8-sig"))
            tag_meta = index.get("tagMeta")
            if isinstance(tag_meta, dict):
                for name, meta in tag_meta.items():
                    if isinstance(name, str) and isinstance(meta, dict):
                        row = [name, meta.get("category", ""), meta.get("order", 0), meta.get("notes", ""), meta.get("score", 0)]
                        db.execute("INSERT OR REPLACE INTO tags VALUES (?, ?)", (name, _dump(row)))
                        counts["tags"] += 1

            for bank in checked.banks:
                kind = BANK.match(bank).group(1)
                try:
                    rows = json.loads(archive.read(bank).decode("utf-8-sig"))
                except (UnicodeDecodeError, json.JSONDecodeError):
                    raise Rejected(f"{bank} is not valid JSON.") from None
                except (zipfile.BadZipFile, OSError, RuntimeError):
                    raise Rejected(f"{bank} could not be read from the zip.") from None
                if not isinstance(rows, list):
                    raise Rejected(f"{bank} should hold a list of entries.")

                good = 0
                for raw in rows:
                    if kind == "term":
                        row = _term_row(raw, version)
                        if row:
                            db.execute(
                                "INSERT INTO terms VALUES (?, ?, ?, ?)",
                                (search_key(row[0]), search_key(row[1]), int(row[4]), _dump(row)),
                            )
                            counts["terms"] += 1
                            if len(term_samples) < 3000:
                                term_samples.append(row[0] + row[1])
                            if len(gloss_samples) < 1500:
                                text: list[str] = []
                                plain_text(row[5], text, 200)
                                gloss_samples.append(" ".join(text))
                    elif kind == "kanji":
                        row = _kanji_row(raw, version)
                        if row:
                            db.execute("INSERT INTO kanji VALUES (?, ?)", (row[0], _dump(row)))
                            counts["kanji"] += 1
                            if len(term_samples) < 3000:
                                term_samples.append(row[1] + row[2])
                            if len(gloss_samples) < 1500:
                                gloss_samples.append(" ".join(m for m in row[4] if isinstance(m, str)))
                    elif kind in ("term_meta", "kanji_meta"):
                        row = _meta_row(raw)
                        if row:
                            table = kind
                            db.execute(
                                f"INSERT INTO {table} VALUES (?, ?, ?)",
                                (search_key(row[0]), row[1], _dump(row)),
                            )
                            counts["termMeta" if kind == "term_meta" else "kanjiMeta"] += 1
                            meta_modes.add(row[1])
                            if kind == "term_meta" and len(term_samples) < 3000:
                                # Frequency and pitch data often carry the reading.
                                reading = row[2].get("reading") if isinstance(row[2], dict) else None
                                term_samples.append(row[0] + (reading if isinstance(reading, str) else ""))
                    else:
                        row = _tag_row(raw)
                        if row:
                            db.execute("INSERT OR REPLACE INTO tags VALUES (?, ?)", (row[0], _dump(row)))
                            counts["tags"] += 1
                    if row:
                        good += 1
                if rows and good < len(rows) / 2:
                    raise Rejected(f"Most entries in {bank} could not be read.")

        db.executemany("INSERT INTO media VALUES (?)", ((path,) for path in checked.media))
        db.executescript(INDEXES)
        db.commit()
    except BaseException:
        db.close()
        if os.path.exists(temp_path):
            os.remove(temp_path)
        raise
    db.close()
    os.replace(temp_path, out_path)

    kinds = []
    if counts["terms"]:
        kinds.append("terms")
    if counts["kanji"]:
        kinds.append("kanji")
    if "freq" in meta_modes:
        kinds.append("frequency")
    if "pitch" in meta_modes:
        kinds.append("pitch")
    if "ipa" in meta_modes:
        kinds.append("ipa")
    summary.counts = counts
    summary.kinds = kinds
    summary.source_language = guess_term_language(term_samples)
    if counts["terms"] or counts["kanji"]:
        summary.target_language = guess_text_language(gloss_samples)
    return summary
