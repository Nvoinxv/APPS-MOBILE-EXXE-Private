from datetime import timedelta, timezone, datetime

class News_Model:
    def __init__(self):
        self.id = None
        self.Title = None
        self.Date = datetime.now(timezone.utc)
        self.Images = None
        self.Description = None
        self.Source = None
        self.Images_news = None
        self.Images_news_2 = None
        self.Images_link = None
        
    def __str__(self):
        return (
            f"News_Model(id={self.id}, Title={self.Title}, Images={self.Images}, "
            f"Date = {self.Date}"
            f"Description={self.Description}, Source={self.Source}, "
            f"Images_news={self.Images_news}, Images_news_2={self.Images_news_2}, "
            f"Images_link={self.Images_link})"
        )

    def to_dict(self):
        return {
            "_id": self.id,
            "Title": self.Title,
            "Date": self.Date,
            "Image": self.Image,
            "Description": self.Description,
            "Source": self.Source,
            "Images_news": self.Images_news,
            "Images_news_2": self.Images_news_2,
            "Images_link": self.Images_link
        }
    
    @classmethod
    def from_dict(cls, data: dict):
        return cls(
            id = data.get("_id"),
            Title = data.get("Title"),
            Content = data.get("Content"),
            Image = data.get("Image"),
            Description = data.get("Description"),
            Source = data.get("Source"),
            Images_news = data.get("Images_news"),
            Images_news_2 = data.get("Images_news_2"),
            Images_link = data.get("Images_link")
        )
