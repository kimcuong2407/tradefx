//+------------------------------------------------------------------+
//|                                                  scalping-v1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

double KeyLevelBuffer[];
double EngulfingBuffer[];
datetime lastCandleTime = 0;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  bool spreadfloat = SymbolInfoInteger(Symbol(), SYMBOL_SPREAD_FLOAT);

  double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
  double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  double spread = ask - bid;
  int spread_points = (int)MathRound(spread / SymbolInfoDouble(Symbol(), SYMBOL_POINT));

  double pipsValue = PointsToPips(spread_points);
  // engfuling();
  engfuling();
  keyLevel();
  // Print(spread_points, " points tương ứng với ", pipsValue, " pips.");

  // xác định đỉnh đáy
  // xác định zone Order block smc
  // xác định trend
  // xác định điểm vào lệnh
  // xác định điểm stoploss
  // xác định điểm takeprofit

  // logic vào lệnh
  // b1: phải phá qua đỉnh đáy.
  // b2: chờ giá về test lại đỉnh đáy.
  // b3: Có nến engulfing -> đặt lệnh buy stop tại đỉnh đáy.
  // code -> buy stop limit nếu nó phá qua đỉnh. trong TH có engulfing.

  // check =0;
  // check = 1;
  // và sau 3 < 7  nến thì quay lại cản check =2;
  // check =2 && engfuling = true ->
  if (checkCloseBar())
  {
    Print("Close bar");
  }

  // for (int i = 0; i < ArraySize(Array); i++)
  // {
  //   Print("element - " + i+" -" + Array[i]);
  // }
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+

bool checkCloseBar()
{
  datetime currentCandleTime = iTime(_Symbol, PERIOD_CURRENT, 0); // Lấy thời gian của nến hiện tại

  if (currentCandleTime != lastCandleTime) // Kiểm tra nếu thời gian của nến đã thay đổi
  {
    if (lastCandleTime != 0)
    {
      lastCandleTime = 0;
      return true;
    }

    lastCandleTime = currentCandleTime; // Cập nhật thời gian của nến cuối cùng
  }
  return false;
}

double PointsToPips(double points)
{
  return points * _Point;
}
void OnTrade()
{
  //---
}
//+------------------------------------------------------------------+

void keyLevel()
{
  int supportResistance = iCustom(_Symbol, _Period, "MQLTA MT5 Support Resistance Lines");
  int totalCopy = CopyBuffer(supportResistance, 8, 0, 2, KeyLevelBuffer);
  for (int i = 0; i < 2; i++)
  {
    // printf("KeyLevelBuffer: index-%d  value: %f", i, KeyLevelBuffer[i]);
  }
}

void engfuling()
{
  int engulfingIndi = iCustom(_Symbol, _Period, "Engulfing");
  int totalCopy = CopyBuffer(engulfingIndi, 2, 0, 2, EngulfingBuffer);
  printf("EA Engulfing totalCopy: %d", totalCopy);
  for (int i = 0; i < 2; i++)
  {
    // printf("EngulfingBuffer: index-%d  value: %f", i, EngulfingBuffer[i]);
  }
  
}
