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
async def check_indicator(date: str, hour: str = "00", min: str = "00"):
    try:
        # MongoDB에서 해당 날짜의 모든 지표 검색
        search_date = date.replace(".", "/")
        client = MongoClient("mongodb://admin2:asd64026@13.209.74.215:27017/")
        db = client["KoreaServer"]
        collection = db["economic_calendar"]

        # 해당 날짜의 모든 이벤트 찾기
        event = collection.find_one({"date": search_date})
        events = event.get("events")
        if events:
            print(events)
            # 모든 이벤트의 시간과 이름을 리스트로 만들기

            unique_times = {}
            # 각 이벤트를 순회하면서 시간이 중복되지 않는 것만 저장
            for event in events:
                time = event.get("time", "")
                # 해당 시간이 아직 없거나, 현재 이벤트의 중요도가 더 높은 경우에만 저장
                if time not in unique_times:
                    unique_times[time] = {
                        "event_time": time,
                        "event_name": event.get("event_name", ""),
                        "importance": event.get("importance", ""),
                    }

            # 딕셔너리 값들을 리스트로 변환
            event_list = list(unique_times.values())

            print(f"Found {len(event_list)} unique events")
            return {"result": "true", "events": event_list}

        print("No events found")
        return {"result": "false"}

    except Exception as e:
        print(f"Error in check_indicator: {str(e)}")
        return {"result": "false", "error": str(e)}


def main():
    # 스케줄러를 별도 쓰레드로 실행
    scheduler_thread = threading.Thread(target=run_scheduler, daemon=True)
    scheduler_thread.start()

    # 기존 코드 유지
    uvicorn.run(app, host="0.0.0.0", port=8000)
