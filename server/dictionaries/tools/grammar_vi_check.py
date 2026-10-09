"""Checks a model's replies to the batches of tools/grammar_vi_batches.py.

Each reply is saved under its batch's name in the replies folder, with or
without text around its JSON. For each batch this reports the points
missing from its reply, those with the wrong number of examples, without
lookup forms, or left in English, and writes the points to do again into
`redo-NNN.txt` beside the batches, a batch like the others. Replies to redo
batches are saved and checked the same way.

    python check.py BATCHES_DIR REPLIES_DIR
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_VIETNAMESE = re.compile("[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]", re.I)
_JAPANESE = re.compile(r"[぀-ヿ㐀-鿿]")


def json_in(text: str) -> dict | None:
    """The largest JSON object in [text]."""
    best = None
    decoder = json.JSONDecoder()
    for start in [match.start() for match in re.finditer(r"\{", text)]:
        try:
            value, end = decoder.raw_decode(text, start)
        except ValueError:
            continue
        if isinstance(value, dict) and (best is None or len(value) > len(best)):
            best = value
    return best


def english(text: str) -> bool:
    """Whether a translation was left in English."""
    return not _VIETNAMESE.search(text) and len(re.findall(r"[A-Za-z]{2,}", text)) >= 3


def problem(point: dict, answer: object) -> str | None:
    """What is wrong with the answer for [point], if anything."""
    if not isinstance(answer, dict):
        return "missing"
    for field in ("m", "l", "f"):
        text = answer.get(field)
        if not isinstance(text, str) or (point[field].strip() and not text.strip()):
            return f"no {field}"
        if field != "f" and english(text):
            return f"{field} left in English"
    if re.search(r"\b(Verb|Noun|Adjective|form)\b", answer["f"]):
        return "f left in English"
    examples = answer.get("ex")
    if not isinstance(examples, list) or len(examples) != len(point["ex"]):
        return f"{len(examples) if isinstance(examples, list) else '?'} examples for {len(point['ex'])}"
    if any(not isinstance(text, str) or not text.strip() or english(text) for text in examples):
        return "an example empty or left in English"
    keys = answer.get("k")
    if not isinstance(keys, list) or not keys or len(keys) > 6:
        return "no lookup forms"
    for key in keys:
        if not isinstance(key, str) or not _JAPANESE.search(key) or re.search(r"[〜～A-Za-z\s]", key):
            return f"lookup form {key!r} is not plain Japanese"
    return None


def check(batch: Path, reply: Path) -> tuple[dict[str, dict], list[dict], list[str]]:
    """The good translations, the points to do again, and what was wrong."""
    found = [json.loads(line) for line in batch.read_text(encoding="utf-8").splitlines() if line.strip()]
    answer = json_in(reply.read_text(encoding="utf-8")) or {}
    good: dict[str, dict] = {}
    redo: list[dict] = []
    problems: list[str] = []
    for point in found:
        wrong = problem(point, answer.get(point["id"]))
        if wrong is None:
            good[point["id"]] = answer[point["id"]]
        else:
            problems.append(f"{point['id']} {point['t']}: {wrong}")
            redo.append(point)
    return good, redo, problems


def translated(batches: Path, replies: Path) -> dict[str, dict]:
    """Every good translation so far, by point."""
    good: dict[str, dict] = {}
    for batch in sorted(batches.glob("*.txt")):
        reply = replies / batch.name
        if reply.exists():
            good.update(check(batch, reply)[0])
    return good


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.stdout.reconfigure(encoding="utf-8")
    batches, replies = Path(sys.argv[1]), Path(sys.argv[2])
    total = 0
    done: set[str] = set()
    redo_number = max([int(path.stem[5:]) for path in batches.glob("redo-*.txt")] or [0])
    for batch in sorted(batches.glob("*.txt")):
        lines = [line for line in batch.read_text(encoding="utf-8").splitlines() if line.strip()]
        if batch.name.startswith("batch-"):
            total += len(lines)
        reply = replies / batch.name
        if not reply.exists():
            continue
        good, redo, problems = check(batch, reply)
        done.update(good)
        for line in problems:
            print(f"{batch.name}: {line}")
        # A point done in a later redo no longer needs one.
        redo = [point for point in redo if point["id"] not in done]
        if redo and batch.name.startswith("batch-"):
            already = any(
                point["id"] in path.read_text(encoding="utf-8") for path in batches.glob("redo-*.txt") for point in redo
            )
            if not already:
                redo_number += 1
                path = batches / f"redo-{redo_number:03d}.txt"
                path.write_text("\n".join(json.dumps(point, ensure_ascii=False) for point in redo) + "\n", encoding="utf-8")
                print(f"-> {path.name}: {len(redo)} points to do again")
    print(f"{len(done)} of {total} points translated")
