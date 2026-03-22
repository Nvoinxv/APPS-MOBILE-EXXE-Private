class ResearchCoinModel:
    def __init__(self, Document_Name=None, File=None, Image=None, Logo_Coin=None):
        self.Document_name = Document_Name
        self.File = File
        self.images = Image
        self.Logo_coin = Logo_Coin

    def __str__(self):
        return (
            f"ResearchCoinModel(Document_name={self.Document_name}, "
            f"File={self.File}, images={self.images}, Logo_coin={self.Logo_coin})"
        )

    def to_dict(self):
        return {
            "Document_Name": self.Document_name,
            "File": self.File,
            "Image": self.images,
            "Logo_Coin": self.Logo_coin
        }

    @classmethod
    def from_dict(cls, data: dict):
        if not data:
            return None
        return cls(
            Document_Name=data.get("Document_Name"),
            File=data.get("File"),
            Image=data.get("Image"),
            Logo_Coin=data.get("Logo_Coin")
        )