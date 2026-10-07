"""Settings, read once from the environment and an optional `.env` file."""

import os
from dataclasses import dataclass
from pathlib import Path

# Tokens shorter than this are ignored, so a typo can't open the server.
MIN_TOKEN_LENGTH = 24


def _load_dotenv(path: Path) -> None:
    """Reads KEY=VALUE lines into the environment without overriding it.

    Carriage returns and surrounding quotes are stripped, so a file saved on
    Windows still yields the exact token.
    """
    if not path.is_file():
        return
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip().rstrip("\r")
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip("'\"")
        os.environ.setdefault(key, value)


def _tokens(name: str) -> tuple[str, ...]:
    values = (part.strip() for part in os.environ.get(name, "").split(","))
    return tuple(value for value in values if len(value) >= MIN_TOKEN_LENGTH)


def _megabytes(name: str, default: int) -> int:
    return int(os.environ.get(name, default)) * 1024 * 1024


@dataclass(frozen=True)
class Settings:
    """Where data lives, who may do what, and the limits uploads must meet."""

    data_dir: Path
    admin_tokens: tuple[str, ...]
    read_tokens: tuple[str, ...]
    max_upload_bytes: int
    max_uncompressed_bytes: int
    max_bank_bytes: int
    max_entries: int
    min_free_bytes: int
    # The app's strings files, copied here on deploy.
    strings_dir: Path = Path("strings")

    @property
    def incoming_dir(self) -> Path:
        return self.data_dir / "incoming"

    @property
    def dictionaries_dir(self) -> Path:
        return self.data_dir / "dictionaries"

    @property
    def catalog_path(self) -> Path:
        return self.data_dir / "catalog.sqlite"


def load(env_file: Path | None = None) -> Settings:
    _load_dotenv(env_file or Path(os.environ.get("DICT_ENV_FILE", ".env")))
    return Settings(
        data_dir=Path(os.environ.get("DICT_DATA_DIR", "data")),
        admin_tokens=_tokens("DICT_ADMIN_TOKENS"),
        read_tokens=_tokens("DICT_READ_TOKENS"),
        max_upload_bytes=_megabytes("DICT_MAX_UPLOAD_MB", 1024),
        max_uncompressed_bytes=_megabytes("DICT_MAX_UNCOMPRESSED_MB", 6144),
        # Each bank is parsed whole, at several times its size in memory.
        max_bank_bytes=_megabytes("DICT_MAX_BANK_MB", 96),
        max_entries=int(os.environ.get("DICT_MAX_ENTRIES", 60000)),
        min_free_bytes=_megabytes("DICT_MIN_FREE_MB", 5120),
        strings_dir=Path(os.environ.get("DICT_STRINGS_DIR", "strings")),
    )
