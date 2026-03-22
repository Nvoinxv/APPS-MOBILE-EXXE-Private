class Top_Trending_Model():
    def __init__(self, id = None, judul = None, 
                 deskripsi = None, date=None):
        self.id = id
        self.judul = judul
        self.deskripsi = deskripsi
        self.date = date
    
    def __str__(self):
        return (
            f"TopTrendingModel id={self.id}, judul={self.judul}, deskripsi={self.deskripsi}, date={self.date}"
        )
    
    def to_dict(self):
        return {
            "id": self.id,
            "judul": self.judul,
            "deskripsi": self.deskripsi,
            "Date": self.date
        }
    
    def from_dict(cls, data:dict):
        return cls (
            id = data.get("id"),
            judul = data.get("judul"),
            deskripsi = data.get("deskripsi"),
            Date = data.get("Date")
        )