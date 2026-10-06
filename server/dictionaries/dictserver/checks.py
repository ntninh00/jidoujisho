"""Checks an uploaded file before anything is unpacked from it.

Only the zip's central directory and `index.json` are read here, so even a
large upload is judged in well under a second. The bank files are read
later, while indexing, and only up to the sizes the directory declares.
"""

import json
import re
import zipfile
from dataclasses import dataclass, field
from pathlib import PurePosixPath

# Yomitan's data files, always at the top of the zip.
BANK = re.compile(r"^(term|term_meta|kanji|kanji_meta|tag)_bank_(\d{1,6})\.json$")

# Pictures used by structured content; the only files served on their own.
MEDIA_TYPES = {
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".gif": "image/gif",
    ".webp": "image/webp",
    ".bmp": "image/bmp",
    ".avif": "image/avif",
    ".svg": "image/svg+xml",
}

LANGUAGE = re.compile(r"^[a-z]{2,3}(-[A-Za-z0-9]{1,8})*$")
MAX_INDEX_BYTES = 1024 * 1024
# A file that inflates more than this many times its packed size is refused.
MAX_RATIO = 200
SUPPORTED_COMPRESSION = {zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED, zipfile.ZIP_BZIP2, zipfile.ZIP_LZMA}


class Rejected(Exception):
    """The upload is not a usable dictionary. The message says why, in words
    meant for the person uploading."""


@dataclass(frozen=True)
class Limits:
    max_entries: int
    max_uncompressed_bytes: int
    max_bank_bytes: int


@dataclass
class Checked:
    """What a dictionary zip holds, once it has passed every check."""

    index: dict
    banks: list[str] = field(default_factory=list)
    media: list[str] = field(default_factory=list)
    uncompressed_bytes: int = 0


def safe_name(name: str) -> bool:
    """A relative path with no way out of the zip's own folder."""
    if not name or len(name) > 1024 or "\x00" in name or "\\" in name:
        return False
    if name.startswith("/") or re.match(r"^[A-Za-z]:", name):
        return False
    parts = name.rstrip("/").split("/")
    return all(part not in ("", ".", "..") for part in parts)


def _text(value: object, limit: int) -> str | None:
    if value is None:
        return None
    if not isinstance(value, str):
        raise Rejected("index.json has a field that should be text but isn't.")
    return value.strip()[:limit] or None


def read_index(raw: bytes) -> dict:
    """Validates `index.json` and keeps only the fields the catalog shows."""
    try:
        index = json.loads(raw.decode("utf-8-sig"))
    except (UnicodeDecodeError, json.JSONDecodeError):
        raise Rejected("index.json is not valid JSON.") from None
    if not isinstance(index, dict):
        raise Rejected("index.json should hold a JSON object.")

    title = _text(index.get("title"), 200)
    if not title:
        raise Rejected("index.json has no title.")
    revision = index.get("revision")
    if isinstance(revision, (int, float)):
        revision = str(revision)
    revision = _text(revision, 100)
    if not revision:
        raise Rejected("index.json has no revision.")
    version = index.get("format", index.get("version"))
    if version not in (1, 2, 3):
        raise Rejected("index.json gives no supported format (1, 2 or 3).")

    languages = {}
    for key in ("sourceLanguage", "targetLanguage"):
        value = index.get(key)
        if value is not None:
            if not isinstance(value, str) or not LANGUAGE.match(value):
                raise Rejected(f"index.json has an invalid {key}.")
            languages[key] = value.lower()

    return {
        "title": title,
        "revision": revision,
        "format": version,
        "sequenced": bool(index.get("sequenced", False)),
        "author": _text(index.get("author"), 300),
        "url": _text(index.get("url"), 500),
        "description": _text(index.get("description"), 4000),
        "attribution": _text(index.get("attribution"), 4000),
        "frequencyMode": _text(index.get("frequencyMode"), 40),
        **languages,
    }


def _why_no_index(names: set[str]) -> str:
    """Explains a zip without index.json in the two usual cases: a pack of
    several dictionaries, or a dictionary zipped inside its folder."""
    packed = sorted(PurePosixPath(name).name for name in names if name.lower().endswith(".zip"))
    if packed:
        listed = ", ".join(packed[:4]) + (", …" if len(packed) > 4 else "")
        return f"This zip holds other dictionaries ({listed}). Unzip it and upload those one at a time."
    nested = sorted(name for name in names if name.endswith("/index.json"))
    if nested:
        folder = nested[0][: -len("/index.json")]
        return f"index.json is inside the folder {folder!r}. Zip the folder's contents, not the folder."
    return "There is no index.json at the top of the zip. Is this a Yomitan dictionary?"


def check_zip(path: str, limits: Limits) -> Checked:
    """Refuses anything that is not a plain, sensibly sized Yomitan zip."""
    if not zipfile.is_zipfile(path):
        raise Rejected("This is not a zip file.")
    try:
        archive = zipfile.ZipFile(path)
    except (zipfile.BadZipFile, OSError):
        raise Rejected("The zip file is damaged.") from None

    with archive:
        infos = archive.infolist()
        if not infos:
            raise Rejected("The zip file is empty.")
        if len(infos) > limits.max_entries:
            raise Rejected(f"The zip holds more than {limits.max_entries} files.")

        names: set[str] = set()
        total = 0
        for info in infos:
            name = info.filename
            if info.flag_bits & 0x1:
                raise Rejected("Password-protected zips are not accepted.")
            if not safe_name(name):
                raise Rejected(f"The zip has an unsafe file path: {name[:120]!r}.")
            if name in names:
                raise Rejected(f"The zip has the same file twice: {name[:120]!r}.")
            names.add(name)
            kind = (info.external_attr >> 16) & 0o170000
            if kind == 0o120000:
                raise Rejected("The zip contains a link, which is not accepted.")
            if info.compress_type not in SUPPORTED_COMPRESSION:
                raise Rejected("The zip uses an unsupported kind of compression.")
            if info.is_dir():
                continue
            total += info.file_size
            if info.file_size > 1024 * 1024 and info.file_size > info.compress_size * MAX_RATIO:
                raise Rejected("A file in the zip unpacks to an implausible size.")
            if BANK.match(name) and info.file_size > limits.max_bank_bytes:
                raise Rejected(f"{name} is too large.")

        if total > limits.max_uncompressed_bytes:
            raise Rejected("The dictionary unpacks to more than the server allows.")
        if "index.json" not in names:
            raise Rejected(_why_no_index(names))
        index_info = archive.getinfo("index.json")
        if index_info.file_size > MAX_INDEX_BYTES:
            raise Rejected("index.json is too large.")
        try:
            index = read_index(archive.read(index_info))
        except (zipfile.BadZipFile, OSError, RuntimeError):
            raise Rejected("index.json could not be read from the zip.") from None

        banks = sorted(
            (name for name in names if BANK.match(name)),
            key=lambda name: (BANK.match(name).group(1), int(BANK.match(name).group(2))),
        )
        if not any(not name.startswith("tag_") for name in banks):
            raise Rejected("The zip has no term, kanji or frequency data.")
        media = sorted(
            name for name in names
            if not name.endswith("/") and PurePosixPath(name).suffix.lower() in MEDIA_TYPES
        )
        return Checked(index=index, banks=banks, media=media, uncompressed_bytes=total)
