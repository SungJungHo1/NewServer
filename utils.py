from typing import List
from pydantic import BaseModel

class MemberInfo(BaseModel):
    AccountNumber: str
    name: str
    Upper_Name: str
    OnOff: bool
    trading_log: List[dict] = []

def get_member_info_dict(member_info):
    return {
        "AccountNumber": member_info["AccountNumber"],
        "name": member_info["name"],
        "Upper_Name": member_info["Upper_Name"],
        "OnOff": member_info["OnOff"],
        "trading_log": member_info["trading_log"],
    }
