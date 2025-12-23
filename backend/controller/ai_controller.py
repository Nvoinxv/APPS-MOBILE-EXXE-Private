from AI.AI_Generate_Text import AIGenerateTextNews
from AI.llm_analisis_sentiment import AnalisisSentiment
from fastapi import APIRouter

router_ai = APIRouter()

class AIController:
    def __init__(self):
        self.ai_generate_text_news = AIGenerateTextNews()
        self.ai_analisis_sentiment = AnalisisSentiment()
    
    @router_ai.post("/generate-text-news")
    def generate_text_news(self, text):
        return self.ai_generate_text_news._generate_content()

    @router_ai.post("/analisis-sentiment")
    def analisis_sentiment(self, text):
        return self.ai_analisis_sentiment.analisis_sentiment()

    