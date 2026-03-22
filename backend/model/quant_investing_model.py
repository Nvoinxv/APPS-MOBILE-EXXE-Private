class QuantInvestingModel:
    def __init__(self, Judul_Pair = None, Name = None,
                 Images_sampul = None, Images_Chart = None,
                 Link_Trading_View = None, Judul_1 = None,
                 Judul_2 = None, Deskripsi_1 = None,
                 Deskripsi_2 = None, Judul_3 = None, Judul_4 = None,
                 Deskripsi_3 = None, Deksripis_4 = None):
        self.Judul_pair = Judul_Pair
        self.Judul_1 = Judul_1
        self.Judul_2 = Judul_2
        self.Judul_3 = Judul_3
        self.Judul_4 = Judul_4
        self.images_sampul = Images_sampul
        self.images_chart = Images_Chart
        self.Name = Name
        self.Deskripsi_1 = Deskripsi_1
        self.Deskripsi_2 = Deskripsi_2
        self.Deskripsi_3 = Deskripsi_3
        self.Deskripsi_4 = Deksripis_4
        self.Link_Trading_View = Link_Trading_View

    def __str__(self):
        return (
            f"QuantInvestingModel("
            f"Judul_pair={self.Judul_pair}, Name={self.Name}, "
            f"Judul_1={self.Judul_1}, Judul_2={self.Judul_2}, "
            f"Judul_3={self.Judul_3}, Judul_4={self.Judul_4}, "
            f"Images_sampul={self.images_sampul}, Images_chart={self.images_chart}, "
            f"Deskripsi_1={self.Deskripsi_1}, Deskripsi_2={self.Deskripsi_2}, "
            f"Deskripsi_3={self.Deskripsi_3}, Deskripsi_4={self.Deskripsi_4}, "
            f"Link_TV={self.Link_Trading_View})"
        )
    
    def to_dict(self):
        return {
            "_id": self.id,
            "Judul_pair": self.Judul_pair,
            "Judul_1": self.Judul_1,
            "Judul_2": self.Judul_2,
            "Judul_3": self.Judul_3,
            "Judul_4": self.Judul_4,
            "Images_sampul": self.images_sampul,
            "Images_chart": self.images_chart,
            "Name": self.Name,
            "Deskripsi_1": self.Deskripsi_1,
            "Deskripsi_2": self.Deskripsi_2,
            "Deskripsi_3": self.Deskripsi_3,
            "Deskripsi_4": self.Deskripsi_4,
            "Link_Trading_View": self.Link_Trading_View
        }
    
    @classmethod
    def from_dict(cls, data:dict):
        if not data:
            return None
        
        return cls(
            Judul_Pair        = data.get("Judul_pair"),
            Name              = data.get("Name"),
            Images_sampul     = data.get("Images_sampul"),
            Images_Chart      = data.get("Images_chart"),
            Link_Trading_View = data.get("Link_Trading_View"),
            Judul_1           = data.get("Judul_1"),
            Judul_2           = data.get("Judul_2"),
            Judul_3           = data.get("Judul_3"),
            Judul_4           = data.get("Judul_4"),
            Deskripsi_1       = data.get("Deskripsi_1"),
            Deskripsi_2       = data.get("Deskripsi_2"),
            Deskripsi_3       = data.get("Deskripsi_3"),
            Deksripis_4       = data.get("Deskripsi_4") 
        )
    
