import json
import datetime
import os
import pandas as pd
import requests
import pickle
import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List
from meteostat import Daily, Point

# --- AYARLAR VE ANAHTARLAR ---
# Football API key'i ortam değişkeninden oku: export FOOTBALL_API_KEY="your_key"
FOOTBALL_API_KEY = os.getenv("FOOTBALL_API_KEY", "")
SAKARYA = Point(40.7569, 30.3783)
MODEL_FILENAME = 'yogunluk_tahmin_modeli.pkl'

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

class Record(BaseModel):
    date: str
    time: str
    timestamp: int
    occupancy: int
    density: str

# --- YARDIMCI FONKSİYONLAR ---

def get_holiday_name(date_str):
    try:
        with open("holidays.json", "r", encoding="utf-8") as f:
            holidays = json.load(f)
        return holidays.get(date_str)
    except:
        return None

def get_past_weather_condition(date_str):
    try:
        day = datetime.datetime.strptime(date_str, "%Y-%m-%d")
        data = Daily(SAKARYA, day, day)
        df = data.fetch()
        if df.empty or "prcp" not in df.columns:
            return "clear"
        prcp = df.iloc[0]["prcp"]
        # 0.5 mm ve üzeri yağış varsa 'rain' kabul edelim
        return "rain" if prcp and prcp > 0.5 else "clear"
    except:
        return "clear"

def get_matches_from_api(date_str):
    # API key yoksa boş dön
    if not FOOTBALL_API_KEY:
        return []
    url = "https://v3.football.api-sports.io/fixtures"
    headers = {"x-apisports-key": FOOTBALL_API_KEY}
    params = {"date": date_str, "league": 203, "season": 2025}
    try:
        r = requests.get(url, headers=headers, params=params, timeout=5)
        return r.json().get("response", [])
    except:
        return []

# --- GÜÇLENDİRİLMİŞ ANALİZ MANTIĞI ---

def analyze_day_logic(df, date_str):
    comments = []
    
    # 1. Saatlik Yoğunluk Analizi
    # Saatlere göre gruplayıp ortalama doluluğu buluyoruz
    hourly_avg = df.groupby("hour")["occupancy"].mean()
    
    # En yoğun saati bul
    peak_hour = hourly_avg.idxmax()
    peak_value = hourly_avg.max()
    
    # 25'ten fazla yolcu varsa 'Yüksek Yoğunluk' diyelim (Senin eşik değerine göre değişebilir)
    if peak_value > 25:
        comments.append(f"Günün en yoğun saati {peak_hour}:00 olarak saptanmıştır (Ortalama {int(peak_value)} yolcu).")
    else:
        comments.append(f"Gün genelinde doluluk oranları makul seyretmiş, en hareketli saat {peak_hour}:00 olmuştur.")

    # 2. Hava Durumu ve Yoğunluk İlişkisi
    weather = get_past_weather_condition(date_str)
    avg_occ = df["occupancy"].mean()

    if weather == "rain":
        if avg_occ > 20:
            comments.append("Yağışlı hava koşullarının toplu taşıma kullanımını doğrudan artırdığı ve yoğunluğa sebep olduğu gözlemlenmiştir.")
        else:
            comments.append("Yağışlı havaya rağmen yolcu trafiği beklenmedik şekilde düşük kalmıştır.")
    else:
        comments.append("Hava koşullarının açık olmasına bağlı olarak ulaşımda büyük bir aksama yaşanmamıştır.")

    # 3. Ekstra Faktörler (Tatil/Maç)
    holiday = get_holiday_name(date_str)
    if holiday:
        comments.append(f"'{holiday}' resmi tatili nedeniyle ulaşım rutininde değişiklikler saptanmıştır.")
    
    matches = get_matches_from_api(date_str)
    if matches:
        comments.append(f"Bölgedeki spor müsabakaları ({len(matches)} maç) belirli saatlerde lokal yoğunluklar oluşturmuştur.")

    # Metni birleştir
    text = f"--- {date_str} ANALİZİ ---\n\n"
    for c in comments:
        text += f"• {c}\n"
    
    return text

# --- ENDPOINT ---

@app.post("/daily-summary")
async def generate_daily_summary(data: List[Record]):
    try:
        if not data:
            return {"status": "no_data", "summary": "Seçilen tarih için analiz edilecek veri yok."}

        # Veriyi işle
        df = pd.DataFrame([r.dict() for r in data])
        df['timestamp'] = pd.to_datetime(df['timestamp'], unit='s')
        df['hour'] = df['timestamp'].dt.hour

        # Analizi çalıştır
        report_date = data[0].date
        report_text = analyze_day_logic(df, report_date)

        return {
            "status": "ok",
            "summary": report_text,
            "prediction": "YAKINDA..."
        }
    except Exception as e:
        print(f"HATA: {str(e)}")
        return {"status": "error", "summary": f"Analiz başarısız: {str(e)}"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)