import pymongo
import os
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path)

class MongoConnection:
    def __init__(self):
        self.client = pymongo.MongoClient(os.getenv("URL_MONGO"))
        self.db = self.client[os.getenv("DATABASE_MONGO")]
        self.collection_news_exclusive = self.db("news_exclusive")
        self.collection_news_general = self.db("news_general")
        
    
    def close(self):
        self.client.close()
