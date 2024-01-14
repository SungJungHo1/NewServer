from typing import List
from pydantic import BaseModel

class MemberList(BaseModel):
    members: List[dict] = []

class TradingLogList(BaseModel):
    trading_logs: List[dict] = []
