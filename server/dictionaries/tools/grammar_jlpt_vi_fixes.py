"""Corrections to hanabira.org's grammar and its Vietnamese, from the
translator's review: a point that teaches the wrong meaning, examples that
are not Japanese, typos, and examples one point borrowed from another.

Each entry replaces the fields it gives: `t`, the pattern; `m`, `l`, `f`
and `k`, as the translation has them; `ex`, the examples whole, as
(Japanese, Vietnamese) pairs; `jp`, single examples' Japanese by position.
"""

from __future__ import annotations

FIXES: dict[str, dict] = {
    # The source teaches の嫌いがある as "dislike", every example included.
    "N1-082": {
        "t": "V / Nの + きらいがある",
        "m": "Có khuynh hướng…, hay… (thường là điều không tốt)",
        "f": "V(thể từ điển / thể ない) + きらいがある; N + の + きらいがある",
        "l": "Diễn tả một người hay sự việc có khuynh hướng, có tật dễ dẫn đến điều không tốt. "
             "Dùng để phê phán nhẹ, mang tính văn viết. 「きらい」 thường viết bằng hiragana. "
             "Mẫu này không mang nghĩa “ghét” của 「嫌い」.",
        "ex": [
            ("彼は物事を大げさに言うきらいがある。", "Anh ấy có tật hay nói quá mọi chuyện."),
            ("最近の若者は、すぐに結果を求めるきらいがある。", "Giới trẻ gần đây có khuynh hướng muốn có kết quả ngay."),
            ("彼女は人の話を最後まで聞かないきらいがある。", "Cô ấy có tật không chịu nghe người khác nói hết."),
            ("彼の意見は、少し独断のきらいがある。", "Ý kiến của anh ấy hơi có phần độc đoán."),
        ],
        "k": ["きらいがある", "嫌いがある"],
    },
    # 〜かれ〜かれ lives on only in a few set phrases; the source's examples
    # (冬かれ夏かれ, 来るかれ来ないかれ) are not Japanese.
    "N1-004": {
        "t": "Aかれ Bかれ",
        "m": "Dù… hay…; …gì cũng (chỉ trong vài thành ngữ cố định)",
        "f": "Aい(bỏ い) + かれ + Aい(bỏ い) + かれ: 遅かれ早かれ, 多かれ少なかれ, 良かれ悪しかれ",
        "l": "Cách nói văn viết, cũ, nay chỉ còn trong vài thành ngữ ghép hai tính từ trái nghĩa: "
             "遅かれ早かれ (sớm muộn gì cũng), 多かれ少なかれ (ít nhiều), 良かれ悪しかれ (dù tốt hay xấu). "
             "Không tự do ghép với danh từ hay động từ; khi đó dùng 「～にしろ～にしろ」 hoặc 「～であれ～であれ」.",
        "ex": [
            ("遅かれ早かれ、本当のことは分かるだろう。", "Sớm muộn gì sự thật cũng sẽ lộ ra."),
            ("多かれ少なかれ、誰にでも悩みはある。", "Ít nhiều gì thì ai cũng có nỗi phiền muộn."),
            ("良かれ悪しかれ、彼の決断が会社を変えた。", "Dù tốt hay xấu, quyết định của anh ấy đã thay đổi công ty."),
        ],
        "k": ["遅かれ早かれ", "早かれ遅かれ", "多かれ少なかれ", "良かれ悪しかれ"],
    },
    "N3-118": {"jp": {3: "彼女は医者らしい。"}},
    "N2-064": {"jp": {1: "電車が遅れたため、タクシーに乗らざるを得なかった。"}},
    # The explanation said it follows verbs and adjectives too.
    "N3-085": {
        "l": "Mẫu 「～に関して」 dùng để nêu chủ đề hoặc nội dung mà người nói đang đề cập, "
             "nghĩa là “về”, “liên quan đến”, “đối với”. Đi sau danh từ; trước một danh từ khác thì "
             "dùng 「～に関する＋N」 hoặc 「～に関しての＋N」.",
    },
    # Two of its examples were めったに～ない's, and its formation put a
    # negative before めったにない.
    "N3-105": {
        "f": "Vこと + は + めったにない; Vの + は + めったにない; N + は + めったにない",
        "l": "「めったにない」 đứng cuối câu, nghĩa là “hiếm khi có, hiếm khi xảy ra”. Thường đi sau "
             "「Vことは」, 「Vのは」 hoặc danh từ. Khác với 「めったに＋Vない」, ở mẫu này 「ない」 là "
             "một phần của 「めったにない」.",
        "ex": [
            ("この町では雪が降ることはめったにない。", "Ở thị trấn này, tuyết hiếm khi rơi."),
            ("友達が遊びに来るのはめったにない。", "Bạn bè hiếm khi đến chơi."),
            ("こんなチャンスはめったにない。", "Cơ hội như thế này hiếm lắm."),
        ],
    },
    # The translation dropped the verb form, which is common.
    "N2-149": {
        "f": "N + もかまわず; V(thể thường) + の + もかまわず",
        "l": "Mẫu 「～もかまわず」 diễn tả việc không bận tâm đến một điều gì đó (người xung quanh, thời gian, "
             "cái lạnh, nguy hiểm…) mà vẫn làm. Có thể dịch là “bất chấp”, “không màng đến”, “mặc kệ”. "
             "Gắn sau danh từ, hoặc sau động từ qua 「の」: 「濡れるのもかまわず」.",
        "ex": [
            ("彼は周りの人もかまわず、大声で話しました。", "Anh ấy không để ý đến những người xung quanh, nói chuyện to tiếng."),
            ("彼は寒さもかまわず、外で運動しました。", "Anh ấy không ngại cái lạnh, vẫn tập thể dục ngoài trời."),
            ("彼女は危険もかまわず、火事の中に飛び込んで助けに行きました。",
             "Cô ấy bất chấp nguy hiểm, lao vào đám cháy để đi cứu người."),
            ("彼は服が濡れるのもかまわず、雨の中を走った。", "Anh ấy chạy dưới mưa, mặc kệ quần áo bị ướt."),
        ],
    },
}


def apply(source: dict, answer: dict) -> tuple[dict, dict]:
    """[source] and [answer] with their point's corrections."""
    fix = FIXES.get(source["id"])
    if not fix:
        return source, answer
    source, answer = {**source, "ex": [list(pair) for pair in source["ex"]]}, {**answer, "ex": list(answer["ex"])}
    if "t" in fix:
        source["t"] = fix["t"]
    for field in ("m", "l", "f", "k"):
        if field in fix:
            answer[field] = fix[field]
    if "ex" in fix:
        source["ex"] = [[japanese, ""] for japanese, _ in fix["ex"]]
        answer["ex"] = [vietnamese for _, vietnamese in fix["ex"]]
    for position, japanese in fix.get("jp", {}).items():
        source["ex"][position][0] = japanese
    return source, answer
