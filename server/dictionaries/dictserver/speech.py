"""Words read aloud by Google's text-to-speech, for the app's speaker when a
phone has no voice for a word's language.

Each word is fetched once and kept under `data/speech`, so playing it again
costs nothing. Words not fetched before are limited per day, which keeps a
runaway client inside Google's free monthly allowance. The key is
GOOGLE_TTS_KEY in the server's `.env`; without it the route says reading
aloud is not set up.
"""

import base64
import datetime
import hashlib
import json
import os
import re
import threading
import time
import urllib.error
import urllib.request
from pathlib import Path
from typing import Callable

API = "https://texttospeech.googleapis.com/v1"
# Where a language the app names is spoken, when Google has more than one.
LOCALES = {
    "ja": "ja-JP", "vi": "vi-VN", "en": "en-US", "zh": "cmn-CN", "ko": "ko-KR",
    "ru": "ru-RU", "fr": "fr-FR", "de": "de-DE", "es": "es-ES", "pt": "pt-BR",
}
# Kinds of voice, best first, among those with a free monthly allowance.
KINDS = ("Wavenet", "Standard")
MAX_TEXT = 80
LANGUAGE = re.compile(r"^[a-z]{2,3}(-[A-Za-z0-9]{2,8})?$")
# The voice list is asked for again after this long.
VOICES_TTL = 24 * 60 * 60

Fetch = Callable[[str, str, dict | None], dict]


class SpeechError(Exception):
    """A word that can't be read aloud, with the status and a message."""

    def __init__(self, status: int, message: str) -> None:
        super().__init__(message)
        self.status = status
        self.message = message


def google(key: str) -> Fetch:
    """Calls Google's API with [key], sent in a header so it stays out of
    logs of addresses."""

    def fetch(method: str, path: str, body: dict | None = None) -> dict:
        request = urllib.request.Request(
            API + path,
            data=json.dumps(body).encode() if body is not None else None,
            method=method,
            headers={"X-Goog-Api-Key": key, "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(request, timeout=15) as response:
                return json.load(response)
        except urllib.error.HTTPError as error:
            raise SpeechError(502, f"Google's text-to-speech refused the request ({error.code}).") from None
        except (urllib.error.URLError, TimeoutError, OSError):
            raise SpeechError(502, "Google's text-to-speech could not be reached.") from None

    return fetch


class Speech:
    def __init__(self, directory: Path, daily_limit: int, fetch: Fetch | None) -> None:
        self.directory = directory
        self.daily_limit = daily_limit
        self._fetch = fetch
        self._voices: list[dict] = []
        self._voices_at = 0.0
        self._lock = threading.Lock()

    @property
    def enabled(self) -> bool:
        return self._fetch is not None

    def _voice_list(self) -> list[dict]:
        if not self._voices or time.monotonic() - self._voices_at > VOICES_TTL:
            answer = self._fetch("GET", "/voices", None)
            self._voices = [voice for voice in answer.get("voices", []) if isinstance(voice, dict)]
            self._voices_at = time.monotonic()
        return self._voices

    def voice_for(self, language: str) -> tuple[str, str] | None:
        """The locale and name of the voice [language] is read in: the best
        kind its usual locale has, else any locale of the language."""
        voices = self._voice_list()
        locale = LOCALES.get(language, language)
        base = language.split("-")[0]
        for wanted in (lambda code: code == locale, lambda code: code.split("-")[0] == base):
            for kind in KINDS:
                found = sorted(
                    (voice["name"], code)
                    for voice in voices
                    for code in voice.get("languageCodes", [])
                    if wanted(code) and f"-{kind}-" in voice.get("name", "")
                )
                if found:
                    name, code = found[0]
                    return code, name
        return None

    def _count_new(self) -> None:
        """Counts a word not fetched before against today's limit."""
        usage = self.directory / "usage.json"
        today = datetime.date.today().isoformat()
        with self._lock:
            try:
                counted = json.loads(usage.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                counted = {}
            count = counted.get("count", 0) if counted.get("day") == today else 0
            if count >= self.daily_limit:
                raise SpeechError(429, "Today's words to read aloud are used up. Try again tomorrow.")
            self.directory.mkdir(parents=True, exist_ok=True)
            usage.write_text(json.dumps({"day": today, "count": count + 1}), encoding="utf-8")

    def audio(self, text: str, language: str) -> Path:
        """An MP3 of [text] read in [language], fetched the first time."""
        if not self.enabled:
            raise SpeechError(404, "Reading aloud is not set up on this server.")
        text = " ".join(text.split())
        if not text or len(text) > MAX_TEXT:
            raise SpeechError(400, f"Send a word or phrase of up to {MAX_TEXT} characters.")
        if not LANGUAGE.match(language):
            raise SpeechError(400, "Name the language with a code such as ja or vi.")
        voice = self.voice_for(language)
        if voice is None:
            raise SpeechError(404, "There is no voice for this language.")
        code, name = voice
        digest = hashlib.sha256(f"{name}\n{text}".encode()).hexdigest()
        path = self.directory / digest[:2] / f"{digest}.mp3"
        if path.is_file():
            return path

        self._count_new()
        answer = self._fetch("POST", "/text:synthesize", {
            "input": {"text": text},
            "voice": {"languageCode": code, "name": name},
            # A single word is easier to catch a little slower.
            "audioConfig": {"audioEncoding": "MP3", "speakingRate": 0.9},
        })
        try:
            data = base64.b64decode(answer["audioContent"])
        except (KeyError, TypeError, ValueError):
            raise SpeechError(502, "Google's text-to-speech sent no audio.") from None
        path.parent.mkdir(parents=True, exist_ok=True)
        temp = path.with_suffix(f".{os.getpid()}.{threading.get_ident()}.tmp")
        temp.write_bytes(data)
        temp.replace(path)
        return path
