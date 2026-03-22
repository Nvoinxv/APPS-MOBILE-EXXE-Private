from datetime import datetime, timezone

class stree_view_model:
    def __init__(self):
        self.id = None
        self.writer_name = None
        self.writer_role = None
        self.sampul_depan = None
        self.Date = datetime.now(timezone.utc)
        self.file = None
        self.Judul = None
        self.Deskripsi = None
        self.Image_1 = None
        self.Deskripsi_2 = None
        self.Image_2 = None
        self.Deskripsi_3 = None
        self.Image_3 = None
        self.Deskripsi_4 = None
        self.Image_4 = None
        self.AI_Summary = None
        self.Source = None
    
    def __str__(self):
        return (
            f"stree_view_model(id={self.id}, Judul={self.Judul}, "
            f"Writer={self.writer_name}, Date={self.Date.strftime('%Y-%m-%d') if self.Date else None})"
        )

    def to_dict(self):
        return {
            "_id": self.id,
            "writer_name": self.writer_name,
            "writer_role": self.writer_role,
            "sampul_depan": self.sampul_depan,
            "date": self.Date,
            "file": self.file,
            "judul": self.Judul,
            "deskripsi": self.Deskripsi,
            "image_1": self.Image_1,
            "deskripsi_2": self.Deskripsi_2,
            "image_2": self.Image_2,
            "deskripsi_3": self.Deskripsi_3,
            "image_3": self.Image_3,
            "deskripsi_4": self.Deskripsi_4,
            "image_4": self.Image_4,
            "ai_summary": self.AI_Summary,
            "source": self.Source
        }

    @classmethod
    def from_dict(cls, data: dict):
        if not data:
            return None
        
        # Bikin instance kosong dulu
        obj = cls()
        
        # Isi satu-satu dari dictionary data (MongoDB)
        obj.id = data.get("_id")
        obj.writer_name = data.get("writer_name")
        obj.writer_role = data.get("writer_role")
        obj.sampul_depan = data.get("sampul_depan")
        obj.Date = data.get("date")
        obj.file = data.get("file")
        obj.Judul = data.get("judul")
        obj.Deskripsi = data.get("deskripsi")
        obj.Image_1 = data.get("image_1")
        obj.Deskripsi_2 = data.get("deskripsi_2")
        obj.Image_2 = data.get("image_2")
        obj.Deskripsi_3 = data.get("deskripsi_3")
        obj.Image_3 = data.get("image_3")
        obj.Deskripsi_4 = data.get("deskripsi_4")
        obj.Image_4 = data.get("image_4")
        obj.AI_Summary = data.get("ai_summary")
        obj.Source = data.get("source")
        
        return obj