class OTPVerifikasiModel:
    def __init__(self, id=None, email=None, otp_hash=None,
    salt=None, attempts=None, created_at=None):
        self.id = id
        self.email = email
        self.otp_hash = otp_hash
        self.salt = salt
        self.attempts = attempts
        self.created_at = created_at

    def __str__(self):
        return (
            f"OTPVerifikasiModel(id={self.id}, email={self.email}, otp_hash={self.otp_hash}, salt={self.salt}, attempts={self.attempts}, created_atr={self.created_at})"
        )

    def to_dict(self):
        return {
            "id": self.id,
            "email": self.email,
            "otp_hash": self.otp_hash,
            "salt": self.salt,
            "attempts": self.attempts,
            "created_at": self.created_at
        }

    def from_dict(cls, data:dict):
        return cls (
            id = data.get("id"),
            email = data.get("email"),
            otp_hash = data.get("otp_hash"),
            salt = data.get("salt"),
            attempts = data.get("attempts"),
            created_at = data.get("created_at")
        )