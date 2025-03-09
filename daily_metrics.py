from pymongo import MongoClient
from datetime import datetime, timedelta
import schedule
import time
import yfinance as yf
import pandas as pd
import requests
from bs4 import BeautifulSoup


# MongoDB 연결 설정
def get_db_connection():
    try:
        client = MongoClient(
            "mongodb://admin2:asd64026@13.209.74.215:27017/?authSource=admin"
        )
        client.server_info()
        return client.KoreaServer
    except Exception as e:
        raise


def collect_market_metrics():
    try:
        db = get_db_connection()
        current_time = datetime.now() + timedelta(hours=9)
        today_date = current_time.date().strftime("%Y-%m-%d")

        # 1. KOSPI 지수 데이터
        kospi = yf.Ticker("^KS11")
        kospi_info = kospi.history(period="1d")

        # 2. KOSDAQ 지수 데이터
        kosdaq = yf.Ticker("^KQ11")
        kosdaq_info = kosdaq.history(period="1d")

        # 3. USD/KRW 환율 데이터
        usd_krw = yf.Ticker("KRW=X")
        usd_krw_info = usd_krw.history(period="1d")

        market_metrics = {
            "date": today_date,
            "timestamp": current_time,
            "kospi": {
                "close": (
                    float(kospi_info["Close"].iloc[-1])
                    if not kospi_info.empty
                    else None
                ),
                "volume": (
                    float(kospi_info["Volume"].iloc[-1])
                    if not kospi_info.empty
                    else None
                ),
                "change_percent": (
                    float(kospi_info["Close"].pct_change().iloc[-1] * 100)
                    if not kospi_info.empty
                    else None
                ),
            },
            "kosdaq": {
                "close": (
                    float(kosdaq_info["Close"].iloc[-1])
                    if not kosdaq_info.empty
                    else None
                ),
                "volume": (
                    float(kosdaq_info["Volume"].iloc[-1])
                    if not kosdaq_info.empty
                    else None
                ),
                "change_percent": (
                    float(kosdaq_info["Close"].pct_change().iloc[-1] * 100)
                    if not kosdaq_info.empty
                    else None
                ),
            },
            "usd_krw": {
                "rate": (
                    float(usd_krw_info["Close"].iloc[-1])
                    if not usd_krw_info.empty
                    else None
                ),
                "change_percent": (
                    float(usd_krw_info["Close"].pct_change().iloc[-1] * 100)
                    if not usd_krw_info.empty
                    else None
                ),
            },
        }

        # 4. 거래량 상위 종목 정보 수집
        try:
            url = "https://finance.naver.com/sise/sise_quant.naver"
            response = requests.get(url)
            soup = BeautifulSoup(response.text, "html.parser")
            top_volume_stocks = []

            rows = soup.select("table.type_2 tr")[2:7]
            for row in rows:
                cols = row.select("td")
                if len(cols) > 5:
                    stock_info = {
                        "name": cols[1].text.strip(),
                        "price": float(cols[2].text.strip().replace(",", "")),
                        "volume": int(cols[5].text.strip().replace(",", "")),
                    }
                    top_volume_stocks.append(stock_info)

            market_metrics["top_volume_stocks"] = top_volume_stocks
        except Exception:
            market_metrics["top_volume_stocks"] = []

        # MongoDB에 저장
        db.market_metrics.insert_one(market_metrics)

    except Exception as e:
        raise


def get_indicator_category(event_name):
    event_name = event_name.lower()

    categories = {
        "GDP": ["gdp", "국내총생산", "경제성장률"],
        "물가": ["물가", "cpi", "ppi", "인플레이션", "디플레이션"],
        "고용": ["고용", "실업", "일자리", "취업", "노동"],
        "무역": ["무역", "수출", "수입", "무역수지", "경상수지"],
        "통화": ["기준금리", "금리", "통화", "화폐", "머니", "통화정책"],
        "제조업": ["제조업", "pmi", "산업생산", "설비가동률", "공장"],
        "소비": ["소비", "소매", "판매", "지출"],
        "주택": ["주택", "부동산", "건설", "건축"],
        "기업": ["기업", "기업신뢰", "수익", "투자"],
        "금융": ["금융", "주가", "증시", "채권", "외환"],
    }

    for category, keywords in categories.items():
        if any(keyword in event_name for keyword in keywords):
            return category

    return "기타"


def collect_economic_calendar():
    try:
        db = get_db_connection()
        current_time = datetime.now() + timedelta(hours=9)

        url = (
            "https://kr.investing.com/economic-calendar/Service/getCalendarFilteredData"
        )
        headers = {
            "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36",
            "Accept": "*/*",
            "Accept-Language": "ko-KR,ko;q=0.9,en-US;q=0.8,en;q=0.7",
            "Content-Type": "application/x-www-form-urlencoded",
            "X-Requested-With": "XMLHttpRequest",
            "Origin": "https://kr.investing.com",
            "Referer": "https://kr.investing.com/economic-calendar/",
        }

        data = {
            "country[]": [
                "110",
                "43",
                "17",
                "42",
                "5",
                "178",
                "32",
                "12",
                "26",
                "36",
                "4",
                "72",
                "10",
                "14",
                "48",
                "35",
                "37",
                "6",
                "122",
                "41",
                "22",
                "11",
                "25",
                "39",
            ],
            "timeZone": "88",
            "timeFilter": "timeRemain",
            "currentTab": "thisWeek",
            "limit_from": "0",
            "importance[]": ["3"],
        }

        response = requests.post(url, headers=headers, data=data)
        response_data = response.json()

        if response.status_code == 200:
            html_content = response_data.get("data", "")
            soup = BeautifulSoup(html_content, "html.parser")
            weekly_events = {}

            event_rows = soup.select("tr.js-event-item")

            for row in event_rows:
                try:
                    event_datetime = row.get("data-event-datetime")
                    if not event_datetime:
                        continue

                    event_date = event_datetime.split(" ")[0]

                    time_elem = row.select_one("td.time")
                    time = time_elem.text.strip() if time_elem else ""

                    try:
                        event_time = datetime.strptime(time, "%H:%M").time()
                        if event_time.hour < 21:
                            continue
                    except ValueError:
                        continue

                    event_elem = row.select_one("td.event a")
                    event_name = event_elem.text.strip() if event_elem else ""

                    country_elem = row.select_one("td.flagCur img")
                    country = (
                        country_elem["title"]
                        if country_elem and "title" in country_elem.attrs
                        else ""
                    )

                    actual_elem = row.select_one("td.bold")
                    forecast_elem = row.select_one("td.fore")
                    previous_elem = row.select_one("td.prev")

                    actual = actual_elem.text.strip() if actual_elem else ""
                    forecast = forecast_elem.text.strip() if forecast_elem else ""
                    previous = previous_elem.text.strip() if previous_elem else ""

                    category = get_indicator_category(event_name)

                    if event_date not in weekly_events:
                        weekly_events[event_date] = []

                    event_data = {
                        "time": time,
                        "country": country,
                        "currency": (
                            row.select_one("td.flagCur").text.strip()[-3:]
                            if row.select_one("td.flagCur")
                            else ""
                        ),
                        "category": category,
                        "event_name": event_name,
                        "event_id": row.get("event_attr_id", ""),
                        "event_link": (
                            f"https://kr.investing.com{event_elem['href']}"
                            if event_elem and "href" in event_elem.attrs
                            else ""
                        ),
                        "importance": "높음",
                        "actual": actual,
                        "forecast": forecast,
                        "previous": previous,
                        "performance": (
                            "상회"
                            if actual_elem
                            and "greenFont" in actual_elem.get("class", [])
                            else (
                                "하회"
                                if actual_elem
                                and "redFont" in actual_elem.get("class", [])
                                else "동일"
                            )
                        ),
                    }
                    weekly_events[event_date].append(event_data)

                except Exception:
                    continue

            for date, events in weekly_events.items():
                daily_data = {
                    "date": date,
                    "timestamp": current_time,
                    "events": events,
                    "collection_status": "success",
                }

                db.economic_calendar.update_one(
                    {"date": date}, {"$set": daily_data}, upsert=True
                )

        else:
            raise Exception(f"API 요청 실패: {response.status_code}")

    except Exception as e:
        try:
            db.economic_calendar.update_one(
                {"date": datetime.now().strftime("%Y-%m-%d")},
                {
                    "$set": {
                        "timestamp": current_time,
                        "events": [],
                        "collection_status": "failed",
                        "error_message": str(e),
                    }
                },
                upsert=True,
            )
        except Exception:
            pass


def start_scheduler():
    try:
        schedule.every().day.at("21:00").do(collect_economic_calendar)

        while True:
            schedule.run_pending()
            time.sleep(60)

    except Exception:
        raise


if __name__ == "__main__":
    try:
        collect_economic_calendar()
        start_scheduler()
    except Exception:
        raise
