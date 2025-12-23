import os
from google import genai 
from google.genai import types
from dotenv import load_dotenv

path_env = os.path.join(os.path.dirname(os.path.dirname(__file__)), ".env")
load_dotenv(dotenv_path=path_env)

ai_api_key = os.getenv("api_key_news")

if ai_api_key is None:
    raise ValueError("API key tidak di temukan!")

client = genai.Client(api_key=ai_api_key)

print("--- Daftar Model Gemini yang Tersedia ---")
# Mengambil daftar model
for model in client.models.list():
    # Kita filter hanya model yang bisa 'generateContent' (untuk chat/text)
    if 'generateContent' in model.supported_actions:
        print(f"Nama Model: {model.name}")
        print(f"Versi: {model.version}")
        print(f"Deskripsi: {model.description}")
        print("-" * 30)

class AnalisisSentiment:
    def __init__(self, api_key):
        # In the new SDK, we initialize a Client
        self.client = genai.Client(api_key=api_key)
        # Note: Check your model name. 
        self.model_id = "gemini-2.5-flash-lite" 
        
    def analisis_sentiment(self, text):
        prompt = f"""Analisis sentiment berita ini dan berikan HANYA satu kata jawaban.

Berita:
{text}

ATURAN KETAT:
1. Baca judul dan deskripsi berita dengan teliti
2. Jawab HANYA dengan satu kata: positif, negatif, atau netral
3. DILARANG memberikan penjelasan, alasan, atau teks tambahan apapun
4. DILARANG menggunakan tanda baca, emoji, atau formatting
5. Output WAJIB lowercase
6. Contoh output yang benar: positif

Jawaban:"""

        # Using the new client.models.generate_content syntax
        response = self.client.models.generate_content(
            model=self.model_id,
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.1,
                top_p=0.8,
                top_k=20,
                max_output_tokens=10,
            ),
        )
        
        sentiment = response.text.strip().lower()
        
        valid_labels = ["positif", "negatif", "netral"]
        if sentiment not in valid_labels:
            for label in valid_labels:
                if label in sentiment:
                    return label
            return "netral"
        
        return sentiment

if __name__ == "__main__":
    analyzer = AnalisisSentiment(ai_api_key)
    
    berita_test = """
    Judul: Ekonomi Indonesia Tumbuh 5.2% di Kuartal III
    Deskripsi: Pertumbuhan ekonomi Indonesia mencatat rekor tertinggi dalam 3 tahun terakhir.
    """
    
    hasil = analyzer.analisis_sentiment(berita_test)
    print(f"Sentiment: {hasil}")