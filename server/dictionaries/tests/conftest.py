import io
import json
import sys
import zipfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

ADMIN = "admin-token-0123456789abcdef"
READER = "reader-token-0123456789abcdef"

# A 1x1 transparent PNG.
PNG = bytes.fromhex(
    "89504e470d0a1a0a0000000d4948445200000001000000010806000000"
    "1f15c4890000000d49444154789c6360000002000154a24f5d0000000049454e44ae426082"
)


# A small copy of the app's strings files.
ENGLISH = {
    "back": "Back",
    "import_name": "Importing 『$name』...",
    "retrying_in": {"seconds": {"one": "Retrying in $n second...", "other": "Retrying in $n seconds..."}},
    "language_names": {"vi": "Vietnamese", "zh": "Chinese"},
    "addons": {"field": {"term": {"label": "Term"}}},
}
VIETNAMESE = {
    "back": "Quay lại",
    "import_name": "Đang nhập 『$name』...",
    "language_names": {"vi": "Tiếng Việt"},
}


def make_zip(files: dict[str, object], *, compression=zipfile.ZIP_DEFLATED) -> bytes:
    """A zip of [files]; values that aren't bytes are written as JSON."""
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression) as archive:
        for name, value in files.items():
            data = value if isinstance(value, bytes) else json.dumps(value, ensure_ascii=False).encode()
            archive.writestr(name, data)
    return buffer.getvalue()


def ja_en(title="Test JA-EN", revision="1", **index) -> bytes:
    return make_zip({
        "index.json": {"title": title, "revision": revision, "format": 3, "sequenced": True, **index},
        "tag_bank_1.json": [["n", "partOfSpeech", 0, "noun", 0]],
        "term_bank_1.json": [
            ["猫", "ねこ", "n", "", 10, ["cat", {"type": "structured-content", "content": {"tag": "img", "path": "img/cat.png"}}], 1, ""],
            ["猫舌", "ねこじた", "n", "", 5, ["sensitive to hot food"], 2, ""],
            ["ネコ", "ねこ", "", "", 1, [{"type": "structured-content", "content": "cat (in katakana)"}], 3, ""],
            ["犬", "いぬ", "n", "", 9, ["dog"], 4, ""],
        ],
        "img/cat.png": PNG,
    })


def ja_ja() -> bytes:
    return make_zip({
        "index.json": {"title": "Test 国語", "revision": "2024", "format": 3},
        "term_bank_1.json": [["猫", "ねこ", "", "", 0, ["ネコ科の小形の哺乳類。愛玩用に飼われる。"], 1, ""]],
    })


def kanji() -> bytes:
    return make_zip({
        "index.json": {"title": "Test Kanji", "revision": "1", "format": 3},
        "kanji_bank_1.json": [["猫", "ビョウ", "ねこ", "", ["cat"], {"strokes": "11"}]],
    })


def frequency() -> bytes:
    return make_zip({
        "index.json": {"title": "Test Frequency", "revision": "1", "format": 3, "frequencyMode": "rank-based"},
        "term_meta_bank_1.json": [
            ["猫", "freq", {"reading": "ねこ", "frequency": 120}],
            ["犬", "freq", {"value": 80, "displayValue": "80"}],
            ["する", "freq", 1],
        ],
    })


def format_one() -> bytes:
    return make_zip({
        "index.json": {"title": "Old Format", "revision": "v1", "version": 1, "tagMeta": {"n": {"category": "pos", "order": 0, "notes": "noun"}}},
        "term_bank_1.json": [["猫", "ねこ", "n", "", 1, "cat", "feline"]],
    })


@pytest.fixture
def settings(tmp_path):
    from dictserver import config

    strings_dir = tmp_path / "strings"
    strings_dir.mkdir()
    (strings_dir / "strings.i18n.json").write_text(json.dumps(ENGLISH, ensure_ascii=False), encoding="utf-8")
    (strings_dir / "strings_vi.i18n.json").write_text(json.dumps(VIETNAMESE, ensure_ascii=False), encoding="utf-8")
    return config.Settings(
        strings_dir=strings_dir,
        data_dir=tmp_path / "data",
        admin_tokens=(ADMIN,),
        read_tokens=(READER,),
        max_upload_bytes=5 * 1024 * 1024,
        max_uncompressed_bytes=20 * 1024 * 1024,
        max_bank_bytes=10 * 1024 * 1024,
        max_entries=1000,
        min_free_bytes=0,
    )


@pytest.fixture
def client(settings):
    from starlette.testclient import TestClient

    from dictserver.app import create_app

    with TestClient(create_app(settings)) as test_client:
        yield test_client


def auth(token: str) -> dict:
    return {"Authorization": f"Bearer {token}"}
