import os
from dotenv import load_dotenv
import pandas as pd

env_path = os.path.join(os.path.dirname(__file__), '.env')
load_dotenv(dotenv_path=env_path)

news_api_key = os.getenv("")