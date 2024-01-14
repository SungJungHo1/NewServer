from pymongo import MongoClient           # pymongo 임포트
from datetime import *
client = MongoClient('mongodb://ser:ser@3.39.46.36', 27017)
db = client.test
users = db.users
def Find_Data(User_Name):
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    
    user = db.users.find_one({'name':User_Name})
    
    if user == None:
        return "2"
    else :
        if not user["OnOff"]:
            return "3"
        else :
            return "1"

def print_Data():
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    
    user = db.users.find({})
    
    return user
            
def Make_Log(User_Name,AccountBalance):
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    Days = datetime.now() + timedelta(hours=3)
    db.Logs.insert_one({'name':User_Name,"Day":str(Days.date()),"Time":Days.strftime("%H:%M:%S"),"AccountBalance":float(AccountBalance)})

def Make_Deposit(User_Name,UNIX_Time,time,Deposit):
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    db.Deposit.insert_one({'name':User_Name,"UNIX_Time" : UNIX_Time,"time" : time,"Deposit" : Deposit})

def Find_Deposit(User_Name):
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    deposit = db.Deposit.find_one({'name':User_Name})
    deposits = db.Deposit.find({'name':User_Name})
    text_List = []
    
    if deposit == None:
        return 0
    else:
        for i in deposits:
            text_List.append([i["name"],i["UNIX_Time"], i["time"],i["Deposit"]])
        UNIX_Time = text_List[len(text_List)-1][1]
        return UNIX_Time

def Find_AccountBalance(User_Name):
    client = MongoClient("mongodb+srv://Cafe:Cafe@cluster1.btsz9.mongodb.net/?retryWrites=true&w=majority")
    db = client.test
    user = db.Logs.find_one({'name':User_Name})
    users = db.Logs.find({'name':User_Name})
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
    # x = test1.find({})
    # for i in x:
    x = print_Data()
    for i in x:
        print(i)
    # Make_Log("nonottlyy",6666)
    # print(Find_AccountBalance("48093112"))
    # print(Find_Deposit("141046139"))
    # Days = date.today().isoformat()
    # print("gg")

