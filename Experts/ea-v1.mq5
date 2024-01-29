//+------------------------------------------------------------------+
//|                                                  scalping-v1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property strict;

#include <Trade/TerminalInfo.mqh>

input double LotSize = 0.01;
input int StopLoss = 5000;
input int TakeProfit = 5000;
input int BodyLength = 500;
input int MaxOrderOpen = 1;
input double DoubleLoss = 2.0;

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
  int isTrade = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED);
  if (!isTrade)
  {
    printf("Trade is not allowed");
    return;
  }

  // get total order open
  int total = PositionsTotal();
  if (total >= MaxOrderOpen)
  {
    return;
  }
  if (checkCloseBar())
  {
    int resultPattern = checkPattern5();
    if (resultPattern > 0)
    {
      openTrade(resultPattern);
    }
  }
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+

int checkPattern5()
{
  double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
  double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
  double low = iLow(_Symbol, PERIOD_CURRENT, 1);
  double close = iClose(_Symbol, PERIOD_CURRENT, 1);

  double prevOpen = iOpen(_Symbol, PERIOD_CURRENT, 2);
  double prevHigh = iHigh(_Symbol, PERIOD_CURRENT, 2);
  double prevLow = iLow(_Symbol, PERIOD_CURRENT, 2);
  double prevClose = iClose(_Symbol, PERIOD_CURRENT, 2);
  double length1;

  length1 = MathAbs(open - close);

  double bodyCandle2 = CalculatePips(MathAbs((prevOpen - prevClose)));

  if (IsGreenCandle(open, close) && IsRedCandle(prevOpen, prevClose))
  {

    if (bodyCandle2 < BodyLength)
    {
      return 0;
    }
    if (low < prevLow && close > prevHigh)
    {
      printf("de5");
      return 1;
    }
  }
  if (IsRedCandle(open, close) && IsGreenCandle(prevOpen, prevClose))
  {

    if (bodyCandle2 < BodyLength)
    {
      return 0;
    }
    if (high > prevHigh && close < prevLow)
    {
      printf("su5");
      return 2;
    }
  }
  return 0;
}

bool IsRedCandle(double currentOpen, double currentClose)
{
  return currentOpen > currentClose;
}

bool IsGreenCandle(double currentOpen, double currentClose)
{
  return currentOpen < currentClose;
}

double CalculatePips(double priceChange)
{
  double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

  double pips = priceChange / tickSize;
  return pips;
}

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
  // Code to handle trade events
}

bool CheckRecentConsecutiveOrdersNegativeProfit()
{
  if (HistorySelect(0, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();
    if (totalDeals >= 2)
    {
      // Lấy thông tin của lệnh gần nhất
      ulong lastDeal = HistoryDealGetTicket(totalDeals - 1);
      if (lastDeal > 0)
      {
        double lastDealProfit = HistoryDealGetDouble(lastDeal, DEAL_PROFIT);

        // Lấy thông tin của lệnh liền trước
        ulong prevDeal = HistoryDealGetTicket(totalDeals - 3);
        if (prevDeal > 0)
        {
          double prevDealProfit = HistoryDealGetDouble(prevDeal, DEAL_PROFIT);
          printf("lastDealProfit: %f, prevDealProfit: %f", lastDealProfit, prevDealProfit);
          // Kiểm tra xem lợi nhuận của hai lệnh liên tiếp có âm không
          if (lastDealProfit < 0 && prevDealProfit < 0)
          {
            Print("Hai lệnh liên tiếp gần nhất có lợi nhuận âm.");
            return true;
          }
          else
          {
            Print("Hai lệnh liên tiếp gần nhất không có lợi nhuận âm.");
            return false;
          }
        }
      }
    }
    else
    {
      Print("Cần ít nhất hai lệnh trong lịch sử để kiểm tra.");
      return false;
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }
  return false;
}

//+------------------------------------------------------------------+
// 1 = buy
// 2 buy sell
uint openTrade(int mode)
{
  long magic_number = 123456; // magic number
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

  // Lấy giá trị Point cho cặp tiền tệ hiện tại
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  bool checkDoubleLoss = CheckRecentConsecutiveOrdersNegativeProfit();

  request.volume = checkDoubleLoss ? MathRound((DoubleLoss * LotSize) * 100) / 100 : LotSize; // volume in 0.1 lots
  if (mode == 1)
  {
    double stopLossPrice = currentPrice - StopLoss * pointValue;
    double takeProfitPrice = currentPrice + TakeProfit * pointValue;

    request.action = TRADE_ACTION_DEAL; // setting a pending order
    request.magic = magic_number;       // ORDER_MAGIC
    request.symbol = _Symbol;           // symbol
    request.sl = stopLossPrice;         // Stop Loss is not specified
    request.tp = takeProfitPrice;       // Take Profit is not specified
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    request.comment = "EA buy";
    request.type = ORDER_TYPE_BUY;
  }
  if (mode == 2)
  {
    double stopLossPrice = currentPrice + StopLoss * pointValue;
    double takeProfitPrice = currentPrice - TakeProfit * pointValue;

    request.action = TRADE_ACTION_DEAL; // setting a pending order
    request.magic = magic_number;       // ORDER_MAGIC
    request.symbol = _Symbol;           // symbol
    request.sl = stopLossPrice;         // Stop Loss is not specified
    request.tp = takeProfitPrice;       // Take Profit is not specified
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    request.comment = "EA sell";
    request.type = ORDER_TYPE_SELL;
  }
  bool status = OrderSend(request, result);
  //--- write the server reply to log

  Print(__FUNCTION__, ":", result.comment);
  if (result.retcode == 10016)
    Print(result.bid, result.ask, result.price);
  //--- return code of the trade server reply
  return result.retcode;
}
