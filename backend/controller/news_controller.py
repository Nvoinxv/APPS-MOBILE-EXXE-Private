from model.news_model import News_Model
from database.mongo_connection import MongoConnection
from fastapi import APIRouter

router_news = APIRouter()

class NewsController:
    def __init__(self):
        self.connection = MongoConnection()
        self.collection_news_exclusive = self.connection.collection_news_exclusive
        self.collection_news_general = self.connection.collection_news_general
    
    @router_news.get("/get-news-exclusive")
    def get_all_news_exclusive(self):
        return self.collection_news_exclusive.find();
    
    @router_news.get("/get-news-general")
    def get_all_news_general(self):
        return self.collection_news_general.find();
    
    @router_news.get("/get-news-title")
    def get_news_by_title(self, title):
        return self.collection_news_exclusive.find_one({"title": title})
    
    @router_news.get("/get-news-general-title")
    def get_news_general_by_title(self, title):
        return self.collection_news_general.find_one({"title": title})
    
    @router_news.post("/upload-news-general")
    def upload_news_general(self, news: News_Model):
        self.collection_news_general.insert_one(news.to_dict())
        return "News umum berhasil di upload!"
    
    @router_news.post("/upload-news-exclusive")
    def upload_news_exclusive(self, news: News_Model):
        self.collection_news_exclusive.insert_one(news.to_dict())
        return "News eksklusif berhasil di upload!"
        