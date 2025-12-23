class UserRole:
    """
    Role user biar bisa di pisahkan.
    Kalau general ini hanya umum saja versi gratisan.
    Kalau exclusive ini berbayar jadi bisa akses gratisan dan versi paid.
    Kalau admin itu bisa semua nya. Jadi upload news bisa bebas itu dia.
    """
    ADMIN = "admin"
    EXCLUSIVE = "exclusive"
    GENERAL = "general"

class UserModel:
    """
    Disini gw buat algo biar komputer,
    bisa tau bentuk data user yang gw inginkan seperti apa!
    sebelum gw buat untuk bagian autentikasi,
    di controller folder.
    """
    def __init__(self, id=None, name=None, email=None, password=None, role=None):
        self.id = id
        self.name = name
        self.email = email
        self.password = password
        self.role = role

    def __str__(self):
        return (
            f"UserModel(id={self.id}, name={self.name}, "
            f"email={self.email}, role={self.role})"
        )

    def to_dict(self):
        return {
            "id": self.id,
            "name": self.name,
            "email": self.email,
            "password": self.password,
            "role": self.role
        }

    @classmethod
    def from_dict(cls, data: dict):
        return cls(
            id=data.get("id"),
            name=data.get("name"),
            email=data.get("email"),
            password=data.get("password"),
            role=data.get("role")
        )
