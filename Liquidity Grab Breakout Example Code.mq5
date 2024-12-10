#include <Trade/Trade.mqh>
CTrade trade;

//GBPUSD-M5

input int tpp = 300;
input int slp = 200;

ulong buypos = 0, sellpos = 0;
input double lott = 0.1;
input int Magic = 0;
int barsTotal = 0;
input int BarsN = 3;

input int MaPeriods = 200;
input int DistanceRange = 100;

input int startHour1 = 13;
input int endHour1 = 14;
input int startHour2 = 17;
input int endHour2 = 19;

input double wickToBodyRatio = 4.0;
input int CandlesBeforeBreakout = 20;
int handleMa;


//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit() {
    trade.SetExpertMagicNumber(Magic);
    handleMa = iMA(_Symbol, PERIOD_CURRENT, MaPeriods, 0, MODE_SMA,PRICE_CLOSE);
    
    if (handleMa == INVALID_HANDLE) {
        Print("Failed to get indicator handles. Error: ", GetLastError());
        return INIT_FAILED;
    }
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // Clean up resources if necessary
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick() {
    int bars = iBars(_Symbol, PERIOD_CURRENT);
    if (barsTotal != bars) {
        barsTotal = bars;

        double ma[];
        
        double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);


        if (CopyBuffer(handleMa, 0, 1, 1, ma) <= 0) {
            Print("Failed to copy MA data. Error: ", GetLastError());
            return;
        }
        if(WasRejectionDown()&&IsWithinTradingHours()&&sellpos==buypos&&bid<ma[0]&&bid<findlow(CandlesBeforeBreakout))
        executeSell();
        else if(WasRejectionUp()&&IsWithinTradingHours()&&sellpos==buypos&&ask>ma[0]&&ask>findhigh(CandlesBeforeBreakout))
        executeBuy();
        
     if(buypos>0&&(!PositionSelectByTicket(buypos)|| PositionGetInteger(POSITION_MAGIC) != Magic)){
      buypos = 0;
      }
     if(sellpos>0&&(!PositionSelectByTicket(sellpos)|| PositionGetInteger(POSITION_MAGIC) != Magic)){
      sellpos = 0;
      }
    }
}

//+------------------------------------------------------------------+
//| Expert trade transaction handling function                       |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans, const MqlTradeRequest& request, const MqlTradeResult& result) {
    if (trans.type == TRADE_TRANSACTION_ORDER_ADD) {
        COrderInfo order;
        if (order.Select(trans.order)) {
            if (order.Magic() == Magic) {
                if (order.OrderType() == ORDER_TYPE_BUY) {
                    buypos = order.Ticket();
                } else if (order.OrderType() == ORDER_TYPE_SELL) {
                    sellpos = order.Ticket();
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check if the current time is within the specified trading hours |
//+------------------------------------------------------------------+
bool IsWithinTradingHours() {
    datetime currentTime = TimeTradeServer();
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    int currentHour = timeStruct.hour;

    if (( currentHour >= startHour1 && currentHour < endHour1) ||
        ( currentHour >= startHour2 && currentHour < endHour2))
         {
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Execute sell trade function                                       |
//+------------------------------------------------------------------+
void executeSell() {
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    bid = NormalizeDouble(bid, _Digits);
    double tp = NormalizeDouble(bid - tpp * _Point, _Digits);
    double sl = NormalizeDouble(bid + slp * _Point, _Digits);
    trade.Sell(lott, _Symbol, bid, sl, tp);
    sellpos = trade.ResultOrder();
}

//+------------------------------------------------------------------+
//| Execute buy trade function                                       |
//+------------------------------------------------------------------+
void executeBuy() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    ask = NormalizeDouble(ask, _Digits);
    double tp = NormalizeDouble(ask + tpp * _Point, _Digits);
    double sl = NormalizeDouble(ask - slp * _Point, _Digits);
    trade.Buy(lott, _Symbol, ask, sl, tp);
    buypos = trade.ResultOrder();
}

    
//+------------------------------------------------------------------+
//| Check if the market rejected in the upward direction             |
//+------------------------------------------------------------------+
bool IsRejectionUp(int shift=1)
{
   // Get the values of the last candle (shift = 1)
   double open = iOpen(_Symbol,PERIOD_CURRENT, shift);
   double close = iClose(_Symbol,PERIOD_CURRENT, shift);
   double high = iHigh(_Symbol,PERIOD_CURRENT, shift);
   double low = iLow(_Symbol,PERIOD_CURRENT,shift);
   
   // Calculate the body size
   double bodySize = MathAbs(close - open);
   
   // Calculate the lower wick size
   double lowerWickSize = open < close ? open - low : close - low;
   
   // Check if the lower wick is significantly larger than the body
   if (lowerWickSize >= wickToBodyRatio * bodySize&&low<findlow(DistanceRange)&&high>findlow(DistanceRange))
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if the market rejected in the downward direction           |
//+------------------------------------------------------------------+
bool IsRejectionDown(int shift = 1)
{
   // Get the values of the last candle (shift = 1)
   double open = iOpen(_Symbol,PERIOD_CURRENT, shift);
   double close = iClose(_Symbol,PERIOD_CURRENT, shift);
   double high = iHigh(_Symbol,PERIOD_CURRENT, shift);
   double low = iLow(_Symbol,PERIOD_CURRENT,shift);
   
   
   // Calculate the body size
   double bodySize = MathAbs(close - open);
   
   // Calculate the upper wick size
   double upperWickSize = open > close ? high - open : high - close;
   
   // Check if the upper wick is significantly larger than the body
   if (upperWickSize >= wickToBodyRatio * bodySize&&high>findhigh(DistanceRange)&&low<findhigh(DistanceRange))
   {
      return true;
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| find the key level high given a look-back period                 |
//+------------------------------------------------------------------+
double findhigh(int Range = 0)
{
   double highesthigh = 0;
   for (int i = BarsN; i < Range; i++)
   {
      double high = iHigh(_Symbol, PERIOD_CURRENT, i);
      if (i > BarsN && iHighest(_Symbol, PERIOD_CURRENT, MODE_HIGH, BarsN * 2 + 1, i - BarsN) == i)
      //used to make sure there's rejection for this high
      {
         if (high > highesthigh)
         {
            return high;
         }
      }
      highesthigh = MathMax(highesthigh, high);
   }
   return 99999;
}

//+------------------------------------------------------------------+
//| find the key level low given a look-back period                  |
//+------------------------------------------------------------------+
double findlow(int Range = 0)
{
   double lowestlow = DBL_MAX;
   for (int i = BarsN; i < Range; i++)
   {
      double low = iLow(_Symbol, PERIOD_CURRENT, i);
      if (i > BarsN && iLowest(_Symbol, PERIOD_CURRENT, MODE_LOW, BarsN * 2 + 1, i - BarsN) == i)
      {
         if (lowestlow > low)
         {
            return low;
         }
      }
      lowestlow = MathMin(lowestlow, low);
   }
   return -1;
}

//+------------------------------------------------------------------+
//| check if there were rejection up for the short look-back period  |
//+------------------------------------------------------------------+
bool WasRejectionUp(){
   for(int i=1; i<CandlesBeforeBreakout;i++){
     if(IsRejectionUp(i))
        return true;  
   }
    return false;
}


//+------------------------------------------------------------------+
//| check if there were rejection down for the short look-back period|
//+------------------------------------------------------------------+
bool WasRejectionDown(){
   for(int i=1; i<CandlesBeforeBreakout;i++){
     if(IsRejectionDown(i))
        return true;  
   }
    return false;


}