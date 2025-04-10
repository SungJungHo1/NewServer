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
input int hedgeInterval = 3;            // 햇징 간격
input int addHedgeCount = 1;
input double dailyProfitTarget = 100.0;    // 일일 목표 수익 달성시 정지

//=== 추가(Server 체크, 브로커/심볼 체크) ===========================
int hedgecount = 0;
string Check = "";                     // 서버 응답 보관
bool   User_Mac = false;              // 서버 검증 통과 여부
bool   firstEntry = true;             // 첫 진입 여부
bool   tradingEnabled = false;        // 거래 ON/OFF (버튼)
bool   indicatorPause = false;        // 경제지표 발표 시 일시정지
bool indicatorManualPause = false; 
bool   manualPause = false;          // 수동 일시정지 상태
bool   blockNewTrades = false;       // 새로운 진입 차단 상태

// 경제지표 정보 저장용 전역변수
string savedEventTime = "";           // 저장된 이벤트 시간
string savedEventName = "";           // 저장된 이벤트 이름
datetime savedEventDateTime = 0;      // 이벤트 시간을 datetime으로 저장
bool eventTriggered = false;         // 이벤트가 트리거 되었는지 여부

// API 서버 정보
string apiHost = "www.mmser.p-e.kr";  // API 서버 주소

// MongoDB 연결 정보
string mongoHost = "13.209.74.215";
int mongoPort = 27017;
string mongoUser = "admin2";
string mongoPass = "asd64026";
string mongoDb = "test";

double OpenPrice = 0;                   // 첫 진입가 저장
int currentTradeCount = 0;              // 현재 열린 거래 수
double totalProfit = 0;                 // 총 수익 계산
int OpenedPosition = 0;
bool firstHedge = true;
double firstOpenPrice = 0;
// 서버/브로커/ECN 심볼 확인용
bool   checkServerEnabled = true; // 필요 없다면 false로
double saveTotalProfit = 0;
// 전역 변수 추가 (파일 상단에)
struct EventInfo {
    string time;
    string name;
    datetime dateTime;
};
// 최대 저장 가능한 이벤트 수 정의
#define MAX_EVENTS 10
EventInfo g_events[MAX_EVENTS];  // 이벤트 정보를 저장할 배열
int g_eventCount = 0;           // 저장된 이벤트 수
string g_lastCheckDate = "";  // 마지막으로 체크한 날짜 저장
// 현재 시간대의 RSI 값 가져오기
// 이벤트 배열 초기화 함수 추가
void ClearEventArray() {
    for(int i = 0; i < MAX_EVENTS; i++) {
        g_events[i].time = "";
        g_events[i].name = "";
        g_events[i].dateTime = 0;
    }
    g_eventCount = 0;
    //g_eventCount = 1;
    //g_events[0].time = "24:00";
    // g_events[0].name = "";
    // g_events[0].dateTime = StrToTime("2025.03.13 01:00");
}
void GetCurrentRSILevels(double& upper, double& lower) {
   datetime currentTime = TimeCurrent();
   int currentHour = TimeHour(currentTime);
   
   if(currentHour <= switchHour) {
      upper = TEAUpper1;
      lower = TEALower1;
   } else {
      upper = TEAUpper2;
      lower = TEALower2;
   }
}

// 경제지표 체크 함수를 별도로 분리
void CheckAndUpdateEconomicEvents() {
    datetime currentTime = TimeLocal();
    
    string currentDate = TimeToStr(currentTime, TIME_DATE);
    // 이미 오늘 체크했다면 스킵
    if(currentDate == g_lastCheckDate) return;
    eventTriggered = false;
    ClearEventArray();
    string cookie = NULL, headers;
    char post[], result[];
    string url = StringFormat("http://www.mmser.p-e.kr/check_indicator?date=%s&hour=1&min=1", 
                            currentDate);
    
    ResetLastError();
    int res = WebRequest("GET", url, cookie, NULL, 5000, post, 0, result, headers);
    Print("res",res);
    if(res != -1) {
        string response = CharArrayToString(result);
        printf(response);
        if(StringFind(response, "true") >= 0) {
            // events 배열 찾기
            int eventsStart = StringFind(response, "\"events\":[") + 9;
            int eventsEnd = StringFind(response, "]", eventsStart);
            string eventsStr = StringSubstr(response, eventsStart, eventsEnd - eventsStart);
            
            // 이벤트 배열 초기화
            g_eventCount = 0;
            
            // 각 이벤트 파싱
            string eventStr = eventsStr;
            while(StringLen(eventStr) > 0 && g_eventCount < MAX_EVENTS) {
                int eventStart = StringFind(eventStr, "{");
                int eventEnd = StringFind(eventStr, "}") + 1;
                if(eventStart == -1 || eventEnd == -1) break;
                
                string event = StringSubstr(eventStr, eventStart, eventEnd - eventStart);
                
                // 시간 추출
                int timeStart = StringFind(event, "\"event_time\":\"") + 14;
                int timeEnd = StringFind(event, "\"", timeStart);
                string eventTime = StringSubstr(event, timeStart, timeEnd - timeStart);
               Print("추출된 실제 시간: ", eventTime);  // 디버깅용
                // 이름 추출
                int nameStart = StringFind(event, "\"event_name\":\"") + 14;
                int nameEnd = StringFind(event, "\"", nameStart);
                string eventName = StringSubstr(event, nameStart, nameEnd - nameStart);
                
                // 이벤트 정보 저장
                if(StringLen(eventTime) > 0) {
                    g_events[g_eventCount].time = eventTime;
                    g_events[g_eventCount].name = eventName;
                    Print("currentDate",currentDate);
                    Print("eventTime",eventTime);
                    g_events[g_eventCount].dateTime = StrToTime(currentDate + " " + eventTime);
                    
                    Print("=== 경제지표 정보 업데이트 [", g_eventCount, "] ===");
                    Print("날짜: ", currentDate);
                    Print("지표명: ", eventName);
                    Print("발표시간: ", eventTime);
                    Print("발표일시: ", TimeToStr(g_events[g_eventCount].dateTime));
                    
                    g_eventCount++;
                }
                
                // 다음 이벤트로
                eventStr = StringSubstr(eventStr, eventEnd);
            }
            Print("총 저장된 이벤트 수: ", g_eventCount);
            // 체크 완료된 날짜 저장
            g_lastCheckDate = currentDate;
        }
    }
}
bool CheckEconomicIndicator() {
 
    if(g_eventCount == 0) return false;  // 저장된 이벤트가 없으면 false
    
    datetime currentTime = TimeLocal();
    
    bool shouldPause = false;
    string activeEvents = "";  // 현재 활성화된 이벤트들을 저장
    int activeCount = 0;      // 활성화된 이벤트 수
    
    // 모든 저장된 이벤트 확인
    for(int i = 0; i < g_eventCount; i++) {
        // 빈 이벤트 스킵
        //Print("\n=== 이벤트 [", i, "] 상세 정보 ===");
        //Print("시간: ", g_events[i].time);
        //Print("이름: ", g_events[i].name);
        //Print("DateTime: ", TimeToStr(g_events[i].dateTime));
        if(g_events[i].dateTime == 0) continue;
        
        int minutesUntil = (int)((g_events[i].dateTime - currentTime) / 60);
        Print("minutesUntil",minutesUntil);
        // 이벤트가 1시간 이내에 있으면 거래 중지
        if(minutesUntil >= 0 && minutesUntil <= 60) {
            shouldPause = true;
            activeCount++;
            
            // 활성화된 이벤트 정보 저장
            activeEvents += StringFormat("\n%d) %s - %s (%d분 남음)", 
                activeCount, g_events[i].time, g_events[i].name, minutesUntil);
            if (!eventTriggered){
               Alert(
                "=== 경제지표 발표 예정 ===\n",
                "발견된 지표 수: ", g_eventCount, "\n",
                "현재 시간: ", TimeToStr(currentTime), "\n",
                "지표명: ", g_events[i].name, "\n",
                "발표시간: ", g_events[i].time, "\n",
                "남은시간: ", minutesUntil, "분"
               );
               eventTriggered = true;
            }
            
            
        }
        // 이벤트가 지났는지 확인 (-1분 여유 시간 추가)
        else if(minutesUntil < -1) {
            // 지난 이벤트는 초기화
            g_events[i].dateTime = 0;
            g_events[i].time = "";
            g_events[i].name = "";
        }
    }
    
    // 활성화된 이벤트가 있으면 Comment 업데이트
    if(shouldPause) {
        string remainTime = "";
        if(activeCount > 0) {
            remainTime = "\n=== 활성화된 경제지표 ===";
            remainTime += activeEvents;
        }
        
        Comment(
            "경제지표 발표로 인한 신규 진입 제한\n",
            "활성화된 지표 수: ", activeCount,
            remainTime, "\n",
            "최대 손실: ", DoubleToString(saveTotalProfit, 2), "\n",
            "현재 수익금(실시간): ", DoubleToString(totalProfit, 2)
        );
    }
    
    // 모든 이벤트가 지났고 거래가 멈춰있었다면 재개
    if(!shouldPause && eventTriggered) {
        eventTriggered = false;
        blockNewTrades = false;
        Print("=== 모든 경제지표 발표 완료 ===");
        Print("거래가 자동으로 재개됩니다.");
    }
    
    return shouldPause;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
   // 1) 서버 검증 로직 (원하면 주석 해제)
   datetime localTime = TimeLocal();    // 로컬 PC 시간
   datetime serverTime = TimeCurrent(); // 서버 시간
   
   Print("=== 시간 정보 ===");
   Print("로컬 시간: ", TimeToString(localTime));
   Print("서버 시간: ", TimeToString(serverTime));
   Print("시차(시간): ", (localTime - serverTime)/3600);
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

   // 2) 경제지표 데이터 미리 체크
   datetime currentTime = TimeLocal();
   string currentDate = TimeToStr(currentTime, TIME_DATE);
   // string currentDate = "2025.03.11";
   Print("currentDate",currentDate);
   CheckAndUpdateEconomicEvents();

   // 3) 버튼 생성
   CreateToggleButton("startStopButton", 100, 10, "시작", clrRed);
   CreateButton("closeButton", 100, 30, "전체 청산", clrGray);
   CreateButton("resumeButton", 100, 50, "거래재개", clrGray);  // 거래재개 버튼 추가

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
   CheckAndUpdateEconomicEvents();
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
   CheckAndUpdateEconomicEvents();
   // 버튼 클릭 확인 (거래재개 버튼)
   if (ObjectGetInteger(0, "resumeButton", OBJPROP_STATE) == 1) {
      indicatorPause = false;  // 경제지표 일시정지 해제
      indicatorManualPause = !indicatorManualPause;
      ObjectSetInteger(0, "resumeButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
      Print("거래가 수동으로 재개되었습니다.");
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
   // 손실이 설정된 한도를 초과하면 청산 버튼의 테두리와 글씨 색을 빨간색으로 변경
   if (totalProfit <= maxLossThreshold) {
      ObjectSetInteger(0, "closeButton", OBJPROP_BGCOLOR, clrRed);  // 글자 색상 빨간색
      ObjectSetInteger(0, "closeButton", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   } else {
      ObjectSetInteger(0, "closeButton", OBJPROP_BGCOLOR, clrGray); // 정상 상태에서는 회색
   }
   if (indicatorManualPause) {
      ObjectSetInteger(0, "resumeButton", OBJPROP_BGCOLOR, clrRed);  // 글자 색상 빨간색
      ObjectSetInteger(0, "resumeButton", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   } else {
      ObjectSetInteger(0, "resumeButton", OBJPROP_BGCOLOR, clrGray); // 정상 상태에서는 회색
   }
 
   double currentUpper, currentLower;
   GetCurrentRSILevels(currentUpper, currentLower);
   
   if (ObjectGetInteger(0, "closeButton", OBJPROP_STATE) == 1) {
      CloseAllPositions();  // 매직 넘버 기준으로 모든 포지션 청산
      ObjectSetInteger(0, "closeButton", OBJPROP_STATE, 0);  // 버튼 상태 초기화
      Print("매직 넘버 기반 포지션 청산 완료");
      OpenedPosition = 0;
      hedgecount = 0;
      firstOpenPrice = 0;
      firstHedge = true;
      firstEntry = true;  // 다시 첫 진입 가능하게 설정
      return;
   }
   // 0) UserCheck 미통과면 종료
   if (!User_Mac) {
      return;
   }
   
   // 경제지표 체크
   if(!indicatorManualPause) {  // 수동 일시정지가 아닐 때만 체크
      indicatorPause = CheckEconomicIndicator();
   }

   // 총 손익 계산
   totalProfit = 0;
   currentTradeCount = 0;
   double totalLots = 0; // 진입된 총 랏 수
   for(int i = 0; i < OrdersTotal(); i++) {
      if(OrderSelect(i, SELECT_BY_POS,MODE_TRADES) && OrderMagicNumber() == magicNumber) {
      
         totalProfit += OrderProfit();
         totalLots += OrderLots(); // 진입된 총 랏 수 계산
         if (OpenedPosition > 0){
            if(OrderType() == OP_BUY){
               currentTradeCount++;      // 현재 열린 거래 수 증가
            }
         }else if(OpenedPosition < 0){
            if(OrderType() == OP_SELL){
               currentTradeCount++;      // 현재 열린 거래 수 증가
            }
         }
         
      }
   }
   if (saveTotalProfit > totalProfit){
      saveTotalProfit = totalProfit;
   }
   
   
   if(indicatorPause) {
      string remainTime = "";
      if(savedEventDateTime > 0) {
         int mins = (int)((savedEventDateTime - TimeLocal()) / 60);
         if(mins > 0) {
            remainTime = "\n발표까지 남은 시간: " + IntegerToString(mins) + "분";
         } else {
            remainTime = "\n잠시 후 자동으로 거래가 재개됩니다.";
         }
      }
      
      // 익절 조건 확인
      double result2 = profitTarget;
      if (currentTradeCount != 0) {
         int quotient2 = (int)(currentTradeCount / dividingFactor);
         result2 = ((quotient2 * multiplyFactor) + 1) * profitTarget;
      }
      
      // 익절 조건 만족 시 청산
      if(totalProfit >= result2) {
         CloseAllPositions();
         OpenedPosition = 0;
         firstOpenPrice = 0;
         hedgecount = 0;
         firstHedge = true;
         firstEntry = true;
         Print("경제지표 발표 중 익절 조건 달성으로 청산");
      }
      
      Comment(
         "경제지표 발표로 인한 신규 진입 제한\n",
         "지표명: ", savedEventName, "\n",
         "발표시간: ", savedEventTime,
         remainTime, "\n",
         "최대 손실: ", DoubleToString(saveTotalProfit, 2), "\n",
         "현재 수익금(실시간): ", DoubleToString(totalProfit, 2)
      );
      return;
   }

   if (!tradingEnabled) {
      return;  // 거래가 정지되면 아래 로직 실행 안 함
   }

   double rsi = iRSI(NULL, 0, 14, PRICE_CLOSE, 0);
   
      // 매직넘버 히스토리 오늘 수익 계산
   double todayMagicProfit = GetTodayMagicProfit(magicNumber);
   
   // 일일 목표 수익 계산 및 체크
   if(todayMagicProfit >= dailyProfitTarget) {
      // 열린 포지션 모두 청산
      CloseAllPositions();
      
      // 변수 초기화
      OpenedPosition = 0;
      hedgecount = 0;
      firstOpenPrice = 0;
      firstHedge = true;
      firstEntry = true;
      
      // 거래 비활성화
      tradingEnabled = false;
      
      // 버튼 상태 업데이트
      ObjectSetString(0, "startStopButton", OBJPROP_TEXT, "시작");
      ObjectSetInteger(0, "startStopButton", OBJPROP_COLOR, clrRed);
      
      // 메시지 표시
      Comment(
         "=== 일일 목표 수익 달성 ===\n",
         "목표 수익: ", DoubleToString(dailyProfitTarget, 2), "\n",
         "달성 수익: ", DoubleToString(todayMagicProfit, 2), "\n",
         "거래가 자동으로 정지되었습니다."
      );
      
      Print("=== 일일 목표 수익 달성으로 거래 정지 ===");
      Print("목표 수익: ", DoubleToString(dailyProfitTarget, 2));
      Print("달성 수익: ", DoubleToString(todayMagicProfit, 2));
      
      return;  // 추가 거래 방지
   }
   
   // 기존 Comment 수정 (수익 정보에 목표 수익 추가)
   Comment(
      "최대 손실 : ",DoubleToString(saveTotalProfit, 2),
      "\n현재 수익금(실시간): ", DoubleToString(totalProfit, 2),
      "\n오늘 실현 손익(매직넘버): ", DoubleToString(todayMagicProfit, 2),
      "\n값: ", DoubleToString(rsi, 2),
      "\n일일 목표 수익: ", DoubleToString(dailyProfitTarget, 2),
      "\n남은 목표 금액: ", DoubleToString(dailyProfitTarget - todayMagicProfit, 2),
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
      OpenedPosition = 0;
      firstOpenPrice = 0;
      hedgecount = 0;
      firstHedge = true;
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
         firstOpenPrice = Ask;
         OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
         OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
         firstEntry = false; // 첫 진입 이후는 RSI를 사용하지 않음
         OpenedPosition = 1;
         currentTradeCount++;
      }
      else if(rsi > currentUpper) {
         // 숏 포지션 첫 진입
         OpenPrice = Bid;
         firstOpenPrice = Bid;
         OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
         OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
         firstEntry = false; // 첫 진입 이후는 RSI를 사용하지 않음
         OpenedPosition = -1;
         currentTradeCount++;
      }
   } else {
      // 추가 진입: 포지션에 따라 진입 조건 변경
      double priceDifference = 0;
      double firstPriceDifference = 0;
      if(OpenedPosition > 0) {
         priceDifference = (OpenPrice - Ask) / Point;
         firstPriceDifference = (firstOpenPrice - Ask) / Point;
         if (firstHedge){
            if(firstPriceDifference <= -pointDistance){
               OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
               firstHedge = false;
            }else if(currentTradeCount == hedgeInterval){
               OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
               firstHedge = false;
            }
         }else if (!firstHedge &&currentTradeCount == hedgeInterval + hedgecount){
            OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
            hedgecount = hedgecount + addHedgeCount;
         }
         if(priceDifference >= pointDistance && currentTradeCount < maxTrades) {
            AddMartingaleOrders(OP_BUY);  // 롱 포지션에 추가 진입
         }
      }
      else if(OpenedPosition < 0) {
         priceDifference = (Bid - OpenPrice) / Point;
         firstPriceDifference = (Bid - firstOpenPrice) / Point;
         if (firstHedge){
            if(firstPriceDifference <= -pointDistance){
               OrderSend(Symbol(), OP_SELL, initialLotSize, Bid, 3, 0, 0, "", magicNumber, 0, Red);
               firstHedge = false;
            }else if(currentTradeCount == hedgeInterval){
               OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
               firstHedge = false;
            }
         }else if (!firstHedge &&currentTradeCount == hedgeInterval + hedgecount){
            OrderSend(Symbol(), OP_BUY, initialLotSize, Ask, 3, 0, 0, "", magicNumber, 0, Blue);
            hedgecount = hedgecount + addHedgeCount;
         }
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
