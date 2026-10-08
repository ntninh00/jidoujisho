"""The catalog: one row per dictionary, with where its files are and how far
along its indexing is."""

import json
import re
import shutil
import sqlite3
import threading
import time
from pathlib import Path

from . import tidy

# waiting -> indexing -> ready, or failed with an error the uploader can read.
STATUSES = ("waiting", "indexing", "ready", "failed")


def _encode_notes(notes: dict[str, str]) -> str:
    return json.dumps(notes, ensure_ascii=False, sort_keys=True)


class Catalog:
    def __init__(self, path: Path, dictionaries_dir: Path) -> None:
        self._path = path
        self._dir = dictionaries_dir
        self._lock = threading.Lock()
        path.parent.mkdir(parents=True, exist_ok=True)
        dictionaries_dir.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.execute(
                """CREATE TABLE IF NOT EXISTS dictionaries (
                    id TEXT PRIMARY KEY,
                    title TEXT NOT NULL,
                    revision TEXT NOT NULL,
                    format INTEGER NOT NULL,
                    author TEXT, url TEXT, description TEXT, attribution TEXT,
                    source_language TEXT, target_language TEXT,
                    languages_guessed INTEGER NOT NULL DEFAULT 0,
                    kinds TEXT NOT NULL DEFAULT '[]',
                    counts TEXT NOT NULL DEFAULT '{}',
                    size INTEGER NOT NULL,
                    sha256 TEXT NOT NULL,
                    file_name TEXT,
                    uploaded_at REAL NOT NULL,
                    status TEXT NOT NULL,
                    error TEXT,
                    note TEXT,
                    replaces TEXT,
                    notes TEXT NOT NULL DEFAULT '{}',
                    tidy TEXT
                )"""
            )
            # Catalogs from before these columns get them.
            columns = {row["name"] for row in db.execute("PRAGMA table_info(dictionaries)")}
            for column in ("note", "replaces", "tidy"):
                if column not in columns:
                    db.execute(f"ALTER TABLE dictionaries ADD COLUMN {column} TEXT")
            if "notes" not in columns:
                db.execute("ALTER TABLE dictionaries ADD COLUMN notes TEXT NOT NULL DEFAULT '{}'")
            # A description from before they had languages was written for
            # the app in English, the only language it had then.
            for row in db.execute("SELECT id, note FROM dictionaries WHERE note IS NOT NULL").fetchall():
                db.execute(
                    "UPDATE dictionaries SET notes = ?, note = NULL WHERE id = ?",
                    (_encode_notes({"en": row["note"]}), row["id"]),
                )

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self._path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    def folder(self, dictionary_id: str) -> Path:
        return self._dir / dictionary_id

    def zip_path(self, dictionary_id: str) -> Path:
        return self.folder(dictionary_id) / "dictionary.zip"

    def search_path(self, dictionary_id: str) -> Path:
        return self.folder(dictionary_id) / "search.sqlite"

    @staticmethod
    def _public(row: sqlite3.Row) -> dict:
        """The row as the API shows it."""
        notes = json.loads(row["notes"] or "{}")
        return {
            "id": row["id"],
            "title": row["title"],
            "revision": row["revision"],
            "format": row["format"],
            "author": row["author"],
            "url": row["url"],
            "description": row["description"],
            "attribution": row["attribution"],
            "notes": notes,
            # How its text definitions were laid out (see tidy.py): None
            # before it was looked at, "" when they were left as they are.
            "tidy": row["tidy"],
            # For apps from before descriptions had languages, which were
            # all in English.
            "note": notes.get("en"),
            "replaces": row["replaces"],
            "sourceLanguage": row["source_language"],
            "targetLanguage": row["target_language"],
            "languagesGuessed": bool(row["languages_guessed"]),
            "kinds": json.loads(row["kinds"]),
            "counts": json.loads(row["counts"]),
            "size": row["size"],
            "sha256": row["sha256"],
            "fileName": row["file_name"],
            "uploadedAt": row["uploaded_at"],
            "status": row["status"],
            "error": row["error"],
        }

    def add(self, dictionary_id: str, index: dict, size: int, sha256: str, file_name: str | None,
            replaces: str | None = None) -> dict:
        """A new dictionary, waiting to be indexed. With [replaces], the one it
        takes the place of once it is ready."""
        with self._lock, self._connect() as db:
            db.execute(
                """INSERT INTO dictionaries (id, title, revision, format, author, url,
                   description, attribution, source_language, target_language,
                   size, sha256, file_name, uploaded_at, status, replaces)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'waiting', ?)""",
                (
                    dictionary_id, index["title"], index["revision"], index["format"],
                    index.get("author"), index.get("url"), index.get("description"),
                    index.get("attribution"), index.get("sourceLanguage"),
                    index.get("targetLanguage"), size, sha256, file_name, time.time(), replaces,
                ),
            )
        return self.get(dictionary_id)

    def get(self, dictionary_id: str) -> dict | None:
        with self._connect() as db:
            row = db.execute("SELECT * FROM dictionaries WHERE id = ?", (dictionary_id,)).fetchone()
        return self._public(row) if row else None

    def all(self) -> list[dict]:
        with self._connect() as db:
            rows = db.execute("SELECT * FROM dictionaries ORDER BY title COLLATE NOCASE").fetchall()
        return [self._public(row) for row in rows]

    def find(self, title: str, revision: str) -> dict | None:
        """The dictionary with this title and revision, not counting one
        still on its way to replace it. A dictionary laid out here counts as
        the revision it was uploaded as."""
        with self._connect() as db:
            pattern = re.sub(r"([\\%_])", r"\\\1", revision) + "+jdj%"
            row = db.execute(
                """SELECT * FROM dictionaries WHERE title = ?
                   AND (revision = ? OR revision LIKE ? ESCAPE '\\')
                   ORDER BY replaces IS NOT NULL, uploaded_at LIMIT 1""",
                (title, revision, pattern),
            ).fetchone()
        return self._public(row) if row else None

    @staticmethod
    def _take_over(db: sqlite3.Connection, dictionary_id: str) -> str | None:
        """A replacement that is ready takes the place of the one it
        replaces, keeping the admin's description and checked languages
        where it has none of its own. Returns the id of the one replaced,
        whose files are then the caller's to remove."""
        new = db.execute("SELECT * FROM dictionaries WHERE id = ?", (dictionary_id,)).fetchone()
        if new is None or new["replaces"] is None:
            return None
        old = db.execute("SELECT * FROM dictionaries WHERE id = ?", (new["replaces"],)).fetchone()
        if old is not None:
            notes = {**json.loads(old["notes"] or "{}"), **json.loads(new["notes"] or "{}")}
            source, target, guessed = new["source_language"], new["target_language"], new["languages_guessed"]
            # Only an admin's own labels carry over; one that failed was
            # never labelled at all.
            if new["languages_guessed"] and not old["languages_guessed"] and old["status"] == "ready":
                source, target, guessed = old["source_language"], old["target_language"], 0
            db.execute(
                """UPDATE dictionaries SET notes = ?, source_language = ?, target_language = ?,
                   languages_guessed = ? WHERE id = ?""",
                (_encode_notes(notes), source, target, guessed, dictionary_id),
            )
            db.execute("DELETE FROM dictionaries WHERE id = ?", (old["id"],))
        db.execute("UPDATE dictionaries SET replaces = NULL WHERE id = ?", (dictionary_id,))
        return new["replaces"]

    def with_status(self, *statuses: str) -> list[str]:
        marks = ",".join("?" for _ in statuses)
        with self._connect() as db:
            rows = db.execute(
                f"SELECT id FROM dictionaries WHERE status IN ({marks}) ORDER BY uploaded_at", statuses
            ).fetchall()
        return [row["id"] for row in rows]

    def set_status(self, dictionary_id: str, status: str, error: str | None = None) -> None:
        assert status in STATUSES
        with self._lock, self._connect() as db:
            db.execute(
                "UPDATE dictionaries SET status = ?, error = ? WHERE id = ?",
                (status, error, dictionary_id),
            )

    def set_indexed(self, dictionary_id: str, kinds: list[str], counts: dict,
                    source: str | None, target: str | None) -> None:
        """Records what indexing found. Languages index.json gave are kept;
        only missing ones are filled in from the guess. A replacement then
        takes the place of the one it replaces, in the same transaction."""
        with self._lock, self._connect() as db:
            row = db.execute(
                "SELECT source_language, target_language FROM dictionaries WHERE id = ?",
                (dictionary_id,),
            ).fetchone()
            if row is None:
                return
            guessed = (row["source_language"] is None and source is not None) or (
                row["target_language"] is None and target is not None
            )
            # Indexed again, a dictionary keeps whether its labels were
            # checked.
            db.execute(
                """UPDATE dictionaries SET kinds = ?, counts = ?,
                   source_language = COALESCE(source_language, ?),
                   target_language = COALESCE(target_language, ?),
                   languages_guessed = CASE WHEN ? THEN 1 ELSE languages_guessed END,
                   status = 'ready', error = NULL
                   WHERE id = ?""",
                (json.dumps(kinds), json.dumps(counts), source, target, int(guessed), dictionary_id),
            )
            replaced = self._take_over(db, dictionary_id)
        if replaced is not None:
            shutil.rmtree(self.folder(replaced), ignore_errors=True)

    def set_languages(self, dictionary_id: str, source: str | None, target: str | None) -> dict | None:
        with self._lock, self._connect() as db:
            db.execute(
                """UPDATE dictionaries SET source_language = ?, target_language = ?,
                   languages_guessed = 0 WHERE id = ?""",
                (source, target, dictionary_id),
            )
        return self.get(dictionary_id)

    def set_tidy(self, dictionary_id: str, layout: str, revision: str | None = None,
                 size: int | None = None, sha256: str | None = None) -> None:
        """Records how the dictionary's text was laid out, and the file that
        came of it when it was rewritten."""
        with self._lock, self._connect() as db:
            db.execute(
                """UPDATE dictionaries SET tidy = ?, revision = COALESCE(?, revision),
                   size = COALESCE(?, size), sha256 = COALESCE(?, sha256) WHERE id = ?""",
                (layout, revision, size, sha256, dictionary_id),
            )

    def untidied(self) -> list[str]:
        """Ready dictionaries whose text was not looked at by the current
        layout rules."""
        with self._connect() as db:
            rows = db.execute("SELECT id, tidy FROM dictionaries WHERE status = 'ready'").fetchall()
        return [row["id"] for row in rows if not tidy.is_current(row["tidy"])]

    def set_notes(self, dictionary_id: str, changes: dict[str, str | None]) -> dict | None:
        """The admin's own descriptions, one per app language and kept apart
        from the one the dictionary came with. Only the languages in
        [changes] change; an empty one is removed."""
        with self._lock, self._connect() as db:
            row = db.execute("SELECT notes FROM dictionaries WHERE id = ?", (dictionary_id,)).fetchone()
            if row is None:
                return None
            notes = json.loads(row["notes"] or "{}")
            for language, note in changes.items():
                if note:
                    notes[language] = note
                else:
                    notes.pop(language, None)
            db.execute("UPDATE dictionaries SET notes = ? WHERE id = ?", (_encode_notes(notes), dictionary_id))
        return self.get(dictionary_id)

    def delete(self, dictionary_id: str) -> bool:
        with self._lock, self._connect() as db:
            deleted = db.execute("DELETE FROM dictionaries WHERE id = ?", (dictionary_id,)).rowcount
        shutil.rmtree(self.folder(dictionary_id), ignore_errors=True)
        return bool(deleted)
