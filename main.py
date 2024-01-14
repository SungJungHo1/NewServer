from DB_findKorea import *
from datetime import *
from fastapi import FastAPI, Request, Form,HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import HTMLResponse
from fastapi.templating import Jinja2Templates
from pymongo import MongoClient
from pydantic import BaseModel, Field
from typing import Annotated
# import threading, time

thread_Count = 0

app = FastAPI()
templates = Jinja2Templates(directory="templates")

client = MongoClient('mongodb://zxc0214:asd64026@3.35.4.52', 27017)
db = client.KoreaServer
collection  = db.users

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

#############################################################################################################################################



class RegisterForm(BaseModel):
    AccountNumber: str = Field(..., description="Account Number")
    name: str = Field(..., description="Name")
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
            {"AccountNumber": account_number},
            {"$set": {"OnOff": new_status}}
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

    return templates.TemplateResponse("all_members.html", {"request": request, "members": all_members})

@app.get("/member/{account_number}/", response_class=HTMLResponse)
async def member_details(request: Request, account_number: str):
    # Get member details and all trading logs from MongoDB
    member_details = collection.find_one({"AccountNumber": account_number})
    trading_logs = member_details.get("trading_log", [])

    return templates.TemplateResponse(
        "member_details.html",
        {"request": request, "member_details": member_details, "trading_logs": trading_logs}
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
):
    # Check if AccountNumber already exists
    if collection.find_one({"AccountNumber": AccountNumber}):
        raise HTTPException(status_code=400, detail="동일한 계좌번호가 이미 존재합니다.")
    
    # MongoDB에 회원 정보 저장
    new_member = {
        "AccountNumber": str(AccountNumber),
        "name": name,
        "Upper_Name": str(Upper_Name),
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

@app.get('/check_User')
def mach_UserName(Number):

    check_User = Find_Data(Number)

    return check_User

@app.get('/Log')
def Call_Log(AccountNumber,time,profit,balance):
    insert_trading_log(AccountNumber,time,profit,balance)
