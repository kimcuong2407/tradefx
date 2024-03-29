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

input group "Trade";
input double LotSize = 0.01;
input int StopLoss = 5000;
input int TakeProfit = 5000;

input group "Risk Management";
input int MaxOrderOpen = 1;
input double xxLoss = 1.0;
input int StartXXWhenLoss = 2; // StartXXWhenLoss = 0 xxLoss Invalid
input double xxProfit = 1.0;
input int StartXXWhenProfit = 2;

input group "Signal";
input int NumberSignal = 1; // Số tín hiệu cần thỏa mãn cùng lúc

input group "RSI";
input bool IsUseRsi = false;
input double RSISell = 65; // Open sell when RSI > input
input double RSIBuy = 30;  // Open buy when RSI < input

input group "Pattern 5";
input bool IsUsePattern5 = false;
input int BodyLength = 50;

// input group "MACD";
bool IsUseMACD = false;

input group "EMA";
input bool IsUseEMA = false;
input ENUM_MA_METHOD EmaMethod = MODE_EMA;
input int MA_Period = 25;
input int MA_Shift = 0;

int ArraySignal[4]; // 1 = buy, 2 sell
const int ModeBuy = 1;
const int ModeSell = 2;
const int ModePending = 0;
datetime lastCandleTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  TesterHideIndicators(true);
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
    ArrayFill(ArraySignal, 0, 4, 0);
    if (IsUseRsi)
    {
      ArraySignal[0] = checkRsi();
    }
    if (IsUsePattern5)
    {
      ArraySignal[1] = checkPattern5();
    }
    if (IsUseMACD)
    {
      ArraySignal[2] = checkMACD();
    }
    if (IsUseEMA)
    {
      ArraySignal[3] = checkEMA();
    }
    int countSignalBuy = 0;
    int countSignalSell = 0;
    for (int i = 0; i < ArraySize(ArraySignal); i++)
    {
      if (ArraySignal[i] == ModeBuy)
      {
        countSignalBuy++;
      }
      if (ArraySignal[i] == ModeSell)
      {
        countSignalSell++;
      }
    }
    if (countSignalBuy >= NumberSignal)
    {
      openTrade(ModeBuy);
    }
    if (countSignalSell >= NumberSignal)
    {
      openTrade(ModeSell);
    }
  }
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
uint checkEMA()
{
  double buffer[];
  int inputIMA = iMA(_Symbol, _Period, MA_Period, MA_Shift, EmaMethod, PRICE_CLOSE);
  CopyBuffer(inputIMA, 0, 0, 1, buffer);
  double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
  double close = iClose(_Symbol, PERIOD_CURRENT, 1);
  if (open < buffer[0] && close > buffer[0])
  {
    return ModeBuy;
  }
  if (open > buffer[0] && close < buffer[0])
  {
    return ModeSell;
  }
  return ModePending;
}
int checkMACD()
{
  double bufferMacd[];
  int iMACD = iCustom(_Symbol, _Period, "MACD", 12, 26, 9, PRICE_CLOSE);
  int copyBufferMacd = CopyBuffer(iMACD, 1, 0, 3, bufferMacd);

  for (int i = 0; i < 3; i++)
  {
    printf("MACD: %f", bufferMacd[i]);
  }
  return 0;
  // if (bufferMacd[0] < 0)
  // {
  //   return 1;
  // }
  // else
  // {
  //   return 2;
  // }
}
int checkRsi()
{
  double bufferRSI[];
  // int iRSI = iCustom(_Symbol, _Period, "Oscillators/Moving Average of Oscillator",  12, 26, 9, PRICE_CLOSE);
  int iRSI = iCustom(_Symbol, _Period, "RSI", 14);
  int copyBufferMacd = CopyBuffer(iRSI, 0, 0, 1, bufferRSI);
  double buffer = bufferRSI[0];

  if (buffer > RSISell)
    return ModeSell;
  if (buffer < RSIBuy)
    return ModeBuy;
  return ModePending;
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
      return ModePending;
    }
    if (low < prevLow && close > prevHigh)
    {
      return ModeBuy;
    }
  }
  if (IsRedCandle(open, close) && IsGreenCandle(prevOpen, prevClose))
  {

    if (bodyCandle2 < BodyLength)
    {
      return ModePending;
    }
    if (high > prevHigh && close < prevLow)
    {
      return ModeSell;
    }
  }
  return ModePending;
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

int GetTotalLossTrades()
{
  int totalLossTrades = 0;

  // Chọn toàn bộ lịch sử giao dịch
  if (HistorySelect(0, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();
    // Duyệt qua từng giao dịch trong lịch sử
    for (int i = 1; i <= totalDeals; i++)
    {
      ulong dealTicket = HistoryDealGetTicket(totalDeals - i);
      if (dealTicket > 0)
      {
        long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

        // Kiểm tra xem lệnh này có là lệnh thua không
        if (dealType == DEAL_ENTRY_OUT)
        {
          if (profit < 0)
          {
            totalLossTrades++;
          }
          else
          {
            break;
          }
        }
      }
      else
      {
        break;
      }
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }

  return totalLossTrades;
}

int GetTotalProfitTrades()
{
  int totalLossTrades = 0;

  // Chọn toàn bộ lịch sử giao dịch
  if (HistorySelect(0, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();
    // Duyệt qua từng giao dịch trong lịch sử
    for (int i = 1; i <= totalDeals; i++)
    {
      ulong dealTicket = HistoryDealGetTicket(totalDeals - i);
      if (dealTicket > 0)
      {
        long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);

        // Kiểm tra xem lệnh này có là lệnh thua không
        if (dealType == DEAL_ENTRY_OUT)
        {
          if (profit > 0)
          {
            totalLossTrades++;
          }
          else
          {
            break;
          }
        }
      }
      else
      {
        break;
      }
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }

  return totalLossTrades;
}

bool IsLastTradeWinner()
{
  // Chọn toàn bộ lịch sử giao dịch
  if (HistorySelect(0, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();

    // Nếu không có giao dịch nào trong lịch sử, trả về false
    if (totalDeals == 0)
      return false;

    // Lấy thông tin về giao dịch gần nhất
    ulong lastDealTicket = HistoryDealGetTicket(totalDeals - 1);
    if (lastDealTicket > 0)
    {
      // Kiểm tra xem lệnh này có lãi hay lỗ
      double profit = HistoryDealGetDouble(lastDealTicket, DEAL_PROFIT);
      return profit > 0; // Nếu lãi thì trả về true, nếu lỗ trả về false
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }

  return false; // Trả về false nếu không thể xác định
}

double calculatorLotSize()
{
  bool isWinner = IsLastTradeWinner();
  int xx;
  if (isWinner)
  {
    int totalRecentProfit = GetTotalProfitTrades(); // lấy số lệnh TP gần nhất
    xx = totalRecentProfit >= StartXXWhenProfit ? totalRecentProfit - StartXXWhenProfit + 1 : 0;
    if (StartXXWhenProfit == 0)
    {
      return LotSize;
    }
    // xxProfit = 1, lotsize = 0.01
    return xx > 0 ? MathRound(CalculateExponential(MathRound(xxProfit), xx) * LotSize * 100) / 100 : LotSize;
  }
  else
  {
    int totalRecentLoss = GetTotalLossTrades(); // số lệnh SL gần nhất
    if (StartXXWhenLoss == 0)
    {
      return MathRound((CalculateExponential(2, totalRecentLoss) * LotSize) * 100) / 100;
    }
    else
    {
      xx = totalRecentLoss >= StartXXWhenLoss ? totalRecentLoss - StartXXWhenLoss + 1 : 0;
      return xx > 0 ? MathRound((xx * xxLoss * LotSize) * 100) / 100 : LotSize;
    }
  }
}
//+------------------------------------------------------------------+
// 1 = buy
// 2 buy sell
int CalculateExponential(int base, int exponent)
{
  int result = 1;
  if (exponent > 5)
  {
    exponent = 5;
  }

  for (int i = 0; i < exponent; i++)
  {
    result *= base;
  }

  return result;
}

uint openTrade(uint mode)
{
  long magic_number = 123456; // magic number
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

  // Lấy giá trị Point cho cặp tiền tệ hiện tại
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  request.volume = calculatorLotSize();
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
