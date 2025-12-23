from model.news_model import News_Model
from database.mongo_connection import MongoConnection
from fastapi import APIRouter

router_news = APIRouter()


# Helper connection
def get_mongo_collections():
    connection = MongoConnection()
    return connection.collection_news_exclusive, connection.collection_news_general

@router_news.get("/get-news-exclusive")
def get_all_news_exclusive():
    exclusive, _ = get_mongo_collections()
    # Convert cursor to list/dict if needed, but returning cursor directly might fail in FastAPI serialization
    # Assuming the user wants list
    return list(exclusive.find())

@router_news.get("/get-news-general")
def get_all_news_general():
    _, general = get_mongo_collections()
    return list(general.find())

@router_news.get("/get-news-title")
def get_news_by_title(title: str):
    exclusive, _ = get_mongo_collections()
    return exclusive.find_one({"title": title})

@router_news.get("/get-news-general-title")
def get_news_general_by_title(title: str):
    _, general = get_mongo_collections()
    return general.find_one({"title": title})

@router_news.post("/upload-news-general")
def upload_news_general(news: News_Model):
    _, general = get_mongo_collections()
    general.insert_one(news.to_dict())
    return "News umum berhasil di upload!"

@router_news.post("/upload-news-exclusive")
def upload_news_exclusive(news: News_Model):
    exclusive, _ = get_mongo_collections()
    exclusive.insert_one(news.to_dict())
    return "News eksklusif berhasil di upload!"
        
