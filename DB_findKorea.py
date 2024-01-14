from pymongo import MongoClient           # pymongo 임포트
from datetime import *
client = MongoClient('mongodb://zxc0214:asd64026@3.35.4.52', 27017)
db = client.KoreaServer
users = db.users

def print_Data():
    
    user = users.find({})
    for i in user:
        print(i)

def Find_Data(AccountNumber):
    
    user = users.find_one({'AccountNumber':AccountNumber})
    
    if user == None:
        return 2
    else :
        if not user["OnOff"]:
            return 3
        else :
            return 1

def insert_trading_log(AccountNumber,time,profit,balance):
    # 유닉스 시간을 날짜와 시간으로 변환
    datetime_object = datetime.utcfromtimestamp(int(time))

    # strftime 함수를 사용하여 원하는 형식의 문자열로 변환
    formatted_time = datetime_object.strftime('%Y-%m-%d')

     # 검색 조건을 정의
    search_condition = {"AccountNumber": AccountNumber, "trading_log.time": formatted_time}

    # 검색 결과를 가져옴
    existing_data = users.find_one(search_condition)
    print(existing_data)
    if existing_data:
        # 동일한 날짜가 이미 존재하는 경우, 해당 날짜의 로그를 업데이트
        update_condition = {"AccountNumber": AccountNumber, "trading_log.time": formatted_time}
        update_data = {"$set": {"trading_log.$.profit": profit, "trading_log.$.balance": balance}}
        users.update_one(update_condition, update_data)
    else:
        # 동일한 날짜가 없는 경우, 새로운 로그를 추가
        insert_data = {"time": formatted_time, "profit": profit, "balance": balance}
        users.update_one({"AccountNumber": AccountNumber}, {"$push": {"trading_log": insert_data}})

def in_Data(AccountNumber,name,Upper_Name,OnOff):
    
    users.insert_one({"AccountNumber":AccountNumber,'name':name,"Upper_Name":Upper_Name,"OnOff":OnOff,"traiding_log":[],"deposit_log":[]})

if __name__ == "__main__":
    # in_Data("48421335","성정호","48384868",True)
    # print(Find_Data("48421335"))
    x = users.find({})
    for i in x:
        print(i)
    # users.delete_many({})