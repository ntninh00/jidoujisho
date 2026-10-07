"""The app's own wording, editable from the strings page.

Each language has up to three layers, the later winning:

- app: the strings files the app was built with, copied here on deploy;
- upload: strings uploaded from a translating model's replies;
- edit: single strings someone changed on the page.

The app asks for whatever differs from what it was built with, so fixes
show without a new build, and a language the app wasn't built with can be
added from here.
"""

import json
import re
import sqlite3
import threading
import time
from pathlib import Path

BASE = "en"
CODE = re.compile(r"^[a-z]{2,3}$")
PLACEHOLDER = re.compile(r"\$[A-Za-z_][A-Za-z0-9_]*")
MAX_VALUE_LENGTH = 2000
TARGET_LINE = re.compile(r"(?im)^\s*target language:\s*(.+?)\s*$")

# Codes for language names a reply's "Target language:" line may give.
CODES = {
    "arabic": "ar", "chinese": "zh", "dutch": "nl", "english": "en", "filipino": "fil",
    "french": "fr", "german": "de", "hindi": "hi", "indonesian": "id", "italian": "it",
    "japanese": "ja", "korean": "ko", "malay": "ms", "polish": "pl", "portuguese": "pt",
    "russian": "ru", "spanish": "es", "tagalog": "fil", "thai": "th", "turkish": "tr",
    "ukrainian": "uk", "vietnamese": "vi",
}


class Invalid(Exception):
    """A string or language that can't be stored, with the reason."""


def flatten(node: dict, prefix: str = "") -> dict[str, str]:
    """{"a": {"b": "x"}} as {"a.b": "x"}."""
    flat: dict[str, str] = {}
    for key, value in node.items():
        path = f"{prefix}.{key}" if prefix else str(key)
        if isinstance(value, dict):
            flat.update(flatten(value, path))
        elif isinstance(value, str):
            flat[path] = value
    return flat


def unflatten(flat: dict[str, str], order: list[str]) -> dict:
    """[flat] nested again, in the order of [order]."""
    root: dict = {}
    for path in order:
        if path not in flat:
            continue
        node = root
        *parents, last = path.split(".")
        for part in parents:
            node = node.setdefault(part, {})
        node[last] = flat[path]
    return root


def placeholders(text: str) -> set[str]:
    return set(PLACEHOLDER.findall(text))


def json_in(text: str) -> dict | None:
    """The JSON object in a translating model's reply: the biggest one, bare
    or inside a ```json block, with any glossary or notes around it."""
    decoder = json.JSONDecoder()
    best, best_size = None, 0
    for match in re.finditer(r"(?m)^[ \t]*\{", text):
        try:
            value, _ = decoder.raw_decode(text, match.end() - 1)
        except ValueError:
            continue
        if isinstance(value, dict):
            size = len(flatten(value))
            if size > best_size:
                best, best_size = value, size
    return best


def guess_code(texts: list[str]) -> tuple[str | None, str | None]:
    """The language a reply names on its "Target language:" line, and its
    code when it's a common one."""
    for text in texts:
        match = TARGET_LINE.search(text)
        if match:
            name = match.group(1)
            return name, CODES.get(name.lower())
    return None, None


class Strings:
    def __init__(self, files_dir: Path, db_path: Path) -> None:
        self._files_dir = files_dir
        self._db_path = db_path
        self._lock = threading.Lock()
        db_path.parent.mkdir(parents=True, exist_ok=True)
        with self._connect() as db:
            db.execute(
                """CREATE TABLE IF NOT EXISTS languages (
                    code TEXT PRIMARY KEY, name TEXT, updated_at REAL NOT NULL)"""
            )
            db.execute(
                """CREATE TABLE IF NOT EXISTS strings (
                    code TEXT NOT NULL, key TEXT NOT NULL, layer TEXT NOT NULL,
                    value TEXT NOT NULL, updated_at REAL NOT NULL,
                    PRIMARY KEY (code, key, layer))"""
            )
        self._app: dict[str, dict[str, str]] = {}
        self._order: list[str] = []
        self.reload()

    def _connect(self) -> sqlite3.Connection:
        db = sqlite3.connect(self._db_path, timeout=10)
        db.row_factory = sqlite3.Row
        return db

    def reload(self) -> None:
        """Reads the app's strings files: strings.i18n.json is English,
        strings_<code>.i18n.json the others."""
        app: dict[str, dict[str, str]] = {}
        order: list[str] = []
        for path in sorted(self._files_dir.glob("strings*.i18n.json")):
            match = re.fullmatch(r"strings(?:_([a-z]{2,3}))?\.i18n\.json", path.name)
            if not match:
                continue
            code = match.group(1) or BASE
            with open(path, encoding="utf-8") as file:
                flat = flatten(json.load(file))
            app[code] = flat
            if code == BASE:
                order = list(flat)
        self._app, self._order = app, order

    @property
    def english(self) -> dict[str, str]:
        return self._app.get(BASE, {})

    # ---------- reading ----------

    def _layers(self, code: str) -> dict[str, dict[str, tuple[str, float]]]:
        with self._connect() as db:
            rows = db.execute(
                "SELECT key, layer, value, updated_at FROM strings WHERE code = ?", (code,)
            ).fetchall()
        layers: dict[str, dict[str, tuple[str, float]]] = {"upload": {}, "edit": {}}
        for row in rows:
            layers[row["layer"]][row["key"]] = (row["value"], row["updated_at"])
        return layers

    def _effective(self, code: str) -> dict[str, str]:
        layers = self._layers(code)
        values = dict(self._app.get(code, {}))
        for layer in ("upload", "edit"):
            values.update({key: value for key, (value, _) in layers[layer].items()})
        return {key: value for key, value in values.items() if key in self.english}

    def name_of(self, code: str) -> str:
        """The language's name, as its own strings write it when they can."""
        with self._connect() as db:
            row = db.execute("SELECT name FROM languages WHERE code = ?", (code,)).fetchone()
        if row and row["name"]:
            return row["name"]
        own = self._effective(code).get(f"language_names.{code}")
        if own and code != BASE:
            return own
        if code == BASE:
            return "English"
        return self.english.get(f"language_names.{code}", code.upper())

    def languages(self) -> list[dict]:
        with self._connect() as db:
            stored = [row["code"] for row in db.execute("SELECT code FROM languages")]
            counts = {
                row["code"]: (row["edited"], row["updated_at"])
                for row in db.execute(
                    """SELECT code, SUM(layer = 'edit') AS edited, MAX(updated_at) AS updated_at
                       FROM strings GROUP BY code"""
                )
            }
        codes = sorted(set(self._app) | set(stored), key=lambda code: (code != BASE, code))
        total = len(self.english)
        result = []
        for code in codes:
            effective = self._effective(code)
            edited, updated_at = counts.get(code, (0, None))
            result.append({
                "code": code,
                "name": self.name_of(code),
                "builtIn": code in self._app,
                "translated": len(effective),
                "total": total,
                "edited": edited or 0,
                "updatedAt": updated_at,
            })
        return result

    def exists(self, code: str) -> bool:
        return any(language["code"] == code for language in self.languages())

    def rows(self, code: str) -> list[dict]:
        """Every string with its English, its value and where it came from."""
        app = self._app.get(code, {})
        layers = self._layers(code)
        rows = []
        for key in self._order:
            source, value, updated_at = None, None, None
            if key in app:
                source, value = "app", app[key]
            for layer in ("upload", "edit"):
                if key in layers[layer]:
                    value, updated_at = layers[layer][key]
                    source = layer
            rows.append({
                "key": key,
                "english": self.english[key],
                "value": value,
                "source": source,
                "updatedAt": updated_at,
            })
        return rows

    def changes(self, code: str) -> dict:
        """What the app should show over what it was built with: for a
        language it has, the strings that differ; for one it doesn't, all of
        them."""
        app = self._app.get(code, {})
        effective = self._effective(code)
        strings = {key: value for key, value in effective.items() if app.get(key) != value}
        layers = self._layers(code)
        stamps = [stamp for layer in layers.values() for _, stamp in layer.values()]
        return {
            "code": code,
            "name": self.name_of(code),
            "builtIn": code in self._app,
            "updatedAt": max(stamps) if stamps else None,
            "strings": strings,
        }

    def export(self, code: str) -> dict:
        """The language's strings as a strings file, nested like the app's."""
        return unflatten(self._effective(code), self._order)

    # ---------- writing ----------

    def check(self, key: str, value: object) -> str:
        """[value] if it can stand for [key], else Invalid saying why."""
        if key not in self.english:
            raise Invalid("The app has no such string.")
        if not isinstance(value, str) or not value.strip():
            raise Invalid("Write some text, or revert to go back to the original.")
        if len(value) > MAX_VALUE_LENGTH:
            raise Invalid(f"Keep it under {MAX_VALUE_LENGTH} characters.")
        wanted, got = placeholders(self.english[key]), placeholders(value)
        if wanted != got:
            missing = ", ".join(sorted(wanted - got))
            extra = ", ".join(sorted(got - wanted))
            parts = []
            if missing:
                parts.append(f"needs {missing}")
            if extra:
                parts.append(f"has {extra}, which the app doesn't fill in")
            raise Invalid("The text " + " and ".join(parts) + ".")
        return value

    def _touch(self, db: sqlite3.Connection, code: str, name: str | None = None) -> None:
        db.execute(
            """INSERT INTO languages (code, name, updated_at) VALUES (?, ?, ?)
               ON CONFLICT(code) DO UPDATE SET updated_at = excluded.updated_at,
               name = COALESCE(excluded.name, languages.name)""",
            (code, name, time.time()),
        )

    def set(self, code: str, key: str, value: object) -> dict:
        """Changes one string. Setting it back to what's underneath removes
        the change."""
        if not CODE.match(code):
            raise Invalid("Use a two- or three-letter language code, such as vi or zh.")
        value = self.check(key, value)
        layers = self._layers(code)
        underneath = layers["upload"].get(key, (self._app.get(code, {}).get(key), 0))[0]
        with self._lock, self._connect() as db:
            if value == underneath:
                db.execute(
                    "DELETE FROM strings WHERE code = ? AND key = ? AND layer = 'edit'", (code, key)
                )
            else:
                db.execute(
                    """INSERT INTO strings (code, key, layer, value, updated_at)
                       VALUES (?, ?, 'edit', ?, ?)
                       ON CONFLICT(code, key, layer) DO UPDATE SET
                       value = excluded.value, updated_at = excluded.updated_at""",
                    (code, key, value, time.time()),
                )
            self._touch(db, code)
        return self.row(code, key)

    def revert(self, code: str, key: str) -> dict:
        with self._lock, self._connect() as db:
            db.execute(
                "DELETE FROM strings WHERE code = ? AND key = ? AND layer = 'edit'", (code, key)
            )
        return self.row(code, key)

    def row(self, code: str, key: str) -> dict:
        return next(row for row in self.rows(code) if row["key"] == key)

    def upload(self, code: str | None, name: str | None, texts: list[str]) -> dict:
        """Takes the strings in translating models' replies for [code]. Each
        reply may hold part of the strings; the parts add up. Strings that
        can't be used are listed with the reason; edits made on the page
        stay on top."""
        guessed_name, guessed_code = guess_code(texts)
        code = (code or guessed_code or "").strip().lower()
        if not CODE.match(code):
            raise Invalid("Give the language's two- or three-letter code, such as zh or id.")
        if code == BASE:
            raise Invalid("English is what the others are translated from; edit its strings one by one.")
        found: dict[str, str] = {}
        unreadable = 0
        for text in texts:
            parsed = json_in(text)
            if parsed is None:
                unreadable += 1
                continue
            found.update(flatten(parsed))
        if not found:
            raise Invalid("No strings found. Upload the replies with the JSON in them.")

        taken: dict[str, str] = {}
        skipped = []
        for key, value in found.items():
            try:
                taken[key] = self.check(key, value)
            except Invalid as error:
                skipped.append({"key": key, "value": value, "reason": str(error)})
        now = time.time()
        with self._lock, self._connect() as db:
            db.executemany(
                """INSERT INTO strings (code, key, layer, value, updated_at)
                   VALUES (?, ?, 'upload', ?, ?)
                   ON CONFLICT(code, key, layer) DO UPDATE SET
                   value = excluded.value, updated_at = excluded.updated_at""",
                [(code, key, value, now) for key, value in taken.items()],
            )
            name = (name or "").strip() or None
            self._touch(db, code, name)
            kept = db.execute(
                "SELECT COUNT(*) FROM strings WHERE code = ? AND layer = 'edit'", (code,)
            ).fetchone()[0]
        effective = self._effective(code)
        return {
            "code": code,
            "name": self.name_of(code),
            "targetLanguage": guessed_name,
            "taken": len(taken),
            "skipped": skipped,
            "missing": [key for key in self._order if key not in effective],
            "keptEdits": kept,
            "unreadable": unreadable,
        }

    def remove(self, code: str) -> None:
        """Drops everything uploaded and edited for [code]."""
        with self._lock, self._connect() as db:
            db.execute("DELETE FROM strings WHERE code = ?", (code,))
            db.execute("DELETE FROM languages WHERE code = ?", (code,))

    # ---------- prompts ----------

    def prompts(self, language: str, system: str) -> dict:
        """The system prompt and the two messages that ask a model to
        translate the English into [language], each small enough for a
        40,000-character message."""
        english = unflatten(self.english, self._order)
        keys = list(english)
        dump = lambda part: json.dumps(part, ensure_ascii=False, indent=2)
        whole = len(dump(english))
        best, best_gap = 1, None
        for cut in range(1, len(keys)):
            gap = abs(len(dump({key: english[key] for key in keys[:cut]})) - whole / 2)
            if best_gap is None or gap < best_gap:
                best, best_gap = cut, gap
        parts = [{key: english[key] for key in keys[:best]}, {key: english[key] for key in keys[best:]}]
        head = f"Target language: {language}\n\n"
        return {
            "system": system,
            "messages": [
                head + dump(parts[0]) + "\n",
                head + "Glossary from part 1:\n"
                "(replace this line with the glossary block from the part 1 reply)\n\n"
                + dump(parts[1]) + "\n",
            ],
        }
