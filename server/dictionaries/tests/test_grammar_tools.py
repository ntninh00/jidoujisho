import json
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))

import grammar_jlpt_vi_build as build  # noqa: E402
from grammar_vi_check import json_in, problem  # noqa: E402

SOURCE = {
    "id": "N3-025", "t": "Verb くせに", "m": "Even though.", "l": "Used to criticise.", "f": "Verb-casual + くせに",
    "ex": [["彼はお金持ちのくせに、ケチです。", "Even though he's rich, he's stingy."]],
}
ANSWER = {
    "m": "Mặc dù…", "l": "Dùng để phê phán. Trong tiếng Anh có thể dịch là 'even though'. Thường dùng trong văn nói.",
    "f": "V(thể thường) + くせに; N + のくせに", "ex": ["Anh ta giàu mà lại keo kiệt."], "k": ["くせに"],
}


def test_a_short_reply_is_read_whole():
    # Each point has more keys than a reply of three points: the reply's own
    # object is still the one read.
    reply = "Here:\n" + json.dumps({f"N2-{n}": ANSWER for n in range(3)}, ensure_ascii=False)
    assert set(json_in(reply)) == {"N2-0", "N2-1", "N2-2"}
    assert problem(SOURCE, ANSWER) is None
    assert problem(SOURCE, {**ANSWER, "f": "Verb + くせに"}) == "f left in English"
    assert problem(SOURCE, {**ANSWER, "ex": []}) == "0 examples for 1"


def test_corrections_apply():
    from grammar_jlpt_vi_fixes import apply

    source = {"id": "N3-118", "t": "～らしい", "ex": [["a", ""], ["b", ""], ["c", ""], ["彼女は医者だらしい。", ""]]}
    fixed, answer = apply(source, {**ANSWER, "ex": ["1", "2", "3", "4"]})
    assert fixed["ex"][3][0] == "彼女は医者らしい。" and source["ex"][3][0] == "彼女は医者だらしい。"
    whole, answer = apply({**SOURCE, "id": "N1-004"}, ANSWER)
    assert len(whole["ex"]) == len(answer["ex"]) == 3 and "遅かれ早かれ" in answer["k"]


def test_the_dictionary_is_built(tmp_path):
    common = {**SOURCE, "id": "N3-021", "t": "～さ"}
    out = tmp_path / "grammar.zip"
    built, rows = build.build([SOURCE, common], {"N3-025": ANSWER, "N3-021": {**ANSWER, "k": ["さ"]}}, out, "1")
    # A point found only by a kana that begins too many words is left out.
    assert (built, rows) == (1, 1)
    with zipfile.ZipFile(out) as archive:
        row = json.loads(archive.read("term_bank_1.json"))[0]
        index = json.loads(archive.read("index.json"))
    assert row[0] == "くせに" and index["targetLanguage"] == "vi"
    flat = json.dumps(row[5], ensure_ascii=False)
    assert "V くせに" in flat and "tiếng Anh" not in flat and "Thường dùng trong văn nói." in flat
    # The pattern stands out in its example.
    assert json.dumps({"tag": "span", "data": {"jdj": "g-em"}, "content": "くせに"}, ensure_ascii=False) in flat
