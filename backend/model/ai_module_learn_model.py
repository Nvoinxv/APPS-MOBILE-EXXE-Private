class AI_Machine_Learning_Model:
    """
    Tugas model ini adalah lebih 
    membuat struktur data biar siap di masukin
    ke database. Kalau tanpa ini
    yang ada data nya berantakan dan si mongo bakal bingung
    """
    def __init__(self, id=None, judul=None, Tumbnail=None,
                 Sub_Bab_1=None, Link_Video_1=None,
                 Sub_Bab_2=None, Link_Video_2=None,
                 Sub_Bab_3=None, Link_Video_3=None,
                 Sub_Bab_4=None, Link_Video_4=None,
                 Sub_Bab_5=None, Link_Video_5=None):
        # Inisialisasi variabel
        self.id = id
        self.judul = judul
        self.Tumbnail = Tumbnail
        self.Sub_Bab_1 = Sub_Bab_1
        self.Link_Video_1 = Link_Video_1
        self.Sub_Bab_2 = Sub_Bab_2
        self.Link_Video_2 = Link_Video_2
        self.Sub_Bab_3 = Sub_Bab_3
        self.Link_Video_3 = Link_Video_3
        self.Sub_Bab_4 = Sub_Bab_4
        self.Link_Video_4 = Link_Video_4
        self.Sub_Bab_5 = Sub_Bab_5
        self.Link_Video_5 = Link_Video_5

    def __str__(self):
        # Menampilkan ringkasan objek saat di-print
        return (
            f"AI_Machine_Learning_Model(id={self.id}, Judul='{self.judul}', "
            f"Bab_Utama='{self.Sub_Bab_1 if self.Sub_Bab_1 else 'Empty'}')"
        )

    def to_dict(self):
        # Konversi objek ke dictionary (format untuk simpan di database/JSON)
        return {
            "_id": self.id,  # Mengikuti standar MongoDB
            "judul": self.judul,
            "tumbnail": self.Tumbnail,
            "sub_bab_1": self.Sub_Bab_1,
            "link_video_1": self.Link_Video_1,
            "sub_bab_2": self.Sub_Bab_2,
            "link_video_2": self.Link_Video_2,
            "sub_bab_3": self.Sub_Bab_3,
            "link_video_3": self.Link_Video_3,
            "sub_bab_4": self.Sub_Bab_4,
            "link_video_4": self.Link_Video_4,
            "sub_bab_5": self.Sub_Bab_5,
            "link_video_5": self.Link_Video_5
        }

    @classmethod
    def from_dict(cls, data: dict):
        # Mengubah data dictionary (dari DB) balik jadi objek Python
        if not data:
            return None

        return cls(
            id=data.get("_id"),
            judul=data.get("judul"),
            Tumbnail=data.get("tumbnail"),
            Sub_Bab_1=data.get("sub_bab_1"),
            Link_Video_1=data.get("link_video_1"),
            Sub_Bab_2=data.get("sub_bab_2"),
            Link_Video_2=data.get("link_video_2"),
            Sub_Bab_3=data.get("sub_bab_3"),
            Link_Video_3=data.get("link_video_3"),
            Sub_Bab_4=data.get("sub_bab_4"),
            Link_Video_4=data.get("link_video_4"),
            Sub_Bab_5=data.get("sub_bab_5"),
            Link_Video_5=data.get("link_video_5")
        )