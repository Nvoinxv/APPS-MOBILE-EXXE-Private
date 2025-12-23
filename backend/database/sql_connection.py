import psycopg2
import os
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path)

class MysqlConnection:
    """
    Kelas ini di gunakan untuk
    menghubungkan ke database
    terutama sql dan disini gw pakai
    sql postgresql.
    """
    def __init__(self):
        self.connection = psycopg2.connect(
            host = os.getenv("HOST"),
            database = os.getenv("DATABASE"),
            user = os.getenv("USER"),
            password = os.getenv("PASSWORD")
        )

    def get_connection(self):
        return self.connection
    
    def close_connection(self):
        self.connection.close()

    def execute_quer(self, query):
        cursor = self.connection.cursor()
        cursor.execute(query)
        self.connection.commit()
        cursor.close()


        