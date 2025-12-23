class News_Model:
    def __init__(self):
        self.id = None
        self.Title = None
        self.Content = None
        self.Image = None
        self.Author = None
        self.Date = None
        self.Description = None
        
    def __str__(self):
        return {
            f"News_Model(id={self.id}, Title={self.Title}, Content={self.Content}, Image={self.Image}, Author={self.Author}, Date={self.Date}, Description={self.Description})"
        }

    def to_dict(self):
        return {
            "id": self.id,
            "Title": self.Title,
            "Content": self.Content,
            "Image": self.Image,
            "Author": self.Author,
            "Date": self.Date,
            "Description": self.Description
        }

    def from_dict(cls, data: dict):
        return cls(
            id = data.get("id"),
            Title = data.get("Title"),
            Content = data.get("Content"),
            Image = data.get("Image"),
            Author = data.get("Author"),
            Date = data.get("Date"),
            Description = data.get("Description")
        )
