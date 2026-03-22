from datetime import datetime, timezone

class MarketOutLookModel:
    def __init__(self, Judul=None, Date=None,
                 Isi_1=None, Images_1=None, Images_2=None,
                 Isi_2=None, Isi_3=None, Images_3=None,
                 Video=None, Video_Drive=None, Source=None, id=None):
        
        # Gunakan datetime sekarang jika Date tidak diisi
        self.id = id
        self.judul = Judul
        self.date = Date if Date else datetime.now(timezone.utc)
        self.isi_1 = Isi_1
        self.isi_2 = Isi_2
        self.isi_3 = Isi_3
        self.Images_1 = Images_1
        self.Images_2 = Images_2
        self.Images_3 = Images_3
        self.video = Video
        self.video_drive = Video_Drive
        self.source = Source

    def __str__(self):
        return (
            f"MarketOutLookModel(id={self.id}, judul={self.judul}, date={self.date}, "
            f"video={self.video}, source={self.source})"
        )

    def to_dict(self):
        return {
            "_id": self.id,
            "Judul": self.judul,
            "Date": self.date,
            "Isi_1": self.isi_1,
            "Isi_2": self.isi_2,
            "Isi_3": self.isi_3,
            "Images_1": self.Images_1,
            "Images_2": self.Images_2,
            "Images_3": self.Images_3,
            "Video": self.video,
            "Video_Drive": self.video_drive,
            "Source": self.source
        }

    @classmethod
    def from_dict(cls, data: dict):
        if not data:
            return None
        return cls(
            id=data.get("_id"),
            Judul=data.get("Judul"),
            Date=data.get("Date"),
            Isi_1=data.get("Isi_1"),
            Isi_2=data.get("Isi_2"),
            Isi_3=data.get("Isi_3"),
            Images_1=data.get("Images_1"),
            Images_2=data.get("Images_2"),
            Images_3=data.get("Images_3"),
            Video=data.get("Video"),
            Video_Drive=data.get("Video_Drive"),
            Source=data.get("Source")
        )