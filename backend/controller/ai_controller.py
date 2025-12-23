from AI.AI_Generate_Text import AIGenerateTextNews
from AI.llm_analisis_sentiment import AnalisisSentiment
from fastapi import APIRouter

router_ai = APIRouter()

@router_ai.post("/generate-text-news")
def generate_text_news(text: str):
    ai_generate_text_news = AIGenerateTextNews()
    return ai_generate_text_news._generate_content()

@router_ai.post("/analisis-sentiment")
def analisis_sentiment(text: str):
    ai_analisis_sentiment = AnalisisSentiment()
    return ai_analisis_sentiment.analisis_sentiment()
