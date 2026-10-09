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
    assert (sense.gloss, sense.notes) == ("vẫn có thể xem là", ["还可以算得上。"])
    assert sense.examples[0].translation == "xử lý như vầy, vẫn có thể xem là một biện pháp hay"


MTBAB_HAO = (
    "Từ phồn thể: (好)\n[hǎo]\nBộ: 女 - Nữ\nSố nét: 6\nHán Việt: HẢO\n"
    "1. tốt; lành; hay。优点多的;使人满意的(跟'坏'相对)。\n好人\nngười tốt\n"
    "庄稼长得很好。\nhoa màu mọc rất tốt.\n2. đẹp; ngon; tốt。用在动词前。\n好看\nđẹp; coi được.\n"
    "Ghi chú: 另见hào\nTừ ghép:\n好比 ; 好不 ; 好处[hào]\nBộ: 女(Nữ)\nHán Việt: HIẾU\n"
    "1. thích; yêu thích。喜爱(跟'恶'相对)。\n好学\nham học"
)


def test_babylon_chinese_entries_with_characters_readings_and_compounds():
    body = tidy.parse_babylon([MTBAB_HAO])
    assert body.han_viet == "HẢO"
    assert body.facts == "6 nét · bộ nữ 女 · phồn thể 好"
    first, compounds, second = body.sections
    good, pretty = first.senses
    assert (good.gloss, good.notes) == ("tốt; lành; hay", ["优点多的;使人满意的(跟'坏'相对)。"])
    assert [(e.text, e.translation) for e in good.examples] == [
        ("好人", "người tốt"), ("庄稼长得很好。", "hoa màu mọc rất tốt."),
    ]
    assert pretty.notes == ["用在动词前。", "xem thêm hào"]
    assert compounds.label == "Từ ghép" and compounds.senses[0].refs == ["好比", "好不", "好处"]
    # The second reading has a part of its own.
    assert second.label == "hào · HIẾU"
    assert second.senses[0].gloss == "thích; yêu thích"
    assert second.senses[0].examples[0].translation == "ham học"
    laid_out = tidy.to_structured(body)
    assert texts(laid_out)[:2] == [("han-viet", "HẢO"), ("facts", "6 nét · bộ nữ 女 · phồn thể 好")]
    # Compounds are links, without an arrow.
    assert '"href": "?query=%E5%A5%BD%E6%AF%94&wildcards=off"' in json.dumps(laid_out)
    assert ("refs", "→ ") not in texts(laid_out)


def test_babylon_word_classes_on_their_own_line():
    # The explanation is longer than the meaning before it.
    body = tidy.parse_babylon(["[xuéxí]\n动\nhọc tập; học。从阅读、听讲、研究、实践中获得知识或技能。\n学习文化\nhọc văn hoá"])
    assert body.sections[0].label == "động từ"
    sense = body.sections[0].senses[0]
    assert (sense.gloss, sense.examples[0].text) == ("học tập; học", "学习文化")
    assert tidy._meaning("đi bước một; từng bước một. 一个脚步接一个脚步") == (
        "đi bước một; từng bước một", "一个脚步接一个脚步",
    )


def test_babylon_vietnamese_english_joins_lines_and_pairs_examples():
    body = tidy.parse_babylon_ve([
        "[nhà] house; home \n Săn sóc tại nhà \n Domiciliary care \n Đừng bao giờ đặt chân đến nhà này nữa! \n"
        " Never set foot in this house again! family \n Bảo tàng \n Hồ Chí Minh ở đây \n The Ho Chi Minh \n"
        " Museum is here"
    ])
    house, family = body.sections[0].senses
    assert house.gloss == "house; home"
    assert [(e.text, e.translation) for e in house.examples] == [
        ("Săn sóc tại nhà", "Domiciliary care"),
        ("Đừng bao giờ đặt chân đến nhà này nữa!", "Never set foot in this house again!"),
    ]
    # Lines broken before capitals are one sentence again.
    assert family.gloss == "family"
    assert [(e.text, e.translation) for e in family.examples] == [
        ("Bảo tàng Hồ Chí Minh ở đây", "The Ho Chi Minh Museum is here"),
    ]


def test_babylon_vietnamese_english_word_classes_labels_and_references():
    run_on = tidy.parse_babylon_ve(["[tinh] danh từ flag, banner (tinh tre)tính từ fine, pure shrewdđộng từ. sign"])
    assert [(s.label, s.senses[0].gloss) for s in run_on.sections] == [
        ("danh từ", "flag, banner (tinh tre)"), ("tính từ", "fine, pure shrewd"), ("động từ", "sign"),
    ]
    spoken = tidy.parse_babylon_ve(["[càn quấy]khẩu ngữ \n Unruly, wayward (nói khái quát)"]).sections[0].senses[0]
    assert (spoken.label, spoken.gloss) == ("khẩu ngữ", "Unruly, wayward (nói khái quát)")
    field = tidy.parse_babylon_ve(["[nồm] (thực vật) a plant"]).sections[0].senses[0]
    assert (field.label, field.gloss) == ("thực vật", "a plant")
    see = tidy.parse_babylon_ve(["[bảo tàng] xem viện bảo tàng"], {"viện bảo tàng"}).sections[0].senses[0]
    assert (see.gloss, see.refs) == ("", ["viện bảo tàng"])
    # A line that mixes both languages stays with the meaning.
    mixed = tidy.parse_babylon_ve(["[cú vọ]danh từ \n Barn-owl; \n Asian owlet mắt cú vọ peevish eyes"])
    sense = mixed.sections[0].senses[0]
    assert (sense.gloss, sense.examples) == ("Barn-owl; Asian owlet mắt cú vọ peevish eyes", [])
    # Babylon's pages of related words are dropped.
    assert tidy.rewrite_row(["zzvels gàn", "", "", "", 0, ["gàn gàn bát sách"], 0, ""], "babylonve") is None


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
    vietnamese_headword = ["nhà", "", "", "", 0, ["[nhà] house; home \n Săn sóc tại nhà \n Domiciliary care"], 0, ""]
    assert tidy.detect([vietnamese_headword] * 20) == "babylonve"
    # English with bullets, and Vietnamese without markup, stay as they are.
    assert tidy.detect([row("▫ a building for people to live in\n• housing")] * 20) is None
    assert tidy.detect([row("nhà ở, căn nhà")] * 20) is None


def test_a_row_keeps_what_is_not_text():
    image = {"type": "image", "path": "house.png"}
    laid = tidy.rewrite_row(["house", "", "", "", 0, [OVDP_HOUSE, image], 0, ""], "markup")
    assert laid[5][0]["type"] == "structured-content"
    assert laid[5][1] == image


def test_inflected_forms_become_links_to_their_words():
    row = ["confectionnés", "", "non-lemma", "", 0, [
        ["confectionner", ["masculine plural", "plural masculine"]],
        ["confectionner", ["past participle"]],
    ], 0, ""]
    laid = tidy.rewrite_row(row, "markup")
    assert laid[:5] == row[:5] and len(laid[5]) == 1
    assert texts(laid[5][0]) == [
        ("form-of", "→ "), ("form-of", "confectionner"), ("form-of", " "),
        ("form-labels", "giống đực số nhiều; quá khứ phân từ"),
    ]
    assert '"href": "?query=confectionner&wildcards=off"' in json.dumps(laid)
    # In a dictionary not in Vietnamese the labels stay in English, in the
    # usual order.
    english = tidy.rewrite_row(["strapping", "", "", "", 0, [["strap", ["participle present"]]], 0, ""], "forms")
    assert ("form-labels", "present participle") in texts(english[5][0])
    assert tidy.rewrite_row(["кошка", "", "", "", 0, [["кот", ["first/third-person singular"]]], 0, ""], "markup")[5][0]["content"][0]["content"][-1]["content"] == "ngôi thứ nhất/ba số ít"
    # Jitendex's redirects have a link of their own beside the pointer.
    redirect = ["勞働相", "", "old kanji form", "", -101, [
        {"type": "structured-content", "content": ["⟶", {"tag": "a", "href": "?query=労働相", "content": "労働相"}]},
        ["労働相", ["redirected from 勞働相"]],
    ], 0, ""]
    assert tidy.rewrite_row(redirect, "forms") == redirect
    assert tidy.detect([redirect] * 20) is None


def test_dictionaries_with_only_inflected_forms_to_rewrite():
    def row(definition):
        return ["word", "", "", "", 0, [definition], 0, ""]

    rows = [row("plain English")] * 15 + [row(["word", ["plural"]])] * 5
    assert tidy.detect(rows) == "forms"
    assert tidy.detect([row("plain English")] * 20) is None
    # Their text stays as it is.
    assert tidy.rewrite_row(row("a small animal"), "forms") == row("a small animal")


def test_rows_that_say_nothing_or_repeat_go():
    assert tidy.rewrite_row(["дом", "", "n", "n", 0, ["@дом\nдом"], 0, ""], "markup") is None
    seen = set()
    first = ["好", "hǎo", "", "", 0, ["x"], 0, ""]
    assert not tidy._repeated(first, "babylon", seen)
    # Another reading of the same character with the same entry.
    assert tidy._repeated(["好", "hào", "", "", 0, ["x"], 0, ""], "babylon", seen)
    assert not tidy._repeated(["好", "hào", "", "", 0, ["x"], 0, ""], "markup", seen)


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
    assert tidy.stamp("markup") == "markup@4" and tidy.is_current("markup@4")
    assert not tidy.is_current("markup@3")
    assert tidy.stamp("html") == "html@1"
    # Looked at before newer layouts were understood: looked at again.
    assert not tidy.is_current("none@6") and tidy.is_current(tidy.stamp(None))
    assert not tidy.is_current("") and not tidy.is_current(None) and not tidy.is_current("odd@3")
    assert tidy.revision_suffix("html") == "+jdj1" and tidy.REVISION_SUFFIX == "+jdj4"


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
