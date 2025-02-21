#include <Trade/Trade.mqh>
CTrade trade;

input double mv = 10;
input double pv = 1.0;
input int Magic = 0;
input int bbPeriod = 100;
input double d = 2.0;
input int maPeriod = 500;

double prev_state;       // Previous estimated price
double prev_covariance = 1;  // Previous covariance (uncertainty)
int barsTotal = 0;
int handleMa;
int handleBb;

//+------------------------------------------------------------------+
//| Initialization                                        |
//+------------------------------------------------------------------+
int OnInit()
{   handleMa = iMA(_Symbol,PERIOD_CURRENT,maPeriod,0,MODE_EMA,PRICE_CLOSE);
    handleBb = iBands(_Symbol,PERIOD_CURRENT,bbPeriod,0,d,PRICE_CLOSE);
    prev_state = iClose(_Symbol,PERIOD_CURRENT,1);  
    trade.SetExpertMagicNumber(Magic);
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Deinitializer function                                           |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
  }

//+------------------------------------------------------------------+
//| OnTick Function                                                 |
//+------------------------------------------------------------------+
void OnTick()
{
  int bars = iBars(_Symbol,PERIOD_CURRENT);
  
  if (barsTotal!= bars){
     barsTotal = bars;
     bool NotInPosition = true;
     double price = iClose(_Symbol,PERIOD_CURRENT,1); 
     double bbLower[], bbUpper[], bbMiddle[];
     double ma[];
     double kalman = KalmanFilter(price,mv,pv);
     
     CopyBuffer(handleMa,0,1,1,ma);
     CopyBuffer(handleBb,UPPER_BAND,1,1,bbUpper);
     CopyBuffer(handleBb,LOWER_BAND,1,1,bbLower);
     CopyBuffer(handleBb,0,1,1,bbMiddle);
     
     for(int i = 0; i<PositionsTotal(); i++){
         ulong pos = PositionGetTicket(i);
         string symboll = PositionGetSymbol(i);
         if(PositionGetInteger(POSITION_MAGIC) == Magic&&symboll== _Symbol){
            NotInPosition = false;
            if((PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY&&price>bbMiddle[0])
            ||(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL&&price<bbMiddle[0]))trade.PositionClose(pos);  
      }
    }  
    
     if(price<bbLower[0]&&price>kalman&&NotInPosition) executeBuy(_Symbol);
     if(price>bbUpper[0]&&price<kalman&&NotInPosition) executeSell(_Symbol);
    }
}

//+------------------------------------------------------------------+
//| Kalman Filter Function                                          |
//+------------------------------------------------------------------+
double KalmanFilter(double price,double measurement_variance,double process_variance)
{
    // Prediction step (state does not change)
    double predicted_state = prev_state;
    double predicted_covariance = prev_covariance + process_variance;

    // Kalman gain calculation
    double kalman_gain = predicted_covariance / (predicted_covariance + measurement_variance);

    // Update step (incorporate new price observation)
    double updated_state = predicted_state + kalman_gain * (price - predicted_state);
    double updated_covariance = (1 - kalman_gain) * predicted_covariance;

    // Store updated values for next iteration
    prev_state = updated_state;
    prev_covariance = updated_covariance;

    return updated_state;
}

//+------------------------------------------------------------------+
//| Buy Function                                                 |
//+------------------------------------------------------------------+
void executeBuy(string symbol) {
       double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
       double lots=0.01;
       double sl = ask*(1-0.01);
       trade.Buy(lots,symbol,ask,sl);
}

//+------------------------------------------------------------------+
//| Sell Function                                                 |
//+------------------------------------------------------------------+
void executeSell(string symbol) {      
       double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
       double lots=0.01;
       double sl = bid*(1+0.01);
       trade.Sell(lots,symbol,bid,sl);     
} 