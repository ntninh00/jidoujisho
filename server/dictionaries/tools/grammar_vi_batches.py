"""Batches of hanabira.org's JLPT grammar points for a model to translate
into Vietnamese, with the instructions and a checker beside them.

hanabira.org (github.com/tristcoil/hanabira.org, MIT) has 828 points from
N5 to N1, each with a short and a long explanation, how it is formed and
example sentences, all in English. Each batch line is one point:

    {"id": "N3-025", "t": "～くせに", "m": "Used to express criticism...",
     "l": "The ～くせに grammar point is used...", "f": "Verb-casual + くせに, ...",
     "ex": [["彼はお金持ちのくせに、ケチです。", "Even though he's rich, he's stingy."]]}

The model answers `{"N3-025": {"m", "l", "f", "ex": [...], "k": [...]}}`:
the explanations, formation and examples in Vietnamese, and the forms the
point is looked up by.

    python tools/grammar_vi_batches.py HANABIRA_JSON_DIR OUT_DIR [--size 16000]
"""

from __future__ import annotations

import argparse
import json
import re
import shutil
from pathlib import Path

LEVELS = ("N5", "N4", "N3", "N2", "N1")
_ROMAJI = re.compile(r"\s*[(（][^()（）]*[A-Za-z~〜～][^()（）]*[)）]\s*$")

SYSTEM_PROMPT = """You translate entries of a Japanese grammar reference from English into Vietnamese, for a Japanese–Vietnamese grammar dictionary used by Vietnamese learners preparing for the JLPT.

## Input

The user message is a batch of grammar points, one JSON object per line:

{"id":"N3-025","t":"～くせに","m":"Used to express criticism or disapproval; 'even though'.","l":"The ～くせに grammar point is used to ...","f":"Verb-casual + くせに, な-Adjective + な/のくせに, Noun + のくせに","ex":[["彼はお金持ちのくせに、ケチです。","Even though he's rich, he's stingy."]]}

- `id`: the point's number. `t`: the pattern.
- `m`: a short explanation. `l`: a longer one. `f`: how the pattern is formed.
- `ex`: example sentences, each as [Japanese, English translation].

## Output

Reply with one JSON object and nothing else, each `id` as a key:

{"N3-025":{"m":"Mặc dù…, vậy mà… (phê phán, bất mãn)","l":"…","f":"V(thể thường) + くせに; Aな + な/のくせに; N + のくせに","ex":["Anh ta giàu mà lại keo kiệt."],"k":["くせに"]}}

- `m`, `l`: the explanations in Vietnamese.
- `f`: the formation, in the notation below.
- `ex`: one Vietnamese translation for each example, in the same order: exactly as many as the input has.
- `k`: the forms the pattern is looked up by (see the end).

Every id in the batch must be there, with all five fields.

## How to translate

- Write natural, clear Vietnamese, as in Vietnamese editions of JLPT grammar books. Write for learners: short, plain sentences.
- Keep Japanese as it is: patterns, words and kana inside explanations stay Japanese, in 「」 where the English quotes them. Never write romaji.
- Translate each example from its Japanese, with the English only as a guide. Keep its meaning and tone (thân mật or lịch sự).
- `m` is one short line, like a dictionary meaning.
- `f` uses textbook notation: V (động từ), N (danh từ), Aい (tính từ い), Aな (tính từ な); forms: thể thường, thể từ điển (Vる), thể ます (Vます), thể て (Vて), thể た (Vた), thể ない (Vない), thể ý chí (Vよう), thể khả năng, thể điều kiện (Vば), thể bị động, thể sai khiến. Separate alternatives with "; ".
- Grammar words: particle = trợ từ, sentence-ending = cuối câu, conjunction = liên từ, polite = lịch sự, casual = thân mật, formal = trang trọng, written language = văn viết, spoken language = văn nói, honorific = tôn kính ngữ, humble = khiêm nhường ngữ.

## k: lookup forms

The app shows a point when a reader taps the first character of one of these strings in a Japanese text. Give 1 to 4 strings:

- Only the fixed Japanese part of the pattern, written as it appears in the examples: "くせに", "なければならない", "に関して".
- No 〜 or ～, no V, N or A, no spaces, no romaji, no English.
- For a pattern with a gap, as ～ば～ほど, its most telling part ("ほど"), not a lone particle unless the point is about that particle.
- For a pattern that conjugates, its plain dictionary form ("ことにする", not "ことにした").
- For a point about one word (いつでも, もっと), that word.
"""

TASK = """# Translate a Japanese grammar dictionary into Vietnamese, batch by batch

This folder holds {points} JLPT grammar points (N5 to N1) in {batches} batches, to be translated from English into Vietnamese.

- `system_prompt.md`: how to translate, and the exact form of each reply. It is the instructions for every batch.
- `batches/batch-001.txt` … `batch-{last:03d}.txt`: the batches, one grammar point per line, N5 first.
- `replies/`: each reply goes here, under the same name as its batch.
- `check.py`: checks the replies (needs Python 3).

## What to do

Go through the batches in order, skipping any that already has a reply in `replies/`, so the work can stop and pick up again at any time.

Hand each batch to a subagent of its own, so your own context stays small. Give it this task, with NNN filled in and FOLDER as this folder's full path:

> Read FOLDER/system_prompt.md: these are your instructions; follow them exactly. Read FOLDER/batches/batch-NNN.txt: it is the user message they describe. Write your reply, exactly as the instructions say and with nothing else in the file, to FOLDER/replies/batch-NNN.txt, as UTF-8. Then say how many points the batch had and how many you translated.

After every five batches, and at the end, run:

    python check.py batches replies

It lists the points that are missing from a reply, have the wrong number of examples, lack a lookup form or were left in English, and writes them to `batches/redo-NNN.txt`. Translate each new redo file the same way, into `replies/redo-NNN.txt`, and run the check again. If a redo file still shows problems after two tries, leave it and mention it at the end.

If Python is not installed, skip the checks; they will be run later.

Do not change the batches, `system_prompt.md` or `check.py`, and do not edit a reply by hand; translate the batch again instead.

When you finish, or have to stop, report the last line of the check ("N of {points} points translated") and the batches still to do.
"""


def title_of(title: str) -> str:
    """A title without its romaji, as `～くせに` for `～くせに (〜kuse ni)`."""
    return _ROMAJI.sub("", title).strip() or title.strip()


def points(source: Path) -> list[dict]:
    found = []
    for level in LEVELS:
        items = json.loads((source / f"grammar_ja_JLPT_{level}_0001.json").read_text(encoding="utf-8"))
        for number, item in enumerate(items, start=1):
            found.append({
                "id": f"{level}-{number:03d}",
                "t": title_of(item["title"]),
                "m": item.get("short_explanation", ""),
                "l": item.get("long_explanation", ""),
                "f": item.get("formation", ""),
                "ex": [[example["jp"], example.get("en", "")] for example in item.get("examples", []) if example.get("jp")],
            })
    return found


def write_batches(found: list[dict], out: Path, size: int) -> list[Path]:
    (out / "batches").mkdir(parents=True, exist_ok=True)
    (out / "replies").mkdir(exist_ok=True)
    batches: list[list[str]] = [[]]
    length = 0
    for point in found:
        line = json.dumps(point, ensure_ascii=False, separators=(",", ":"))
        if batches[-1] and length + len(line) + 1 > size:
            batches.append([])
            length = 0
        batches[-1].append(line)
        length += len(line) + 1
    paths = []
    for number, lines in enumerate(batches, start=1):
        path = out / "batches" / f"batch-{number:03d}.txt"
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
        paths.append(path)
    return paths


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path, help="hanabira.org's backend/express/json_data")
    parser.add_argument("out", type=Path)
    parser.add_argument("--size", type=int, default=16000, help="most characters in one batch")
    arguments = parser.parse_args()
    found = points(arguments.source)
    paths = write_batches(found, arguments.out, arguments.size)
    (arguments.out / "system_prompt.md").write_text(SYSTEM_PROMPT, encoding="utf-8")
    (arguments.out / "TASK.md").write_text(
        TASK.format(points=len(found), batches=len(paths), last=len(paths)), encoding="utf-8")
    shutil.copy(Path(__file__).with_name("grammar_vi_check.py"), arguments.out / "check.py")
    print(f"{len(found)} points in {len(paths)} batches; system prompt {len(SYSTEM_PROMPT)} characters")
