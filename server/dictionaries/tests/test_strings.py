import json

from conftest import ADMIN, READER, auth


def test_the_page_needs_no_token_but_its_data_does(client):
    page = client.get("/strings")
    assert page.status_code == 200
    assert "text/html" in page.headers["content-type"]
    assert "script-src 'self'" in page.headers["content-security-policy"]
    assert client.get("/strings/page.js").status_code == 200
    assert client.get("/strings/page.css").status_code == 200
    assert client.get("/api/strings").status_code == 401


def test_languages_the_app_has(client):
    body = client.get("/api/strings", headers=auth(READER)).json()
    languages = {language["code"]: language for language in body["languages"]}
    assert list(languages) == ["en", "vi"]
    assert languages["vi"]["name"] == "Tiếng Việt"
    assert languages["vi"]["builtIn"] is True
    assert languages["vi"]["total"] == 7
    assert languages["vi"]["translated"] == 3


def test_both_tokens_edit_a_string(client):
    url = "/api/strings/vi/back"
    edited = client.put(url, json={"value": "Trở lại"}, headers=auth(READER))
    assert edited.status_code == 200
    assert edited.json()["value"] == "Trở lại"
    assert edited.json()["source"] == "edit"
    assert client.put("/api/strings/vi/import_name", json={"value": "Nhập 『$name』"}, headers=auth(ADMIN)).status_code == 200

    rows = {row["key"]: row for row in client.get("/api/strings/vi", headers=auth(READER)).json()["strings"]}
    assert rows["back"]["english"] == "Back"
    assert rows["back"]["value"] == "Trở lại"
    assert rows["addons.field.term.label"]["value"] is None
    assert rows["retrying_in.seconds.one"]["english"] == "Retrying in $n second..."

    changes = client.get("/api/strings/vi/changes", headers=auth(READER)).json()
    assert changes["strings"] == {"back": "Trở lại", "import_name": "Nhập 『$name』"}

    reverted = client.delete(url, headers=auth(READER)).json()
    assert reverted["value"] == "Quay lại"
    assert reverted["source"] == "app"
    # Writing back what the app has is the same as reverting.
    client.put(url, json={"value": "Lùi"}, headers=auth(READER))
    same = client.put(url, json={"value": "Quay lại"}, headers=auth(READER)).json()
    assert same["source"] == "app"


def test_edits_must_fit_the_app(client):
    def put(key, value):
        return client.put(f"/api/strings/vi/{key}", json={"value": value}, headers=auth(READER))

    lost = put("import_name", "Đang nhập...")
    assert lost.status_code == 400
    assert "$name" in lost.json()["error"]
    assert "$count" in put("import_name", "Đang nhập $name $count").json()["error"]
    assert put("back", "   ").status_code == 400
    assert put("back", "x" * 2001).status_code == 400
    assert put("back", 5).status_code == 400
    assert put("no_such_string", "x").status_code == 404
    assert client.put("/api/strings/VI!/back", json={"value": "x"}, headers=auth(READER)).status_code == 404
    assert client.put("/api/strings/vi/back", json={"value": "x"}).status_code == 401


ZH_PART_1 = json.dumps({"back": "返回", "import_name": "正在导入『$name』……"}, ensure_ascii=False, indent=2)
ZH_PART_2 = (
    "Target language: Chinese\n\nGlossary from part 1:\ncard = 卡片\n\n"
    + json.dumps({
        "retrying_in": {"seconds": {"one": "$n 秒后重试……", "other": "$n 秒后重试……"}},
        "language_names": {"vi": "越南语", "zh": "中文"},
        "addons": {"field": {"term": {"label": "词条"}}},
        "not_in_the_app": "x",
    }, ensure_ascii=False, indent=2)
    + "\n\n```glossary\nterm = 词条\n```\n"
)


def test_uploading_replies_adds_a_language(client):
    response = client.post("/api/strings/upload", json={"texts": [ZH_PART_1, ZH_PART_2]}, headers=auth(READER))
    assert response.status_code == 200
    report = response.json()
    assert report["code"] == "zh"
    assert report["targetLanguage"] == "Chinese"
    assert report["name"] == "中文"
    assert report["taken"] == 7
    assert [skipped["key"] for skipped in report["skipped"]] == ["not_in_the_app"]
    assert report["missing"] == []

    languages = {language["code"]: language for language in client.get("/api/strings", headers=auth(READER)).json()["languages"]}
    assert languages["zh"]["builtIn"] is False
    assert languages["zh"]["translated"] == 7

    # The app doesn't have Chinese, so it gets every string.
    changes = client.get("/api/strings/zh/changes", headers=auth(READER)).json()
    assert changes["builtIn"] is False
    assert changes["strings"]["back"] == "返回"
    assert len(changes["strings"]) == 7

    # An edit stays on top of a later upload.
    client.put("/api/strings/zh/back", json={"value": "后退"}, headers=auth(READER))
    again = client.post(
        "/api/strings/upload", json={"code": "zh", "texts": [ZH_PART_1]}, headers=auth(READER)
    ).json()
    assert again["keptEdits"] == 1
    rows = {row["key"]: row for row in client.get("/api/strings/zh", headers=auth(READER)).json()["strings"]}
    assert rows["back"]["value"] == "后退"
    assert client.delete("/api/strings/zh/back", headers=auth(READER)).json()["value"] == "返回"

    exported = client.get("/api/strings/zh/export", headers=auth(READER)).json()
    assert exported["retrying_in"]["seconds"]["one"] == "$n 秒后重试……"


def test_uploads_that_cant_be_used(client):
    def upload(**body):
        return client.post("/api/strings/upload", json=body, headers=auth(READER))

    assert "code" in upload(texts=[ZH_PART_1]).json()["error"]
    assert upload(code="en", texts=[ZH_PART_1]).status_code == 400
    assert "No strings" in upload(code="zh", texts=["no json here"]).json()["error"]
    assert upload(code="zh", texts="not a list").status_code == 400
    wrong = upload(code="zh", texts=[json.dumps({"import_name": "正在导入"}), ZH_PART_1]).json()
    # The later reply's good string wins over the earlier broken one.
    assert wrong["skipped"] == []
    broken = upload(code="ko", texts=[json.dumps({"import_name": "가져오는 중"})]).json()
    assert broken["taken"] == 0
    assert "$name" in broken["skipped"][0]["reason"]


def test_only_admins_remove_a_language(client):
    client.post("/api/strings/upload", json={"code": "zh", "texts": [ZH_PART_1]}, headers=auth(READER))
    assert client.delete("/api/strings/zh", headers=auth(READER)).status_code == 403
    assert client.delete("/api/strings/zh", headers=auth(ADMIN)).status_code == 204
    codes = [language["code"] for language in client.get("/api/strings", headers=auth(READER)).json()["languages"]]
    assert codes == ["en", "vi"]
    assert client.get("/api/strings/zh", headers=auth(READER)).status_code == 404


def test_prompts_for_a_new_language(client):
    body = client.get("/api/strings/prompts", params={"language": "Indonesian"}, headers=auth(READER)).json()
    assert "target language" in body["system"]
    assert len(body["system"]) < 6000
    first, second = body["messages"]
    assert first.startswith("Target language: Indonesian\n\n{")
    assert "Glossary from part 1:" in second
    assert all(len(message) < 40000 for message in body["messages"])
    halves = {}
    for message in body["messages"]:
        halves.update(json.loads(message[message.index("{"):]))
    assert halves["back"] == "Back"
    assert client.get("/api/strings/prompts", headers=auth(READER)).status_code == 400
