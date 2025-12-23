from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline
from sklearn.model_selection import train_test_split, cross_val_score, cross_val_predict
from sklearn.metrics import classification_report, confusion_matrix, accuracy_score
import pandas as pd
import joblib
import numpy as np

class AnalisisSentiment:
    """
    Disini gw buat pelatihan machine learning
    Untuk menganalisa sentiment.
    Jadi si machine learning ini fokus analisa
    mana yang negatif, netral, atau positif 
    dari data berita yang gw berikan.
    Kalau sumber pelatihan nya gw ambil dari 
    judul nya karna pas deploy lebih ringan gak 
    makan resource gede.
    """
    def __init__(self, X, y, model=None):
        self.X = X
        self.y = y
        self.vectorizer = TfidfVectorizer(
            max_features=10000,      # batasi fitur biar noise berkurang
            ngram_range=(1,2),       # pake unigram + bigram
            stop_words='english',    # hapus stopwords langsung
            min_df=5,                # abaikan kata yang jarang muncul
            max_df=0.8               # abaikan kata yang terlalu sering
        )
        self.model = model if model else LogisticRegression()
        self.pipeline = Pipeline(
            [
                ("Vectorizer", self.vectorizer),
                ("Model", self.model)
            ]
        )

    def train(self, test_size=0.2):
        self.X_train, self.X_test, self.y_train, self.y_test = train_test_split(
            self.X, self.y, test_size=test_size, random_state=42
        )
        self.pipeline.fit(self.X_train, self.y_train)
        print("Training selesai!")

    def predict(self, text):
        # Cek apakah inputnya string tunggal
        data = [text] if isinstance(text, str) else text
        return self.pipeline.predict(data)

    def cross_val(self):
        return cross_val_score(self.pipeline, self.X_train, self.y_train, cv=5)

    def cross_val_predict(self):
        return cross_val_predict(self.pipeline, self.X_train, self.y_train, cv=5)
    
    # Bagian validasi atau hasil akurasi nya
    # jika di atas 0.7 itu maka hasil nya lumayan akurat
    # Gw ekspektasi di atas 0.8 biar hasil nya lumayan bagus
    # Tetapi jg jangan sampai overfitting nanti hasil ny buruk
    def classification_report_metrics(self):
        return classification_report(self.y_test, self.predict(self.X_test))

    def confusion_matrix_metrics(self):
        return confusion_matrix(self.y_test, self.predict(self.X_test))

    def accuracy_score_metrics(self):
        return accuracy_score(self.y_test, self.predict(self.X_test))

    def save_model(self):
        joblib.dump(self.pipeline, "model_sentiment_general.joblib")

if __name__ == "__main__":
    print("=== Memulai Pelatihan Model AI ===")
    file_path = r"D:\APPS_EXXE\backend\AI\data\news_sentiment_analysis.csv"
    df = pd.read_csv(file_path)
    # Kita gabungin kolom nya jadi satu fitur text karena TfidfVectorizer butuh input 1 dimensi
    # Dan kita handle missing values biar gak error pas concat
    x = df["Title"].fillna("") + " " + df["Description"].fillna("") 
    y = df["Sentiment"]
    model = AnalisisSentiment(x, y)
    model.train()
    
    print("=== Melakukan Validasi Model AI ===")
    print("Hasil dari cross validation: ")
    print(model.cross_val())

    print("Hasil dari cross validation predict: ")
    print(model.cross_val_predict())

    print("=== Melakukan Evaluasi Model AI ===")
    print("Hasil dari classification report: ")
    print(model.classification_report_metrics())

    print("Hasil dari confusion metrics: ")
    print(model.confusion_matrix_metrics())
    
    print("Hasil dari accuracy score: ")
    print(model.accuracy_score_metrics())

    print("=== Menyimpan Model AI ===")
    model.save_model()
    print("Model AI berhasil di simpan!")

    print("=== Pelatihan AI Selesai ===")