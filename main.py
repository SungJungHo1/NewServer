from DB_findKorea import *
from datetime import *
from fastapi import FastAPI, Request, Form, HTTPException, WebSocket
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pymongo import MongoClient
from pydantic import BaseModel, Field
from typing import Annotated

# import threading, time

# 스케줄러 임포트
from scheduler import run_scheduler
import threading
import uvicorn
from datetime import datetime, timedelta

thread_Count = 0

app = FastAPI()
templates = Jinja2Templates(directory="templates")

client = MongoClient("mongodb://admin2:asd64026@13.209.74.215:27017/?authSource=admin")
db = client.KoreaServer
collection = db.users
economic_db = client.KoreaServer  # test에서 KoreaServer로 변경


class WebSocketManager:
    def __init__(self):
        self.connections = set()

    async def connect(self, websocket: WebSocket):
        await websocket.accept()
        self.connections.add(websocket)

    def disconnect(self, websocket: WebSocket):
        self.connections.remove(websocket)

    async def broadcast(self, message: dict):
        for connection in self.connections:
            await connection.send_text(message)


manager = WebSocketManager()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

#############################################################################################################################################


class RegisterForm(BaseModel):
    AccountNumber: str = Field(..., description="Account Number")
    name: str = Field(..., description="Name")
    phone_number: str = Field(..., description="phone number")
    Upper_Name: str = Field(..., description="Upper Name")


# 클라이언트에서 호출할 엔드포인트 추가
@app.post("/toggle_status/{account_number}")
async def toggle_status(account_number: str):
    # MongoDB에서 해당 계좌번호의 사용자 정보 조회
    user = collection.find_one({"AccountNumber": account_number})

    if user:
        # 사용자의 OnOff 필드 값을 토글
        new_status = not user["OnOff"]

        # MongoDB에서 사용자 정보 업데이트
        collection.update_one(
            {"AccountNumber": account_number}, {"$set": {"OnOff": new_status}}
        )

        return {"status": "success", "new_status": new_status}

    return {"status": "error", "message": "User not found"}


@app.get("/", response_class=HTMLResponse)
async def main_page(request: Request):
    return templates.TemplateResponse("main_page.html", {"request": request})


@app.post("/main/", response_class=HTMLResponse)
async def main_login(request: Request, password: str = Form(...)):
    if password == "5555":
        return templates.TemplateResponse("main_logged_in.html", {"request": request})
    else:
        raise HTTPException(status_code=401, detail="Incorrect password")


@app.get("/all_members/", response_class=HTMLResponse)
async def all_members(request: Request):
    # Get all members from MongoDB
    all_members = list(collection.find({}))

    return templates.TemplateResponse(
        "all_members.html", {"request": request, "members": all_members}
    )


@app.post("/delete_member/{account_number}")
async def delete_member(account_number: str):
    # MongoDB에서 해당 계좌번호의 사용자 정보 조회
    user = collection.find_one({"AccountNumber": account_number})

    if user:
        # 사용자 정보 삭제
        collection.delete_one({"AccountNumber": account_number})

        # WebSocket을 통해 클라이언트에게 삭제 이벤트를 알림
        await manager.broadcast(
            {"event": "member_deleted", "account_number": account_number}
        )

        return {"status": "success", "message": "Member deleted"}

    return {"status": "error", "message": "User not found"}


@app.get("/member/{account_number}/", response_class=HTMLResponse)
async def member_details(request: Request, account_number: str):
    # Get member details and all trading logs from MongoDB
    member_details = collection.find_one({"AccountNumber": account_number})
    trading_logs = member_details.get("trading_log", [])

    return templates.TemplateResponse(
        "member_details.html",
        {
            "request": request,
            "member_details": member_details,
            "trading_logs": trading_logs,
        },
    )


# 회원 등록 페이지 (폼 표시)
@app.get("/register", response_class=HTMLResponse)
async def show_register_form(request: Request):
    return templates.TemplateResponse("register.html", {"request": request})


@app.post("/register/", response_class=HTMLResponse)
async def register(
    request: Request,
    AccountNumber: str = Form(...),
    name: str = Form(...),
    Upper_Name: str = Form(...),
    phone_number: str = Form(...),
):
    # Check if AccountNumber already exists
    if collection.find_one({"AccountNumber": AccountNumber}):
        raise HTTPException(
            status_code=400, detail="동일한 계좌번호가 이미 존재합니다."
        )

    # MongoDB에 회원 정보 저장
    new_member = {
        "AccountNumber": str(AccountNumber),
        "name": name,
        "Upper_Name": str(Upper_Name),
        "phone_number": str(phone_number),
        "OnOff": True,
        "trading_log": [],
        "deposit_log": [],
    }
    collection.insert_one(new_member)

    return templates.TemplateResponse(
        "register_result.html",
        {"request": request, "AccountNumber": AccountNumber, "name": name},
    )


#############################################################################################################################################


@app.get("/check_User")
def mach_UserName(Number):

    check_User = Find_Data(Number)

    return check_User


@app.get("/Log")
def Call_Log(AccountNumber, time, profit, balance):
    insert_trading_log(AccountNumber, time, profit, balance)


@app.get("/check_indicator")
async def check_indicator(date: str, hour: str, min: str):
    try:
        # MT4에서 받은 날짜 형식(YYYY.MM.DD)을 MongoDB 형식(YYYY/MM/DD)으로 변환
        date = date.replace(".", "/")
        print(f"\n=== Indicator Check Debug ===")
        print(f"Checking date: {date}")

        # MongoDB에서 해당 날짜의 경제지표 데이터 조회
        indicator_data = economic_db.economic_calendar.find_one({"date": date})

        print(f"Found data: {indicator_data is not None}")

        if indicator_data and indicator_data.get("events"):
            events = indicator_data.get("events", [])
            print(f"Found {len(events)} events")

            # 현재 시간과 가장 가까운 이벤트 찾기
            current_hour = int(hour)
            current_min = int(min)
            closest_event = None
            min_time_diff = float("inf")

            for event in events:
                event_time = event.get("time", "")
                if event_time:
                    event_hour, event_min = map(int, event_time.split(":"))
                    time_diff = (event_hour - current_hour) * 60 + (
                        event_min - current_min
                    )

                    # 앞으로 다가올 이벤트 중 가장 가까운 것 선택
                    if 0 <= time_diff < min_time_diff:
                        min_time_diff = time_diff
                        closest_event = event

            if closest_event:
                return {
                    "result": "true",
                    "event_time": closest_event["time"],
                    "event_name": closest_event["event_name"],
                    "minutes_until": min_time_diff,
                }

        return {"result": "false"}

    except Exception as e:
        print(f"Error in check_indicator: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


def main():
    # 스케줄러를 별도 쓰레드로 실행
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()

    # 기존 코드 유지
    uvicorn.run(app, host="0.0.0.0", port=8000)
