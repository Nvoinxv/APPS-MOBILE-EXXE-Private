import os
from google import genai
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(__file__), ".env")
load_dotenv(dotenv_path=path_env)

if path_env is None:
    raise ValueError("Path env tidak di temukan!")

api_key = os.getenv("api_key_news")

class AIGenerateTextNews:
    def __init__(self, api_key, output_dir="daily_content", db_uri=None, db_name="arxiv_db"):
        self.api_key = api_key
        genai.configure(api_key=self.api_key)
        self.model = genai.GenerativeModel("gemini-2.5-flash")
        self.output_dir = output_dir
        
        # Buat folder output jika belum ada
        if not os.path.exists(self.output_dir):
            os.makedirs(self.output_dir)
            print(f"[INIT] Folder '{self.output_dir}' dibuat untuk menyimpan konten harian.")

        self.db_url = db_uri
        self.db_name = db_name
        self.safety_settings = [
            {
                "category": genai.types.HarmCategory.HARM_CATEGORY_HARASSMENT, 
                "threshold": genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
            },
            {
                "category": genai.types.HarmCategory.HARM_CATEGORY_HATE_SPEECH, 
                "threshold": genai.types.HarmBlockThreshold.BLOCK_MEDIUM_AND_ABOVE
            },
        ]

        def generate_content_AI(self, text):
            prompt = f"""
            Kau buat konten berita yang sudah kita kasih ke kau {text},
            Lalu kamu buat ulang dengan bahasa mu sendiri tetapi bahasa nya natural kek Gen Z.
            Tetapi masih relevant dengan berita yang ku berikan jadi cuma di modifikasi saja Bahasa nya.
            Dan kamu memberikan berita Sekitar terutama deskripsi itu 2000 karakter.
            Itu semua berlaku di judul dan deskripsi nya dan owner nya itu EXXE News.
            Jangan sampai ada yang tidak sesuai dengan aturan ini!
            """
            
            try:

                response = self.model.generate_content(prompt,
                    safety_settings=self.safety_settings,
                    max_output_tokens=2000,
                    temperature=0.7
                )

                content_text = response_text.text.strip()
                
                # Validasi apakah AI nya ini penjelasan nya full
                # Nanti di validasi dari kelengkapan
                # Dan juga bagian ... (mksd nya kek kurang lengkap atau kepotong)
                if "Action Steps" not in content_text:
                    print("⚠️ WARNING: Response tidak mengandung Action Steps! Retry...")
                    raise ValueError("Incomplete response - missing Action Steps")
            
                
                if content_text.endswith("...") or content_text.endswith(".."):
                    print("⚠️ WARNING: Response terpotong! Retry...")
                    raise ValueError("Incomplete response - truncated output")
        
                return content_text

            except Exception as e:
                print(f"Error: {str(e)}")
                return None

    def run_once(self):
        print("\n=== Eksekusi Sekali (Run Once) ===\n")
        self._generate_content()

    def daily_job(self):
        """Job harian yang dijalankan oleh scheduler"""
        print(f"\n=== Daily Job Running @ {datetime.now()} ===\n")
        self._generate_content()

    def _generate_content(self):
        """Fungsi utama generate konten (LLM summarization only)"""
        print("🔄 Updating news from RSS feeds...")
        self.news_update.update_news()

        # Ambil semua berita dari database
        all_news = list(self.news_update.collection.find())
    
        if not all_news:
            print("⚠️ Tidak ada berita ditemukan di database.")
            return

        # Pilih berita secara acak sebanyak self.max_news
        news_in_db = random.sample(all_news, min(self.max_news, len(all_news)))

        print(f"\n📋 Found {len(news_in_db)} news articles to process\n")

        for i, news in enumerate(news_in_db, 1):
            print(f"\n{'='*70}")
            print(f"🔹 Processing News #{i}/{len(news_in_db)}")
            print(f"{'='*70}")
        
            # Ambil data berita
            news_title = news.get("title", "Untitled News")
            news_link = news.get("link", "No link available")
            news_published = news.get("published", "Unknown date")
        
            # Ambil konten lengkap untuk summarization
            full_text = news.get("full_article") or news.get("summary")
        
            if full_text:
                print(f"📅 Published: {news_published}")
                print(f"\n🤖 Generating AI summary...\n")
            
                try:
                    # Generate ringkasan
                    summary_text = self.generate_summary(full_text)
                
                    # Format output Discord-ready
                    discord_message = f"""
                    {summary_text}
                    """
                
                    print(f"\n{'='*70}")
                    print("✅ HASIL RINGKASAN (Discord Format)")
                    print(f"{'='*70}")
                    print(discord_message)
                
                    # Optional: simpan ke file untuk backup
                    self._save_to_file(discord_message, i)
                
                except Exception as e:
                    print(f"❌ Error generating summary: {e}")
            else:
                print(f"⚠️ Berita '{news_title}' tidak punya konten lengkap untuk diproses.")
    
        print(f"\n{'='*70}")
        print("✅ SEMUA BERITA SELESAI DIPROSES")
        print(f"{'='*70}\n")


    def _save_to_file(self, content, index):
        """Simpan output ke file sebagai backup"""
        os.makedirs(self.output_dir, exist_ok=True)
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        filename = f"news_summary_{index}_{timestamp}.txt"
        filepath = os.path.join(self.output_dir, filename)
        
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(content)
        
        print(f"💾 Saved to: {filepath}")

    def run_scheduler(self):
        """Jalankan scheduler harian jam 09:00 WIB"""
        print("\n" + "="*70)
        print("⏰ SCHEDULER AKTIF")
        print("="*70)
        print("📅 Schedule: Setiap hari jam 09:00 WIB")
        print("🔄 Waiting for next execution...")
        print("="*70 + "\n")
        
        schedule.every().day.at("09:00").do(self.daily_job)

        while True:
            schedule.run_pending()
            time.sleep(1)
            

