"""
AI_Generate_Text.py
--------------------
Generate rangkuman berita bergaya Gen Z menggunakan Gemini.
Struktur output diselaraskan dengan News_Model yang dipakai di seluruh project.

Lokasi file:
    /home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/backend/AI/AI_Generate_Text.py

Dependensi (satu folder yang sama):
    - news_data.py              → NewsUpdater, fetch berita mentah
    - llm_analisis_sentiment.py → SentimentAnalyzer, SentimentResult

Cara pakai:
    from AI_Generate_Text import AIGenerateTextNews

    generator = AIGenerateTextNews(ai_api_key=..., news_api_key=...)
    results   = generator.run()   # list[News_Model]
"""

import os
import sys
import time
import json
from datetime import datetime, timezone

# ─── Path fix ─────────────────────────────────────────────────────────────────
_AI_DIR = os.path.dirname(os.path.abspath(__file__))
if _AI_DIR not in sys.path:
    sys.path.insert(0, _AI_DIR)
# ──────────────────────────────────────────────────────────────────────────────

from google import genai
from google.genai import types
from dotenv import load_dotenv

from news_data import NewsUpdater
from llm_analisis_sentiment import SentimentAnalyzer, SentimentResult


# ══════════════════════════════════════════════════════════════════════════════
# NEWS MODEL
# Diselaraskan dengan News_Model yang dipakai di seluruh project.
# Ditambahkan field sentiment karena itu bagian terpenting dari pipeline ini.
# ══════════════════════════════════════════════════════════════════════════════

class News_Model:
    """
    Model utama untuk satu artikel berita hasil AI generate.

    Field yang ada di News_Model asli dipertahankan 100%.
    Tambahan field sentiment diletakkan paling bawah agar tidak
    mengacaukan struktur yang sudah ada.
    """

    def __init__(self):
        # ── Core fields (sama persis dengan News_Model asli) ──────────────────
        self.id            = None          # ID unik artikel
        self.Title         = None          # Judul hasil AI generate (Gen Z style)
        self.Date          = datetime.now(timezone.utc)   # Waktu generate
        self.Image         = None          # URL thumbnail / gambar utama artikel
        self.Description   = None          # Ringkasan singkat 1–2 kalimat (~200 karakter)
        self.Source        = None          # Nama media sumber asli
        self.Images_news   = None          # Gambar pendukung 1 (dari artikel asli)
        self.Images_news_2 = None          # Gambar pendukung 2 (dari artikel asli)
        self.Images_link   = None          # Link gambar utama (URL lengkap)

        # ── Extended fields khusus AI Generate ────────────────────────────────
        self.Body          = None          # Isi rangkuman panjang ~2000 karakter
        self.Domain        = None          # Kategori: economy / technology / geopolitics
        self.Original_Title = None         # Judul asli dari sumber (sebelum di-generate)
        self.Original_Link  = None         # URL artikel sumber asli
        self.Original_Published = None     # Tanggal publikasi asli dari sumber

        # ── Sentiment — bagian terpenting, JANGAN dihapus ─────────────────────
        self.Sentiment     = None          # Label: optimis/positif/netral/negatif/pesimis
        self.Confidence    = None          # Skor confidence (0.0–1.0)
        self.Score         = None          # Skor numerik sentiment (-1.0 s/d +1.0)

        # ── Owner ──────────────────────────────────────────────────────────────
        self.Owner         = "EXXE News"

    def __str__(self):
        return (
            f"News_Model("
            f"id={self.id}, "
            f"Title={self.Title}, "
            f"Date={self.Date}, "
            f"Image={self.Image}, "
            f"Description={self.Description}, "
            f"Source={self.Source}, "
            f"Images_news={self.Images_news}, "
            f"Images_news_2={self.Images_news_2}, "
            f"Images_link={self.Images_link}, "
            f"Sentiment={self.Sentiment}, "
            f"Confidence={self.Confidence}, "
            f"Score={self.Score}"
            f")"
        )

    def to_dict(self) -> dict:
        """
        Konversi ke dict.
        Key mengikuti konvensi News_Model asli (PascalCase).
        """
        return {
            # ── Core ──────────────────────────────────────────────────────────
            "_id"           : self.id,
            "Title"         : self.Title,
            "Date"          : self.Date.isoformat() if isinstance(self.Date, datetime) else self.Date,
            "Image"         : self.Image,
            "Description"   : self.Description,
            "Source"        : self.Source,
            "Images_news"   : self.Images_news,
            "Images_news_2" : self.Images_news_2,
            "Images_link"   : self.Images_link,
            # ── Extended ──────────────────────────────────────────────────────
            "Body"               : self.Body,
            "Domain"             : self.Domain,
            "Original_Title"     : self.Original_Title,
            "Original_Link"      : self.Original_Link,
            "Original_Published" : self.Original_Published,
            # ── Sentiment ─────────────────────────────────────────────────────
            "Sentiment"  : self.Sentiment,
            "Confidence" : self.Confidence,
            "Score"      : self.Score,
            # ── Meta ──────────────────────────────────────────────────────────
            "Owner" : self.Owner,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "News_Model":
        """Buat instance dari dict (misalnya dari MongoDB atau JSON file)."""
        obj = cls()
        # ── Core ──────────────────────────────────────────────────────────────
        obj.id            = data.get("_id")
        obj.Title         = data.get("Title")
        obj.Date          = data.get("Date", datetime.now(timezone.utc))
        obj.Image         = data.get("Image")
        obj.Description   = data.get("Description")
        obj.Source        = data.get("Source")
        obj.Images_news   = data.get("Images_news")
        obj.Images_news_2 = data.get("Images_news_2")
        obj.Images_link   = data.get("Images_link")
        # ── Extended ──────────────────────────────────────────────────────────
        obj.Body               = data.get("Body")
        obj.Domain             = data.get("Domain")
        obj.Original_Title     = data.get("Original_Title")
        obj.Original_Link      = data.get("Original_Link")
        obj.Original_Published = data.get("Original_Published")
        # ── Sentiment ─────────────────────────────────────────────────────────
        obj.Sentiment  = data.get("Sentiment")
        obj.Confidence = data.get("Confidence")
        obj.Score      = data.get("Score")
        # ── Meta ──────────────────────────────────────────────────────────────
        obj.Owner = data.get("Owner", "EXXE News")
        return obj

    def display(self) -> str:
        """Tampilkan artikel ke konsol dengan format rapi."""
        sep = "─" * 70
        sentiment_emoji = {
            "optimis": "🟢", "positif": "🔵", "netral": "⚪",
            "negatif": "🟠", "pesimis": "🔴",
        }.get(self.Sentiment or "", "⚪")

        return (
            f"\n{sep}\n"
            f"  🗞️  {self.Title}\n"
            f"  💬 {self.Description}\n"
            f"{sep}\n"
            f"  {self.Body}\n\n"
            f"  🔗 Sumber : {self.Source}\n"
            f"  📅 Tanggal: {self.Original_Published}\n"
            f"  🌐 Link   : {self.Original_Link}\n"
            f"  {sentiment_emoji} Sentiment : {str(self.Sentiment).upper()}  "
            f"conf={self.Confidence:.2f}  score={self.Score:.2f}\n"
            f"  🏷️  Owner   : {self.Owner}\n"
            f"{sep}"
        )


# ══════════════════════════════════════════════════════════════════════════════
# AI GENERATE TEXT NEWS
# ══════════════════════════════════════════════════════════════════════════════

class AIGenerateTextNews:
    """
    Generate rangkuman berita bergaya Gen Z, lengkap dengan analisis sentiment.

    Alur kerja:
        fetch berita (NewsUpdater)
            → generate Title + Description + Body (Gemini)
            → analisis sentiment (SentimentAnalyzer)
            → hasilkan list[News_Model]
            → simpan ke JSON + TXT

    Parameters
    ----------
    ai_api_key   : Gemini API key
    news_api_key : NewsData.io API key
    output_dir   : direktori output, default "daily_content"
    max_news     : jumlah berita per run, default 3
    categories   : kategori yang difetch, default economy/technology/geopolitics
    language     : bahasa berita, default "en"
    """

    GENERATE_MODEL  = "gemini-2.5-flash"
    SENTIMENT_MODEL = "gemini-2.5-flash-lite"

    SAFETY_SETTINGS = [
        types.SafetySetting(
            category  = "HARM_CATEGORY_HARASSMENT",
            threshold = "BLOCK_MEDIUM_AND_ABOVE",
        ),
        types.SafetySetting(
            category  = "HARM_CATEGORY_HATE_SPEECH",
            threshold = "BLOCK_MEDIUM_AND_ABOVE",
        ),
    ]

    def __init__(
        self,
        ai_api_key:   str,
        news_api_key: str,
        output_dir:   str             = "daily_content",
        max_news:     int             = 3,
        categories:   list[str]|None  = None,
        language:     str             = "en",
    ):
        if not ai_api_key:
            raise ValueError("Gemini API key tidak boleh kosong.")
        if not news_api_key:
            raise ValueError("NewsData API key tidak boleh kosong.")

        self.output_dir = output_dir
        self.categories = categories or ["economy", "technology", "geopolitics"]

        os.makedirs(self.output_dir, exist_ok=True)

        self.client = genai.Client(api_key=ai_api_key)

        self.updater = NewsUpdater(
            api_key    = news_api_key,
            output_dir = output_dir,
            max_news   = max_news,
            language   = language,
            randomize  = True,
        )

        self.sentiment_analyzer = SentimentAnalyzer(
            api_key  = ai_api_key,
            model_id = self.SENTIMENT_MODEL,
        )

    # ──────────────────────────────────────────────────────────────────────────
    # PUBLIC API
    # ──────────────────────────────────────────────────────────────────────────

    def run(
        self,
        export_json: bool = True,
        export_txt:  bool = True,
    ) -> list[News_Model]:
        """
        Jalankan pipeline penuh: fetch → generate → sentiment → export.

        Returns
        -------
        list[News_Model]
        """
        print("\n" + "=" * 70)
        print("  AI GENERATE TEXT NEWS — EXXE News")
        print("=" * 70)

        # Step 1: Fetch berita mentah
        print("\n[STEP 1] Fetch berita dari NewsData.io...")
        articles = self.updater.run(
            categories     = self.categories,
            export_formats = [],
        )

        if not articles:
            print("[WARN] Tidak ada artikel. Pipeline dihentikan.")
            return []

        print(f"[STEP 1] ✓ {len(articles)} artikel siap diproses.\n")

        # Step 2: Generate konten AI + sentiment per artikel
        print("[STEP 2] Generate konten AI + analisis sentiment...\n")
        results: list[News_Model] = []

        for i, article in enumerate(articles, 1):
            print(f"  [{i}/{len(articles)}] {article.title[:65]}...")
            news_model = self._process_article(article)
            if news_model:
                results.append(news_model)
                print(news_model.display())
            if i < len(articles):
                time.sleep(2)

        if not results:
            print("[WARN] Tidak ada konten berhasil di-generate.")
            return []

        # Step 3: Export
        print(f"\n[STEP 3] Menyimpan {len(results)} konten...")
        if export_json:
            self._save_json(results)
        if export_txt:
            self._save_txt(results)

        print("\n" + "=" * 70)
        print(f"  SELESAI — {len(results)} artikel berhasil di-generate oleh AI")
        print("=" * 70 + "\n")

        return results

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: proses satu artikel
    # ──────────────────────────────────────────────────────────────────────────

    def _process_article(self, article: "NewsArticle") -> "News_Model | None":
        """
        Proses satu artikel: generate teks AI → analisis sentiment → News_Model.
        Return None jika generate gagal.
        """
        # 1. Generate Title + Description + Body sekaligus
        try:
            title, description, body = self._generate_content(article)
        except Exception as e:
            print(f"          → [ERROR generate] {e}")
            return None

        # 2. Analisis sentiment — BAGIAN TERPENTING, jangan dihapus
        try:
            sentiment_result: SentimentResult = self.sentiment_analyzer.analyze(article)
            sentiment  = sentiment_result.sentiment
            confidence = sentiment_result.confidence
            score      = sentiment_result.score
        except Exception as e:
            print(f"          → [WARN sentiment] {e} — fallback ke netral")
            sentiment, confidence, score = "netral", 0.5, 0.0

        print(
            f"          → ✓ generate OK  |  "
            f"sentiment={sentiment}  conf={confidence:.2f}  score={score:.2f}"
        )

        # 3. Bangun News_Model
        news = News_Model()

        # Core fields
        news.Title         = title
        news.Date          = datetime.now(timezone.utc)
        news.Image         = getattr(article, "image_url", None)     # thumbnail dari sumber
        news.Description   = description                              # 1–2 kalimat singkat
        news.Source        = article.source
        news.Images_news   = getattr(article, "images_news",   None) # gambar pendukung 1
        news.Images_news_2 = getattr(article, "images_news_2", None) # gambar pendukung 2
        news.Images_link   = getattr(article, "image_url",     None) # link gambar utama

        # Extended fields
        news.Body               = body
        news.Domain             = article.domain
        news.Original_Title     = article.title
        news.Original_Link      = article.link
        news.Original_Published = article.published

        # Sentiment — bagian terpenting
        news.Sentiment  = sentiment
        news.Confidence = confidence
        news.Score      = score

        news.Owner = "EXXE News"

        return news

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: Gemini generate
    # ──────────────────────────────────────────────────────────────────────────

    def _generate_content(self, article: "NewsArticle") -> tuple[str, str, str]:
        """
        Panggil Gemini untuk generate Title + Description + Body.

        Returns
        -------
        (title, description, body)

        Raises
        ------
        ValueError jika output terpotong atau parsing gagal.
        """
        raw_text = f"Judul: {article.title}\n\nKonten:\n{article.summary[:1500]}"

        prompt = f"""Kamu adalah editor berita muda dari EXXE News yang menulis dengan gaya Gen Z — natural, relatable, informatif, dan tetap faktual.

Berikut berita asli yang perlu kamu tulis ulang:

{raw_text}

TUGAS KAMU (3 bagian, wajib semua):

1. JUDUL — 1 baris, gaya Gen Z, tetap relevan dengan isi berita.

2. DESKRIPSI — 1 sampai 2 kalimat singkat, maksimal 200 karakter.
   Dipakai sebagai preview card di aplikasi, harus to-the-point
   dan bikin orang penasaran buat baca lebih lanjut.

3. BODY — rangkuman editorial ~2000 karakter (tidak kurang dari 1500 karakter).
   - Bahasa natural Gen Z Indonesia, tidak kaku, tetapi tetap akurat
   - Tidak mengubah fakta — hanya mengubah gaya bahasa
   - Tidak menggunakan bullet point atau heading
   - Mengalir seperti paragraf editorial yang enak dibaca
   - Akhiri dengan kalimat penutup yang solid, JANGAN biarkan terpotong

FORMAT OUTPUT (ikuti PERSIS, tanpa teks tambahan di luar format):
JUDUL: <judul hasil tulisanmu>
DESKRIPSI: <1–2 kalimat, maks 200 karakter>
BODY:
<rangkuman editorial di sini, min 1500 karakter, diakhiri kalimat lengkap>

Ingat: owner konten ini adalah EXXE News. Jangan sebut nama media lain sebagai penulis."""

        response = self.client.models.generate_content(
            model    = self.GENERATE_MODEL,
            contents = prompt,
            config   = types.GenerateContentConfig(
                temperature       = 0.75,
                top_p             = 0.92,
                top_k             = 40,
                max_output_tokens = 2048,
                safety_settings   = self.SAFETY_SETTINGS,
            ),
        )

        raw_output = response.text.strip()

        # Validasi output tidak terpotong di tengah
        if raw_output.endswith("...") or raw_output.endswith(".."):
            raise ValueError("Output terpotong (diakhiri '...'). Kemungkinan token limit.")

        return self._parse_generated(raw_output)

    def _parse_generated(self, raw: str) -> tuple[str, str, str]:
        """
        Parse output Gemini → (title, description, body).

        Mapping ke News_Model:
            JUDUL      → Title
            DESKRIPSI  → Description
            BODY       → Body
        """
        title        = ""
        description  = ""
        body_lines: list[str] = []

        # mode: None | "description" | "body"
        mode = None

        for line in raw.splitlines():
            stripped = line.strip()
            lower    = stripped.lower()

            # ── Deteksi header section ──────────────────────────────────────
            if lower.startswith("judul:"):
                title = stripped.split(":", 1)[1].strip()
                mode  = None

            elif lower.startswith("deskripsi:"):
                inline = stripped.split(":", 1)[1].strip()
                if inline:
                    description = inline
                mode = "description"

            elif lower.startswith("body:"):
                inline = stripped.split(":", 1)[1].strip()
                if inline:
                    body_lines.append(inline)
                mode = "body"

            # ── Isi section ─────────────────────────────────────────────────
            elif mode == "description":
                if stripped:
                    description += (" " + stripped) if description else stripped
                elif description:
                    mode = None   # baris kosong setelah description = selesai

            elif mode == "body":
                body_lines.append(line)

        body = "\n".join(body_lines).strip()

        # Bersihkan karakter kutip di description
        description = description.strip('"\'')

        # ── Fallback kalau parsing gagal ────────────────────────────────────
        if not title:
            title = "Berita Terkini — EXXE News"

        if not description:
            sentences   = [s.strip() for s in body.replace("\n", " ").split(".") if s.strip()]
            fallback    = ". ".join(sentences[:2])
            description = (fallback[:197] + "...") if len(fallback) > 200 else fallback

        if not body:
            body = raw

        # Pastikan description tidak melebihi 200 karakter
        if len(description) > 200:
            description = description[:197] + "..."

        return title, description, body

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: export
    # ──────────────────────────────────────────────────────────────────────────

    def _save_json(self, results: list[News_Model]) -> str:
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"generated_news_{ts}.json"
        filepath = os.path.join(self.output_dir, filename)

        payload = {
            "generated_at" : datetime.now(timezone.utc).isoformat(),
            "total"        : len(results),
            "owner"        : "EXXE News",
            "articles"     : [r.to_dict() for r in results],
        }
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        print(f"[EXPORT] JSON saved → {filepath}")
        return filepath

    def _save_txt(self, results: list[News_Model]) -> str:
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"generated_news_{ts}.txt"
        filepath = os.path.join(self.output_dir, filename)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write("EXXE News — Daily Report\n")
            f.write(f"Generated : {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total     : {len(results)} artikel\n")
            f.write("=" * 70 + "\n\n")

            for i, r in enumerate(results, 1):
                f.write(f"[{i}] {r.Title}\n")
                f.write(f"{'─' * 70}\n")
                f.write(f"📋 {r.Description}\n\n")
                f.write(f"{r.Body}\n\n")
                f.write(f"Sumber    : {r.Source}\n")
                f.write(f"Tanggal   : {r.Original_Published}\n")
                f.write(f"Link      : {r.Original_Link}\n")
                f.write(f"Sentiment : {str(r.Sentiment).upper()}  "
                        f"(conf={r.Confidence:.2f}  score={r.Score:.2f})\n")
                f.write(f"Owner     : {r.Owner}\n")
                f.write("\n" + "=" * 70 + "\n\n")

        print(f"[EXPORT] TXT saved  → {filepath}")
        return filepath


# ══════════════════════════════════════════════════════════════════════════════
# CLI entry point
# ══════════════════════════════════════════════════════════════════════════════

def main():
    env_path = os.path.join(os.path.dirname(__file__), ".env")
    if not os.path.exists(env_path):
        env_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
    load_dotenv(dotenv_path=env_path)

    ai_api_key   = os.getenv("api_key_ai")
    news_api_key = (
        os.getenv("api_key_news")
        or os.getenv("API_NEWS")
        or os.getenv("NEWS_API_KEY")
    )

    if not ai_api_key:
        raise EnvironmentError("Gemini API key tidak ditemukan! Cek .env → api_key_ai")
    if not news_api_key:
        raise EnvironmentError("News API key tidak ditemukan! Cek .env → api_key_news / API_NEWS")

    generator = AIGenerateTextNews(
        ai_api_key   = ai_api_key,
        news_api_key = news_api_key,
        output_dir   = "daily_content",
        max_news     = 3,
        categories   = ["economy", "technology", "geopolitics"],
        language     = "en",
    )

    generator.run(export_json=True, export_txt=True)


if __name__ == "__main__":
    main()