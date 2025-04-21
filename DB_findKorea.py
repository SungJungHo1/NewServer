from pymongo import MongoClient  # pymongo 임포트
from datetime import *

client = MongoClient("mongodb://admin2:asd64026@13.209.64.113:27017/?authSource=admin")
db = client.KoreaServer
users = db.users


def print_Data():
    user = users.find({})
    for i in user:
        print(i)


def Find_Data(AccountNumber):
    user = users.find_one({"AccountNumber": AccountNumber})

    if user == None:
        return 2
    else:
        if not user["OnOff"]:
            return 3
        else:
            return 1


def insert_trading_log(AccountNumber, time, profit, balance):
    # 유닉스 시간을 날짜와 시간으로 변환
    datetime_object = datetime.utcfromtimestamp(int(time))

    # strftime 함수를 사용하여 원하는 형식의 문자열로 변환
    formatted_time = datetime_object.strftime("%Y-%m-%d")

    # 검색 조건을 정의
    search_condition = {
        "AccountNumber": AccountNumber,
        "trading_log.time": formatted_time,
    }

    # 검색 결과를 가져옴
    existing_data = users.find_one(search_condition)
    # print(existing_data)
    if existing_data:
        # 동일한 날짜가 이미 존재하는 경우, 해당 날짜의 로그를 업데이트
        update_condition = {
            "AccountNumber": AccountNumber,
            "trading_log.time": formatted_time,
        }
        update_data = {
            "$set": {"trading_log.$.profit": profit, "trading_log.$.balance": balance}
        }
        users.update_one(update_condition, update_data)
    else:
        # 동일한 날짜가 없는 경우, 새로운 로그를 추가
        insert_data = {"time": formatted_time, "profit": profit, "balance": balance}
        users.update_one(
            {"AccountNumber": AccountNumber}, {"$push": {"trading_log": insert_data}}
        )


def in_Data(AccountNumber, name, Upper_Name, OnOff):
    users.insert_one(
        {
            "AccountNumber": AccountNumber,
            "name": name,
            "Upper_Name": Upper_Name,
            "OnOff": OnOff,
            "traiding_log": [],
            "deposit_log": [],
        }
    )


def Make_Log(User_Name, AccountBalance):
    Days = datetime.now() + timedelta(hours=3)
    db.Logs.insert_one(
        {
            "name": User_Name,
            "Day": str(Days.date()),
            "Time": Days.strftime("%H:%M:%S"),
            "AccountBalance": float(AccountBalance),
        }
    )


def Make_Deposit(User_Name, UNIX_Time, time, Deposit):
    db.Deposit.insert_one(
        {"name": User_Name, "UNIX_Time": UNIX_Time, "time": time, "Deposit": Deposit}
    )


def Find_Deposit(User_Name):
    deposit = db.Deposit.find_one({"name": User_Name})
    deposits = db.Deposit.find({"name": User_Name})
    text_List = []

    if deposit == None:
        return 0
    else:
        for i in deposits:
            text_List.append([i["name"], i["UNIX_Time"], i["time"], i["Deposit"]])
        UNIX_Time = text_List[len(text_List) - 1][1]
        return UNIX_Time


def Find_AccountBalance(User_Name):
    user = db.Logs.find_one({"name": User_Name})
    users = db.Logs.find({"name": User_Name})
    text_List = []

    if user == None:
        return -1
    else:
        for i in users:
            text_List.append([i["name"], i["Day"], i["Time"], i["AccountBalance"]])
        AccountBalance = text_List[len(text_List) - 1][3]
        return AccountBalance


def get_main_indicators():
    try:
        # 오늘 날짜 구하기
        today = datetime.now().strftime("%Y/%m/%d")  # 날짜 형식을 YYYY/MM/DD로 변경

        # 오늘 날짜의 경제지표 데이터 조회
        indicators = db.economic_calendar.find_one({"date": today})

        if indicators:
            return indicators.get("events", [])
        return []

    except Exception as e:
        # print(f"Error getting indicators: {str(e)}")
        return []


if __name__ == "__main__":
    x = users.find({})
    for i in x:
        print(i)
