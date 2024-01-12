//+------------------------------------------------------------------+
//|                                                  scalping-v1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict;
double KeyLevelBuffer[];
double EngulfingBuffer[];
int level = 0;
int levelChecking = 0;
// level 1 tức là đang có nến EG mua;
// level 2 tức là đang có nến EG bán;
// level 3 tức là đáp ứng nến trc đó
// level 4 tức là đáp ứng nến trc đó còn 1
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
    engfuling();
    printf("Close bar with level: %d", level);
    if (level == 1 || level == 2)
    {
      levelChecking++;
      
      if (level != 3 && level != 4 && levelChecking == 10)
      {
        levelChecking = 0;
        level = 0;
      }
    }
    keyLevel();
    if (level == 3 || level == 4)
    {
      openTrade();
    }
    printf("EG buy: %f", EngulfingBuffer[0]);
    printf("EG sell: %f", EngulfingBuffer[1]);
    // printf("Key level green: %f", KeyLevelBuffer[0]);
    // printf("Key level red: %f", KeyLevelBuffer[1]);
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
  double eg1 = iClose(_Symbol, _Period, 1);
  double eg2 = iClose(_Symbol, _Period, 2);
  if (level == 1)
  {
    if (KeyLevelBuffer[0] > eg2 && KeyLevelBuffer[0] < eg1)
    {
      level = 3;
    }
  }
  if (level == 2)
  {
    if (KeyLevelBuffer[0] < eg2 && KeyLevelBuffer[0] > eg1)
    {
      level = 4;
    }
  }
}

void engfuling()
{
  int engulfingIndi = iCustom(_Symbol, _Period, "Engulfing");
  int totalCopy = CopyBuffer(engulfingIndi, 2, 0, 2, EngulfingBuffer);
  if (EngulfingBuffer[0] == 1)
  {
    level = 1;
  }
  else if (EngulfingBuffer[1] == 1)
  {
    level = 2;
  }
}

uint openTrade()
{
  long magic_number = 123456; // magic number
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  if (level == 3)
  {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Lấy giá trị Point cho cặp tiền tệ hiện tại
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Tính toán giá Stop Loss (SL) cách 1500 điểm từ giá hiện tại
    double stopLossPrice = currentPrice - 1500 * pointValue;
    double takeProfitPrice = currentPrice + 1500 * pointValue;
    // level = 0;
    request.action = TRADE_ACTION_DEAL; // setting a pending order
    request.magic = magic_number;       // ORDER_MAGIC
    request.symbol = _Symbol;           // symbol
    request.volume = 0.01;              // volume in 0.1 lots
    request.sl = stopLossPrice;         // Stop Loss is not specified
    request.tp = takeProfitPrice;       // Take Profit is not specified
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    request.comment = "EA buy";
    request.type = ORDER_TYPE_BUY;
  }
  if (level == 4)
  {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Lấy giá trị Point cho cặp tiền tệ hiện tại
    double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Tính toán giá Stop Loss (SL) cách 1500 điểm từ giá hiện tại
    double stopLossPrice = currentPrice + 1500 * pointValue;
    double takeProfitPrice = currentPrice - 1500 * pointValue;

    request.action = TRADE_ACTION_DEAL; // setting a pending order
    request.magic = magic_number;       // ORDER_MAGIC
    request.symbol = _Symbol;           // symbol
    request.volume = 0.01;              // volume in 0.1 lots
    request.sl = stopLossPrice;         // Stop Loss is not specified
    request.tp = takeProfitPrice;       // Take Profit is not specified
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    request.comment = "EA sell";
    request.type = ORDER_TYPE_SELL;
  }
  OrderSend(request, result);
  //--- write the server reply to log
  level = 0;
  Print(__FUNCTION__, ":", result.comment);
  if (result.retcode == 10016)
    Print(result.bid, result.ask, result.price);
  //--- return code of the trade server reply
  return result.retcode;
}
