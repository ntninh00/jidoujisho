import io
import zipfile

import pytest

from conftest import ja_en, make_zip
from dictserver.checks import Limits, Rejected, check_zip, safe_name

LIMITS = Limits(max_entries=100, max_uncompressed_bytes=50 * 1024 * 1024, max_bank_bytes=20 * 1024 * 1024)


def check(tmp_path, data: bytes, limits: Limits = LIMITS):
    path = tmp_path / "upload.zip"
    path.write_bytes(data)
    return check_zip(str(path), limits)


def rejected(tmp_path, data: bytes, words: str, limits: Limits = LIMITS) -> None:
    with pytest.raises(Rejected) as error:
        check(tmp_path, data, limits)
    assert words in str(error.value)


def test_a_good_dictionary_passes(tmp_path):
    checked = check(tmp_path, ja_en())
    assert checked.index["title"] == "Test JA-EN"
    assert checked.banks == ["tag_bank_1.json", "term_bank_1.json"]
    assert checked.media == ["img/cat.png"]


@pytest.mark.parametrize("name", ["../evil.json", "/etc/passwd", "a/../../b", "C:/x", "a\\b", "./index.json", "a//b"])
def test_unsafe_paths_are_unsafe(name):
    assert not safe_name(name)


@pytest.mark.parametrize("name", ["index.json", "img/cat.png", "a/b/c.json", "folder/"])
def test_ordinary_paths_are_safe(name):
    assert safe_name(name)


def test_not_a_zip(tmp_path):
    rejected(tmp_path, b"hello, this is not a zip", "not a zip")


def test_path_traversal(tmp_path):
    data = make_zip({"index.json": {"title": "x", "revision": "1", "format": 3}, "../escape.json": []})
    rejected(tmp_path, data, "unsafe file path")


def test_missing_index(tmp_path):
    rejected(tmp_path, make_zip({"term_bank_1.json": []}), "no index.json")


def test_index_without_title(tmp_path):
    data = make_zip({"index.json": {"revision": "1", "format": 3}, "term_bank_1.json": []})
    rejected(tmp_path, data, "no title")


def test_unknown_format(tmp_path):
    data = make_zip({"index.json": {"title": "x", "revision": "1", "format": 9}, "term_bank_1.json": []})
    rejected(tmp_path, data, "supported format")


def test_bad_language_code(tmp_path):
    data = make_zip({"index.json": {"title": "x", "revision": "1", "format": 3, "sourceLanguage": "<script>"}, "term_bank_1.json": []})
    rejected(tmp_path, data, "sourceLanguage")


def test_no_data_banks(tmp_path):
    data = make_zip({"index.json": {"title": "x", "revision": "1", "format": 3}, "tag_bank_1.json": []})
    rejected(tmp_path, data, "no term, kanji or frequency")


def test_zip_bomb(tmp_path):
    data = make_zip({
        "index.json": {"title": "x", "revision": "1", "format": 3},
        "term_bank_1.json": [],
        "padding.bin": b"\0" * (8 * 1024 * 1024),
    })
    rejected(tmp_path, data, "implausible size")


def test_too_many_files(tmp_path):
    files = {"index.json": {"title": "x", "revision": "1", "format": 3}, "term_bank_1.json": []}
    files.update({f"img/{i}.png": b"x" for i in range(120)})
    rejected(tmp_path, make_zip(files), "more than 100 files")


def test_unpacked_size_limit(tmp_path):
    small = Limits(max_entries=100, max_uncompressed_bytes=1000, max_bank_bytes=1000)
    data = make_zip({"index.json": {"title": "x", "revision": "1", "format": 3}, "term_bank_1.json": ["a" * 2000]}, compression=zipfile.ZIP_STORED)
    rejected(tmp_path, data, "too large", small)


def test_symlink(tmp_path):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("index.json", '{"title": "x", "revision": "1", "format": 3}')
        archive.writestr("term_bank_1.json", "[]")
        link = zipfile.ZipInfo("link")
        link.external_attr = (0o120777 << 16)
        archive.writestr(link, "/etc/passwd")
    rejected(tmp_path, buffer.getvalue(), "link")


def test_duplicate_names(tmp_path):
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w") as archive:
        archive.writestr("index.json", '{"title": "x", "revision": "1", "format": 3}')
        archive.writestr("term_bank_1.json", "[]")
        with pytest.warns(UserWarning):
            archive.writestr("term_bank_1.json", "[]")
    rejected(tmp_path, buffer.getvalue(), "same file twice")
