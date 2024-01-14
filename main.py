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

@app.get('/')
def mach_UserName(name):

    temp = name
    check_User = Find_Data(temp)

    return check_User

@app.get('/Log')
def Call_Log(name,balance):

    AccountName = name
    AccountBalance = balance
    Make_Log(AccountName,AccountBalance)
    return "sds"

@app.get('/Deposit')
def Add_Deposit(name,UNIX_Time,time,Deposit):

    AccountName = name
    UNIX__Time = UNIX_Time
    AccountBalance = Deposit
    Make_Deposit(AccountName,UNIX__Time,time,AccountBalance)
    return "sds"

@app.get('/Find_Deposit')
def Finds_Deposit(name):

    AccountName = name
    UNIX_Time = Find_Deposit(AccountName)
    return str(UNIX_Time)

    