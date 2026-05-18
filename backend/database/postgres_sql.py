import psycopg2
import os
from dotenv import load_dotenv

load_dotenv() 

class Postgres_SQL:
    def __init__(self):
        self.connection = psycopg2.connect(
            host=os.getenv("HOST_LOCAL", "postgres"),
            port=int(os.getenv("PORT_LOCAL", 5432)),
            dbname=os.getenv("DATABASE_LOCAL"),
            user=os.getenv("USER_LOCAL"),
            password=os.getenv("PASSWORD_LOCAL"),
        )
        self.cursor = self.connection.cursor()

    def __iter__(self):
        # biar bisa: connection, cursor = MysqlConnection()
        return iter((self, self.cursor))

    def get_connection(self):
        return self.connection

    def close_connection(self):
        self.cursor.close()
        self.connection.close()

        