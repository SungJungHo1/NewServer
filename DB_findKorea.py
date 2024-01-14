from pymongo import MongoClient           # pymongo 임포트
from datetime import *
from DB_find import print_Data
client = MongoClient('mongodb://ser:ser@3.39.46.36', 27017)
db = client.KoreaServer
users = db.users
Logs = db.Logs
Deposits = db.Deposit

def print_Data():
    
    user = users.find({})
    for i in user:
        print(i)

def Find_Data(User_Name):
    
    user = users.find_one({'name':User_Name})
    
    if user == None:
        return 2
    else :
        if not user["OnOff"]:
            return 3
        else :
            return 1

def in_Data(name,Upper_Name,AccountNumber,OnOff):
    
    users.insert_one({'name':name,"Upper_Name":Upper_Name,"AccountNumber":AccountNumber,"OnOff":OnOff})

def Make_Log(User_Name,AccountBalance):
    
    timezone_kst = timezone(timedelta(hours=9))
    datetime_utc2 = datetime.now(timezone_kst)
    Logs.insert_one({'name':User_Name,"Day":str(datetime_utc2.date()),"Time":datetime_utc2.strftime("%H:%M:%S"),"AccountBalance":float(AccountBalance)})

def Make_Deposit(User_Name,UNIX_Time,time,Deposit):
    
    Deposits.insert_one({'name':User_Name,"UNIX_Time" : UNIX_Time,"time" : time,"Deposit" : Deposit})

def Find_Deposit(User_Name):
    
    deposit = Deposits.find_one({'name':User_Name})
    deposits = Deposits.find({'name':User_Name})
    text_List = []
    
    if deposit == None:
        return 0
    else:
        for i in deposits:
            text_List.append([i["name"],i["UNIX_Time"], i["time"],i["Deposit"]])
        UNIX_Time = text_List[len(text_List)-1][1]
        return UNIX_Time

def Find_AccountBalance(User_Name):

    user = Logs.find_one({'name':User_Name})
    users = Logs.find({'name':User_Name})
    text_List = []
    
    if user == None:
        return -1
    else:
        for i in users:
            text_List.append([i["name"],i["Day"], i["Time"],i["AccountBalance"]])
        AccountBalance = text_List[len(text_List)-1][3]
        return AccountBalance

if __name__ == "__main__":
    # Find_Data("48093112")
    # test1.insert_one({'name':"sdsds"})
    x = Logs.find({})
    for i in x:
        print(i)
    # Make_Data("nonottlyy")
    # Make_Log("nonottlyy",6666)
    # print(Find_AccountBalance("48093112"))
    # print(Find_Deposit("141046139"))
    # Days = date.today().isoformat()
    # print("gg")

