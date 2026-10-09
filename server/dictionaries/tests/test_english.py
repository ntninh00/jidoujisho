import json

from dictserver import english, tidy
from test_tidy import texts

WORDSET = (
    "1. pos: noun\n\ta car on a freight train for use of the train crew\n\tsyn: cabin car\n"
    "\t2. pos: noun\n\tthe area for food preparation on a ship\n\tex: the galley was hot\n"
    "\tsyn: cookhouse, galley\n\t"
)
CAMBRIDGE = (
    "adverb\n\tsoon: \n\t· We will shortly be arriving.\n\t\n\tshortly after/before sth\n\tadverb\n"
    "\ta short time after or before something: \n\t· Shortly after you left, a man came.\n\t\n"
    "\tadverb [ not gradable ] · formal\n\tsoon: \n\t· We will be landing shortly.\n\t\n"
)
NOAD = (
    "en·sem·ble | änˈsämbəlɑnˈsɑmbəl |\nnoun\n"
    "1 a group of musicians, actors, or dancers who perform together:  a Bulgarian\n"
    "folk ensemble.\n"
    "• a scene or passage written for performance by a whole cast, choir, or group\n"
    "of instruments.\n"
    "PHRASES\nin the abstract\n"
    "in a general way; without reference to specific instances:  there's a fine\n"
    "line between promoting US business interests in the abstract and promoting\n"
    "specific companies.\n"
    "ORIGIN\nlate Middle English  (as an adverb): from French, based on Latin insimul, from in-\n"
    "‘in’ \\+ simul ‘at the same time’."
)
MACMILLAN = (
    "US /fɔɡ/\nNOUN\n1. COUNTABLE/UNCOUNTABLE \na thick cloud that forms close to the ground\n"
    "· thick/heavy fog: Heavy fog forced drivers to slow down.\n\n1a. ONLY BEFORE NOUN\n"
    "belonging to fog\n· a fog light\n\n2. SINGULAR \na cloud of smoke\n\n"
)
MWALD = (
    "beau·ti·ful\n  /ˈbjuːtıfəl/ adj \n    1 : having beauty: such as\n"
    "    1 a : very attractive in a physical way\n      a beautiful young woman/child\n"
    "    1 b : giving pleasure to the mind or the senses\n      a beautiful song\n"
    "    — see also ↑<>\n    2 : very good or pleasing : ↑<>\n      a beautiful sunny day /\n"
    "    break the bank\n      : to be very expensive\n    — usually used in negative statements\n"
    "  • • •\n  Main Entry: ↑<>\n"
)


def test_wordset():
    body = english.parse("wordset", [WORDSET], "caboose")
    car, galley = body.sections[0].senses
    assert (car.gloss, car.synonyms) == ("a car on a freight train for use of the train crew", ["cabin car"])
    assert galley.examples[0].text == "the galley was hot" and galley.synonyms == ["cookhouse", "galley"]
    assert '"examples-plain"' in json.dumps(tidy.to_structured(body))


def test_cambridge():
    body = english.parse("cambridge", [CAMBRIDGE], "shortly")
    adverb, phrase, again = body.sections
    assert adverb.label == "adverb" and adverb.senses[0].gloss == "soon"
    assert phrase.kind == "idiom" and phrase.label == "shortly after/before sth"
    assert (phrase.senses[0].label, phrase.senses[0].gloss) == ("adverb", "a short time after or before something")
    assert again.senses[0].label == "[not gradable] formal"
    assert again.senses[0].examples[0].text == "We will be landing shortly."
    forms = english.parse("cambridge", ["past simple and past participle of buttress \n\t\n\t"], "buttressed")
    assert forms.forms == [("buttress", "past simple and past participle")]


def test_noad_ipa_is_told_from_the_respelling():
    assert english.noad_ipa("änˈsämbəlɑnˈsɑmbəl") == "ɑnˈsɑmbəl"
    assert english.noad_ipa("ˈlab(ə)ˌrinTHˈlæb(ə)ˌrɪnθ") == "ˈlæb(ə)ˌrɪnθ"
    assert english.noad_ipa("ˈbyo͞odəfəlˈbjudəfəl") == "ˈbjudəfəl"
    assert english.noad_ipa("rənrən") == "rən"


def test_noad():
    body = english.parse("noad", [NOAD], "ensemble")
    assert (body.syllables, body.pronunciation) == ("en·sem·ble", "ɑnˈsɑmbəl")
    noun, phrases, phrase, origin = body.sections
    group = noun.senses[0]
    # Lines wrapped by the source are joined.
    assert group.examples[0].text == "a Bulgarian folk ensemble."
    assert group.subsenses[0].gloss.endswith("choir, or group of instruments.")
    assert (phrases.kind, phrase.kind, phrase.label) == ("heading", "idiom", "in the abstract")
    assert phrase.senses[0].examples[0].text.endswith("and promoting specific companies.")
    assert origin.senses[0].notes == [
        "late Middle English  (as an adverb): from French, based on Latin insimul, from in- ‘in’ + simul ‘at the same time’."
    ]


def test_macmillan():
    body = english.parse("macmillan", [MACMILLAN], "fog")
    assert body.pronunciation == "fɔɡ"
    cloud, smoke = body.sections[0].senses
    assert (cloud.label, cloud.gloss) == ("countable/uncountable", "a thick cloud that forms close to the ground")
    assert (cloud.examples[0].pattern, cloud.examples[0].text) == ("thick/heavy fog", "Heavy fog forced drivers to slow down.")
    assert (cloud.subsenses[0].label, cloud.subsenses[0].gloss) == ("only before noun", "belonging to fog")
    assert smoke.label == "singular"


def test_mwald():
    body = english.parse("mwald", [MWALD], "beautiful")
    assert (body.syllables, body.pronunciation) == ("beau·ti·ful", "ˈbjuːtıfəl")
    beauty, good, bank = body.sections[0].senses
    assert [sub.gloss for sub in beauty.subsenses] == ["very attractive in a physical way", "giving pleasure to the mind or the senses"]
    # Cross-references that lost their targets are gone.
    assert good.gloss == "very good or pleasing"
    assert good.examples[0].text == "a beautiful sunny day"
    assert (bank.label, bank.gloss, bank.notes) == ("break the bank", "to be very expensive", ["usually used in negative statements"])
    assert "↑<>" not in str(tidy.to_structured(body))
    assert english.says_nothing("mwald", ["↑<>\n————————\n  — see ↑<>, 2\n"])


def test_english_dictionaries_are_told_apart():
    def row(text):
        return ["word", "", "", "", 0, [text], 0, ""]

    assert tidy.detect([row(WORDSET)] * 20) == "wordset"
    assert tidy.detect([row(CAMBRIDGE)] * 20) == "cambridge"
    assert tidy.detect([row(NOAD)] * 20) == "noad"
    assert tidy.detect([row(MACMILLAN)] * 20) == "macmillan"
    assert tidy.detect([row({"type": "text", "text": MWALD})] * 20) == "mwald"
    # Text definitions are replaced by the layout, not kept beside it.
    laid = tidy.rewrite_row(row({"type": "text", "text": MWALD}), "mwald")
    assert len(laid[5]) == 1 and laid[5][0]["type"] == "structured-content"
    assert tidy.rewrite_row(row({"type": "text", "text": "↑<>\n"}), "mwald") is None
