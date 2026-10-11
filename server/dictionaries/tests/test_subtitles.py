import io
import json
import zipfile

import pytest
from conftest import READER, auth

from dictserver import subtitles

SRT = "1\n00:00:01,000 --> 00:00:02,000\n猫猫、薬を作る。\n"


def season_zip() -> bytes:
    data = io.BytesIO()
    with zipfile.ZipFile(data, "w") as archive:
        archive.writestr("Kusuriya/[Sub] Kusuriya no Hitorigoto - 01.ja.srt", SRT)
        archive.writestr("Kusuriya/[Sub] Kusuriya no Hitorigoto - 02.ja.ass", "[Script Info]\n")
        archive.writestr("Kusuriya/readme.txt", "hello")
    return data.getvalue()


class Jimaku:
    """Stands in for Jimaku, counting what it was asked."""

    def __init__(self):
        self.asked: list[str] = []

    def __call__(self, url):
        self.asked.append(url)
        if "/entries/search?" in url:
            return json.dumps([
                {"id": 7, "name": "Kusuriya no Hitorigoto", "japanese_name": "薬屋のひとりごと",
                 "english_name": "The Apothecary Diaries", "flags": {"anime": True},
                 "last_modified": "2026-01-01T00:00:00Z"},
                {"id": 8, "name": "Something adult", "flags": {"adult": True},
                 "last_modified": "2026-01-01T00:00:00Z"},
            ]).encode()
        if url.endswith("/entries/7/files"):
            return json.dumps([
                {"name": "Kusuriya no Hitorigoto S01E03.srt", "size": 40,
                 "url": "https://jimaku.cc/entry/7/download/e03.srt"},
                {"name": "season 1.zip", "size": 900, "url": "https://jimaku.cc/entry/7/download/s1.zip"},
                {"name": "elsewhere.srt", "size": 40, "url": "https://example.com/e.srt"},
                {"name": "notes.txt", "size": 4, "url": "https://jimaku.cc/entry/7/download/notes.txt"},
            ]).encode()
        if url.endswith("/s1.zip"):
            return season_zip()
        if url.endswith("/e03.srt"):
            # Shift JIS, as many Japanese subtitles are.
            return SRT.replace("猫猫", "壬氏").encode("cp932")
        raise subtitles.SubtitleError(404, "Jimaku doesn't have that.")


def test_episodes_are_guessed_from_file_names():
    for name, episode in [
        ("Kusuriya no Hitorigoto S01E03.srt", 3),
        ("[Sub] Kusuriya no Hitorigoto - 12.ja.srt", 12),
        ("薬屋のひとりごと 第5話.ass", 5),
        ("Show EP07 1080p.srt", 7),
        ("Show [24v2].ass", 24),
        ("show_08.srt", 8),
        ("Show 1080p x264.srt", None),
        ("Movie (2023).srt", None),
    ]:
        assert subtitles.episode_of(name) == episode, name


def test_shows_files_and_zips_are_listed(tmp_path):
    jimaku = Jimaku()
    found = subtitles.Subtitles(tmp_path, jimaku)
    assert [entry["id"] for entry in found.search("kusuriya")] == [7]
    assert found.search("  kusuriya ")[0]["japaneseName"] == "薬屋のひとりごと"
    assert sum("/search?" in url for url in jimaku.asked) == 1

    files = found.files(7)
    assert files == [
        {"name": "Kusuriya no Hitorigoto S01E03.srt", "size": 40, "episode": 3},
        {"name": "season 1.zip/Kusuriya/[Sub] Kusuriya no Hitorigoto - 01.ja.srt", "size": len(SRT.encode()),
         "episode": 1},
        {"name": "season 1.zip/Kusuriya/[Sub] Kusuriya no Hitorigoto - 02.ja.ass", "size": 14, "episode": 2},
    ]


def test_a_file_comes_as_utf8_and_only_from_jimaku(tmp_path):
    jimaku = Jimaku()
    found = subtitles.Subtitles(tmp_path, jimaku)
    path, suffix = found.file(7, "Kusuriya no Hitorigoto S01E03.srt")
    assert suffix == ".srt"
    assert path.read_text(encoding="utf-8") == SRT.replace("猫猫", "壬氏")
    path, suffix = found.file(7, "season 1.zip/Kusuriya/[Sub] Kusuriya no Hitorigoto - 01.ja.srt")
    assert path.read_text(encoding="utf-8") == SRT
    # The ZIP was fetched once, for both its listing and its file.
    found.files(7)
    assert sum(url.endswith("/s1.zip") for url in jimaku.asked) == 1
    for name, status in [("elsewhere.srt", 404), ("notes.txt", 404), ("missing.srt", 404),
                         ("season 1.zip/Kusuriya/readme.txt", 404), ("season 1.zip/../../x.srt", 404)]:
        with pytest.raises(subtitles.SubtitleError) as error:
            found.file(7, name)
        assert error.value.status == status, name


def test_searches_that_cannot_be_made(tmp_path):
    found = subtitles.Subtitles(tmp_path, Jimaku())
    for query in ["", "   ", "x" * 101]:
        with pytest.raises(subtitles.SubtitleError) as error:
            found.search(query)
        assert error.value.status == 400
    with pytest.raises(subtitles.SubtitleError) as off:
        subtitles.Subtitles(tmp_path, None).search("kusuriya")
    assert off.value.status == 404


def test_the_routes_need_a_token(settings):
    from starlette.testclient import TestClient

    from dictserver.app import create_app

    with TestClient(create_app(settings, subtitles_fetch=Jimaku())) as client:
        answer = client.get("/api/subtitles/search", params={"query": "kusuriya"}, headers=auth(READER))
        assert answer.status_code == 200
        assert answer.json()["entries"][0]["englishName"] == "The Apothecary Diaries"
        assert client.get("/api/subtitles/search", params={"query": "kusuriya"}).status_code == 401
        files = client.get("/api/subtitles/7/files", headers=auth(READER)).json()["files"]
        assert len(files) == 3
        answer = client.get("/api/subtitles/7/file", params={"name": files[1]["name"]}, headers=auth(READER))
        assert answer.status_code == 200
        assert answer.headers["content-type"] == "text/plain; charset=utf-8"
        assert answer.text == SRT
        assert client.get("/api/subtitles/x/files", headers=auth(READER)).status_code == 404


def test_without_a_key_the_routes_say_so(client):
    answer = client.get("/api/subtitles/search", params={"query": "kusuriya"}, headers=auth(READER))
    assert answer.status_code == 404
    assert "not set up" in answer.json()["error"]
