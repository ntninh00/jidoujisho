import base64
import json

import pytest
from conftest import READER, auth

from dictserver import speech

VOICES = {"voices": [
    {"name": "ja-JP-Standard-A", "languageCodes": ["ja-JP"]},
    {"name": "ja-JP-Wavenet-B", "languageCodes": ["ja-JP"]},
    {"name": "ja-JP-Wavenet-A", "languageCodes": ["ja-JP"]},
    {"name": "ja-JP-Chirp3-HD-Aoede", "languageCodes": ["ja-JP"]},
    {"name": "vi-VN-Standard-A", "languageCodes": ["vi-VN"]},
    {"name": "en-GB-Wavenet-A", "languageCodes": ["en-GB"]},
    {"name": "en-US-Wavenet-C", "languageCodes": ["en-US"]},
]}


class Google:
    """Stands in for Google, counting what it was asked."""

    def __init__(self):
        self.spoken: list[dict] = []

    def __call__(self, method, path, body=None):
        if path == "/voices":
            return VOICES
        self.spoken.append(body)
        return {"audioContent": base64.b64encode(f"mp3 of {body['input']['text']}".encode()).decode()}


def test_voices_are_the_best_free_kind_in_the_usual_locale(tmp_path):
    voices = speech.Speech(tmp_path, 10, Google())
    assert voices.voice_for("ja") == ("ja-JP", "ja-JP-Wavenet-A")
    assert voices.voice_for("vi") == ("vi-VN", "vi-VN-Standard-A")
    assert voices.voice_for("en") == ("en-US", "en-US-Wavenet-C")
    assert voices.voice_for("en-GB") == ("en-GB", "en-GB-Wavenet-A")
    assert voices.voice_for("la") is None


def test_a_word_is_fetched_once_and_new_words_are_limited_per_day(tmp_path):
    google = Google()
    voices = speech.Speech(tmp_path, 2, google)
    first = voices.audio("たべる", "ja")
    assert first.read_bytes() == "mp3 of たべる".encode()
    assert voices.audio(" たべる ", "ja") == first
    assert len(google.spoken) == 1
    assert google.spoken[0]["voice"] == {"languageCode": "ja-JP", "name": "ja-JP-Wavenet-A"}
    voices.audio("nhà", "vi")
    with pytest.raises(speech.SpeechError) as limited:
        voices.audio("museum", "en")
    assert limited.value.status == 429
    # Words already kept still play.
    assert voices.audio("たべる", "ja") == first
    assert json.loads((tmp_path / "usage.json").read_text())["count"] == 2


def test_requests_that_cannot_be_read(tmp_path):
    voices = speech.Speech(tmp_path, 10, Google())
    for text, language, status in [("", "ja", 400), ("a" * 81, "en", 400), ("salve", "la", 404), ("x", "ja;", 400)]:
        with pytest.raises(speech.SpeechError) as error:
            voices.audio(text, language)
        assert error.value.status == status
    with pytest.raises(speech.SpeechError) as off:
        speech.Speech(tmp_path, 10, None).audio("たべる", "ja")
    assert off.value.status == 404


def test_the_route_serves_mp3_to_either_token(settings):
    from starlette.testclient import TestClient

    from dictserver.app import create_app

    with TestClient(create_app(settings, speech_fetch=Google())) as client:
        answer = client.get("/api/speech", params={"text": "たべる", "lang": "ja"}, headers=auth(READER))
        assert answer.status_code == 200
        assert answer.headers["content-type"] == "audio/mpeg"
        assert answer.content == "mp3 of たべる".encode()
        assert client.get("/api/speech", params={"text": "たべる", "lang": "ja"}).status_code == 401
        assert client.get("/api/speech", params={"text": "salve", "lang": "la"}, headers=auth(READER)).status_code == 404


def test_without_a_key_the_route_says_so(client):
    answer = client.get("/api/speech", params={"text": "たべる", "lang": "ja"}, headers=auth(READER))
    assert answer.status_code == 404
    assert "not set up" in answer.json()["error"]
