"""The catalog: one row per dictionary, with where its files are and how far
along its indexing is."""

import json
import shutil
import sqlite3
import threading
import time
from pathlib import Path

# waiting -> indexing -> ready, or failed with an error the uploader can read.
STATUSES = ("waiting", "indexing", "ready", "failed")


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
                    note TEXT
                )"""
            )
            # Catalogs from before notes get the column.
            columns = {row["name"] for row in db.execute("PRAGMA table_info(dictionaries)")}
            if "note" not in columns:
                db.execute("ALTER TABLE dictionaries ADD COLUMN note TEXT")

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
        return {
            "id": row["id"],
            "title": row["title"],
            "revision": row["revision"],
            "format": row["format"],
            "author": row["author"],
            "url": row["url"],
            "description": row["description"],
            "attribution": row["attribution"],
            "note": row["note"],
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

    def add(self, dictionary_id: str, index: dict, size: int, sha256: str, file_name: str | None) -> dict:
        with self._lock, self._connect() as db:
            db.execute(
                """INSERT INTO dictionaries (id, title, revision, format, author, url,
                   description, attribution, source_language, target_language,
                   size, sha256, file_name, uploaded_at, status)
                   VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'waiting')""",
                (
                    dictionary_id, index["title"], index["revision"], index["format"],
                    index.get("author"), index.get("url"), index.get("description"),
                    index.get("attribution"), index.get("sourceLanguage"),
                    index.get("targetLanguage"), size, sha256, file_name, time.time(),
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
        with self._connect() as db:
            row = db.execute(
                "SELECT * FROM dictionaries WHERE title = ? AND revision = ?", (title, revision)
            ).fetchone()
        return self._public(row) if row else None

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
        only missing ones are filled in from the guess."""
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
            db.execute(
                """UPDATE dictionaries SET kinds = ?, counts = ?,
                   source_language = COALESCE(source_language, ?),
                   target_language = COALESCE(target_language, ?),
                   languages_guessed = ?, status = 'ready', error = NULL
                   WHERE id = ?""",
                (json.dumps(kinds), json.dumps(counts), source, target, int(guessed), dictionary_id),
            )

    def set_languages(self, dictionary_id: str, source: str | None, target: str | None) -> dict | None:
        with self._lock, self._connect() as db:
            db.execute(
                """UPDATE dictionaries SET source_language = ?, target_language = ?,
                   languages_guessed = 0 WHERE id = ?""",
                (source, target, dictionary_id),
            )
        return self.get(dictionary_id)

    def set_note(self, dictionary_id: str, note: str | None) -> dict | None:
        """The admin's own description, kept apart from the one the
        dictionary came with."""
        with self._lock, self._connect() as db:
            db.execute("UPDATE dictionaries SET note = ? WHERE id = ?", (note, dictionary_id))
        return self.get(dictionary_id)

    def delete(self, dictionary_id: str) -> bool:
        with self._lock, self._connect() as db:
            deleted = db.execute("DELETE FROM dictionaries WHERE id = ?", (dictionary_id,)).rowcount
        shutil.rmtree(self.folder(dictionary_id), ignore_errors=True)
        return bool(deleted)
