import pytest

from conftest import make_zip
from dictserver.checks import Limits, Rejected, check_zip
from dictserver.text import guess_term_language, guess_text_language, search_key


def test_search_keys_fold_width_case_and_kana():
    assert search_key("ネコ") == "ねこ"
    assert search_key("ＡＢＣ ") == "abc"
    assert search_key("House") == "house"


@pytest.mark.parametrize("samples, language", [
    (["猫ねこ", "犬いぬ", "食べるたべる"], "ja"),
    (["house", "run", "beautiful"], "en"),
    (["nhà", "đọc", "ăn", "người", "ba", "con"], "vi"),
    (["고양이", "개"], "ko"),
])
def test_headword_languages(samples, language):
    assert guess_term_language(samples) == language


@pytest.mark.parametrize("samples, language", [
    # English definitions quoting Japanese examples are still English.
    (["a cat; puss(y); a tomcat", "猫を飼う to keep a cat", "sensitive to hot food"], "en"),
    (["ネコ科の小形の哺乳類。愛玩用に飼われる。"], "ja"),
    (["nhà ở, căn nhà, toà nhà - nhà, chuồng", "danh từ, số nhiều houses"], "vi"),
    # English definitions quoting Vietnamese examples are still English.
    (["house; home; domicile; dwelling-house", "Săn sóc tại nhà", "Domiciliary care; home treatment", "To read a letter from home"], "en"),
    # Other accented Latin text is left for an admin to name.
    (["la maison où l'on habite pendant l'été; être à côté"], None),
])
def test_definition_languages(samples, language):
    assert guess_text_language(samples) == language


# A Wiktionary German-Vietnamese dictionary: most entries are inflected forms
# explained in English, the rest in Vietnamese.
GERMAN_VIETNAMESE = ["abmagern future future-i infinitive"] * 18 + ["gầy đi, sụt cân"] * 2


@pytest.mark.parametrize("samples, source, language", [
    (GERMAN_VIETNAMESE, "de", "vi"),
    # Without knowing the words aren't Vietnamese, it reads as English.
    (GERMAN_VIETNAMESE, None, "en"),
    # A Vietnamese-English dictionary quoting Vietnamese stays English.
    (["house; home; domicile", "Săn sóc tại nhà", "Domiciliary care", "To read a letter"], "vi", "en"),
    # Japanese-English with no Vietnamese at all.
    (["a cat; puss(y)", "sensitive to hot food"], "ja", "en"),
])
def test_definitions_of_another_language_in_vietnamese(samples, source, language):
    assert guess_text_language(samples, source) == language


def test_a_pack_of_dictionaries_is_explained(tmp_path):
    path = tmp_path / "pack.zip"
    path.write_bytes(make_zip({"pack/readme.txt": b"hi", "pack/dict-a.zip": b"x", "pack/dict-b.zip": b"y"}))
    with pytest.raises(Rejected) as error:
        check_zip(str(path), Limits(max_entries=100, max_uncompressed_bytes=10**7, max_bank_bytes=10**7))
    assert "holds other dictionaries (dict-a.zip, dict-b.zip)" in str(error.value)


def test_a_dictionary_inside_a_folder_is_explained(tmp_path):
    path = tmp_path / "folder.zip"
    path.write_bytes(make_zip({"My Dict/index.json": {"title": "x"}, "My Dict/term_bank_1.json": []}))
    with pytest.raises(Rejected) as error:
        check_zip(str(path), Limits(max_entries=100, max_uncompressed_bytes=10**7, max_bank_bytes=10**7))
    assert "inside the folder 'My Dict'" in str(error.value)
