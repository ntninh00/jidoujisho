import json
import zipfile

from conftest import ADMIN, READER, auth, make_zip

from dictserver import tidy

OVDP_HOUSE = (
    "@house /haus/\n* danh từ, số nhiều houses\n- nhà ở, căn nhà, toà nhà\n- nhà, chuồng\n"
    "=the house of God+ nhà thờ\n=house of detention+ nhà tù, nhà giam\n"
    "!to keep house\n- quản lý việc nhà\n@Chuyên ngành kinh tế\n- hãng buôn"
)
PRODICT_HOUSE = (
    "`1`house\n`4`\xa0buồng lái\xa0cất vào kho\xa0hãngbusiness house: hãng buônhouse flag: cờ hãng"
    "publishing house: hãng xuất bản\xa0nhà380V (distribution) house: nhà (phân phối) 380V"
    "bamboo house: nhà bằng trebasement house: nhà có tầng hầmbath house: nhà tắm (công cộng)"
    "block of house: khu phố, dãy nhà"
)
PRODICT_WORDS = {
    "house", "business", "flag", "publishing", "distribution", "bamboo", "basement", "bath",
    "block", "of", "kv", "ng",
}


def texts(node) -> list:
    """Every piece of text in structured content, in order, with its kind."""
    found = []

    def walk(item, kind=None):
        if isinstance(item, str):
            found.append((kind, item))
        elif isinstance(item, list):
            for child in item:
                walk(child, kind)
        elif isinstance(item, dict):
            walk(item.get("content"), (item.get("data") or {}).get("jdj", kind))

    walk(node)
    return found


def test_ovdp_becomes_sections_meanings_and_examples():
    body = tidy.parse_markup([OVDP_HOUSE])
    assert body.pronunciation == "haus"
    assert [(s.label, s.kind) for s in body.sections] == [
        ("danh từ, số nhiều houses", "pos"),
        ("to keep house", "idiom"),
        ("Chuyên ngành kinh tế", "domain"),
    ]
    noun = body.sections[0]
    assert [sense.gloss for sense in noun.senses] == ["nhà ở, căn nhà, toà nhà", "nhà, chuồng"]
    assert [(e.text, e.translation) for e in noun.senses[1].examples] == [
        ("the house of God", "nhà thờ"),
        ("house of detention", "nhà tù, nhà giam"),
    ]

    laid_out = texts(tidy.to_structured(body))
    assert ("ipa", "/haus/") in laid_out
    assert ("example", "the house of God") in laid_out
    assert ("translation", "nhà thờ") in laid_out
    assert ("idiom", "to keep house") in laid_out


def test_other_exports_of_the_same_grammar():
    # FVDP: two spaces between an example and its translation.
    fvdp = tidy.parse_markup(["- [thuộc về] quý tộc, quý phái\n= ~ое ́общество  xã hội quý tộc"])
    assert fvdp.sections[0].senses[0].examples[0].translation == "xã hội quý tộc"
    # Pháp-Việt: ═ for =.
    french = tidy.parse_markup([
        "* danh từ giống cái\n- tính chát\n═  L'acerbité des fruits sauvages+ tính chát của quả dại"
    ])
    assert french.sections[0].kind == "pos"
    assert french.sections[0].senses[0].examples[0].text == "L'acerbité des fruits sauvages"
    # Donsa: • is a meaning, and Ex: an example with its translation in braces.
    donsa = tidy.parse_markup([
        "• {apparent} rõ ràng, hiển nhiên\n• {seeming} làm ra vẻ\n"
        "  Ex: anscheinend ist er beleidigt {he seems to be offended}"
    ])
    senses = donsa.sections[0].senses
    assert [s.gloss for s in senses] == ["{apparent} rõ ràng, hiển nhiên", "{seeming} làm ra vẻ"]
    assert senses[1].examples[0].translation == "he seems to be offended"
    # Nga Việt 2005: an indented example, its translation on the next line.
    russian = tidy.parse_markup(["ở, tại, trong\n\n  в Москве’\nở (tại) Mát-xcơ-va"])
    sense = russian.sections[0].senses[0]
    assert sense.gloss == "ở, tại, trong"
    assert (sense.examples[0].text, sense.examples[0].translation) == ("в Москве’", "ở (tại) Mát-xcơ-va")
    # A subject in parentheses before any meaning heads the entry.
    german = tidy.parse_markup(["(Typographie)\n- {to impose} đánh, lên khuôn"])
    assert (german.sections[0].label, german.sections[0].kind) == ("Typographie", "domain")


def test_accents_written_apart_are_joined():
    row = ["в", "", "", "", 0, ["ở\n\n  во Вьетна’ме\nở (tại) Vie\u0302\u0323t-nam"], 0, ""]
    laid = tidy.rewrite_row(row, "markup")
    assert ("translation", "ở (tại) Việt-nam") in texts(laid[5][0])


def test_babylon_chinese_pairs_examples_with_translations():
    body = tidy.parse_babylon([
        "[bùshīwéi]\nvẫn có thể xem là。还可以算得上。\n这样处理，还不失为一个好办法。\n"
        "xử lý như vầy, vẫn có thể xem là một biện pháp hay"
    ])
    sense = body.sections[0].senses[0]
    assert sense.gloss == "vẫn có thể xem là。还可以算得上。"
    assert sense.examples[0].translation == "xử lý như vầy, vẫn có thể xem là một biện pháp hay"


def test_prodict_phrases_are_pulled_apart():
    body = tidy.parse_prodict([PRODICT_HOUSE], "house", PRODICT_WORDS)
    senses = body.sections[0].senses
    assert [s.gloss for s in senses] == ["buồng lái", "cất vào kho", "hãng", "nhà"]
    assert [(e.text, e.translation) for e in senses[2].examples] == [
        ("business house", "hãng buôn"),
        ("house flag", "cờ hãng"),
        ("publishing house", "hãng xuất bản"),
    ]
    assert [(e.text, e.translation) for e in senses[3].examples] == [
        ("380V (distribution) house", "nhà (phân phối) 380V"),
        ("bamboo house", "nhà bằng tre"),
        ("basement house", "nhà có tầng hầm"),
        ("bath house", "nhà tắm (công cộng)"),
        ("block of house", "khu phố, dãy nhà"),
    ]
    # A field opens a section.
    field = tidy.parse_prodict(["`1`AFIP\n`4`Lĩnh vực: điện tử & viễn thông\xa0giao thức nặc danh"], "AFIP")
    assert field.sections[0].label == "điện tử & viễn thông"
    assert field.sections[0].senses[0].gloss == "giao thức nặc danh"


def test_only_vietnamese_dictionaries_with_markup_are_laid_out():
    def row(text):
        return ["house", "", "", "", 0, [text], 0, ""]

    assert tidy.detect([row(OVDP_HOUSE)] * 20) == "markup"
    assert tidy.detect([row(PRODICT_HOUSE)] * 20) == "prodict"
    assert tidy.detect([row("[bùshīwéi]\nvẫn có thể xem là")] * 20) == "babylon"
    # English with bullets, and Vietnamese without markup, stay as they are.
    assert tidy.detect([row("▫ a building for people to live in\n• housing")] * 20) is None
    assert tidy.detect([row("nhà ở, căn nhà")] * 20) is None


def test_a_row_keeps_what_is_not_text():
    pointer = ["butterfly", ["plural"]]
    row = ["butterflies", "", "", "", 0, [pointer], 0, ""]
    assert tidy.rewrite_row(row, "markup") == row
    laid = tidy.rewrite_row(["house", "", "", "", 0, [OVDP_HOUSE, pointer], 0, ""], "markup")
    assert laid[5][0]["type"] == "structured-content"
    assert laid[5][1] == pointer


def ovdp_zip(revision="1") -> bytes:
    return make_zip({
        "index.json": {"title": "Test Anh-Việt", "revision": revision, "format": 3},
        "term_bank_1.json": [["house", "", "", "", 0, [OVDP_HOUSE], 0, ""]] * 30,
    })


def test_uploads_with_markup_are_laid_out_and_kept(client, settings):
    from test_api import ready, upload

    response = upload(client, ovdp_zip())
    entry = ready(client, response.json()["id"])
    assert entry["status"] == "ready", entry["error"]
    assert entry["tidy"] == "markup"
    assert entry["revision"] == "1" + tidy.REVISION_SUFFIX
    folder = settings.dictionaries_dir / entry["id"]
    assert (folder / "original.zip").exists()
    with zipfile.ZipFile(folder / "dictionary.zip") as archive:
        assert "jdj" in archive.read("styles.css").decode()
        row = json.loads(archive.read("term_bank_1.json"))[0]
    assert row[5][0]["type"] == "structured-content"
    styles = client.get(f"/api/dictionaries/{entry['id']}/styles", headers=auth(READER))
    assert styles.status_code == 200
    result = client.get(f"/api/dictionaries/{entry['id']}/search", params={"q": "house"}, headers=auth(READER)).json()
    assert result["terms"][0][5][0]["type"] == "structured-content"
    # The same file again is still recognised as already there.
    assert upload(client, ovdp_zip()).status_code == 409


def test_dictionaries_from_before_are_laid_out_once(settings):
    from starlette.testclient import TestClient

    from dictserver.app import create_app

    with TestClient(create_app(settings)) as client:
        from test_api import added

        plain = added(client, make_zip({
            "index.json": {"title": "Plain", "revision": "1", "format": 3},
            "term_bank_1.json": [["cat", "", "", "", 0, ["a small animal"], 0, ""]],
        }))
        assert plain["tidy"] == ""
        app = client.app
        entry = added(client, ovdp_zip("7"))
        assert entry["tidy"] == "markup"
        # As a catalog from before laying out existed would have it.
        catalog = app.state.catalog
        folder = settings.dictionaries_dir / entry["id"]
        (folder / "original.zip").replace(folder / "dictionary.zip")
        catalog.set_tidy(entry["id"], None, "7")

    with TestClient(create_app(settings)) as client:
        import time

        # Looked at in the background, then indexed again.
        for _ in range(100):
            again = client.get(f"/api/dictionaries/{entry['id']}", headers=auth(ADMIN)).json()
            if again["tidy"] == "markup" and again["status"] == "ready":
                break
            time.sleep(0.05)
        assert again["status"] == "ready"
        assert again["tidy"] == "markup"
        assert again["revision"] == "7" + tidy.REVISION_SUFFIX
        assert client.get(f"/api/dictionaries/{plain['id']}", headers=auth(ADMIN)).json()["tidy"] == ""
