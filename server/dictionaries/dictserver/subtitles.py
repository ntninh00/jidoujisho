"""Japanese subtitles from Jimaku (jimaku.cc), for a video the app plays
without any. The account's API key is JIMAKU_KEY in the server's `.env`;
without it the routes say finding subtitles is not set up.

Shows found and their file lists are kept for a while, and files for good,
under `data/subtitles`, so asking again costs Jimaku nothing. A season is
often one ZIP of every episode; the subtitle files inside it are listed
as `season.zip/episode 01.srt`, and only that file is sent to the app.
"""

import codecs
import hashlib
import json
import re
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path
from typing import Callable

API = "https://jimaku.cc/api"
HOST = "jimaku.cc"
USER_AGENT = "jdj-dictionaries (jidoujisho fork)"
SUBTITLE_TYPES = (".srt", ".ass", ".ssa", ".vtt")
MAX_QUERY = 100
MAX_RESULTS = 20
# A subtitle is text; anything bigger is not one.
MAX_FILE_BYTES = 4 * 1024 * 1024
MAX_ARCHIVE_BYTES = 40 * 1024 * 1024
MAX_ARCHIVE_FILES = 400
# Lists are asked for again after this long, as files are added.
LIST_TTL = 30 * 60

Fetch = Callable[[str], bytes]


class SubtitleError(Exception):
    """Subtitles that can't be found or sent, with the status and a message."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def jimaku(key: str) -> Fetch:
    """Fetches from Jimaku with the account's [key]."""

    def fetch(url: str) -> bytes:
        request = urllib.request.Request(url, headers={"Authorization": key, "User-Agent": USER_AGENT})
        try:
            with urllib.request.urlopen(request, timeout=30) as response:
                return response.read(MAX_ARCHIVE_BYTES + 1)
        except urllib.error.HTTPError as error:
            if error.code == 429:
                raise SubtitleError(429, "Jimaku is busy. Try again in a minute.") from None
            if error.code == 404:
                raise SubtitleError(404, "Jimaku doesn't have that.") from None
            if error.code in (401, 403):
                raise SubtitleError(502, "Jimaku refused the server's key.") from None
            raise SubtitleError(502, f"Jimaku answered {error.code}.") from None
        except (urllib.error.URLError, TimeoutError):
            raise SubtitleError(502, "Jimaku could not be reached.") from None

    return fetch


# An episode number in a file name: S01E05, E05, EP05, #05, 第5話, - 05,
# [05] or a lone number, tried in that order.
_EPISODE = [
    re.compile(r"[Ss]\d{1,2}[ ._-]?[Ee](\d{1,4})"),
    re.compile(r"(?:^|[^A-Za-z])(?:EP?|Episode|ep)[ ._-]?(\d{1,4})(?!\d)", re.IGNORECASE),
    re.compile(r"#(\d{1,4})(?!\d)"),
    re.compile(r"第\s*(\d{1,4})\s*[話话回]"),
    re.compile(r"\s-\s(\d{1,4})(?!\d)"),
    re.compile(r"\[(\d{1,4})(?:v\d)?\]"),
]
_NUMBER = re.compile(r"(?<![\dA-Za-z])(\d{1,3})(?![\dA-Za-z])")
# Numbers in names that are rarely episodes.
_NOT_EPISODE = re.compile(r"(?:480|540|576|720|1080|2160)[pP]|[xh]26[45]|10.?bit|\d{4}", re.IGNORECASE)


def episode_of(name: str) -> int | None:
    """The episode a subtitle file is for, guessed from its name."""
    stem = Path(name).stem
    for pattern in _EPISODE:
        match = pattern.search(stem)
        if match:
            return int(match.group(1))
    numbers = _NUMBER.findall(_NOT_EPISODE.sub(" ", stem))
    return int(numbers[-1]) if len(numbers) == 1 else None


def is_subtitle(name: str) -> bool:
    return Path(name).suffix.lower() in SUBTITLE_TYPES


def _on_jimaku(url: object) -> bool:
    """Whether [url] is a file on Jimaku itself, the only place fetched."""
    if not isinstance(url, str):
        return False
    parts = urllib.parse.urlsplit(url)
    return parts.scheme == "https" and parts.hostname == HOST


def as_text(data: bytes) -> str:
    """A subtitle file's text. Japanese ones are often Shift JIS or UTF-16
    rather than UTF-8, which is what the app reads."""
    if data.startswith((codecs.BOM_UTF16_LE, codecs.BOM_UTF16_BE)):
        return data.decode("utf-16")
    for encoding in ("utf-8-sig", "cp932", "gb18030"):
        try:
            return data.decode(encoding)
        except UnicodeDecodeError:
            continue
    return data.decode("utf-8", errors="replace")


class Subtitles:
    def __init__(self, directory: Path, fetch: Fetch | None) -> None:
        self.directory = directory
        self.fetch = fetch
        self.lock = threading.Lock()
        self.kept: dict[str, tuple[float, object]] = {}

    @property
    def enabled(self) -> bool:
        return self.fetch is not None

    def _get(self, url: str) -> bytes:
        if self.fetch is None:
            raise SubtitleError(404, "Finding subtitles is not set up on this server.")
        return self.fetch(url)

    def _remembered(self, key: str, make: Callable[[], object]) -> object:
        with self.lock:
            kept = self.kept.get(key)
            if kept and time.monotonic() - kept[0] < LIST_TTL:
                return kept[1]
        value = make()
        with self.lock:
            self.kept[key] = (time.monotonic(), value)
        return value

    def search(self, query: str) -> list[dict]:
        """Shows whose names match [query], in romaji, English or Japanese."""
        query = " ".join(query.split())
        if not query or len(query) > MAX_QUERY:
            raise SubtitleError(400, f"Search with 1 to {MAX_QUERY} characters.")

        def make() -> list[dict]:
            url = f"{API}/entries/search?" + urllib.parse.urlencode({"query": query, "anime": "true"})
            entries = json.loads(self._get(url))
            return [
                {
                    "id": entry["id"],
                    "name": entry.get("name") or "",
                    "japaneseName": entry.get("japanese_name"),
                    "englishName": entry.get("english_name"),
                    "lastModified": entry.get("last_modified"),
                }
                for entry in entries[:MAX_RESULTS]
                if isinstance(entry.get("id"), int) and not (entry.get("flags") or {}).get("adult")
            ]

        return self._remembered("search " + query.lower(), make)  # type: ignore[return-value]

    def _listing(self, entry: int) -> list[dict]:
        """The entry's files as Jimaku lists them, with their addresses."""

        def make() -> list[dict]:
            files = json.loads(self._get(f"{API}/entries/{entry}/files"))
            return [
                {"name": item["name"], "size": item.get("size") or 0, "url": item["url"]}
                for item in files
                if isinstance(item.get("name"), str) and _on_jimaku(item.get("url"))
            ]

        return self._remembered(f"files {entry}", make)  # type: ignore[return-value]

    def _download(self, url: str, limit: int) -> bytes:
        if not _on_jimaku(url):
            raise SubtitleError(502, "Jimaku listed a file somewhere else.")
        data = self._get(url)
        if len(data) > limit:
            raise SubtitleError(413, "That file is too large to be a subtitle.")
        return data

    def _archive(self, entry: int, item: dict) -> Path:
        """A ZIP of the entry's, fetched once and kept."""
        path = self.directory / str(entry) / (hashlib.sha256(item["url"].encode()).hexdigest() + ".zip")
        if not path.is_file():
            data = self._download(item["url"], MAX_ARCHIVE_BYTES)
            path.parent.mkdir(parents=True, exist_ok=True)
            partial = path.with_suffix(".part")
            partial.write_bytes(data)
            partial.replace(path)
        return path

    def _members(self, archive: Path) -> list[zipfile.ZipInfo]:
        try:
            with zipfile.ZipFile(archive) as opened:
                infos = opened.infolist()
        except zipfile.BadZipFile:
            return []
        return [
            info
            for info in infos[:MAX_ARCHIVE_FILES]
            if not info.is_dir() and is_subtitle(info.filename) and info.file_size <= MAX_FILE_BYTES
        ]

    def files(self, entry: int) -> list[dict]:
        """The entry's subtitle files, those in its ZIPs too, each with the
        episode its name suggests."""
        found = []
        for item in self._listing(entry):
            name = item["name"]
            if is_subtitle(name) and item["size"] <= MAX_FILE_BYTES:
                found.append({"name": name, "size": item["size"]})
            elif name.lower().endswith(".zip") and item["size"] <= MAX_ARCHIVE_BYTES:
                try:
                    archive = self._archive(entry, item)
                except SubtitleError:
                    continue
                for info in self._members(archive):
                    found.append({"name": f"{name}/{info.filename}", "size": info.file_size})
        for file in found:
            file["episode"] = episode_of(file["name"].rsplit("/", 1)[-1])
        return found

    def file(self, entry: int, name: str) -> tuple[Path, str]:
        """One of the entry's subtitle files, as [files] names it: kept on
        disk, with the type it has."""
        cut = name.lower().find(".zip/")
        member = name[cut + 5:] if cut >= 0 else ""
        wanted = name[: cut + 4] if cut >= 0 else name
        item = next((item for item in self._listing(entry) if item["name"] == wanted), None)
        if item is None or not is_subtitle(member or name):
            raise SubtitleError(404, "That show has no such subtitle file.")
        suffix = Path(member or name).suffix.lower()
        path = self.directory / str(entry) / (hashlib.sha256(name.encode()).hexdigest() + suffix)
        if path.is_file():
            return path, suffix
        if member:
            archive = self._archive(entry, item)
            infos = {info.filename: info for info in self._members(archive)}
            if member not in infos:
                raise SubtitleError(404, "That show has no such subtitle file.")
            with zipfile.ZipFile(archive) as opened:
                data = opened.read(infos[member])
        else:
            data = self._download(item["url"], MAX_FILE_BYTES)
        path.parent.mkdir(parents=True, exist_ok=True)
        partial = path.with_suffix(".part")
        partial.write_text(as_text(data), encoding="utf-8", newline="")
        partial.replace(path)
        return path, suffix
