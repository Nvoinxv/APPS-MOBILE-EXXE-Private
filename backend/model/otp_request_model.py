class OTPRequestModel:
    def __init__(self, id=None, email=None, created_at=None):
        self.id = id
        self.email = email
        self.created_at = created_at

    def __str__(self):
        return (
            f"OTPRequestModel id={self.id}, email={self.email}, created_at={self.created_at}"
        )

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "created_at": self.created_at
        }

    def from_dict(cls, data:dict):
        return cls (
            id = data.get("id"),
            email = data.get("email"),
            created_at = data.get("created_at")
        )