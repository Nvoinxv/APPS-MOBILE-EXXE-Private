import pymongo
import os
from dotenv import load_dotenv

dotenv_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=dotenv_path)

ENV = os.getenv("APP_ENV", "local")

if ENV == "production":
    MONGO_URI = os.getenv("MONGO_URL")
    DB_NAME = os.getenv("DATABASE_MONGO")
else:
    MONGO_URI = os.getenv("URL_MONGO_LOCAL")
    DB_NAME = os.getenv("DATABASE_LOCAL_MONGO")

if not MONGO_URI:
    raise RuntimeError("Mongo URI is not set!")

# 🔒 SINGLETON MongoClient
client = pymongo.MongoClient(MONGO_URI)
db = client[DB_NAME]

class MongoConnection:
    def __init__(self):
        self.client = client
        self.db = db

        # Collections
        self.collection_news_exclusive = self.db["news_exclusive"]
        self.collection_news_general = self.db["news_general"]
        self.collection_daily_research_exclusive = self.db["daily_research_exclusive"]
        self.collection_quant_investing_exclusive = self.db["quant_investing_exclusive"]
        self.collection_trade_ideas_exclusive = self.db["trade_ideas_exclusive"]
        self.collection_market_outlook_exclusive = self.db["market_outlook_exclusive"]
        self.collection_research_coin_exclusive = self.db["research_coin_exclusive"]
        self.collection_street_view_exclusive = self.db["street_view_exclusive"]

    def close(self):
        pass  # jangan close global client di request-level