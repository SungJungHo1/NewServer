from DB_findKorea import *
from datetime import *
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
# import threading, time

thread_Count = 0

app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=['*'],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get('/check_User')
def mach_UserName(Number):

    check_User = Find_Data(Number)

    return check_User

@app.get('/Log')
def Call_Log(AccountNumber,time,profit,balance):
    insert_trading_log(AccountNumber,time,profit,balance)
