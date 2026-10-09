"""Checks a model's replies to the batches of tools/javi_batches.py.

Each reply is saved under the batch's name in the replies folder, as
`batch-001.txt` for `batch-001.txt`, with or without text around its JSON.
For each batch this reports the words missing from its reply, those with
the wrong number of meanings, and meanings left in English, and writes the
words to do again into `redo-NNN.txt` beside the batches, a batch like the
others. Replies to redo batches are saved and checked the same way.

    python tools/javi_check.py BATCHES_DIR REPLIES_DIR
"""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path

_VIETNAMESE = re.compile("[ăâđêôơưàáảãạằắẳẵặầấẩẫậèéẻẽẹềếểễệìíỉĩịòóỏõọồốổỗộờớởỡợùúủũụừứửữựỳýỷỹỵ]", re.I)


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
    return not _VIETNAMESE.search(text) and len(re.findall(r"[A-Za-z]+", text)) >= 3


def check(batch: Path, reply: Path) -> tuple[dict[str, list[str]], list[dict], list[str]]:
    """The good translations, the words to do again, and what was wrong."""
    words = [json.loads(line) for line in batch.read_text(encoding="utf-8").splitlines() if line.strip()]
    answer = json_in(reply.read_text(encoding="utf-8")) or {}
    good: dict[str, list[str]] = {}
    redo: list[dict] = []
    problems: list[str] = []
    for word in words:
        key = str(word["id"])
        meanings = answer.get(key)
        if meanings is None:
            problems.append(f"{key} {word['w']}: missing")
        elif not isinstance(meanings, list) or len(meanings) != len(word["s"]):
            problems.append(f"{key} {word['w']}: {len(meanings) if isinstance(meanings, list) else '?'} meanings for {len(word['s'])}")
        elif any(not isinstance(text, str) or not text.strip() for text in meanings):
            problems.append(f"{key} {word['w']}: an empty meaning")
        elif any(english(text) for text in meanings):
            problems.append(f"{key} {word['w']}: left in English")
        else:
            good[key] = [text.strip() for text in meanings]
            continue
        redo.append(word)
    return good, redo, problems


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    sys.stdout.reconfigure(encoding="utf-8")
    batches, replies = Path(sys.argv[1]), Path(sys.argv[2])
    total = 0
    done: set[str] = set()
    for batch in sorted(batches.glob("*.txt")):
        reply = replies / batch.name
        words = sum(1 for line in batch.read_text(encoding="utf-8").splitlines() if line.strip())
        if batch.name.startswith("batch-"):
            total += words
        if not reply.exists():
            continue
        good, redo, problems = check(batch, reply)
        done.update(good)
        print(f"{batch.name}: {len(good)} of {words} good" + (f", {len(redo)} to redo" if redo else ""))
        for problem in problems[:5]:
            print("   ", problem)
        if redo:
            redo_path = batches / batch.name.replace("batch-", "redo-")
            if redo_path != batch:
                redo_path.write_text(
                    "".join(json.dumps(word, ensure_ascii=False, separators=(",", ":")) + "\n" for word in redo),
                    encoding="utf-8",
                )
                print(f"    words to redo written to {redo_path.name}")
    print(f"{len(done)} of {total} words translated")
