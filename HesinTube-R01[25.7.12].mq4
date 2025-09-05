//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
input double TEAUpper1 = 60.0;           // RSI 상한값 (오전)
input double TEALower1 = 40.0;           // RSI 하한값 (오전)
input double TEAUpper2 = 65.0;           // RSI 상한값 (오후)
input double TEALower2 = 35.0;           // RSI 하한값 (오후)
input int switchHour = 12;               // 전환 시간 (24시간 기준)
input double pointDistance = 140;       // 추가 진입 포인트 간격
input double profitTarget = 2;      // 익절 기준 금액
input double martingaleFactor = 1.3;      // 마틴게일 배수
input double maxLossThreshold = -40.0;  // 색 변경 금액
input int magicNumber = 123456;         // 매직 넘버
input int maxTrades = 30;                // 최대 거래 개수
input double initialLotSize = 0.01;      // 첫 진입 시 로트 크기
input int    dividingFactor   = 1;     // totalLots 나누는 값
input double multiplyFactor   = 0.3;    // 곱하는 값 (y 역할)

//=== 추가(Server 체크, 브로커/심볼 체크) ===========================
string Check = "";                     // 서버 응답 보관
bool   User_Mac = false;              // 서버 검증 통과 여부
bool   firstEntry = true;             // 첫 진입 여부
bool   tradingEnabled = false;        // 거래 ON/OFF (버튼)


double OpenPrice = 0;                   // 첫 진입가 저장
int currentTradeCount = 0;              // 현재 열린 거래 수
double totalProfit = 0;                 // 총 수익 계산

// 서버/브로커/ECN 심볼 확인용
bool   checkServerEnabled = true; // 필요 없다면 false로

// 현재 시간대의 RSI 값 가져오기
void GetCurrentRSILevels(double& upper, double& lower) {
   datetime currentTime = TimeCurrent();
   int currentHour = TimeHour(currentTime);
   
   if(currentHour < switchHour) {
      upper = TEAUpper1;
      lower = TEALower1;
   } else {
      upper = TEAUpper2;
      lower = TEALower2;
   }
}
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // 1) 서버 검증 로직 (원하면 주석 해제)
   if (!IsDemo() && !IsTesting())
   {
      if (!ServerCheckAndUserCheck())
      {
         // 서버 검증 실패 => EA 종료
         ExpertRemove();
         return INIT_FAILED;
      }
   }
   else
   {
      // 서버 체크 안 할 경우
      User_Mac = true;
   }

   // 2) 버튼 생성
   CreateToggleButton("startStopButton", 100, 10, "시작", clrRed);
   CreateButton("closeButton", 100, 30, "전체 청산", clrGray);
   CreateButton("buyButton", 100, 50, "수동 바이", clrLime);
   CreateButton("sellButton", 100, 70, "수동 숏", clrRed);

   Print("OnInit 완료. 계좌번호=", AccountNumber());

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| 서버 검증 및 브로커/심볼 체크 함수                               |
//+------------------------------------------------------------------+
bool ServerCheckAndUserCheck()
{
   // a) 브로커 확인
 
   if (AccountCompany() != "Capitalxtend (Mauritius) LLC")
   {
      Alert("이 프로그램은 Capitalxtend에서만 사용 가능합니다.");
      return false;
   }

   // b) ECN 심볼 확인 (! 포함)
   string sym = Symbol();
   if (StringFind(sym, "!") < 0)
   {
      Alert("이 프로그램은 '!'가 포함된 ECN 심볼에서만 사용 가능합니다.");
      return false;
   }

   // c) 서버 웹 검증 예시
   // --------------------------------------------------------------
   //  - 본인 서버 주소/파라미터로 수정. 없는 경우 주석 처리.
   // --------------------------------------------------------------
   string cookie = NULL, headers;
   char post[], result[];
   int res;
   int timeout = 5000;
   string number = IntegerToString(AccountNumber());
   string url    = "http://www.mmser.p-e.kr/check_User?Number=" + number;

   ResetLastError();
   res = WebRequest("GET", url, cookie, NULL, timeout, post, 0, result, headers);
   if (res == -1)
   {
      Alert("서버가 확인되지 않습니다");
      return false;
   }
   Check = CharArrayToString(result);
   int code = (int)Check;  // 서버 응답을 int 변환
   if (code == 2)
   {
      Alert("유저가 존재하지 않습니다.");
      return false;
   }
   else if (code == 3)
   {
      Alert("계정이 비활성화 되었습니다.");
      return false;
   }
   else if (code == 4)
   {
      Alert("잔고가 불일치 합니다.");
      return false;
   }
   else if (code == 1)
   {
      PrintFormat("서버 검증 통과. 사용자(%s) 환영합니다.", number);
      User_Mac = true;
      return true;
   }

   // 그 외 응답값인 경우
   Alert("서버 응답 불명: ", Check);
   return false;
}
//+------------------------------------------------------------------+
//| OnDeinit                                                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("EA 종료 OnDeinit reason=", reason);
}

//+------------------------------------------------------------------+
//| 버튼 생성 함수                                                    |
//+------------------------------------------------------------------+
void CreateButton(string buttonName, int x, int y, string text, color buttonColor) {
   if (!ObjectCreate(0, buttonName, OBJ_BUTTON, 0, 0, 0)) {
      Print("버튼 생성 실패: ", buttonName);
      return;
   }
   ObjectSetInteger(0, buttonName, OBJPROP_CORNER, 0);  // 왼쪽 상단 기준
   ObjectSetInteger(0, buttonName, OBJPROP_XDISTANCE, x);  // x 위치 (코멘트 옆)
   ObjectSetInteger(0, buttonName, OBJPROP_YDISTANCE, y);  // y 위치
   ObjectSetInteger(0, buttonName, OBJPROP_COLOR, clrBlack);  // 글자 색
   ObjectSetInteger(0, buttonName, OBJPROP_FONTSIZE, 12);  // 글자 크기
   ObjectSetInteger(0, buttonName, OBJPROP_HIDDEN, false);  // 숨기지 않음
   ObjectSetString(0, buttonName, OBJPROP_TEXT, text);  // 버튼에 표시할 텍스트
   ObjectSetInteger(0, buttonName, OBJPROP_WIDTH, 100);  // 버튼 너비
   ObjectSetInteger(0, buttonName, OBJPROP_BORDER_TYPE, BORDER_RAISED);  // 테두리 스타일
   ObjectSetInteger(0, buttonName, OBJPROP_BACK, true);  // 배경 활성화
}

//+------------------------------------------------------------------+
//| 시작/정지 버튼 상태 변경 함수                                     |
//+------------------------------------------------------------------+
void CreateToggleButton(string buttonName, int x, int y, string text, color buttonColor) {
   // 시작/정지 버튼 생성
   CreateButton(buttonName, x, y, text, buttonColor);
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
   // 0) UserCheck 미통과면 종료
   if (!User_Mac)
   {
      return;
   }
   
   // 총 손익 계산
   totalProfit = 0;
   currentTradeCount = 0;
   double totalLots = 0; // 진입된 총 랏 수
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber() == magicNumber) {
      
         totalProfit += OrderProfit();
         totalLots += OrderLots(); // 진입된 총 랏 수 계산
         currentTradeCount++;      // 현재 열린 거래 수 증가
      }
   }

   // 손실이 설정된 한도를 초과하면 청산 버튼의 테두리와 글씨 색을 빨간색으로 변경
   if (totalProfit <= maxLossThreshold) {
      ObjectSetInteger(0, "closeButton", OBJPROP_BGCOLOR, clrRed);  // 글자 색상 빨간색
      ObjectSetInteger(0, "closeButton", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   } else {
      ObjectSetInteger(0, "closeButton", OBJPROP_BGCOLOR, clrGray); // 정상 상태에서는 회색
   }

   // 버튼 클릭 확인
   if (ObjectGetInteger(0, "startStopButton", OBJPROP_STATE) == 1) {
      // 시작/정지 버튼 클릭 시
      tradingEnabled = !tradingEnabled;  // 거래 활성화/비활성화 토글
      if (tradingEnabled) {
         // 거래 시작 상태 (녹색)
         ObjectSetString(0, "startStopButton", OBJPROP_TEXT, "정지");
         ObjectSetInteger(0, "startStopButton", OBJPROP_COLOR, clrLime);
         Print("거래 시작");
      } else {
         // 거래 정지 상태 (빨간색)
         ObjectSetString(0, "startStopButton", OBJPROP_TEXT, "시작");
         ObjectSetInteger(0, "startStopButton", OBJPROP_COLOR, clrRed);
         Print("거래 정지");
      }
      ObjectSetInteger(0, "startStopButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
   }
   double currentUpper, currentLower;
   GetCurrentRSILevels(currentUpper, currentLower);

   if (ObjectGetInteger(0, "closeButton", OBJPROP_STATE) == 1) {
      CloseAllPositions();  // 매직 넘버 기준으로 모든 포지션 청산
      ObjectSetInteger(0, "closeButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
      Print("매직 넘버 기반 포지션 청산 완료");
      firstEntry = true;  // 다시 첫 진입 가능하게 설정
      return;
   }

   // 수동 바이 버튼 클릭 처리
   if (ObjectGetInteger(0, "buyButton", OBJPROP_STATE) == 1) {
      if (currentTradeCount < maxTrades) {
         OpenPrice = Ask;
         OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "수동 바이", magicNumber, 0, Blue);
         firstEntry = false;  // 수동 진입 후 자동 RSI 진입 비활성화
         currentTradeCount++;
         Print("수동 바이 포지션 진입 완료");
      } else {
         Print("최대 거래 수에 도달하여 수동 바이 진입 불가");
      }
      ObjectSetInteger(0, "buyButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
   }

   // 수동 숏 버튼 클릭 처리
   if (ObjectGetInteger(0, "sellButton", OBJPROP_STATE) == 1) {
      if (currentTradeCount < maxTrades) {
         OpenPrice = Bid;
         OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "수동 숏", magicNumber, 0, Red);
         firstEntry = false;  // 수동 진입 후 자동 RSI 진입 비활성화
         currentTradeCount++;
         Print("수동 숏 포지션 진입 완료");
      } else {
         Print("최대 거래 수에 도달하여 수동 숏 진입 불가");
      }
      ObjectSetInteger(0, "sellButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
   }

   if (!tradingEnabled) {
      return;  // 거래가 정지되면 아래 로직 실행 안 함
   }

   double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
   
      // 매직넘버 히스토리 오늘 수익 계산
   double todayMagicProfit = GetTodayMagicProfit(magicNumber);

   // 이미 사용 중인 Comment에 추가 예시
   Comment(
      "현재 수익금(실시간): ", DoubleToString(totalProfit, 2),
      "\n오늘 실현 손익(매직넘버): ", DoubleToString(todayMagicProfit, 2),
      "\n총 진입 랏 수: ", DoubleToString(totalLots, 2)
   );
   

   // 익절 조건 확인 후 모든 포지션 청산
   // (int)(profitTarget / x)로 소수점 이하를 버린 정수 몫
   double result = profitTarget;
   if (currentTradeCount != 0) {
      // quotient 계산 로직
      int quotient = (int)(currentTradeCount / dividingFactor);
      result = ((quotient * multiplyFactor) + 1)* profitTarget;
      Print("Debug => quotient=", quotient, " result=", result,
      ", currentTradeCount=", currentTradeCount);
   }
   if(totalProfit >= result) {
      CloseAllPositions();
      firstEntry = true; // 다시 RSI 기준으로 첫 진입 가능
      return;
   }
   
   // 최대 거래 수 제한 확인
   if(currentTradeCount >= maxTrades) {
      return; // 최대 거래 수에 도달했을 경우 더 이상 진입하지 않음
   }
   // 첫 진입만 RSI를 사용하여 결정
   if(firstEntry) {
      if(rsi < currentLower) {
         // 롱 포지션 첫 진입
         OpenPrice = Ask;
         OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
         firstEntry = false; // 첫 진입 이후는 RSI를 사용하지 않음
         currentTradeCount++;
      }
      else if(rsi > currentUpper) {
         // 숏 포지션 첫 진입
         OpenPrice = Bid;
         OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
         firstEntry = false; // 첫 진입 이후는 RSI를 사용하지 않음
         currentTradeCount++;
      }
   } else {
      // 추가 진입: 포지션에 따라 진입 조건 변경
      double priceDifference = 0;
      if(IsPositionOpen(OP_BUY)) {
         priceDifference = (OpenPrice - Ask) / Point;
         if(priceDifference >= pointDistance && currentTradeCount < maxTrades) {
            AddMartingaleOrders(OP_BUY);  // 롱 포지션에 추가 진입
         }
      }
      else if(IsPositionOpen(OP_SELL)) {
         priceDifference = (Bid - OpenPrice) / Point;
         if(priceDifference >= pointDistance && currentTradeCount < maxTrades) {
            AddMartingaleOrders(OP_SELL); // 숏 포지션에 추가 진입
         }
      }
   }
}

// 포지션 추가 진입 (마틴게일 방식)
void AddMartingaleOrders(int orderType) {
   double currentPrice = (orderType == OP_BUY) ? Ask : Bid;
   
   // 마틴게일 방식으로 로트 증가
   double nextLotSize = initialLotSize * MathPow(martingaleFactor, currentTradeCount); // 기존 로트 크기에서 배수 적용
   OrderSend(Symbol(), orderType, nextLotSize, currentPrice, 3, 0, 0, "", magicNumber, 0, Yellow);
   OpenPrice = currentPrice; // 새로운 진입가 설정
   currentTradeCount++; // 현재 거래 수 증가
}

// 포지션 존재 여부 확인
bool IsPositionOpen(int orderType) {
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber() == magicNumber && OrderType() == orderType) {
         return true;
      }
   }
   return false;
}

// 매직 넘버 기준 모든 포지션 청산
void CloseAllPositions() {
   for(int i = OrdersTotal() - 1; i >= 0; i--) {  // 역순으로 반복
      if (OrderSelect(i, SELECT_BY_POS,MODE_TRADES)) {
         // 매직 넘버가 설정된 값과 동일한 포지션만 청산
         if (OrderSymbol() == Symbol()) {
            if (OrderType() == OP_BUY) {
               OrderClose(OrderTicket(), OrderLots(), Bid, 3, Red);
            } else if (OrderType() == OP_SELL) {
               OrderClose(OrderTicket(), OrderLots(), Ask, 3, Blue);
            }
         }
      }
   }
}

// 오늘 날짜(Year(),Month(),Day())에 체결 완료된(히스토리) 중에서
// 해당 매직넘버인 주문들의 Profit + Commission 합계를 구함
double GetTodayMagicProfit(int magicNum)
{
   double sumProfit = 0.0;

   // 1. 오늘 날짜 문자열(ex: "2025.02.25")
   string todayStr = StringFormat("%04d.%02d.%02d", Year(), Month(), Day());

   int totalHistory = OrdersHistoryTotal();
   for(int i=totalHistory - 1; i>=0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
         continue;

      // 실제 매매 주문(ORDER_TYPE_BALANCE 제외) 검사
      if(OrderType() <= OP_SELL && OrderSymbol() == Symbol()) 
      {
         datetime closeT = OrderCloseTime();
         if(closeT > 0)
         {
            string closeDate = TimeToString(closeT, TIME_DATE);

            if(StringCompare(closeDate, todayStr) == 0)
            {
               sumProfit += (OrderProfit() + OrderCommission());
            }
         }
      }
   }

   return sumProfit;
}

