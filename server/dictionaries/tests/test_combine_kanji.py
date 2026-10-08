import json
import zipfile

from conftest import make_zip
from tools.combine_kanji import REVISION_SUFFIX, combine

VIETNAMESE = {
    "index.json": {
        "title": "Từ điển Hán Nôm", "format": 3, "revision": "hannom.1",
        "description": "Từ điển Hán tự tiếng Việt cho Yomitan", "attribution": "hvdic",
        "isUpdatable": True, "indexUrl": "https://example.com/i.json", "downloadUrl": "https://example.com/d.zip",
    },
    "tag_bank_1.json": [["Strokes", "misc", 0, "Tổng nét", 0]],
    "kanji_bank_1.json": [
        ["猫", "miêu", "", "", ["[miêu] con mèo"], {"Strokes": "11", "Radical": "khuyển 犬 (+8 nét)", "Shape": "⿰⺨苗"}],
        ["当", "đang đáng đương", "", "", ["[đang] nên", "[đang] hầu", "[đáng] đúng", "[đương] nên", "[đương] hầu"], {}],
    ],
    "kanji_bank_2.json": [
        ["𠮟", "sất", "", "", [], {"Strokes": "5"}],
    ],
}
ENGLISH = {
    "index.json": {"title": "KANJIDIC", "format": 3, "revision": "kanjidic2", "attribution": "EDRDG"},
    "tag_bank_1.json": [
        ["jouyou", "frequent", -5, "included in list of regular-use characters", 0],
        ["strokes", "misc", 0, "Stroke count", 0],
    ],
    "kanji_bank_1.json": [
        ["猫", "ビョウ", "ねこ", "jouyou", ["cat"], {"strokes": "11"}],
        ["当", "トウ", "あ.たる まさ.に", "jouyou", ["hit"], {}],
        ["𠮟", "シツ シチ", "しか.る", "jouyou", ["scold", "reprove"], {}],
    ],
}


def texts(node) -> list:
    """Each element's kind and its text, in order."""
    found = []
    if isinstance(node, list):
        for item in node:
            found += texts(item)
    elif isinstance(node, dict):
        inner = node.get("content")
        if isinstance(inner, str):
            found.append((node.get("data", {}).get("jdj", node.get("tag")), inner))
        else:
            found += texts(inner)
    elif isinstance(node, str):
        found.append(("text", node))
    return found


def test_characters_get_japanese_readings_laid_out_with_their_vietnamese(tmp_path):
    (tmp_path / "vi.zip").write_bytes(make_zip(VIETNAMESE))
    (tmp_path / "en.zip").write_bytes(make_zip(ENGLISH))
    assert combine(tmp_path / "vi.zip", tmp_path / "en.zip", tmp_path / "out.zip") == 3

    with zipfile.ZipFile(tmp_path / "out.zip") as archive:
        index = json.loads(archive.read("index.json"))
        tags = json.loads(archive.read("tag_bank_1.json"))
        rows = {row[0]: row for row in json.loads(archive.read("term_bank_1.json"))}
        assert "[data-sc-jdj=\"pill\"]" in archive.read("styles.css").decode()

    cat = rows["猫"]
    assert cat[:5] == ["猫", "", "", "", 0] and cat[7] == "jouyou"
    assert texts(cat[5][0]["content"]) == [
        ("pill", "Hán Việt"), ("han-viet", "miêu"),
        ("pill", "On"), ("text", "ビョウ"),
        ("pill", "Kun"), ("text", "ねこ"),
        ("div", "con mèo"),
        ("facts", "11 nét · bộ khuyển 犬 (+8 nét) · ⺨ + 苗"),
    ]

    # Meanings under each Sino-Vietnamese reading; readings that mean the
    # same share them. Okurigana are set apart.
    laid_out = texts(rows["当"][5][0]["content"])
    assert ("text", "あ") in laid_out and ("okurigana", "たる") in laid_out
    assert laid_out[laid_out.index(("group", "đang, đương")) + 1:][:3] == [
        ("li", "nên"), ("li", "hầu"), ("group", "đáng"),
    ]
    assert ("div", "đúng") in laid_out

    # No Vietnamese meaning: the English ones, marked.
    scold = texts(rows["𠮟"][5][0]["content"])
    assert scold[-4:] == [("label", "Nghĩa tiếng Anh"), ("li", "scold"), ("li", "reprove"), ("facts", "5 nét")]

    assert index["revision"] == "hannom.1" + REVISION_SUFFIX
    assert (index["sourceLanguage"], index["targetLanguage"]) == ("ja", "vi")
    assert not {"isUpdatable", "indexUrl", "downloadUrl"} & set(index)
    assert index["attribution"] == "hvdic. EDRDG."
    assert "KANJIDIC2" in index["description"]
    assert tags == [["jouyou", "frequent", -5, "Chữ Hán thường dùng (Jōyō kanji)", 0]]
