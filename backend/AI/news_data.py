"""
news_data.py
------------
Fetch berita dari NewsData.io API dan sediakan class NewsUpdater
yang kompatibel dengan AI_Generate_Text.py.

API endpoint: https://newsdata.io/api/1/news
Docs        : https://newsdata.io/documentation

Dependensi:
    pip install requests python-dotenv
"""

import os
import json
import random
import requests
from datetime import datetime
from dataclasses import dataclass, asdict
from typing import Optional


# ---------------------------------------------------------------------------
# Dataclass artikel — dipakai oleh AI_Generate_Text.py
# ---------------------------------------------------------------------------

@dataclass
class NewsArticle:
    """
    Satu artikel berita dari NewsData.io.

    Fields yang wajib ada (dipakai AI_Generate_Text.py):
        title     : judul artikel
        link      : URL artikel asli
        source    : nama media (source_id dari API)
        domain    : kategori (economy / technology / geopolitics)
        published : tanggal publikasi
        summary   : isi / deskripsi artikel
    """
    title:     str
    link:      str
    source:    str
    domain:    str
    published: str
    summary:   str

    def to_dict(self) -> dict:
        return asdict(self)


# ---------------------------------------------------------------------------
# Mapping kategori → query NewsData.io
# ---------------------------------------------------------------------------

# NewsData.io pakai parameter `category` — mapping ke kategori yang didukung:
# business, entertainment, environment, food, health, politics,
# science, sports, technology, top, tourism, world
CATEGORY_MAP = {
    "economy"      : "business",
    "technology"   : "technology",
    "geopolitics"  : "politics",
    "business"     : "business",
    "politics"     : "politics",
    "science"      : "science",
    "health"       : "health",
    "sports"       : "sports",
    "entertainment": "entertainment",
    "world"        : "world",
    "top"          : "top",
}


# ---------------------------------------------------------------------------
# NewsUpdater
# ---------------------------------------------------------------------------

class NewsUpdater:
    """
    Fetch berita dari NewsData.io dan return list[NewsArticle].

    Kompatibel penuh dengan AI_Generate_Text.py:
        updater = NewsUpdater(api_key=..., output_dir=..., max_news=3, ...)
        articles = updater.run(categories=[...], export_formats=[])

    Parameters
    ----------
    api_key    : str        — NewsData.io API key (dari env API_NEWS / api_key_news)
    output_dir : str        — direktori output untuk export file, default "news_output"
    max_news   : int        — jumlah maksimal artikel per run, default 3
    language   : str        — kode bahasa berita, default "en"
    randomize  : bool       — jika True, hasil di-shuffle sebelum dipotong max_news
    """

    BASE_URL = "https://newsdata.io/api/1/news"

    def __init__(
        self,
        api_key:    str,
        output_dir: str  = "news_output",
        max_news:   int  = 3,
        language:   str  = "en",
        randomize:  bool = False,
    ):
        if not api_key:
            raise ValueError("NewsData.io API key tidak boleh kosong.")

        self.api_key    = api_key
        self.output_dir = output_dir
        self.max_news   = max_news
        self.language   = language
        self.randomize  = randomize

        os.makedirs(self.output_dir, exist_ok=True)

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def run(
        self,
        categories:     list[str] | None = None,
        export_formats: list[str]        = [],
    ) -> list[NewsArticle]:
        """
        Fetch berita untuk semua kategori yang diminta.

        Parameters
        ----------
        categories     : list kategori (misal ["economy", "technology"])
                         default: ["economy", "technology", "geopolitics"]
        export_formats : list format export ("json", "txt")
                         jika kosong [], tidak ada file yang disimpan

        Returns
        -------
        list[NewsArticle] — maks max_news artikel, sudah di-deduplikasi
        """
        if categories is None:
            categories = ["economy", "technology", "geopolitics"]

        print(f"[NewsUpdater] Fetch kategori: {categories} | lang={self.language}")

        all_articles: list[NewsArticle] = []
        seen_links: set[str] = set()

        for cat in categories:
            api_cat = CATEGORY_MAP.get(cat.lower(), cat.lower())
            fetched = self._fetch_category(api_cat, cat)

            for article in fetched:
                if article.link not in seen_links:
                    seen_links.add(article.link)
                    all_articles.append(article)

        if self.randomize:
            random.shuffle(all_articles)

        # Potong sesuai max_news
        result = all_articles[: self.max_news]

        print(f"[NewsUpdater] ✓ {len(result)} artikel siap (dari {len(all_articles)} total unik)")

        # Export jika diminta
        if "json" in export_formats:
            self._export_json(result)
        if "txt" in export_formats:
            self._export_txt(result)

        return result

    # ------------------------------------------------------------------
    # Internal: fetch per kategori
    # ------------------------------------------------------------------

    def _fetch_category(self, api_category: str, original_category: str) -> list[NewsArticle]:
        """Fetch berita untuk satu kategori dari NewsData.io."""
        params = {
            "apikey"  : self.api_key,
            "category": api_category,
            "language": self.language,
        }

        try:
            response = requests.get(self.BASE_URL, params=params, timeout=15)
            response.raise_for_status()
            data = response.json()
        except requests.exceptions.RequestException as e:
            print(f"  [ERROR] Gagal fetch kategori '{api_category}': {e}")
            return []
        except json.JSONDecodeError:
            print(f"  [ERROR] Response bukan JSON valid untuk kategori '{api_category}'")
            return []

        if data.get("status") != "success":
            msg = data.get("message", "unknown error")
            print(f"  [WARN] API error untuk '{api_category}': {msg}")
            return []

        articles = []
        for item in data.get("results", []):
            article = self._parse_item(item, original_category)
            if article:
                articles.append(article)

        print(f"  → '{original_category}' ({api_category}): {len(articles)} artikel")
        return articles

    def _parse_item(self, item: dict, domain: str) -> Optional[NewsArticle]:
        """Parse satu item dari API response → NewsArticle. Return None jika data tidak lengkap."""
        title = (item.get("title") or "").strip()
        link  = (item.get("link")  or "").strip()

        # Skip jika tidak ada judul atau link
        if not title or not link:
            return None

        # Summary: coba ambil dari description, fallback ke content, lalu judul
        summary = (
            item.get("description") or
            item.get("content")     or
            title
        ).strip()

        source    = item.get("source_id") or item.get("source_name") or "unknown"
        published = item.get("pubDate") or datetime.now().strftime("%Y-%m-%d %H:%M:%S")

        return NewsArticle(
            title     = title,
            link      = link,
            source    = source,
            domain    = domain,
            published = published,
            summary   = summary,
        )

    # ------------------------------------------------------------------
    # Internal: export
    # ------------------------------------------------------------------

    def _export_json(self, articles: list[NewsArticle]) -> str:
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"news_raw_{ts}.json"
        filepath = os.path.join(self.output_dir, filename)

        payload = {
            "fetched_at": datetime.now().isoformat(),
            "total"     : len(articles),
            "articles"  : [a.to_dict() for a in articles],
        }
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(payload, f, ensure_ascii=False, indent=2)

        print(f"[NewsUpdater] JSON saved → {filepath}")
        return filepath

    def _export_txt(self, articles: list[NewsArticle]) -> str:
        ts       = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"news_raw_{ts}.txt"
        filepath = os.path.join(self.output_dir, filename)

        with open(filepath, "w", encoding="utf-8") as f:
            f.write(f"News Fetch — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
            f.write(f"Total: {len(articles)}\n")
            f.write("=" * 60 + "\n\n")

            for i, a in enumerate(articles, 1):
                f.write(f"[{i}] {a.title}\n")
                f.write(f"{'─' * 60}\n")
                f.write(f"Sumber   : {a.source}\n")
                f.write(f"Kategori : {a.domain}\n")
                f.write(f"Tanggal  : {a.published}\n")
                f.write(f"Link     : {a.link}\n\n")
                f.write(f"{a.summary}\n\n")
                f.write("=" * 60 + "\n\n")

        print(f"[NewsUpdater] TXT saved  → {filepath}")
        return filepath


# ---------------------------------------------------------------------------
# CLI — test mandiri
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    from dotenv import load_dotenv

    # Coba load .env dari folder ini atau parent
    for env_path in [".env", "../.env"]:
        if os.path.exists(env_path):
            load_dotenv(env_path)
            break

    api_key = (
        os.getenv("api_key_news") or
        os.getenv("API_NEWS")     or
        os.getenv("NEWS_API_KEY")
    )

    if not api_key:
        raise EnvironmentError("API key tidak ditemukan! Set API_NEWS di .env")

    updater  = NewsUpdater(api_key=api_key, max_news=3, randomize=True)
    articles = updater.run(
        categories     = ["economy", "technology", "geopolitics"],
        export_formats = ["json", "txt"],
    )

    print(f"\n{'=' * 60}")
    print(f"  HASIL FETCH: {len(articles)} artikel")
    print(f"{'=' * 60}")
    for i, a in enumerate(articles, 1):
        print(f"\n[{i}] {a.title}")
        print(f"    Sumber : {a.source} | {a.domain} | {a.published}")
        print(f"    Link   : {a.link}")
        print(f"    Summary: {a.summary[:120]}...")