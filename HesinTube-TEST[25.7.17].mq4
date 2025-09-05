//+------------------------------------------------------------------+
//|                                           HesinTube-TEST[25.7.17].mq4 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

// 입력 매개변수
input double LotSize = 0.01;           // 거래량
input int MinPoints = 100;             // 최소 포인트 (진입 조건)
input int StartPoint = 10;             // 시작 포인트 (진입 조건)
input double TakeProfit = 50.0;        // 익절 목표 (달러)
input double LotMartinMultiplier = 2.0; // 거래량 마틴게일 배수
input double ProfitMartinMultiplier = 2.0; // 익절금액 마틴게일 배수
input int MaxMartinLevel = 5;          // 최대 마틴게일 레벨
input int MagicNumber = 123456;        // 매직 넘버

// 전역 변수
datetime LastProfitTime = 0;           // 마지막 익절 시간
bool CanTrade = true;                  // 거래 가능 여부
int CandleCount = 0;                   // 익절 후 캔들 카운트
int MartinLevel = 0;                   // 현재 마틴게일 레벨
double CurrentLotSize = 0;             // 현재 거래량
double CurrentTakeProfit = 0;          // 현재 익절 목표

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("HesinTube EA 시작됨");
    
    // 초기 거래량과 익절 목표 설정
    CurrentLotSize = LotSize;
    CurrentTakeProfit = TakeProfit;
    MartinLevel = 0;
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    Print("HesinTube EA 종료됨");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // 현재 포지션이 있으면 항상 익절 확인 (틱마다)
    if(HasOpenPosition())
    {
        CheckTakeProfit();
        return;
    }
    
    // 익절 후 재진입 제한 확인
    CheckReentryCondition();
    
    // 거래 가능 상태가 아니면 리턴
    if(!CanTrade) return;
    
    // 진입 조건 확인 (현재 진행중인 캔들 포함하므로 틱마다 확인)
    CheckEntryCondition();
}

//+------------------------------------------------------------------+
//| 현재 포지션이 있는지 확인                                        |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                return true;
            }
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| 익절 조건 확인                                                   |
//+------------------------------------------------------------------+
void CheckTakeProfit()
{
    double totalProfit = 0;
    
    // 모든 포지션의 수익 합계 계산
    for(int i = 0; i < OrdersTotal(); i++)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                totalProfit += OrderProfit() + OrderSwap() + OrderCommission();
            }
        }
    }
    
    // 디버깅을 위한 실시간 수익 출력 (10초마다)
    static datetime lastPrintTime = 0;
    if(TimeCurrent() - lastPrintTime >= 10)
    {
        Print("현재 수익: $", DoubleToStr(totalProfit, 2), " / 목표: $", DoubleToStr(CurrentTakeProfit, 2), " 마틴레벨: ", MartinLevel, " 거래량: ", DoubleToStr(CurrentLotSize, 2));
        lastPrintTime = TimeCurrent();
    }
    
    // 목표 수익에 도달하면 전체 청산
    if(totalProfit >= CurrentTakeProfit)
    {
        CloseAllPositions();
        LastProfitTime = Time[0];
        CanTrade = false;
        CandleCount = 0;
        
        // 익절 시 마틴게일 레벨 초기화
        MartinLevel = 0;
        CurrentLotSize = LotSize;
        CurrentTakeProfit = TakeProfit;
        
        Print("목표 수익 달성! 전체 청산. 수익: $", DoubleToStr(totalProfit, 2), " 마틴레벨 초기화");
    }
    // 손실이 CurrentTakeProfit 이상이면 손절
    else if(totalProfit <= -CurrentTakeProfit)
    {
        CloseAllPositions();
        LastProfitTime = Time[0];
        CanTrade = false;
        CandleCount = 0;
        
        // 손절 시 마틴게일 레벨 증가
        if(MartinLevel < MaxMartinLevel)
        {
            MartinLevel++;
            CurrentLotSize = LotSize * MathPow(LotMartinMultiplier, MartinLevel);
            CurrentTakeProfit = TakeProfit * MathPow(ProfitMartinMultiplier, MartinLevel);
            Print("손절 실행! 마틴레벨 증가: ", MartinLevel, " 다음 거래량: ", DoubleToStr(CurrentLotSize, 2), " 다음 목표: $", DoubleToStr(CurrentTakeProfit, 2));
        }
        else
        {
            // 최대 마틴게일 레벨 도달 시 초기화
            MartinLevel = 0;
            CurrentLotSize = LotSize;
            CurrentTakeProfit = TakeProfit;
            Print("최대 마틴레벨 도달! 초기화됨. 손실: $", DoubleToStr(totalProfit, 2));
        }
    }
}

//+------------------------------------------------------------------+
//| 모든 포지션 청산                                                 |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
    for(int i = OrdersTotal() - 1; i >= 0; i--)
    {
        if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
            if(OrderSymbol() == Symbol() && OrderMagicNumber() == MagicNumber)
            {
                bool result = false;
                if(OrderType() == OP_BUY)
                {
                    result = OrderClose(OrderTicket(), OrderLots(), Bid, 0, clrRed);
                }
                else if(OrderType() == OP_SELL)
                {
                    result = OrderClose(OrderTicket(), OrderLots(), Ask, 0, clrBlue);
                }
                
                if(!result)
                {
                    Print("포지션 청산 실패: ", GetLastError());
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| 재진입 조건 확인                                                 |
//+------------------------------------------------------------------+
void CheckReentryCondition()
{
    if(!CanTrade && LastProfitTime > 0)
    {
        // 익절 후 2개의 새로운 캔들이 생성되었는지 확인
        int barsAfterProfit = iBarShift(Symbol(), PERIOD_M1, LastProfitTime, false);
        
        if(barsAfterProfit >= 2)
        {
            CanTrade = true;
            Print("재진입 가능 상태로 변경됨");
        }
    }
}

//+------------------------------------------------------------------+
//| 진입 조건 확인                                                   |
//+------------------------------------------------------------------+
void CheckEntryCondition()
{
    // 최소 3개의 캔들이 필요 (현재 진행중인 캔들 포함)
    if(Bars < 3) return;
    
    // 캔들 방향 확인 (양봉: true, 음봉: false)
    bool candle2_bullish = Close[2] > Open[2]; // 2번째 이전 캔들 (완성된 캔들)
    bool candle1_bullish = Close[1] > Open[1]; // 1번째 이전 캔들 (완성된 캔들)
    
    // 연속된 2개의 같은 방향 캔들 확인
    if(candle2_bullish && candle1_bullish)
    {
        // 2개의 연속 양봉 - 상승 추세
        // 0번 캔들의 시작점(Open[0])에서 현재가(Close[0])까지의 움직임 확인
        double totalMove = Close[0] - Open[0];
        if(totalMove >= StartPoint * Point)
        {
            OpenBuyOrder();
        }
    }
    else if(!candle2_bullish && !candle1_bullish)
    {
        // 2개의 연속 음봉 - 하락 추세
        // 0번 캔들의 시작점(Open[0])에서 현재가(Close[0])까지의 움직임 확인
        double totalMove = Open[0] - Close[0];
        if(totalMove >= StartPoint * Point)
        {
            OpenSellOrder();
        }
    }
}

//+------------------------------------------------------------------+
//| 매수 주문 실행                                                   |
//+------------------------------------------------------------------+
void OpenBuyOrder()
{
    double price = Ask;
    int ticket = OrderSend(Symbol(), OP_BUY, CurrentLotSize, price, 0, 0, 0, 
                          "HesinTube Buy L" + IntegerToString(MartinLevel), MagicNumber, 0, clrGreen);
    
    if(ticket > 0)
    {
        Print("매수 주문 성공. 티켓: ", ticket, " 가격: ", DoubleToStr(price, Digits));
    }
    else
    {
        Print("매수 주문 실패. 에러: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| 매도 주문 실행                                                   |
//+------------------------------------------------------------------+
void OpenSellOrder()
{
    double price = Bid;
    int ticket = OrderSend(Symbol(), OP_SELL, CurrentLotSize, price, 0, 0, 0, 
                          "HesinTube Sell L" + IntegerToString(MartinLevel), MagicNumber, 0, clrRed);
    
    if(ticket > 0)
    {
        Print("매도 주문 성공. 티켓: ", ticket, " 가격: ", DoubleToStr(price, Digits));
    }
    else
    {
        Print("매도 주문 실패. 에러: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| 캔들 방향 확인 함수                                             |
//+------------------------------------------------------------------+
bool IsBullishCandle(int index)
{
    return Close[index] > Open[index];
}

//+------------------------------------------------------------------+
//| 캔들 방향 확인 함수                                             |
//+------------------------------------------------------------------+
bool IsBearishCandle(int index)
{
    return Close[index] < Open[index];
}
