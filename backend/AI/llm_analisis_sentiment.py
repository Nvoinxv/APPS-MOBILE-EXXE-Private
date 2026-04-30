"""
sentiment_analyzer.py
----------------------
Analisis sentiment 5 level untuk berita, terintegrasi dengan NewsUpdater.

5 Level Sentiment:
    optimis   — berita sangat menggembirakan, outlook sangat cerah
    positif   — berita cenderung baik / harapan membangun
    netral    — berita faktual / tidak berpihak / campuran
    negatif   — berita cenderung buruk / mengkhawatirkan
    pesimis   — berita krisis / outlook sangat suram

Output per artikel: label + confidence score (0.0 – 1.0)

Cara pakai:
    from sentiment_analyzer import NewsSentimentPipeline

    pipeline = NewsSentimentPipeline(ai_api_key=..., news_api_key=...)
    results = pipeline.run()
"""

import os
import json
import time
from dataclasses import dataclass, field, asdict
from datetime import datetime
from typing import TYPE_CHECKING

from google import genai
from google.genai import types
from dotenv import load_dotenv


from news_data import NewsUpdater

# NewsArticle hanya dipakai untuk type hint — tidak di-import saat runtime
# supaya tidak ada circular/redundant dependency dengan news_api.py
if TYPE_CHECKING:
    from news_api import NewsArticle


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

VALID_LABELS = ["optimis", "positif", "netral", "negatif", "pesimis"]

# Skor numerik untuk keperluan agregasi (-1.0 s/d +1.0)
LABEL_SCORE_MAP: dict[str, float] = {
    "optimis":  1.0,
    "positif":  0.5,
    "netral":   0.0,
    "negatif": -0.5,
    "pesimis": -1.0,
}

LABEL_EMOJI: dict[str, str] = {
    "optimis":  "🟢",
    "positif":  "🔵",
    "netral":   "⚪",
    "negatif":  "🟠",
    "pesimis":  "🔴",
}


# ---------------------------------------------------------------------------
# Data class
# ---------------------------------------------------------------------------

@dataclass
class SentimentResult:
    """Hasil analisis sentiment satu artikel berita."""

    # Metadata artikel
    article_title:     str
    article_link:      str
    article_source:    str
    article_domain:    str
    article_published: str

    # Hasil sentiment
    sentiment:  str    # salah satu dari VALID_LABELS
    confidence: float  # 0.0 – 1.0

    # Dihitung otomatis dari label
    score: float = field(init=False)

    def __post_init__(self):
        self.score = LABEL_SCORE_MAP.get(self.sentiment, 0.0)

    def to_dict(self) -> dict:
        return asdict(self)

    def display(self) -> str:
        """Tampilkan satu baris ringkas: emoji label conf bar judul."""
        emoji = LABEL_EMOJI.get(self.sentiment, "⚪")
        bar   = self._confidence_bar()
        return (
            f"{emoji} {self.sentiment:<8}  conf={self.confidence:.2f}  {bar}\n"
            f"   {self.article_title[:75]}\n"
            f"   {self.article_source} — {self.article_published}\n"
            f"   {self.article_link}\n"
        )

    def _confidence_bar(self, width: int = 10) -> str:
        filled = round(self.confidence * width)
        return "[" + "█" * filled + "░" * (width - filled) + "]"


# ---------------------------------------------------------------------------
# Core analyzer
# ---------------------------------------------------------------------------

class SentimentAnalyzer:
    """
    Analisis sentiment 5 level menggunakan Gemini API.

    Parameters
    ----------
    api_key  : str  — Google Gemini API key
    model_id : str  — Model yang dipakai, default gemini-2.5-flash-lite
    """

    def __init__(self, api_key: str, model_id: str = "gemini-2.5-flash-lite"):
        if not api_key:
            raise ValueError("Gemini API key tidak boleh kosong.")
        self.client   = genai.Client(api_key=api_key)
        self.model_id = model_id

    # ------------------------------------------------------------------
    # Public methods
    # ------------------------------------------------------------------

    def analyze(self, article: "NewsArticle") -> SentimentResult:
        """Analisis satu NewsArticle, kembalikan SentimentResult."""
        text = self._build_text(article)
        raw  = self._call_api(text)
        sentiment, confidence = self._parse_response(raw)

        return SentimentResult(
            article_title     = article.title,
            article_link      = article.link,
            article_source    = article.source,
            article_domain    = article.domain,
            article_published = article.published,
            sentiment         = sentiment,
            confidence        = confidence,
        )

    def analyze_batch(
        self,
        articles: list["NewsArticle"],
        delay_seconds: float = 1.2,
    ) -> list[SentimentResult]:
        """
        Analisis sekumpulan artikel satu per satu.

        Parameters
        ----------
        articles      : Daftar NewsArticle
        delay_seconds : Jeda antar request (hindari rate limit Gemini)

        Returns
        -------
        list[SentimentResult]
        """
        results: list[SentimentResult] = []
        total = len(articles)

        for i, article in enumerate(articles, 1):
            print(f"  [{i}/{total}] {article.title[:65]}...")
            try:
                result = self.analyze(article)
                emoji  = LABEL_EMOJI.get(result.sentiment, "⚪")
                print(f"          → {emoji} {result.sentiment:<8}  conf={result.confidence:.2f}")
                results.append(result)
            except Exception as e:
                print(f"          → [ERROR] {e} — fallback ke netral, conf=0.00")
                results.append(self._fallback(article, str(e)))

            if i < total:
                time.sleep(delay_seconds)

        return results

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _build_text(self, article: "NewsArticle") -> str:
        parts = [f"Judul: {article.title}"]
        if article.summary:
            parts.append(f"Konten: {article.summary[:800]}")
        return "\n".join(parts)

    def _call_api(self, text: str) -> str:
        prompt = f"""Kamu adalah analis sentiment berita profesional.

Analisis teks berita berikut. Tentukan sentiment dan confidence score-nya.

TEKS BERITA:
{text}

DEFINISI 5 LEVEL SENTIMENT:
- optimis  : outlook sangat cerah, berita sangat menggembirakan
- positif  : berita cenderung baik, harapan membangun
- netral   : berita faktual, tidak berpihak, atau campuran
- negatif  : berita cenderung buruk, mengkhawatirkan
- pesimis  : outlook sangat suram, berita krisis atau bencana

ATURAN OUTPUT (ikuti PERSIS, tanpa teks tambahan):
SENTIMENT: <satu kata dari: optimis / positif / netral / negatif / pesimis>
CONFIDENCE: <angka 0.00 – 1.00, dua desimal>

Contoh output yang benar:
SENTIMENT: positif
CONFIDENCE: 0.78

Jawaban:"""

        response = self.client.models.generate_content(
            model    = self.model_id,
            contents = prompt,
            config   = types.GenerateContentConfig(
                temperature       = 0.1,
                top_p             = 0.85,
                top_k             = 20,
                max_output_tokens = 20,
            ),
        )
        return response.text.strip()

    def _parse_response(self, raw: str) -> tuple[str, float]:
        """
        Parse output model → (sentiment, confidence).
        Robust terhadap variasi format output model.
        """
        sentiment  = "netral"
        confidence = 0.5

        for line in raw.splitlines():
            line  = line.strip()
            lower = line.lower()

            if lower.startswith("sentiment:"):
                candidate = line.split(":", 1)[1].strip().lower()
                for label in VALID_LABELS:
                    if label in candidate:
                        sentiment = label
                        break

            elif lower.startswith("confidence:"):
                val_str = line.split(":", 1)[1].strip()
                try:
                    confidence = max(0.0, min(1.0, float(val_str)))
                except ValueError:
                    confidence = 0.5

        return sentiment, confidence

    def _fallback(self, article: "NewsArticle", error: str) -> SentimentResult:
        return SentimentResult(
            article_title     = article.title,
            article_link      = article.link,
            article_source    = article.source,
            article_domain    = article.domain,
            article_published = article.published,
            sentiment         = "netral",
            confidence        = 0.0,
        )


# ---------------------------------------------------------------------------
# Aggregator / Reporter
# ---------------------------------------------------------------------------

class SentimentReport:
    """
    Laporan agregat dari sekumpulan SentimentResult.

    Parameters
    ----------
    results : list[SentimentResult]
    """

    def __init__(self, results: list[SentimentResult]):
        self.results = results

    def summary(self) -> dict:
        """Statistik: distribusi label, rata-rata skor & confidence."""
        if not self.results:
            return {}

        label_counts: dict[str, int] = {label: 0 for label in VALID_LABELS}
        scores:       list[float]    = []
        confidences:  list[float]    = []

        for r in self.results:
            label_counts[r.sentiment] = label_counts.get(r.sentiment, 0) + 1
            scores.append(r.score)
            confidences.append(r.confidence)

        avg_score = sum(scores) / len(scores)
        avg_conf  = sum(confidences) / len(confidences)

        # Overall mood dari rata-rata skor
        if avg_score >= 0.75:
            overall = "optimis"
        elif avg_score >= 0.25:
            overall = "positif"
        elif avg_score <= -0.75:
            overall = "pesimis"
        elif avg_score <= -0.25:
            overall = "negatif"
        else:
            overall = "netral"

        return {
            "total_articles"     : len(self.results),
            "overall_sentiment"  : overall,
            "average_score"      : round(avg_score, 3),
            "average_confidence" : round(avg_conf, 3),
            "distribution"       : label_counts,
        }

    def print_report(self) -> None:
        """Cetak laporan lengkap ke konsol."""
        sep = "=" * 70
        print(f"\n{sep}")
        print("  LAPORAN SENTIMENT BERITA")
        print(sep + "\n")

        for result in self.results:
            print(result.display())

        stats = self.summary()
        if not stats:
            return

        overall_emoji = LABEL_EMOJI.get(stats["overall_sentiment"], "⚪")
        print(sep)
        print("  RINGKASAN")
        print(sep)
        print(f"  Total artikel       : {stats['total_articles']}")
        print(f"  Overall sentiment   : {overall_emoji} {stats['overall_sentiment'].upper()}")
        print(f"  Rata-rata skor      : {stats['average_score']:+.3f}  (pesimis -1.0 ↔ optimis +1.0)")
        print(f"  Rata-rata confidence: {stats['average_confidence']:.3f}")
        print()
        print("  Distribusi label:")
        for label in VALID_LABELS:
            count = stats["distribution"].get(label, 0)
            bar   = "▮" * count + "▯" * max(0, 5 - count)
            emoji = LABEL_EMOJI[label]
            print(f"    {emoji} {label:<10} {bar}  ({count})")
        print(sep + "\n")

    def to_json(self, output_dir: str = "news_output", filename: str = "") -> str:
        """Simpan hasil + summary ke JSON."""
        os.makedirs(output_dir, exist_ok=True)
        if not filename:
            ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
            filename = f"sentiment_{ts}.json"
        filepath = os.path.join(output_dir, filename)

        payload = {
            "generated_at": datetime.now().isoformat(),
            "summary"     : self.summary(),
            "articles"    : [r.to_dict() for r in self.results],
        }
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        print(f"[EXPORT] Sentiment JSON saved → {filepath}")
        return filepath


# ---------------------------------------------------------------------------
# Pipeline: NewsUpdater + SentimentAnalyzer dalam satu .run()
# ---------------------------------------------------------------------------

class NewsSentimentPipeline:
    """
    Pipeline lengkap: fetch berita → analisis sentiment → laporan.

    Parameters
    ----------
    ai_api_key   : str        — Gemini API key
    news_api_key : str        — NewsData.io API key
    max_news     : int        — jumlah artikel per run (default 5)
    output_dir   : str        — direktori output file
    categories   : list[str]  — kategori yang difetch
    language     : str        — bahasa berita (default "en")
    """

    def __init__(
        self,
        ai_api_key  : str,
        news_api_key: str,
        max_news    : int             = 5,
        output_dir  : str             = "news_output",
        categories  : list[str]|None  = None,
        language    : str             = "en",
    ):
        self.categories = categories or ["economy", "technology", "geopolitics"]
        self.output_dir = output_dir

        self.updater  = NewsUpdater(
            api_key    = news_api_key,
            output_dir = output_dir,
            max_news   = max_news,
            language   = language,
            randomize  = True,
        )
        self.analyzer = SentimentAnalyzer(api_key=ai_api_key)

    def run(
        self,
        export_news     : bool = True,
        export_sentiment: bool = True,
    ) -> tuple[list["NewsArticle"], list[SentimentResult]]:
        """
        Jalankan pipeline lengkap.

        Returns
        -------
        (articles, sentiment_results)
        """
        print("\n" + "=" * 60)
        print("  NEWS SENTIMENT PIPELINE — START")
        print("=" * 60)

        # Step 1: Fetch berita
        print("\n[STEP 1] Fetch berita...")
        articles = self.updater.run(
            categories     = self.categories,
            export_formats = ["json", "txt"] if export_news else [],
        )

        if not articles:
            print("[WARN] Tidak ada artikel untuk dianalisis.")
            return [], []

        # Step 2: Analisis sentiment
        print(f"\n[STEP 2] Analisis sentiment {len(articles)} artikel...\n")
        results = self.analyzer.analyze_batch(articles, delay_seconds=1.2)

        # Step 3: Cetak laporan
        report = SentimentReport(results)
        report.print_report()

        # Step 4: Export JSON
        if export_sentiment:
            report.to_json(output_dir=self.output_dir)

        return articles, results


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    load_dotenv(dotenv_path=path_env)

    ai_api_key   = os.getenv("api_key_ai")
    news_api_key = os.getenv("API_NEWS") or os.getenv("NEWS_API_KEY")

    if not ai_api_key:
        raise ValueError("Gemini API key tidak ditemukan! Cek .env → api_key_ai")
    if not news_api_key:
        raise ValueError("News API key tidak ditemukan! Cek .env → API_NEWS atau NEWS_API_KEY")

    # Pipeline penuh: fetch + analisis + export
    pipeline = NewsSentimentPipeline(
        ai_api_key   = ai_api_key,
        news_api_key = news_api_key,
        max_news     = 5,
        output_dir   = "news_output",
        categories   = ["economy", "technology", "geopolitics"],
    )
    pipeline.run()


if __name__ == "__main__":
    main()