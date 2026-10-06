"""Looks words up in one dictionary's search database for a preview.

Exact matches on the term or its reading come first, best scored first,
then words starting with the query. Kanji dictionaries are searched by
each character of the query. The tags the results use are returned with
them, so a client can show their names and colours.
"""

import json
import sqlite3
from pathlib import Path

from .text import search_key

MAX_QUERY = 100


def _rows(db: sqlite3.Connection, sql: str, args: tuple) -> list[list]:
    return [json.loads(row[0]) for row in db.execute(sql, args)]


def _prefix_bounds(key: str) -> tuple[str, str]:
    return key, key + "\U0010ffff"


def search(path: Path, query: str, limit: int = 20) -> dict:
    key = search_key(query[:MAX_QUERY])
    result: dict = {"terms": [], "kanji": [], "termMeta": [], "kanjiMeta": [], "tags": {}}
    if not key:
        return result
    limit = max(1, min(limit, 50))
    low, high = _prefix_bounds(key)

    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        exact = _rows(
            db,
            "SELECT row FROM terms WHERE key = ? OR reading_key = ? ORDER BY score DESC LIMIT ?",
            (key, key, limit),
        )
        terms = exact
        if len(terms) < limit:
            seen = {json.dumps(row, ensure_ascii=False) for row in terms}
            more = _rows(
                db,
                """SELECT row FROM terms
                   WHERE (key > ? AND key < ?) OR (reading_key > ? AND reading_key < ?)
                   ORDER BY length(key), score DESC LIMIT ?""",
                (low, high, low, high, limit),
            )
            for row in more:
                text = json.dumps(row, ensure_ascii=False)
                if text not in seen and len(terms) < limit:
                    seen.add(text)
                    terms.append(row)
        result["terms"] = terms

        characters = list(dict.fromkeys(ch for ch in query[:MAX_QUERY] if not ch.isspace()))[:limit]
        for ch in characters:
            result["kanji"].extend(_rows(db, "SELECT row FROM kanji WHERE key = ?", (ch,)))
            result["kanjiMeta"].extend(_rows(db, "SELECT row FROM kanji_meta WHERE key = ?", (ch,)))

        result["termMeta"] = _rows(
            db,
            "SELECT row FROM term_meta WHERE key = ? LIMIT ?",
            (key, limit),
        ) or _rows(
            db,
            "SELECT row FROM term_meta WHERE key > ? AND key < ? ORDER BY length(key) LIMIT ?",
            (low, high, limit),
        )

        names: set[str] = set()
        for row in result["terms"]:
            for field in (row[2], row[7]):
                if isinstance(field, str):
                    names.update(field.split())
        for row in result["kanji"]:
            if isinstance(row[3], str):
                names.update(row[3].split())
        if names:
            marks = ",".join("?" for _ in names)
            for name, row in db.execute(f"SELECT name, row FROM tags WHERE name IN ({marks})", tuple(names)):
                result["tags"][name] = json.loads(row)
    finally:
        db.close()
    return result


def has_media(path: Path, media: str) -> bool:
    db = sqlite3.connect(f"file:{path}?mode=ro", uri=True)
    try:
        return db.execute("SELECT 1 FROM media WHERE path = ?", (media,)).fetchone() is not None
    finally:
        db.close()
