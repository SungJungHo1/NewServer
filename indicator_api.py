from fastapi import FastAPI, HTTPException
from pymongo import MongoClient
from datetime import datetime, timedelta
from typing import Optional

app = FastAPI()

# MongoDB 연결 설정
MONGO_URI = "mongodb://admin2:asd64026@13.209.74.215:27017/?authSource=admin"
client = MongoClient(MONGO_URI)
db = client.test


@app.get("/check_indicator")
async def check_indicator(date: str, hour: str, min: str):
    try:
        # 현재 시간 파싱
        current_time = datetime.strptime(f"{date} {hour}:{min}", "%Y.%m.%d %H:%M")

        # 5분 후의 시간 계산
        check_time = current_time + timedelta(minutes=5)

        # MongoDB에서 해당 날짜의 경제지표 데이터 조회
        indicator_data = db.economic_calendar.find_one({"date": date})

        if not indicator_data:
            return {"result": "false"}

        # 이벤트 확인
        events = indicator_data.get("events", [])
        for event in events:
            event_time = datetime.strptime(f"{date} {event['time']}", "%Y.%m.%d %H:%M")

            # 현재 시간부터 5분 이내에 발표되는 지표가 있는지 확인
            if current_time <= event_time <= check_time:
                return {"result": "true"}

        return {"result": "false"}

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/health")
async def health_check():
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=8000)
