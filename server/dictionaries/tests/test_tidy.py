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


def test_prodict_fields_and_explanations_run_on_too():
    wiring = tidy.parse_prodict([
        "`1`house wiring\n`4`Lĩnh vực: xây dựng\xa0điện nhàsymbols, house wiring: các ký hiệu điện "
        "nhàLĩnh vực: điện\xa0hệ thống điện nhàGiải thích VN: Hệ thống điện mắc trong nhà.\xa0"
        "mạng điện gia dụng"
    ], "house wiring", {"symbols", "house", "wiring"})
    assert [section.label for section in wiring.sections] == ["xây dựng", "điện"]
    building, electrical = wiring.sections
    assert building.senses[0].gloss == "điện nhà"
    assert [(e.text, e.translation) for e in building.senses[0].examples] == [
        ("symbols, house wiring", "các ký hiệu điện nhà")
    ]
    assert [sense.gloss for sense in electrical.senses] == ["hệ thống điện nhà", "mạng điện gia dụng"]
    assert electrical.senses[0].notes == ["Hệ thống điện mắc trong nhà."]

    keeping = tidy.parse_prodict([
        "`1`housekeeping\n`4`Lĩnh vực: toán & tin\xa0housekeepingGiải thích VN: Để chỉ các tiện ích."
        "\xa0nội dịchhousekeeping instruction: lệnh nội dịchhousekeeping data\xa0thông tin giữ nhà"
        "housekeeping maintenance\xa0sự bảo dưỡng thường xuyên"
    ], "housekeeping", {"housekeeping", "instruction", "data", "maintenance"})
    first, second = keeping.sections[0].senses
    assert (first.gloss, first.notes) == ("housekeeping", ["Để chỉ các tiện ích."])
    assert second.gloss == "nội dịch"
    # Phrases whose translation comes after a no-break space.
    assert [(e.text, e.translation) for e in second.examples] == [
        ("housekeeping instruction", "lệnh nội dịch"),
        ("housekeeping data", "thông tin giữ nhà"),
        ("housekeeping maintenance", "sự bảo dưỡng thường xuyên"),
    ]
    laid_out = texts(tidy.to_structured(keeping))
    assert ("note", "Để chỉ các tiện ích.") in laid_out


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


WTY_SUM = (
    "<b>sum (present infinitive esse); irregular</b><ol><li>(copulative) to be, exist<br>"
    "<i>Cīvis rōmānus sum.</i> — I am a Roman citizen.<ul><li>to belong<br>"
    "<i>Mihī est multum tempus.</i> — I have a lot of time.</li></ul></li>"
    "<li>there be</li><li>it&#x27;s &amp; <a href=\"x\">this</a><img src=\"y\"><font>that</font></li></ol>"
)


def test_html_written_as_text_becomes_structured_content():
    laid = tidy.parse_html(WTY_SUM)
    assert laid["type"] == "structured-content"
    headline, senses = laid["content"]
    assert headline == {
        "tag": "div",
        "content": {"tag": "span", "style": {"fontWeight": "bold"}, "content": "sum (present infinitive esse); irregular"},
    }
    assert senses["tag"] == "ol"
    first, second, third = senses["content"]
    # The meaning on its own line, its example and translation beneath it.
    assert texts(first)[:3] == [
        (None, "(copulative) to be, exist"), ("example", "Cīvis rōmānus sum."), ("translation", "I am a Roman citizen."),
    ]
    assert first["content"][1]["data"] == {"jdj": "html-example"}
    assert texts(first)[3:] == [
        (None, "to belong"), ("example", "Mihī est multum tempus."), ("translation", "I have a lot of time."),
    ]
    assert second == {"tag": "li", "content": "there be"}
    # Entities read, a link to nowhere kept as text, pictures and unknown
    # tags left out around their text.
    assert texts(third) == [(None, "it's & "), (None, "this"), (None, "that")]
    assert tidy.parse_html("plain text, a < b") is None


def test_html_dictionaries_are_laid_out_in_any_language():
    def row(text):
        return ["sum", "", "", "", 0, [text], 0, ""]

    assert tidy.detect([row(WTY_SUM)] * 20) == "html"
    assert tidy.detect([row(WTY_SUM)] * 5 + [row("to be")] * 15) is None
    laid = tidy.rewrite_row(["sum", "", "", "", 0, [WTY_SUM, "plain"], 0, ""], "html")
    assert laid[5][0]["type"] == "structured-content"
    assert laid[5][1] == "plain"


JAVIDIC_YOUSU = (
    "「ようす」\nbộ dáng\n〘n〙\nthái độ\n態度\ntrạng thái\n"
    "* Cụm từ hay dùng: 〜を見る: lặng lẽ trông\nvẻ bề ngoài; dáng vẻ\n"
    "近ごろ彼の〜がおかしい:\ngần đây anh ta trông thật lạ lùng.\n外見 ."
)


def test_javidic_lays_out_word_classes_examples_and_words_to_look_up():
    body = tidy.parse_javidic([JAVIDIC_YOUSU])
    plain, noun = body.sections
    assert [sense.gloss for sense in plain.senses] == ["bộ dáng"]
    assert noun.label == "danh từ"
    attitude, state, looks = noun.senses
    assert (attitude.gloss, attitude.refs) == ("thái độ", ["態度"])
    assert state.notes == ["Cụm từ hay dùng: 〜を見る: lặng lẽ trông"]
    assert looks.examples[0].text == "近ごろ彼の〜がおかしい"
    assert looks.examples[0].translation == "gần đây anh ta trông thật lạ lùng."
    # The stray full stop at the end is gone.
    assert looks.refs == ["外見"]
    laid_out = tidy.to_structured(body)
    assert ("label", "danh từ") in texts(laid_out)
    assert '"href": "?query=%E6%85%8B%E5%BA%A6&wildcards=off"' in json.dumps(laid_out)


def test_mazii_keeps_its_sino_vietnamese_reading():
    body = tidy.parse_mazii(["DẠNG TỬ\n1. bộ dáng\n2. thái độ\n3. 態度\n4. vẻ bề ngoài .\n"])
    assert body.han_viet == "DẠNG TỬ"
    senses = body.sections[0].senses
    assert [(sense.gloss, sense.refs) for sense in senses] == [
        ("bộ dáng", []), ("thái độ", ["態度"]), ("vẻ bề ngoài", []),
    ]
    assert texts(tidy.to_structured(body))[0] == ("han-viet", "DẠNG TỬ")


def test_japanese_dictionaries_get_their_own_layouts():
    def row(term, text):
        return [term, "", "", "", 0, [text], 0, ""]

    assert tidy.detect([row("様子", JAVIDIC_YOUSU)] * 20) == "javidic"
    assert tidy.detect([row("様子", "DẠNG TỬ\n1. bộ dáng\n2. dáng")] * 20) == "mazii"
    jdict = "- dí dỏm\n* adj\n- thú vị; hay\n- 面白み"
    assert tidy.detect([row("面白い", jdict)] * 20) == "jmarkup"
    assert tidy.detect([row("house", OVDP_HOUSE)] * 20) == "markup"
    body = tidy.japanese_touches(tidy.parse_markup([jdict]))
    assert body.sections[1].label == "tính từ"
    assert [(sense.gloss, sense.refs) for sense in body.sections[1].senses] == [("thú vị; hay", ["面白み"])]
    assert tidy.word_classes("v5r, vt") == "động từ nhóm 1, tha động từ"
    assert tidy.word_classes("danh từ") is None


def test_each_layout_has_its_own_rules_number():
    assert tidy.stamp("markup") == "markup@3" and tidy.is_current("markup@3")
    assert tidy.stamp("html") == "html@1"
    # Looked at before newer layouts were understood: looked at again.
    assert not tidy.is_current("none@4") and tidy.is_current(tidy.stamp(None))
    assert not tidy.is_current("") and not tidy.is_current(None) and not tidy.is_current("odd@3")
    assert tidy.revision_suffix("html") == "+jdj1" and tidy.REVISION_SUFFIX == "+jdj3"


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
    assert entry["tidy"] == tidy.stamp("markup")
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
        assert plain["tidy"] == tidy.stamp(None)
        app = client.app
        entry = added(client, ovdp_zip("7"))
        assert entry["tidy"] == tidy.stamp("markup")
        # As a catalog from before laying out existed would have it.
        catalog = app.state.catalog
        folder = settings.dictionaries_dir / entry["id"]
        (folder / "original.zip").replace(folder / "dictionary.zip")
        catalog.set_tidy(entry["id"], None, "7")
        # And one laid out by older rules.
        older = added(client, make_zip({
            "index.json": {"title": "Older", "revision": "3", "format": 3},
            "term_bank_1.json": [["house", "", "", "", 0, [OVDP_HOUSE], 0, ""]] * 30,
        }))
        catalog.set_tidy(older["id"], "markup@1", "3+jdj1")

    with TestClient(create_app(settings)) as client:
        import time

        # Looked at in the background, then indexed again.
        for _ in range(200):
            again = client.get(f"/api/dictionaries/{entry['id']}", headers=auth(ADMIN)).json()
            relaid = client.get(f"/api/dictionaries/{older['id']}", headers=auth(ADMIN)).json()
            if again["tidy"] == tidy.stamp("markup") and again["status"] == "ready" and tidy.is_current(relaid["tidy"]) and relaid["status"] == "ready":
                break
            time.sleep(0.05)
        assert again["status"] == "ready"
        assert again["tidy"] == tidy.stamp("markup")
        assert again["revision"] == "7" + tidy.REVISION_SUFFIX
        # Laid out again from the original, not from the older layout.
        assert relaid["revision"] == "3" + tidy.REVISION_SUFFIX
        assert relaid["status"] == "ready"
        assert client.get(f"/api/dictionaries/{plain['id']}", headers=auth(ADMIN)).json()["tidy"] == tidy.stamp(None)
