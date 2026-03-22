from datetime import datetime, timezone

class research_model:
    def __init__(self, id=None, judul=None, 
                 Deskripsi_1=None, Date=None, 
                 Images=None, sub_judul=None, Deskripsi_2=None,
                 Deskripsi_3=None, Video=None, Source=None):
        # Inisialisasi variabel (pake default datetime kalau Date kosong)
        self.id = id
        self.judul = judul
        self.deskripsi_1 = Deskripsi_1
        self.deskripsi_2 = Deskripsi_2
        self.deskripsi_3 = Deskripsi_3
        self.images = Images
        self.Date = Date if Date else datetime.now(timezone.utc)
        self.sub_judul = sub_judul
        self.video = Video
        self.source = Source

    def __str__(self):
        # Return string (bukan set), pake deskripsi_1 buat ringkasan
        return (
            f"Research_model(id={self.id}, Judul={self.judul}, "
            f"Date={self.Date.strftime('%Y-%m-%d') if self.Date else None}, "
            f"Source={self.source})"
        )
    
    def to_dict(self):
        # Export semua field ke dictionary buat disimpan di MongoDB
        return {
            "_id": self.id, # Mongo biasanya pake _id
            "judul": self.judul,
            "sub_judul": self.sub_judul,
            "deskripsi_1": self.deskripsi_1,
            "deskripsi_2": self.deskripsi_2,
            "deskripsi_3": self.deskripsi_3,
            "images": self.images,
            "date": self.Date,
            "video": self.video,
            "source": self.source
        }
    
    @classmethod
    def from_dict(cls, data: dict):
        # Buat balik jadi objek Python dari data MongoDB
        if not data:
            return None
            
        return cls(
            id=data.get("_id"),
            judul=data.get("judul"),
            sub_judul=data.get("sub_judul"),
            Deskripsi_1=data.get("deskripsi_1"),
            Deskripsi_2=data.get("deskripsi_2"),
            Deskripsi_3=data.get("deskripsi_3"),
            Images=data.get("images"),
            Date=data.get("date"),
            Video=data.get("video"),
            Source=data.get("source")
        )