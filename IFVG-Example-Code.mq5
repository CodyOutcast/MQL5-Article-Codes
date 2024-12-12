//NQ-3
string previousGapObjName = "";
double previousGapHigh = 0.0;
double previousGapLow = 0.0;
int LastGapIndex = 0;
double gapHigh = 0.0;
double gapLow = 0.0;
double gap = 0.0;
double lott= 0.1;
ulong buypos = 0, sellpos = 0;
double anyGap = 0.0;
double anyGapHigh = 0.0;
double anyGapLow = 0.0;
int barsTotal = 0;
int newFVGformed = 0;
int currentFVGstatus = 0;
int handleMa;

#include <Trade/Trade.mqh>
CTrade trade;

input int gapMaxPoint = 1100;
input int gapMinPoint = 500;
input int startHour = 14;
input int endHour = 19;
input int maxBreakoutPoints =400;
input int MaPeriods = 400;
input int lookBack = 16;
input int tpp = 2500;
input int slp = 1700;
input int Magic = 0;

//+------------------------------------------------------------------+
//| Initializer function                                             |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(Magic);
   handleMa =iMA(_Symbol,PERIOD_CURRENT,MaPeriods,0,MODE_SMA,PRICE_CLOSE);  
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Destructor function                                              |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   
  }

//+------------------------------------------------------------------+
//| OnTick function                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {
  int bars = iBars(_Symbol,PERIOD_CURRENT);
  if (barsTotal!= bars){
     barsTotal = bars;
     double ma[];
     double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
     double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
     CopyBuffer(handleMa,BASE_LINE,1,1,ma);
     
     if (IsBrokenLow()&&sellpos == buypos&&newFVGformed ==1&&bid<ma[0]){
          executeSell();
          newFVGformed =0;
        }  
     else if (IsBrokenUp()&&sellpos == buypos&&newFVGformed ==1&&ask>ma[0]){
         executeBuy();
         newFVGformed =0;
       }
       
     getFVG();
     
     if(buypos>0&&(!PositionSelectByTicket(buypos)|| PositionGetInteger(POSITION_MAGIC) != Magic)){
     buypos = 0;
     }
     if(sellpos>0&&(!PositionSelectByTicket(sellpos)|| PositionGetInteger(POSITION_MAGIC) != Magic)){
     sellpos = 0;
     }
     
  }
}

//+------------------------------------------------------------------+
//| To get the most recent Fair Value Gap (FVG)                      |
//+------------------------------------------------------------------+
void getFVG()
{
    // Loop through the bars to find the most recent FVG
    for (int i = 1; i < 3; i++)
    {
        datetime currentTime = iTime(_Symbol,PERIOD_CURRENT, i);
        datetime previousTime = iTime(_Symbol,PERIOD_CURRENT, i + 2);
        // Get the high and low of the current and previous bars
        double currentLow = iLow(_Symbol,PERIOD_CURRENT, i);
        double previousHigh = iHigh(_Symbol,PERIOD_CURRENT, i+2);
        
        double currentHigh = iHigh(_Symbol,PERIOD_CURRENT, i);
        double previousLow = iLow(_Symbol,PERIOD_CURRENT, i+2);
        anyGap = MathAbs(previousLow - currentHigh);
        // Check for an upward gap
        if (currentLow > previousHigh)
        {   
             anyGapHigh = currentLow;
             anyGapLow = previousHigh;
        //Check for singular
            if (LastGapIndex != i){
               if (IsGapValid()){
                  
                  gapHigh = currentLow;
                  gapLow = previousHigh;
                  gap = anyGap;
                  currentFVGstatus = 1;//bullish FVG
                 
                  DrawGap(previousTime,currentTime,gapHigh,gapLow);
                  LastGapIndex = i;
                  newFVGformed =1;
                  return;
               }
            }   
        }
        
        // Check for a downward gap
        else if (currentHigh < previousLow)
        {
          anyGapHigh = previousLow;
          anyGapLow = currentHigh;
           if (LastGapIndex != i){
             if(IsGapValid()){
                  gapHigh = previousLow;
                  gapLow = currentHigh;
                  gap = anyGap;
                  currentFVGstatus = -1;
                  DrawGap(previousTime,currentTime,gapHigh,gapLow);
                  LastGapIndex = i;
                  newFVGformed =1;
                  return;
            }
        }
        
       } 
    }
    

}



//+------------------------------------------------------------------+
//|     Function to draw the FVG gap on the chart                    |
//+------------------------------------------------------------------+
void DrawGap(datetime timeStart, datetime timeEnd, double gaphigh, double gaplow)
{
    // Delete the previous gap object if it exists
    if (previousGapObjName != "")
    {
        ObjectDelete(0, previousGapObjName);
    }
    
    // Generate a new name for the gap object
    previousGapObjName = "FVG_" + IntegerToString(TimeCurrent());
    
    // Create a rectangle object to highlight the gap
    ObjectCreate(0, previousGapObjName, OBJ_RECTANGLE, 0, timeStart, gaphigh, timeEnd, gaplow);
    
    // Set the properties of the rectangle
    ObjectSetInteger(0, previousGapObjName, OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, previousGapObjName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, previousGapObjName, OBJPROP_WIDTH, 2);
    ObjectSetInteger(0, previousGapObjName, OBJPROP_RAY, false);
    
    // Update the previous gap information
    previousGapHigh = gaphigh;
    previousGapLow = gaplow;
    
    
}

//+------------------------------------------------------------------+
//|     Function to validate the FVG gap                             |
//+------------------------------------------------------------------+
bool IsGapValid(){
  if (anyGap<=gapMaxPoint*_Point && anyGap>=gapMinPoint*_Point&&IsReacted()) return true;  
  else return false;
}

//+------------------------------------------------------------------+
//|     Check for gap reaction to validate its strength              |
//+------------------------------------------------------------------+
bool IsReacted(){
  int count1 = 0;
  int count2 = 0;
  for (int i = 4; i < lookBack; i++){
    double aLow = iLow(_Symbol,PERIOD_CURRENT,i);
    double aHigh = iHigh(_Symbol,PERIOD_CURRENT,i);
    if   (aHigh<anyGapHigh&&aHigh>anyGapLow&&aLow<anyGapLow){
      count1++;
      
    }
    else if (aLow<anyGapHigh&&aLow>anyGapLow&&aHigh>anyGapHigh){
      count2++;
    }
  
  }
  if (count1>=2||count2>=2) return true;
  else return false;

}

//+------------------------------------------------------------------+
//|     Check if price broke out to the upside of the gap            |
//+------------------------------------------------------------------+
bool IsBrokenUp(){
    int lastClosedIndex = 1;
    double lastOpen = iOpen(_Symbol, PERIOD_CURRENT, lastClosedIndex);
    double lastClose = iClose(_Symbol, PERIOD_CURRENT, lastClosedIndex);
    if (lastOpen < gapHigh && lastClose > gapHigh&&(lastClose-gapHigh)<maxBreakoutPoints*_Point)
    {
      if(currentFVGstatus==-1){
        return true;}
    }
    return false;
}

//+------------------------------------------------------------------+
//|     Check if price broke out to the downside of the gap          |
//+------------------------------------------------------------------+
bool IsBrokenLow(){
    int lastClosedIndex = 1;
    double lastOpen = iOpen(_Symbol, PERIOD_CURRENT, lastClosedIndex);
    double lastClose = iClose(_Symbol, PERIOD_CURRENT, lastClosedIndex);
    
    if (lastOpen > gapLow && lastClose < gapLow&&(gapLow -lastClose)<maxBreakoutPoints*_Point)
    { 
       if(currentFVGstatus==1){
        return true;}
    }
    return false;


}

//+------------------------------------------------------------------+
//|     Store order ticket number into buypos/sellpos variables      |
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
//| Execute sell trade function                                       |
//+------------------------------------------------------------------+
void executeSell() {
    if (IsWithinTradingHours()){
       double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
       bid = NormalizeDouble(bid,_Digits);
       double tp = bid - tpp * _Point;
       tp = NormalizeDouble(tp, _Digits);
       double sl = bid + slp * _Point;
       sl = NormalizeDouble(sl, _Digits);    
       trade.Sell(lott,_Symbol,bid,sl,tp);
       sellpos = trade.ResultOrder();
       
       }
    }

//+------------------------------------------------------------------+
//| Execute buy trade function                                       |
//+------------------------------------------------------------------+
void executeBuy() {
    if (IsWithinTradingHours()){
       double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
       ask = NormalizeDouble(ask,_Digits);
       double tp = ask + tpp * _Point;
       tp = NormalizeDouble(tp, _Digits);
       double sl = ask - slp * _Point;
       sl = NormalizeDouble(sl, _Digits);
       trade.Buy(lott,_Symbol,ask,sl,tp);
       buypos= trade.ResultOrder();
       }
    }

//+------------------------------------------------------------------+
//| Check if is trading hours                                        |
//+------------------------------------------------------------------+
bool IsWithinTradingHours()
{
    datetime currentTime = TimeTradeServer(); 
    MqlDateTime timeStruct;
    TimeToStruct(currentTime, timeStruct);
    int currentHour = timeStruct.hour;
    if (currentHour >= startHour && currentHour < endHour)
        return true;
    else
        return false;
}