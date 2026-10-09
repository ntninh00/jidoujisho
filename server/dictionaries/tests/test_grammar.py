import json

from dictserver import grammar, tidy

DOJG = (
    "文法項目 | だけ  | 基本 \n [解説] \n  A particle which expresses a limit. \n\n [意味]\n Only; just \n\n"
    " [例文A] \n (ksa).　スミスさんだけ来た。\n Only Mr. Smith came.\n \n \n[例文B]\n"
    " (a).　一度だけ行った。\n I went only once.\n \n\n [接続] \n \n(i) Noun | だけ | | \n"
    " | 先生だけ | The teacher alone | \n(ii) 一切 | Vnegativeない | | \n"
)
BUNKEI_MAIN = [
    "ことだし\nから／ので\nsince\n\n ❶ 雨も降っていることだし、終わりにしましょう。\n ❷\nまだ若いことだし、また挑戦してください。\n\n"
    "接続\n〔普通形〕＋ことだし\n\n軽い理由を表す言い方。\n\n"
    "Indicates insignificant reasons. Similar to し.ことだし \n \n \n google.com/search?q=ことだし 文法解説 \n"
    " itazuraneko.neocities.org/grammar/donnatoki/mainentries.html#ことだし\n\n"
]
BUNKEI_POINTER = [
    "だけある\n ➡ ", {"tag": "a", "href": "?query=だけあって", "content": "だけあって"},
    " \n \n \n google.com/search?q=だけある 文法解説 \n itazuraneko.neocities.org/grammar/donnatoki/mainentries.html#だけある\n\n",
]
EDEWAKARU = [
    {"tag": "span", "content": [{"tag": "a", "content": "詳細", "href": "https://www.edewakaru.com/1.html"}], "data": {"name": "header"}},
    {"tag": "div", "content": {"tag": "img", "path": "img2/a.jpeg", "height": 20, "sizeUnits": "em"},
     "data": {"jp-edewakaru": "image"}},
    "〜に関して｜日本語能力試験　JLPT　N３\n\n\n【接続】\n名詞＋に関して\n\n\n【意味】\n〜について\n\n\n【例文】\n①この文法",
    {"tag": "span", "style": {"fontWeight": "bold"}, "content": "に関して"},
    "、質問はありますか？\n→この文法について、質問はありますか？\n\n\n【説明】\n「Aに関して」は「Aについて」という意味です。\n\n\n"
    "語学(日本語)ランキング\n\nにほんブログ村\n \r\n    \n",
    "\n\n", {"tag": "a", "href": "https://www.edewakaru.com/1.html", "content": "edewakaru link"}, "\n――以上――",
]


def text_of(node) -> str:
    if isinstance(node, str):
        return node
    if isinstance(node, list):
        return "".join(text_of(item) for item in node)
    if isinstance(node, dict):
        return text_of(node.get("content", ""))
    return ""


def kinds(node) -> list[str]:
    found = []
    if isinstance(node, list):
        for item in node:
            found += kinds(item)
    elif isinstance(node, dict):
        if "data" in node and "jdj" in node["data"]:
            found.append(node["data"]["jdj"])
        found += kinds(node.get("content"))
    return found


def test_dojg():
    point = grammar.parse_dojg(DOJG, "だけ", "だけ")
    assert (point.level, point.title, point.meanings) == ("Basic", "だけ", ["Only; just"])
    labels = [part.label for part in point.parts]
    assert labels == ["", "Formation", "Key sentences", "Examples"]
    forms = point.parts[1].items
    assert forms[0].text == "(i) Noun だけ"
    assert (forms[1].text, forms[1].gloss, forms[1].example) == ("先生だけ", "The teacher alone", True)
    # A word run into the Japanese after it gets its space back.
    assert forms[2].text == "(ii) 一切 Vnegative ない"
    key = point.parts[2].items[0]
    assert text_of(key.text) == "スミスさんだけ来た。" and key.translation == "Only Mr. Smith came."
    # The pattern stands out in its examples.
    assert {"tag": "span", "data": {"jdj": "g-em"}, "content": "だけ"} in key.text


def test_bunkei():
    point = grammar.parse_bunkei(BUNKEI_MAIN, "事だし", "ことだし")
    assert (point.title, point.meanings, point.also) == ("ことだし", ["から／ので"], ["since"])
    examples, forms, notes, english = point.parts
    # A sentence that starts on the line after its number is still its own.
    assert [text_of(example.text) for example in examples.items] == [
        "雨も降っていることだし、終わりにしましょう。", "まだ若いことだし、また挑戦してください。",
    ]
    assert forms.items[0].text == "〔普通形〕＋ことだし"
    assert notes.items == ["軽い理由を表す言い方。"]
    # The headword run onto the English is gone, and so are the links out.
    assert english.second and english.items == ["Indicates insignificant reasons. Similar to し."]
    assert "google" not in json.dumps(grammar.to_structured(point), ensure_ascii=False)
    pointer = grammar.parse_bunkei(BUNKEI_POINTER, "だけある", "だけある")
    assert (pointer.title, pointer.see) == ("だけある", ["だけあって"])


def test_edewakaru():
    point = grammar.parse_edewakaru(EDEWAKARU, "に関して", "にかんして", "絵でわかる中級文法")
    assert (point.title, point.level, point.meanings) == ("〜に関して", "N3", ["〜について"])
    assert point.image["path"] == "img2/a.jpeg"
    forms, examples, explanation = point.parts
    assert forms.items[0].text == "名詞＋に関して"
    example = examples.items[0]
    assert text_of(example.text) == "この文法に関して、質問はありますか？"
    assert example.notes == ["→この文法について、質問はありますか？"]
    flat = json.dumps(grammar.to_structured(point), ensure_ascii=False)
    for leftover in ("ランキング", "ブログ村", "以上", "edewakaru link", "詳細"):
        assert leftover not in flat
    # An entry that is only a picture keeps it.
    picture = grammar.parse_edewakaru(EDEWAKARU[:2], "開く", "ひらく")
    assert kinds(grammar.to_structured(picture)["content"]) == ["g-image"]


def test_grammar_dictionaries_are_told_apart_and_rewritten():
    def row(term, definition, tags=""):
        return [term, term, "spelled", "", 0, [definition], 1, tags]

    assert tidy.detect([row("だけ", DOJG)] * 10) == "dojg"
    bunkei = {"type": "structured-content", "content": BUNKEI_MAIN}
    assert tidy.detect([row("事だし", bunkei)] * 10) == "bunkei"
    edewakaru = {"type": "structured-content", "content": EDEWAKARU}
    assert tidy.detect([row("に関して", edewakaru)] * 10) == "edewakaru"
    rewritten = tidy.rewrite_row(row("だけ", DOJG, "DOJG基本"), "dojg")
    # The tags, which held other spellings and the book, are shown in the
    # point instead of as chips.
    assert (rewritten[2], rewritten[7]) == ("", "")
    assert rewritten[5][0]["type"] == "structured-content"
    assert "g-level" in kinds(rewritten[5][0]["content"])
    # The spelling from the tags is the point's title.
    assert text_of(rewritten[5][0]["content"]).startswith("Basicspelled")
