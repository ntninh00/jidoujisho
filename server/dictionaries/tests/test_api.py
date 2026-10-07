import hashlib
import io
import time
import zipfile

from conftest import ADMIN, PNG, READER, auth, format_one, frequency, ja_en, ja_ja, kanji, make_zip


def upload(client, data: bytes, token=ADMIN, **params):
    return client.put("/api/dictionaries", content=data, headers=auth(token), params={"name": "test.zip", **params})


def ready(client, dictionary_id: str) -> dict:
    deadline = time.time() + 15
    while time.time() < deadline:
        entry = client.get(f"/api/dictionaries/{dictionary_id}", headers=auth(READER)).json()
        if entry["status"] in ("ready", "failed"):
            return entry
        time.sleep(0.05)
    raise AssertionError("indexing did not finish")


def added(client, data: bytes) -> dict:
    response = upload(client, data)
    assert response.status_code == 202, response.text
    return ready(client, response.json()["id"])


def test_health_needs_no_token(client):
    response = client.get("/api/health")
    assert response.status_code == 200
    assert response.headers["x-content-type-options"] == "nosniff"
    assert "sandbox" in response.headers["content-security-policy"]


def test_everything_else_needs_a_token(client):
    assert client.get("/api/dictionaries").status_code == 401
    assert client.get("/api/dictionaries", headers=auth("wrong-token-0123456789abcdef")).status_code == 401
    assert client.get("/api/me", headers=auth(READER)).json() == {"role": "read"}
    assert client.get("/api/me", headers=auth(ADMIN)).json() == {"role": "admin"}


def test_readers_cannot_change_anything(client):
    assert upload(client, ja_en(), token=READER).status_code == 403
    entry = added(client, ja_en())
    assert client.delete(f"/api/dictionaries/{entry['id']}", headers=auth(READER)).status_code == 403
    assert client.patch(f"/api/dictionaries/{entry['id']}", json={"sourceLanguage": "en"}, headers=auth(READER)).status_code == 403


def test_wrong_tokens_are_slowed_down(client):
    for _ in range(10):
        assert client.get("/api/me", headers=auth("x" * 30)).status_code == 401
    assert client.get("/api/me", headers=auth("x" * 30)).status_code == 429
    # Even the right token waits until the window passes, from that address.
    assert client.get("/api/me", headers=auth(READER)).status_code == 429


def test_upload_index_and_search(client):
    entry = added(client, ja_en())
    assert entry["status"] == "ready", entry["error"]
    assert entry["kinds"] == ["terms"]
    assert entry["counts"]["terms"] == 4
    assert entry["counts"]["media"] == 1
    assert (entry["sourceLanguage"], entry["targetLanguage"]) == ("ja", "en")
    assert entry["languagesGuessed"] is True
    assert entry["fileName"] == "test.zip"

    result = client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "猫"}, headers=auth(READER)).json()
    assert [row[0] for row in result["terms"]] == ["猫", "猫舌"]
    assert result["tags"]["n"] == ["n", "partOfSpeech", 0, "noun", 0]

    # By reading, across hiragana and katakana, exact before longer words.
    by_reading = client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "ネコ"}, headers=auth(READER)).json()
    assert [row[0] for row in by_reading["terms"]] == ["猫", "ネコ", "猫舌"]

    nothing = client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "zzz"}, headers=auth(READER)).json()
    assert nothing["terms"] == []


def test_languages_from_index_are_kept(client):
    entry = added(client, ja_en(sourceLanguage="ja", targetLanguage="en"))
    assert entry["languagesGuessed"] is False


def test_kinds_and_languages_by_kind(client):
    mono = added(client, ja_ja())
    assert (mono["sourceLanguage"], mono["targetLanguage"]) == ("ja", "ja")
    characters = added(client, kanji())
    assert characters["kinds"] == ["kanji"]
    assert characters["sourceLanguage"] == "ja"
    freq = added(client, frequency())
    assert freq["kinds"] == ["frequency"]
    assert (freq["sourceLanguage"], freq["targetLanguage"]) == ("ja", None)

    kanji_result = client.get(f"/api/dictionaries/{characters['id']}/search", params={"q": "猫"}, headers=auth(READER)).json()
    assert kanji_result["kanji"][0][0] == "猫"
    freq_result = client.get(f"/api/dictionaries/{freq['id']}/search", params={"q": "犬"}, headers=auth(READER)).json()
    assert freq_result["termMeta"] == [["犬", "freq", {"value": 80, "displayValue": "80"}]]


def test_format_one_rows_come_back_as_format_three(client):
    entry = added(client, format_one())
    assert entry["status"] == "ready", entry["error"]
    result = client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "ねこ"}, headers=auth(READER)).json()
    assert result["terms"] == [["猫", "ねこ", "n", "", 1, ["cat", "feline"], 0, ""]]
    assert result["tags"]["n"][3] == "noun"


def test_download_is_the_original_zip(client):
    data = ja_en()
    entry = added(client, data)
    response = client.get(f"/api/dictionaries/{entry['id']}/download", headers=auth(READER))
    assert response.status_code == 200
    assert response.content == data
    assert response.headers["etag"] == f'"{hashlib.sha256(data).hexdigest()}"'
    assert entry["sha256"] == hashlib.sha256(data).hexdigest()


def test_media_only_for_listed_pictures(client):
    entry = added(client, ja_en())
    base = f"/api/dictionaries/{entry['id']}/media"
    picture = client.get(base, params={"path": "img/cat.png"}, headers=auth(READER))
    assert picture.status_code == 200
    assert picture.content == PNG
    assert picture.headers["content-type"] == "image/png"
    for path in ("index.json", "term_bank_1.json", "../catalog.sqlite", "img/missing.png"):
        assert client.get(base, params={"path": path}, headers=auth(READER)).status_code == 404


def test_styles_when_the_dictionary_has_them(client):
    css = "span[data-sc-content=\"tag\"] { color: #333; }".encode()
    with zipfile.ZipFile(io.BytesIO(ja_en())) as archive:
        files = {name: archive.read(name) for name in archive.namelist()}
    styled = added(client, make_zip({**files, "styles.css": css}))
    response = client.get(f"/api/dictionaries/{styled['id']}/styles", headers=auth(READER))
    assert response.status_code == 200
    assert response.content == css
    assert response.headers["content-type"].startswith("text/css")
    plain = added(client, ja_ja())
    assert client.get(f"/api/dictionaries/{plain['id']}/styles", headers=auth(READER)).status_code == 404
    assert client.get(f"/api/dictionaries/{styled['id']}/styles").status_code == 401


def test_duplicates_and_replacing(client, settings):
    first = added(client, ja_en())
    again = upload(client, ja_en())
    assert again.status_code == 409
    assert "already on the server" in again.json()["error"]
    client.patch(f"/api/dictionaries/{first['id']}", json={"note": "Kept", "targetLanguage": "vi"}, headers=auth(ADMIN))
    replaced = upload(client, ja_en(), replace="1")
    assert replaced.status_code == 202
    assert replaced.json()["replaces"] == first["id"]
    new = ready(client, replaced.json()["id"])
    ids = [entry["id"] for entry in client.get("/api/dictionaries", headers=auth(READER)).json()]
    assert first["id"] not in ids
    assert new["id"] in ids
    assert new["replaces"] is None
    assert new["note"] == "Kept"
    assert new["targetLanguage"] == "vi"
    assert not (settings.dictionaries_dir / first["id"]).exists()


def test_a_failed_replacement_keeps_the_one_it_replaced(client, settings, monkeypatch):
    from dictserver import indexer

    first = added(client, ja_en())

    def broken(*args, **kwargs):
        raise RuntimeError("disk on fire")

    monkeypatch.setattr(indexer, "build", broken)
    replaced = upload(client, ja_en(), replace="1")
    assert replaced.status_code == 202
    failed = ready(client, replaced.json()["id"])
    assert failed["status"] == "failed"
    kept = client.get(f"/api/dictionaries/{first['id']}", headers=auth(READER)).json()
    assert kept["status"] == "ready"
    assert (settings.dictionaries_dir / first["id"]).exists()
    search = client.get(f"/api/dictionaries/{first['id']}/search", params={"q": "猫"}, headers=auth(READER))
    assert search.status_code == 200


def test_relabel_languages(client):
    entry = added(client, ja_en())
    response = client.patch(f"/api/dictionaries/{entry['id']}", json={"targetLanguage": "vi"}, headers=auth(ADMIN))
    assert response.status_code == 200
    assert (response.json()["sourceLanguage"], response.json()["targetLanguage"]) == ("ja", "vi")
    assert response.json()["languagesGuessed"] is False
    bad = client.patch(f"/api/dictionaries/{entry['id']}", json={"targetLanguage": "Vietnamese!"}, headers=auth(ADMIN))
    assert bad.status_code == 400


def test_admins_describe_dictionaries(client):
    entry = added(client, ja_en(description="From the index"))
    url = f"/api/dictionaries/{entry['id']}"
    assert entry["note"] is None
    guessed = entry["languagesGuessed"]
    response = client.patch(url, json={"note": "  Best for N3 reading.  "}, headers=auth(ADMIN))
    assert response.status_code == 200
    body = response.json()
    assert body["note"] == "Best for N3 reading."
    assert body["description"] == "From the index"
    assert body["languagesGuessed"] == guessed
    listed = client.get("/api/dictionaries", headers=auth(READER)).json()
    assert listed[0]["note"] == "Best for N3 reading."
    assert client.patch(url, json={"note": "x"}, headers=auth(READER)).status_code == 403
    assert client.patch(url, json={"note": "x" * 1001}, headers=auth(ADMIN)).status_code == 400
    assert client.patch(url, json={"note": 5}, headers=auth(ADMIN)).status_code == 400
    relabelled = client.patch(url, json={"targetLanguage": "vi"}, headers=auth(ADMIN)).json()
    assert relabelled["note"] == "Best for N3 reading."
    cleared = client.patch(url, json={"note": "   "}, headers=auth(ADMIN)).json()
    assert cleared["note"] is None
    assert cleared["targetLanguage"] == "vi"


def test_older_catalogs_get_notes(settings):
    import sqlite3

    from dictserver.store import Catalog

    settings.catalog_path.parent.mkdir(parents=True, exist_ok=True)
    with sqlite3.connect(settings.catalog_path) as db:
        db.execute(
            """CREATE TABLE dictionaries (id TEXT PRIMARY KEY, title TEXT NOT NULL,
               revision TEXT NOT NULL, format INTEGER NOT NULL, author TEXT, url TEXT,
               description TEXT, attribution TEXT, source_language TEXT, target_language TEXT,
               languages_guessed INTEGER NOT NULL DEFAULT 0, kinds TEXT NOT NULL DEFAULT '[]',
               counts TEXT NOT NULL DEFAULT '{}', size INTEGER NOT NULL, sha256 TEXT NOT NULL,
               file_name TEXT, uploaded_at REAL NOT NULL, status TEXT NOT NULL, error TEXT)"""
        )
        db.execute(
            """INSERT INTO dictionaries (id, title, revision, format, size, sha256,
               uploaded_at, status) VALUES ('0123456789ab', 'Old', '1', 3, 1, 'x', 0, 'ready')"""
        )
    catalog = Catalog(settings.catalog_path, settings.dictionaries_dir)
    assert catalog.get("0123456789ab")["note"] is None
    assert catalog.set_note("0123456789ab", "kept")["note"] == "kept"


def test_delete_removes_files(client, settings):
    entry = added(client, ja_en())
    assert client.delete(f"/api/dictionaries/{entry['id']}", headers=auth(ADMIN)).status_code == 204
    assert client.get("/api/dictionaries", headers=auth(READER)).json() == []
    assert not (settings.dictionaries_dir / entry["id"]).exists()
    assert client.get(f"/api/dictionaries/{entry['id']}", headers=auth(READER)).status_code == 404


def test_bad_uploads_leave_nothing_behind(client, settings):
    for data, words in (
        (b"not a zip at all", "not a zip"),
        (make_zip({"term_bank_1.json": []}), "no index.json"),
        (make_zip({"index.json": {"title": "x", "revision": "1", "format": 3}, "../x.json": []}), "unsafe file path"),
    ):
        response = upload(client, data)
        assert response.status_code == 400
        assert words in response.json()["error"]
    assert list(settings.incoming_dir.iterdir()) == []
    assert client.get("/api/dictionaries", headers=auth(READER)).json() == []


def test_unreadable_banks_fail_with_a_reason(client):
    data = make_zip({"index.json": {"title": "Broken", "revision": "1", "format": 3}, "term_bank_1.json": b"[not json"})
    entry = ready(client, upload(client, data).json()["id"])
    assert entry["status"] == "failed"
    assert "not valid JSON" in entry["error"]
    assert client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "x"}, headers=auth(READER)).status_code == 409


def test_size_limit(client):
    big = b"\0" * (6 * 1024 * 1024)
    response = client.put("/api/dictionaries", content=big, headers=auth(ADMIN))
    assert response.status_code == 413
