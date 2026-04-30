"""
AI_Generate_Text.py
--------------------
Generate rangkuman berita bergaya Gen Z menggunakan Gemini,
lalu simpan hasilnya ke MongoDB via MongoConnection.

Lokasi file:
    /home/nvoinxv/Documents/APPS-MOBILE-EXXE-Private/backend/AI/AI_Generate_Text.py

Dependensi (satu folder yang sama):
    - news_data.py              → NewsUpdater, fetch berita mentah
    - llm_analisis_sentiment.py → SentimentAnalyzer, SentimentResult

Dependensi (dari folder database/):
    - ../database/mongo_connection.py → MongoConnection

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
_AI_DIR      = os.path.dirname(os.path.abspath(__file__))
_BACKEND_DIR = os.path.dirname(_AI_DIR)   # naik satu level ke /backend

for _path in (_AI_DIR, _BACKEND_DIR):
    if _path not in sys.path:
        sys.path.insert(0, _path)
# ──────────────────────────────────────────────────────────────────────────────

from google import genai
from google.genai import types
from dotenv import load_dotenv

from news_data import NewsUpdater
from llm_analisis_sentiment import SentimentAnalyzer, SentimentResult

# MongoDB — import lazy supaya error koneksi tidak crash saat import module
try:
    from database.mongo_connection import MongoConnection
    _MONGO_AVAILABLE = True
except ImportError:
    _MONGO_AVAILABLE = False
    print("[WARN] MongoConnection tidak bisa diimport — fitur save ke DB dinonaktifkan.")


# ══════════════════════════════════════════════════════════════════════════════
# NEWS MODEL
# ══════════════════════════════════════════════════════════════════════════════

class News_Model:
    """
    Model utama untuk satu artikel berita hasil AI generate.

    Field yang ada di News_Model asli dipertahankan 100%.
    Tambahan field sentiment diletakkan paling bawah agar tidak
    mengacaukan struktur yang sudah ada.
    """

    def __init__(self):
        # ── Core fields ───────────────────────────────────────────────────────
        self.id            = None
        self.Title         = None
        self.Date          = datetime.now(timezone.utc)
        self.Image         = None
        self.Description   = None          # 3–5 kalimat, ~400–600 karakter
        self.Source        = None
        self.Images_news   = None
        self.Images_news_2 = None
        self.Images_link   = None

        # ── Extended fields ───────────────────────────────────────────────────
        self.Body               = None
        self.Domain             = None
        self.Original_Title     = None
        self.Original_Link      = None
        self.Original_Published = None

        # ── Sentiment — JANGAN dihapus ────────────────────────────────────────
        self.Sentiment  = None
        self.Confidence = None
        self.Score      = None

        # ── Meta ──────────────────────────────────────────────────────────────
        self.Owner = "EXXE News"

    def __str__(self):
        return (
            f"News_Model("
            f"id={self.id}, Title={self.Title}, Date={self.Date}, "
            f"Sentiment={self.Sentiment}, Confidence={self.Confidence}, Score={self.Score}"
            f")"
        )

    def to_dict(self) -> dict:
        return {
            "_id"                : self.id,
            "Title"              : self.Title,
            "Date"               : self.Date.isoformat() if isinstance(self.Date, datetime) else self.Date,
            "Image"              : self.Image,
            "Description"        : self.Description,
            "Source"             : self.Source,
            "Images_news"        : self.Images_news,
            "Images_news_2"      : self.Images_news_2,
            "Images_link"        : self.Images_link,
            "Body"               : self.Body,
            "Domain"             : self.Domain,
            "Original_Title"     : self.Original_Title,
            "Original_Link"      : self.Original_Link,
            "Original_Published" : self.Original_Published,
            "Sentiment"          : self.Sentiment,
            "Confidence"         : self.Confidence,
            "Score"              : self.Score,
            "Owner"              : self.Owner,
        }

    @classmethod
    def from_dict(cls, data: dict) -> "News_Model":
        obj = cls()
        obj.id             = data.get("_id")
        obj.Title          = data.get("Title")
        obj.Date           = data.get("Date", datetime.now(timezone.utc))
        obj.Image          = data.get("Image")
        obj.Description    = data.get("Description")
        obj.Source         = data.get("Source")
        obj.Images_news    = data.get("Images_news")
        obj.Images_news_2  = data.get("Images_news_2")
        obj.Images_link    = data.get("Images_link")
        obj.Body               = data.get("Body")
        obj.Domain             = data.get("Domain")
        obj.Original_Title     = data.get("Original_Title")
        obj.Original_Link      = data.get("Original_Link")
        obj.Original_Published = data.get("Original_Published")
        obj.Sentiment  = data.get("Sentiment")
        obj.Confidence = data.get("Confidence")
        obj.Score      = data.get("Score")
        obj.Owner      = data.get("Owner", "EXXE News")
        return obj

    def display(self) -> str:
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
# KONSTANTA PANJANG DESKRIPSI
# ══════════════════════════════════════════════════════════════════════════════

_DESC_MIN_CHARS = 400
_DESC_MAX_CHARS = 600


# ══════════════════════════════════════════════════════════════════════════════
# MONGO SAVE HELPER
# ══════════════════════════════════════════════════════════════════════════════

def _save_to_mongo(results: list["News_Model"]) -> dict[str, int]:
    if not _MONGO_AVAILABLE:
        print("[MONGO] ⚠️  MongoConnection tidak tersedia — skip save ke DB.")
        return {"inserted": 0, "skipped": 0, "errors": 0}

    summary = {"inserted": 0, "updated": 0, "errors": 0}

    try:
        mongo = MongoConnection()
        col   = mongo.collection_news_general

        for news in results:
            doc = news.to_dict()

            # Hapus _id None supaya MongoDB auto-generate ObjectId
            if doc.get("_id") is None:
                doc.pop("_id", None)

            original_link = news.Original_Link or ""

            if not original_link:
                # Tidak ada link unik → insert langsung
                try:
                    col.insert_one(doc)
                    summary["inserted"] += 1
                    print(f"  [MONGO] ✓ Inserted (no link): {news.Title[:55]}")
                except Exception as e:
                    summary["errors"] += 1
                    print(f"  [MONGO] ✗ Insert error: {e}")
                continue

            try:
                # Cek dulu apakah dokumen sudah ada
                existing = col.find_one({"Original_Link": original_link}, {"_id": 1})

                if existing:
                    # Update semua field kecuali _id
                    col.update_one(
                        {"Original_Link": original_link},
                        {"$set": doc}   # ← update konten terbaru
                    )
                    summary["updated"] += 1
                    print(f"  [MONGO] ↺ Updated    : {news.Title[:55]}")
                else:
                    col.insert_one(doc)
                    summary["inserted"] += 1
                    print(f"  [MONGO] ✓ Inserted   : {news.Title[:55]}")

            except Exception as e:
                summary["errors"] += 1
                print(f"  [MONGO] ✗ Error '{news.Title[:45]}': {e}")

    except Exception as e:
        print(f"[MONGO] ✗ Gagal koneksi ke MongoDB: {e}")
        summary["errors"] += len(results)

    return summary

# ══════════════════════════════════════════════════════════════════════════════
# AI GENERATE TEXT NEWS
# ══════════════════════════════════════════════════════════════════════════════

class AIGenerateTextNews:
    """
    Generate rangkuman berita bergaya Gen Z, lengkap dengan analisis sentiment,
    lalu simpan hasilnya ke MongoDB collection news_general.

    Alur kerja:
        fetch berita (NewsUpdater)
            → generate Title + Description + Body (Gemini)
            → analisis sentiment (SentimentAnalyzer)
            → simpan ke MongoDB   ← BARU
            → export ke JSON + TXT (opsional)

    Parameters
    ----------
    ai_api_key      : Gemini API key
    news_api_key    : NewsData.io API key
    output_dir      : direktori output file, default "daily_content"
    max_news        : jumlah berita per run, default 3
    categories      : kategori yang difetch
    language        : bahasa berita, default "en"
    save_to_mongo   : simpan ke MongoDB setelah generate (default True)
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
        ai_api_key:    str,
        news_api_key:  str,
        output_dir:    str            = "daily_content",
        max_news:      int            = 3,
        categories:    list[str]|None = None,
        language:      str            = "en",
        save_to_mongo: bool           = True,
    ):
        if not ai_api_key:
            raise ValueError("Gemini API key tidak boleh kosong.")
        if not news_api_key:
            raise ValueError("NewsData API key tidak boleh kosong.")

        self.output_dir    = output_dir
        self.categories    = categories or ["economy", "technology", "geopolitics"]
        self.save_to_mongo = save_to_mongo

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
        Jalankan pipeline penuh: fetch → generate → sentiment → MongoDB → export.

        Returns
        -------
        list[News_Model]
        """
        print("\n" + "=" * 70)
        print("  AI GENERATE TEXT NEWS — EXXE News")
        print("=" * 70)

        # ── Step 1: Fetch berita mentah ───────────────────────────────────────
        print("\n[STEP 1] Fetch berita dari NewsData.io...")
        articles = self.updater.run(
            categories     = self.categories,
            export_formats = [],
        )

        if not articles:
            print("[WARN] Tidak ada artikel. Pipeline dihentikan.")
            return []

        print(f"[STEP 1] ✓ {len(articles)} artikel siap diproses.\n")

        # ── Step 2: Generate konten AI + sentiment ────────────────────────────
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

        # ── Step 3: Simpan ke MongoDB ─────────────────────────────────────────
        if self.save_to_mongo:
            print(f"\n[STEP 3] Menyimpan {len(results)} artikel ke MongoDB (news_general)...")
            mongo_summary = _save_to_mongo(results)
            print(
                f"[STEP 3] ✓ Selesai — "
                f"inserted={mongo_summary.get('inserted', 0)}  "
                f"updated={mongo_summary.get('updated', 0)}  "
                f"errors={mongo_summary.get('errors', 0)}"
            )
        else:
            print("\n[STEP 3] Skip MongoDB (save_to_mongo=False).")

        # ── Step 4: Export file (opsional) ────────────────────────────────────
        print(f"\n[STEP 4] Export file...")
        if export_json:
            self._save_json(results)
        if export_txt:
            self._save_txt(results)
        if not export_json and not export_txt:
            print("  (tidak ada format yang diminta)")

        print("\n" + "=" * 70)
        print(f"  SELESAI — {len(results)} artikel berhasil di-generate oleh AI")
        print("=" * 70 + "\n")

        return results

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: proses satu artikel
    # ──────────────────────────────────────────────────────────────────────────

    def _process_article(self, article: "NewsArticle") -> "News_Model | None":
        try:
            title, description, body = self._generate_content(article)
        except Exception as e:
            print(f"          → [ERROR generate] {e}")
            return None

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
            f"sentiment={sentiment}  conf={confidence:.2f}  score={score:.2f}  "
            f"desc_len={len(description)}"
        )

        news = News_Model()
        news.Title         = title
        news.Date          = datetime.now(timezone.utc)
        news.Image         = getattr(article, "image_url", None)
        news.Description   = description
        news.Source        = article.source
        news.Images_news   = getattr(article, "images_news",   None)
        news.Images_news_2 = getattr(article, "images_news_2", None)
        news.Images_link   = getattr(article, "image_url",     None)
        news.Body               = body
        news.Domain             = article.domain
        news.Original_Title     = article.title
        news.Original_Link      = article.link
        news.Original_Published = article.published
        news.Sentiment  = sentiment
        news.Confidence = confidence
        news.Score      = score
        news.Owner      = "EXXE News"

        return news

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: Gemini generate
    # ──────────────────────────────────────────────────────────────────────────

    def _generate_content(self, article: "NewsArticle") -> tuple[str, str, str]:
        raw_text = f"Judul: {article.title}\n\nKonten:\n{article.summary[:1500]}"

        prompt = f"""Kamu adalah editor berita muda dari EXXE News yang menulis dengan gaya Gen Z — natural, relatable, informatif, dan tetap faktual.

Berikut berita asli yang perlu kamu tulis ulang:

{raw_text}

TUGAS KAMU (3 bagian, wajib semua):

1. JUDUL — 1 baris, gaya Gen Z, tetap relevan dengan isi berita.

2. DESKRIPSI — paragraf preview yang informatif dan menarik.
   - Panjang WAJIB antara {_DESC_MIN_CHARS}–{_DESC_MAX_CHARS} karakter (sekitar 3–5 kalimat)
   - Ceritakan KONTEKS utama: apa yang terjadi, siapa yang terlibat, dan kenapa ini penting
   - Sertakan satu fakta atau angka konkret dari berita jika ada (misal: persentase, nilai, nama tokoh)
   - Akhiri dengan kalimat yang bikin pembaca penasaran atau relevan sama kehidupan mereka
   - Gaya bahasa Gen Z Indonesia — santai tapi tetap informatif, bukan clickbait
   - JANGAN potong di tengah kalimat
   - JANGAN tulis hanya 1–2 kalimat pendek — ini harus cukup informatif buat dibaca di card

3. BODY — rangkuman editorial ~2000 karakter (tidak kurang dari 1500 karakter).
   - Bahasa natural Gen Z Indonesia, tidak kaku, tetapi tetap akurat
   - Tidak mengubah fakta — hanya mengubah gaya bahasa
   - Tidak menggunakan bullet point atau heading
   - Mengalir seperti paragraf editorial yang enak dibaca
   - Akhiri dengan kalimat penutup yang solid, JANGAN biarkan terpotong

FORMAT OUTPUT (ikuti PERSIS, tanpa teks tambahan di luar format):
JUDUL: <judul hasil tulisanmu>
DESKRIPSI:
<paragraf preview di sini, {_DESC_MIN_CHARS}–{_DESC_MAX_CHARS} karakter, diakhiri kalimat lengkap>
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
                max_output_tokens = 2560,
                safety_settings   = self.SAFETY_SETTINGS,
            ),
        )

        raw_output = response.text.strip()

        if raw_output.endswith("...") or raw_output.endswith(".."):
            raise ValueError("Output terpotong (diakhiri '...'). Kemungkinan token limit.")

        return self._parse_generated(raw_output)

    def _parse_generated(self, raw: str) -> tuple[str, str, str]:
        title       = ""
        description = ""
        body_lines: list[str] = []
        mode = None

        for line in raw.splitlines():
            stripped = line.strip()
            lower    = stripped.lower()

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

            elif mode == "description":
                if stripped:
                    description += (" " + stripped) if description else stripped
                elif len(description) >= _DESC_MIN_CHARS:
                    mode = None

            elif mode == "body":
                body_lines.append(line)

        body        = "\n".join(body_lines).strip()
        description = description.strip('"\'').strip()

        # Clamp panjang description — truncate di batas kalimat
        if len(description) > _DESC_MAX_CHARS:
            truncated   = description[:_DESC_MAX_CHARS]
            last_period = max(
                truncated.rfind(". "),
                truncated.rfind("! "),
                truncated.rfind("? "),
            )
            if last_period > _DESC_MIN_CHARS:
                description = truncated[:last_period + 1].strip()
            else:
                description = truncated.rstrip() + "…"

        # Fallback kalau parsing gagal atau terlalu pendek
        if not title:
            title = "Berita Terkini — EXXE News"

        if not description or len(description) < _DESC_MIN_CHARS // 2:
            sentences = [s.strip() for s in body.replace("\n", " ").split(".") if s.strip()]
            fallback  = ". ".join(sentences[:5])
            if fallback and not fallback.endswith("."):
                fallback += "."
            description = fallback if len(fallback) >= 50 else (body[:_DESC_MAX_CHARS] if body else "")
            if len(description) > _DESC_MAX_CHARS:
                description = description[:_DESC_MAX_CHARS].rstrip() + "…"

        if not body:
            body = raw

        return title, description, body

    # ──────────────────────────────────────────────────────────────────────────
    # INTERNAL: export file
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
                f.write(
                    f"Sentiment : {str(r.Sentiment).upper()}  "
                    f"(conf={r.Confidence:.2f}  score={r.Score:.2f})\n"
                )
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
        ai_api_key    = ai_api_key,
        news_api_key  = news_api_key,
        output_dir    = "daily_content",
        max_news      = 3,
        categories    = ["economy", "technology", "geopolitics"],
        language      = "en",
        save_to_mongo = True,   # set False kalau mau skip MongoDB saat testing
    )

    generator.run(export_json=True, export_txt=True)


if __name__ == "__main__":
    main()