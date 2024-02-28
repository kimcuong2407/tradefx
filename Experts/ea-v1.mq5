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
// input int StopLoss = 150;
input int RiskReward = 3;
input int TakeProfit = 150;

input group "Risk Management";
int MaxOrderOpen = 1;
input int StartXXWhenLoss = 2; // StartXXWhenLoss = 0 xxLoss Invalid
input double xxLoss = 1.0;
input int StartXXWhenProfit = 2;
input double xxProfit = 1.0;

input group "Signal";
input string NumberSignal = "1-2-4"; // Nhập tín hiệu vào lệnh. Example: 1-2

input group "RSI signal 1";
input double RSISell = 70; // Open sell when RSI > input
input double RSIBuy = 30;  // Open buy when RSI < input
// Input logic vào lệnh thật check với lệnh ảo
input int RSIStartTradeNumberVirtualTradeLoss = 0;   // Số lệnh trade ảo thua thì sẽ vào lệnh thật
input int RSIStartTradeNumberVirtualTradeCheck = 10; // kiểm tra trong 10 lệnh gần nhất tổng RR = ?
input int RSIStartTradeRRLossOpenTrade = 10;         // Nếu RR <= số input thì bắt đầu vào lệnh
// input logic kết thúc chuỗi lệnh
input int RSIStopWhenWinXXRR = 0;  // Stop chuỗi lệnh khi win xx lệnh với RR >= input
input int RSIStopWhenLossXXRR = 0; // Stop chuỗi lệnh khi loss xx lệnh với RR <= input
input int RSIStopAfterAction = 0;  // xxLot Khi gặp chuỗi thua. Giữ Nguyên Lot input = 1

// ----------

input group "Pattern 5 signal 2";
input int BodyLength = 50;
input int Pattern5StartTradeNumberVirtualTradeLoss = 0;   // Số lệnh trade ảo thua thì sẽ vào lệnh thật
input int Pattern5StartTradeNumberVirtualTradeCheck = 10; // kiểm tra trong 10 lệnh gần nhất tổng RR = ?
input int Pattern5StartTradeRRLossOpenTrade = 10;         // Nếu RR <= số input thì bắt đầu vào lệnh
// input logic kết thúc chuỗi lệnh
input int Pattern5StopWhenWinXXRR = 0;  // Stop chuỗi lệnh khi win xx lệnh với RR >= input
input int Pattern5StopWhenLossXXRR = 0; // Stop chuỗi lệnh khi loss xx lệnh với RR <= input
input int Pattern5StopAfterAction = 0;  // xxLot Khi gặp chuỗi thua. Giữ Nguyên Lot input = 1

// ----------

// input group "MACD";
input group "MACD signal 3";
// Input logic vào lệnh thật check với lệnh ảo
input int MACDStartTradeNumberVirtualTradeLoss = 0;   // Số lệnh trade ảo thua thì sẽ vào lệnh thật
input int MACDStartTradeNumberVirtualTradeCheck = 10; // kiểm tra trong 10 lệnh gần nhất tổng RR = ?
input int MACDStartTradeRRLossOpenTrade = 10;         // Nếu RR <= số input thì bắt đầu vào lệnh
// input logic kết thúc chuỗi lệnh
input int MACDStopWhenWinXXRR = 0;  // Stop chuỗi lệnh khi win xx lệnh với RR >= input
input int MACDStopWhenLossXXRR = 0; // Stop chuỗi lệnh khi loss xx lệnh với RR <= input
input int MACDStopAfterAction = 0;  // xxLot Khi gặp chuỗi thua. Giữ Nguyên Lot input = 1

// ----------

input group "EMA signal 4";
input ENUM_MA_METHOD MaMethod = MODE_EMA;
input int MAPeriod = 25;
input int MAShift = 0;
// Input logic vào lệnh thật check với lệnh ảo
input int MALineStartTradeNumberVirtualTradeLoss = 0;   // Số lệnh trade ảo thua thì sẽ vào lệnh thật
input int MALineStartTradeNumberVirtualTradeCheck = 10; // kiểm tra trong 10 lệnh gần nhất tổng RR = ?
input int MALineStartTradeRRLossOpenTrade = 10;         // Nếu RR <= số input thì bắt đầu vào lệnh
// input logic kết thúc chuỗi lệnh
input int MALineStopWhenWinXXRR = 0;  // Stop chuỗi lệnh khi win xx lệnh với RR >= input
input int MALineStopWhenLossXXRR = 0; // Stop chuỗi lệnh khi loss xx lệnh với RR <= input
input int MALineStopAfterAction = 0;  // xxLot Khi gặp chuỗi thua. Giữ Nguyên Lot input = 1

// ----------
enum ConditionOpenTrade
{
  error = -1,
  openTradeNormal = 0,
  openTradeVirtualLoss = 1,
  openTradeVirtualRR = 2,
};

enum TradeStatus
{
  Pending = 3, // File Virtual thì không có tác dụng. File CommandTrade thì tương ứng là chưa bắt đầu chuỗi
  Start = 0,   // File Virtual thì lệnh được mở. File CommandTrade thì tương ứng bắt đầu chuỗi
  Win = 1,     // File Virtual thì lệnh win. File CommandTrade thì tương ứng kết thúc chuỗi reset về Pending
  Loss = 2,    // File Virtual thì lệnh loss. File CommandTrade thì tương ứng chuỗi thua, xử lý input x2 lot hoặc khi RR = 0 thì reset về Pending
};
struct CommentWithConditionTrade
{
  int condition;
  string comment;
};
struct InputVirtualRR
{
  int StartTradeNumberVirtualTradeLoss; // Số lệnh trade ảo thua liên tiếp thì sẽ vào lệnh thật
  int CheckRecentVirtualTrade;          // kiểm tra trong 10 lệnh gần nhất tổng RR = ?
  int StartTradeRRLossOpenTrade;        // Mở lệnh Trade khi tổng RR <= input
  int StopWhenWinXXRR;
  int StopWhenLossXXRR;
  int StopAfterAction;
};

struct ContentFile
{
  TradeStatus Status; // Quan tâm với lệnh ảo
  string BuySell;     // Order Type // 1 = buy, 2 = sell
  string Entry;
  string Sl;
  string Tp;
  string StartTime;
  string EndTime;
  ulong Ticket;
  int SignalNumber; // 1, 2, 3, 4
  int RR;
  string SignalName; // RSi, Pattern 5, MACD, EMA
};

struct Signal
{
  int SignalNumber;
  string SignalName;
  string FileName[4];
  ulong MagicNumber;
};

//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+

const string FileNameStartCommandTrade = "StartCommandTrade.txt";

const int Signal1Rsi = 1;
const int Signal2Pattern5 = 2;
const int Signal3MACD = 3;
const int Signal4EMA = 4;

const int MagicNumber1Rsi = 120021;
const int MagicNumber2Pattern5 = 120022;
const int MagicNumber3MACD = 120023;
const int MagicNumber4EMA = 120024;

const CommentWithConditionTrade CommentWithConditionTradeArray[] = {
    {ConditionOpenTrade::openTradeNormal, "Normal"},
    {ConditionOpenTrade::openTradeVirtualLoss, "Virtual Loss"},
    {ConditionOpenTrade::openTradeVirtualRR, "Virtual RR"},
};
const Signal SignalsArray[4] = {
    {Signal1Rsi,
     "RSI",
     {"1RSI_temp",
      "1RSI_history",
      "1RSI_REAL",
      "1RSI_ALL_TRADE"},
     MagicNumber1Rsi},
    {Signal2Pattern5,
     "Pattern 5",
     {
         "2Pattern5_temp",
         "2Pattern5_history",
         "2Pattern5_REAL",
         "2Pattern5_ALL_TRADE",
     },
     MagicNumber2Pattern5},
    {Signal3MACD,
     "MACD",
     {
         "3MACD_temp",
         "3MACD_history",
         "3MACD_REAL",
         "3MACD_ALL_TRADE",
     },
     MagicNumber3MACD},
    {Signal4EMA,
     "Moving Average",
     {
         "4EMA_temp",
         "4EMA_history",
         "4EMA_REAL",
         "4EMA_ALL_TRADE",
     },
     MagicNumber4EMA},
};

//+------------------------------------------------------------------+
//|  end update when new signal                                      |
//+------------------------------------------------------------------+

string NumberSignalsArray[];

const int ModeBuy = 1;
const int ModeSell = 2;
const int ModePending = 0;
datetime lastCandleTime = 0;

// double VirtualHistory[][]; // result - buy|sell - sl - tp
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

  ConvertStringToArray(NumberSignal, NumberSignalsArray);
  int totalNumberSignal = ArraySize(NumberSignalsArray);
  if (FileIsExist(FileNameStartCommandTrade) == false)
  {
    CreateFileIfNotExists(FileNameStartCommandTrade);
    ContentFile contentFile[];
    for (int i = 0; i < totalNumberSignal; i++)
    {
      ContentFile content = GetDefaultContentFile();
      int signalNumber = int(NumberSignalsArray[i]);
      content.SignalNumber = signalNumber;
      content.SignalName = GetSignalNameBySignalNumber(signalNumber);

      ArrayResize(contentFile, ArraySize(contentFile) + 1);
      contentFile[ArraySize(contentFile) - 1] = content;
    }
    WriteArrayStrucContentToFile(FileNameStartCommandTrade, contentFile);
  }

  // Convert Input and hide indicator on backtest
  for (int i = 0; i < totalNumberSignal; i++)
  {
    int signalNumber = int(NumberSignalsArray[i]);
    CreateFileIfNotExists(GetFileNameBySignal(signalNumber));
    CreateFileIfNotExists(GetFileNameBySignal(signalNumber, 1));
    CreateFileIfNotExists(GetFileNameBySignal(signalNumber, 2));
    CreateFileIfNotExists(GetFileNameBySignal(signalNumber, 3));
  }
  TesterHideIndicators(true);
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //--- remove files
  for (int i = 0; i < ArrayRange(SignalsArray, 0); i++)
  {
    // DeleteFileContents(GetFileNameBySignal(SignalsArray[i].SignalNumber));
  }
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

  if (CheckCloseBar())
  {
    for (int i = 0; i < ArraySize(NumberSignalsArray); i++)
    {
      int numberSignal = int(NumberSignalsArray[i]);
      ulong magicNumber = GetMagicNumberBySignal(numberSignal);

      int totalPositionOpenWithTicket = GetTotalPositionOpenByMagicNumber(magicNumber);
      string fileName = GetFileNameBySignal(numberSignal);
      ContentFile AllSignal[];
      ContentFile VirtualTrades[];

      // update file signal history
      CheckVirtualTradeStatus(AllSignal, numberSignal, 0, 1, 100, 30);

      // update file virtual trade real
      CheckVirtualTradeStatus(VirtualTrades, numberSignal, 2, 3, 100, 20);

      uint BuySell = CheckSignal(numberSignal);

      if (BuySell == 0)
      {
        // note: Don't have signal
        continue;
      }
      if (totalPositionOpenWithTicket >= MaxOrderOpen)
      {
        // note: add log SignalAll
        WriteLogTradeVirtual(BuySell, numberSignal);
        continue;
      }
      // Kiểm tra xem CommandTrade có đc update status không
      UpdateStatusCommandTrade(numberSignal);

      ContentFile CommandSignal = GetSignalCommandTradeBySignalNumber(numberSignal);
      ConditionOpenTrade conditionOpenTrade = CheckSignalStartTradeCommand(numberSignal, VirtualTrades);
      if (CommandSignal.Status == TradeStatus::Pending)
      {
        // note: Khởi tạo 1 chuỗi lệnh mới
        // kiểm tra tại thời điểm này có đủ điều kiện để mở lệnh không
        ulong ticket = OpenTrade(BuySell, numberSignal, conditionOpenTrade);
        if (ticket > 0)
        {
          CommandSignal.Status = TradeStatus::Start;
          CommandSignal.Ticket = ticket;
          UpdateSignalCommandTradeBySignalNumber(numberSignal, CommandSignal);
          WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
        }
        else
        {
          WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
          WriteLogTradeVirtual(BuySell, numberSignal);
        }
      }
      else // chỗ này chỉ cần xử lý Loss || Start
      {
        if (CommandSignal.Status == TradeStatus::Loss)
        {
          ulong ticket = OpenTrade(BuySell, numberSignal, conditionOpenTrade);
          if (ticket > 0)
          {
            WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
            WriteLogTradeVirtual(BuySell, numberSignal);
          }
          else
          {
            WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
          }
          // Open Trade
        }
        else // cứ thế open lệnh thôi
        {
          ulong ticket = OpenTrade(BuySell, numberSignal, conditionOpenTrade);
          if (ticket > 0)
          {
            WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
            WriteLogTradeVirtual(BuySell, numberSignal);
          }
          else
          {
            WriteLogTradeVirtual(BuySell, numberSignal, ticket, true);
          }
        }
      }
    }
  }
}

void OnTrade()
{
  // Code to handle trade events
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+

// todo: recheck logic
uint CheckEMA()
{
  double buffer[];
  int inputIMA = iMA(_Symbol, _Period, MAPeriod, MAShift, MaMethod, PRICE_CLOSE);
  ArraySetAsSeries(buffer, true);
  CopyBuffer(inputIMA, 0, 0, 3, buffer);
  double valueMaPrevious = buffer[1];
  double open = iOpen(_Symbol, PERIOD_CURRENT, 1);
  double close = iClose(_Symbol, PERIOD_CURRENT, 1);
  if (open < valueMaPrevious && close > valueMaPrevious)
  {
    return ModeBuy;
  }
  if (open > valueMaPrevious && close < valueMaPrevious)
  {
    return ModeSell;
  }
  return ModePending;
}
// todo: pending logic
int CheckMACD()
{
  double bufferMACD[];
  int indexMacd = iMACD(_Symbol, PERIOD_CURRENT, 12, 26, 9, PRICE_CLOSE);
  int copyBufferMacd = CopyBuffer(indexMacd, 1, 0, 3, bufferMACD);

  for (int i = 0; i < 3; i++)
  {
    printf("MACD: %f", bufferMACD[i]);
  }
  return 0;
}
int CheckRsi()
{
  double bufferRSI[];
  ArraySetAsSeries(bufferRSI, true);
  int total = CopyBuffer(iRSI(_Symbol, PERIOD_CURRENT, 14, PRICE_CLOSE), 0, 0, 4, bufferRSI);

  double buffer = bufferRSI[1];
  double buffer1 = bufferRSI[2];

  if (RSISell >= buffer1 && buffer > RSISell)
    return ModeSell;
  if (RSIBuy <= buffer1 && buffer < RSIBuy)
    return ModeBuy;
  return ModePending;
}

bool CheckCloseBar()
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
// todo: recheck Logic
int CheckPattern5()
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
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
ConditionOpenTrade CheckSignalStartTradeCommand(int numberSignal, ContentFile &VirtualTrades[])
{
  InputVirtualRR inputVirtualRR = GetInputTradeWithRR(numberSignal);
  ContentFile CommandSignal = GetSignalCommandTradeBySignalNumber(numberSignal);
  if (ArraySize(VirtualTrades) == 0)
  {
    return ConditionOpenTrade::error;
  }
  int totalRR = GetTotalRRRecentHistoryByInput(VirtualTrades, inputVirtualRR);
  if (totalRR <= inputVirtualRR.StartTradeRRLossOpenTrade)
  {
    return ConditionOpenTrade::openTradeVirtualRR;
  }
  int totalRecentTradeLoss = GetTotalTradeVirtualRecentWinLoss(VirtualTrades, TradeStatus::Loss);
  if (totalRecentTradeLoss == inputVirtualRR.StartTradeNumberVirtualTradeLoss)
  {
    return ConditionOpenTrade::openTradeVirtualLoss;
  }
  return ConditionOpenTrade::error;
}

// Nếu status = Start
//  - update sang pending nếu RR >= inputVirtualRR.StopWhenWinXXRR
//  - update sang loss nếu RR <= inputVirtualRR.StopWhenLossXXRR
void UpdateStatusCommandTrade(int numberSignal)
{
  InputVirtualRR inputVirtualRR = GetInputTradeWithRR(numberSignal);
  ContentFile CommandSignal = GetSignalCommandTradeBySignalNumber(numberSignal);

  int totalRR = GetTotalRRHistoryTradeRealByTicket(numberSignal, CommandSignal.Ticket);
  if (CommandSignal.Status == TradeStatus::Start)
  {

    if (totalRR >= inputVirtualRR.StopWhenWinXXRR)
    {
      // Update CommandSignal to Pending
      CommandSignal.Status = TradeStatus::Pending;
      CommandSignal.Ticket = 0;
      UpdateSignalCommandTradeBySignalNumber(numberSignal, CommandSignal);
    }
    if (totalRR <= inputVirtualRR.StopWhenLossXXRR)
    {
      // Update CommandSignal to Loss
      CommandSignal.Status = TradeStatus::Loss;
      UpdateSignalCommandTradeBySignalNumber(numberSignal, CommandSignal);
    }
  }
  if (CommandSignal.Status == TradeStatus::Loss)
  {
    if (totalRR >= 0)
    {
      // Update CommandSignal to Pending
      CommandSignal.Status = TradeStatus::Pending;
      CommandSignal.Ticket = 0;
      UpdateSignalCommandTradeBySignalNumber(numberSignal, CommandSignal);
    }
  }
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
      if (dealTicket <= 0)
        break;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      string comment = HistoryDealGetString(dealTicket, DEAL_COMMENT);
      // Kiểm tra xem lệnh này có là lệnh thua không
      if (dealType == DEAL_ENTRY_OUT)
      {
        if (profit > 0)
          break;
        totalLossTrades++;
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
      if (dealTicket <= 0)
        break;

      long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      // Kiểm tra xem lệnh này có là lệnh thua không
      if (dealType == DEAL_ENTRY_OUT)
      {
        if (profit <= 0)
          break;
        totalLossTrades++;
      }
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }

  return totalLossTrades;
}

// ticket sẽ check lịch xử giao dịch của signal và khi gặp ticket
int GetTotalRRHistoryTradeRealByTicket(int signalNumber, ulong ticket)
{

  if (!HistorySelect(0, TimeCurrent()))
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
    return 0;
  }
  ulong magicNumberBySignal = GetMagicNumberBySignal(signalNumber);
  int totalRR = 0;

  int totalDeals = HistoryDealsTotal();
  for (int i = 0; i < totalDeals; i++)
  {
    ulong dealTicket = HistoryDealGetTicket(totalDeals - i);
    if (dealTicket == ticket)
      break;
    if (dealTicket > 0)
    {
      long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY); // in = 0, out = 1
      if (dealType == DEAL_ENTRY_OUT
          // && magic == magicNumberBySignal
      )
      {
        double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
        if (profit >= 0)
          totalRR = totalRR + 1;
        else
          totalRR = totalRR - RiskReward;
      }
    }
  }
  return totalRR;
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

// Todo: Recheck
double CalculatorLotSize(int xx = 1)
{
  return LotSize * MathPow(xx, 2);
  // bool isWinner = IsLastTradeWinner();
  // int xx;
  // if (isWinner)
  // {
  //   int totalRecentProfit = GetTotalProfitTrades(); // lấy số lệnh TP gần nhất
  //   xx = totalRecentProfit >= StartXXWhenProfit ? totalRecentProfit - StartXXWhenProfit + 1 : 0;
  //   if (StartXXWhenProfit == 0)
  //   {
  //     return LotSize;
  //   }
  //   // xxProfit = 1, lotsize = 0.01
  //   return xx > 0 ? MathRound(CalculateExponential(int(MathRound(xxProfit)), xx) * LotSize * 100) / 100 : LotSize;
  // }
  // else
  // {
  //   int totalRecentLoss = GetTotalLossTrades(); // số lệnh SL gần nhất
  //   if (StartXXWhenLoss == 0)
  //   {
  //     return MathRound((CalculateExponential(2, totalRecentLoss) * LotSize) * 100) / 100;
  //   }
  //   else
  //   {
  //     xx = totalRecentLoss >= StartXXWhenLoss ? totalRecentLoss - StartXXWhenLoss + 1 : 0;
  //     return xx > 0 ? MathRound((xx * xxLoss * LotSize) * 100) / 100 : LotSize;
  //   }
  // }
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

double CalculateStopLoss(int mode)
{
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double result;
  if (mode == ModeBuy)
  {
    result = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - TakeProfit * RiskReward * pointValue;
  }
  else
  {
    result = SymbolInfoDouble(Symbol(), SYMBOL_BID) + TakeProfit * RiskReward * pointValue;
  }
  int digits = int(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  return NormalizeDouble(result, digits);
}

double CalculatePrice(int mode)
{
  double result;
  if (mode == ModeBuy)
  {
    result = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  }
  else
  {
    result = SymbolInfoDouble(Symbol(), SYMBOL_BID);
  }
  int digits = int(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  return NormalizeDouble(result, digits);
}
double CalculateTakeProfit(int mode)
{
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double result;
  if (mode == ModeBuy)
  {
    result = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + TakeProfit * pointValue;
  }
  else
  {
    result = SymbolInfoDouble(Symbol(), SYMBOL_BID) - TakeProfit * pointValue;
  }
  int digits = int(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  return NormalizeDouble(result, digits);
}
ulong OpenTrade(uint mode, int numberSignal, ConditionOpenTrade conditionOpenTrade)
{
  if (conditionOpenTrade == ConditionOpenTrade::error)
  {
    return 0;
  }
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  ContentFile CommandSignal = GetSignalCommandTradeBySignalNumber(numberSignal);
  if (CommandSignal.Status == TradeStatus::Loss)
  {
    InputVirtualRR inputVirtualRR = GetInputTradeWithRR(numberSignal);
    request.volume = CalculatorLotSize(inputVirtualRR.StopAfterAction);
  }
  else
  {
    request.volume = LotSize;
  }
  if (mode == 1)
  {
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    request.type = ORDER_TYPE_BUY;
  }
  else
  {
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    request.type = ORDER_TYPE_SELL;
  }
  request.magic = GetMagicNumberBySignal(numberSignal);
  request.symbol = _Symbol;               // symbol
  request.action = TRADE_ACTION_DEAL;     // setting a pending order
  request.sl = CalculateStopLoss(mode);   // Stop Loss is not specified
  request.tp = CalculateTakeProfit(mode); // Take Profit is not specified
  request.comment = GetComment(numberSignal, mode, conditionOpenTrade);
  bool status = OrderSend(request, result);
  ulong ticket = result.deal;
  if (!status)
  {
    printf("Trade is not opened. Error: %d", GetLastError());
    return 0;
  }
  return ticket;
}

void ConvertStringToArray(string str, string &subString[], string delimiter = "-")
{
  int count = StringSplit(str, StringGetCharacter(delimiter, 0), subString);
}

string ConvertArrayToString(string &array[], string separator = "-")
{
  string result = "";

  for (int i = 0; i < ArraySize(array); i++)
  {
    if (i > 0)
    {
      result += separator; // Add the separator between elements
    }

    // Convert the array element to string and append to the result
    result += array[i];
  }

  return result;
}

void WriteStringToFile(string FileName, string content = "hello")
{
  int h = FileOpen(FileName, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    printf("WriteString Error opening file %s", FileName);
  }
  else
  {
    FileSeek(h, 0, SEEK_END);
    FileWrite(h, content);
    FileClose(h);
  }
}

// nếu giá trị hợp lệ thì sẽ update mảng $trades và trả về true
// ở ngoài cần xử lý update lại file text
// -1 = không có trade virtul nào đang tồn tại
// 0 = có trade virtual nhưng chưa có kết quả
// 1 = có trade virtual và đã có kết quả
short CheckVirtualTradeSlTp(ContentFile &trades[])
{
  double low = iLow(_Symbol, PERIOD_CURRENT, 1);
  double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
  short check = -1;
  for (int i = 0; i < ArraySize(trades); i++)
  {
    ContentFile ContentStruct = trades[i];
    if (ContentStruct.Status != TradeStatus::Start)
    {
      continue;
    }
    check++;
    int mode = int(ContentStruct.BuySell);
    double sl = double(ContentStruct.Sl);
    double tp = double(ContentStruct.Tp);
    if (mode == ModeBuy)
    {
      if (high > tp)
      {
        ContentStruct.Status = TradeStatus::Win;
      }
      else if (low < sl)
      {
        ContentStruct.Status = TradeStatus::Loss;
      }
    }
    else
    {
      if (low < tp)
      {
        ContentStruct.Status = TradeStatus::Win;
      }
      else if (high > sl)
      {
        ContentStruct.Status = TradeStatus::Loss;
      }
    }
    if (ContentStruct.Status != TradeStatus::Pending)
    {
      ContentStruct.EndTime = string(TimeCurrent());
      trades[i] = ContentStruct;
      check++;
    }
  }

  return check;
}

ContentFile GetSignalCommandTradeBySignalNumber(int signal)
{
  ContentFile result = GetDefaultContentFile();
  ContentFile signalHistoryStart[];
  ReadFile(FileNameStartCommandTrade, signalHistoryStart);
  for (int i = 0; i < ArraySize(signalHistoryStart); i++)
  {
    if (signalHistoryStart[i].SignalNumber == signal)
    {
      result = signalHistoryStart[i];
      break;
    }
  }
  return result;
}
int GetTotalTradeVirtualRecentWinLoss(ContentFile &trades[], TradeStatus mode)
{
  int total = 0;
  int totalSizeTrade = ArraySize(trades);
  for (int i = totalSizeTrade; i >= 0; i--)
  {
    ContentFile content = trades[totalSizeTrade - i];
    if (content.Status != mode)
    {
      break;
    }
    total++;
  }
  return total;
}

void WriteArrayStrucContentToFile(string FileName, ContentFile &content[])
{
  int h = FileOpen(FileName, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    printf("Write ArrayStrucContent Error opening file %s", FileName);
  }
  else
  {

    FileSeek(h, 0, SEEK_END);
    for (int i = 0; i < ArraySize(content); i++)
    {
      FileWrite(h, ConvertStructContentFileToString(content[i]));
    }
    FileClose(h);
  }
}

// realTrade = true, chỉ ghi file lệnh thật.
// realTrade = false, chỉ ghi file lệnh ảo.
void WriteLogTradeVirtual(uint BuySell, int numberSignal, ulong ticket = 0, bool realTrade = false)
{
  string fileNameSignal = GetFileNameBySignal(numberSignal);
  string fileNameRealTrade = GetFileNameBySignal(numberSignal, 2);
  ContentFile contentStruct = GetDefaultContentFile();
  contentStruct.Status = TradeStatus::Start;
  contentStruct.BuySell = string(BuySell);
  contentStruct.Entry = string(CalculatePrice(BuySell));
  contentStruct.Sl = string(CalculateStopLoss(BuySell));
  contentStruct.Tp = string(CalculateTakeProfit(BuySell));
  contentStruct.StartTime = string(TimeCurrent());
  contentStruct.EndTime = "0";
  contentStruct.Ticket = ticket;
  string content = ConvertStructContentFileToString(contentStruct);
  if (realTrade)
    WriteStringToFile(fileNameRealTrade, content);
  else
    WriteStringToFile(fileNameSignal, content);
}

void UpdateSignalCommandTradeBySignalNumber(int signal, ContentFile &signalHistoryStartItem)
{
  ContentFile signalHistoryStartArray[];
  ReadFile(FileNameStartCommandTrade, signalHistoryStartArray);
  for (int i = 0; i < ArraySize(signalHistoryStartArray); i++)
  {
    if (signalHistoryStartArray[i].SignalNumber == signal)
    {
      signalHistoryStartArray[i].Ticket = signalHistoryStartItem.Ticket;
    }
  }
  DeleteFileContents(FileNameStartCommandTrade);
  WriteArrayStrucContentToFile(FileNameStartCommandTrade, signalHistoryStartArray);
}
// Đọc file và gán giá trị file $result
void ReadFile(string FileName, ContentFile &result[])
{
  int h = FileOpen(FileName, FILE_READ | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    Print("Read Error opening file: %s", FileName);
    return;
  }
  int i = 0;
  while (!FileIsEnding(h))
  {
    string str = FileReadString(h);
    ArrayResize(result, i + 1);
    result[i] = ConvertStringToStructContentFile(str);
    i++;
  }
  FileClose(h);
}

void CreateFileIfNotExists(string fileName)
{
  // Kiểm tra xem file có tồn tại không
  if (!FileIsExist(fileName))
  {
    // Nếu file chưa tồn tại, tạo mới
    int fileHandle = FileOpen(fileName, FILE_WRITE | FILE_TXT);

    // Kiểm tra xem file đã được tạo thành công hay không
    if (fileHandle != INVALID_HANDLE)
    {
      Print("File đã được tạo: ", fileName);
      FileClose(fileHandle);
    }
    else
    {
      Print("Không thể tạo file: ", fileName);
    }
  }
  else
  {
    Print("File đã tồn tại: ", fileName);
  }
}

void DeleteFileContents(string fileName)
{
  int fileHandle = FileOpen(fileName, FILE_WRITE);

  if (fileHandle != INVALID_HANDLE)
  {
    FileClose(fileHandle);
  }
  else
  {
    printf("Lỗi khi mở file: %s", fileName);
  }
}

// input signalNumber ------ type = 0 temp, type = 1 history
// trả về tên file -- default type = 0 return temp file
string GetFileNameBySignal(int signal, int type = 0)
{
  for (int i = 0; i < ArrayRange(SignalsArray, 0); i++)
  {
    if (SignalsArray[i].SignalNumber == signal)
    {
      return SignalsArray[i].FileName[type] + ".txt";
    }
  }
  return "";
}
string ConvertStructContentFileToString(ContentFile &content)
{
  string result = "";
  result += string(TradeStatus(content.Status)) + "-";
  result += content.BuySell + "-";
  result += content.Entry + "-";
  result += content.Sl + "-";
  result += content.Tp + "-";
  result += content.StartTime + "-";
  result += content.EndTime + "-";
  result += string(content.Ticket) + "-";
  result += string(content.SignalNumber) + "-";
  result += string(content.RR) + "-";
  result += string(content.SignalName);
  return result;
}

ContentFile ConvertStringToStructContentFile(string content)
{
  ContentFile result;
  string contentArray[];
  ConvertStringToArray(content, contentArray);
  result.Status = TradeStatus(contentArray[0]);
  result.BuySell = contentArray[1];
  result.Entry = contentArray[2];
  result.Sl = contentArray[3];
  result.Tp = contentArray[4];
  result.StartTime = contentArray[5];
  result.EndTime = contentArray[6];
  result.Ticket = ulong(contentArray[7]);
  result.SignalNumber = TradeStatus(contentArray[8]);
  result.RR = int(contentArray[9]);
  result.SignalName = contentArray[10];
  return result;
}

double GetHighCandle(int period = 1)
{
  return iHigh(_Symbol, PERIOD_CURRENT, 1);
}
double GetLowCandle(int period = 1)
{
  return iLow(_Symbol, PERIOD_CURRENT, 1);
}

// Hàm này chỉ để Xử lý lệnh Trade ảo và update status không ảnh hưởng tới trade thật
// - nếu không có skip vào lệnh thật
// - nếu có
//    - đọc xem trong file đã có trade nào đang tồn tại không
//    - nếu có thì check xem nó đã có kết quả chưa
//    - nếu số trade ảo bằng vs số trade config nhập.
void CheckVirtualTradeStatus(
    ContentFile &trades[],
    int signal,
    int indexFileFrom,
    int indexFileDestination,
    int totalRecordFileTemp = 100,
    int numberKeepRecord = 50)
{
  string fileNameFrom = GetFileNameBySignal(signal, indexFileFrom);

  ReadFile(fileNameFrom, trades);

  int statusTradeVirtual = CheckVirtualTradeSlTp(trades);
  if (statusTradeVirtual >= 0)
  {
    string fileNameDestination = GetFileNameBySignal(signal, indexFileDestination);
    DeleteFileContents(fileNameFrom);
    // check nếu có hơn totalRecordTemp element thì push vào history sau đó xóa đi trong file temp
    if (ArraySize(trades) > totalRecordFileTemp)
    {
      for (int i = 0; i < numberKeepRecord; i++)
      {
        WriteStringToFile(fileNameDestination, ConvertStructContentFileToString(trades[i]));
      }

      ArrayRemove(trades, 0, numberKeepRecord);
    }

    WriteArrayStrucContentToFile(fileNameFrom, trades);
  }
}

int GetTotalPositionOpenByMagicNumber(ulong magicNumber)
{
  int total = 0;

  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong ticket = PositionGetTicket(i);
    if (PositionGetInteger(POSITION_MAGIC) == magicNumber)
    {
      total++;
    }
  }
  return total;
}

int GetTotalRRRecentHistoryByInput(ContentFile &trades[], InputVirtualRR &inputRR)
{
  int resultTotalRR = 0;
  int countTradeChecked = 0;

  int countContent = ArraySize(trades);
  for (int i = countContent - 1; i >= 0; i--)
  {
    ContentFile content = trades[i];
    if (content.Status == TradeStatus::Start || content.Status == TradeStatus::Pending)
    {
      continue;
    }
    if (countTradeChecked >= inputRR.CheckRecentVirtualTrade)
    {
      break;
    }
    countTradeChecked++;
    if (content.Status == TradeStatus::Win)
    {
      resultTotalRR = resultTotalRR + 1;
    }
    else
    {
      resultTotalRR = resultTotalRR - RiskReward;
    }
  }

  return resultTotalRR;
}
string GetComment(int signal, uint mode, ConditionOpenTrade conditionOpenTrade)
{
  string comment = mode == ModeBuy ? "EA buy" : "EA sell";
  return comment + " - " + GetSignalNameBySignalNumber(signal) + " - " + GetConditionOpenTradeCommentByType(conditionOpenTrade);
}

ulong GetMagicNumberBySignal(int signal)
{
  for (int i = 0; i < ArrayRange(SignalsArray, 0); i++)
  {
    if (SignalsArray[i].SignalNumber == signal)
    {
      return SignalsArray[i].MagicNumber;
    }
  }
  return 0;
}

string GetSignalNameBySignalNumber(int signal)
{
  for (int i = 0; i < ArrayRange(SignalsArray, 0); i++)
  {
    if (SignalsArray[i].SignalNumber == signal)
    {
      return SignalsArray[i].SignalName;
    }
  }
  return "No signal";
}

string GetConditionOpenTradeCommentByType(int type)
{
  for (int i = 0; i < ArraySize(CommentWithConditionTradeArray); i++)
  {
    if (type == CommentWithConditionTradeArray[i].condition)
    {
      return CommentWithConditionTradeArray[i].comment;
    }
  }
  return "";
}

//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+
ContentFile GetDefaultContentFile()
{
  ContentFile result = {
      TradeStatus::Pending,
      "0",
      "0",
      "0",
      "0",
      "0",
      "0",
      0,
      0,
      0,
      "No Signal",
  };
  return result;
}

// input là Number signal
// Trả về 0 nếu không có tín hiệu
// Trả về 1 nếu có tín hiệu mua
// Trả về 2 nếu có tín hiệu bán
uint CheckSignal(int switchCase)
{
  switch (switchCase)
  {
  case 1:
    return CheckRsi();
  case 2:
    return CheckPattern5();
  case 3:
    return CheckMACD();
  case 4:
    return CheckEMA();
  default:
    return 0;
  }
}

InputVirtualRR GetInputTradeWithRR(int signalNumber)
{
  InputVirtualRR inputVirtualRR;
  switch (signalNumber)
  {
  case 1:
    inputVirtualRR.StartTradeNumberVirtualTradeLoss = RSIStartTradeNumberVirtualTradeLoss;
    inputVirtualRR.CheckRecentVirtualTrade = RSIStartTradeNumberVirtualTradeCheck;
    inputVirtualRR.StartTradeRRLossOpenTrade = RSIStartTradeRRLossOpenTrade;
    inputVirtualRR.StopWhenWinXXRR = RSIStopWhenWinXXRR;
    inputVirtualRR.StopWhenLossXXRR = RSIStopWhenLossXXRR;
    inputVirtualRR.StopAfterAction = RSIStopAfterAction;
    break;
  case 2:
    inputVirtualRR.StartTradeNumberVirtualTradeLoss = Pattern5StartTradeNumberVirtualTradeLoss;
    inputVirtualRR.CheckRecentVirtualTrade = Pattern5StartTradeNumberVirtualTradeCheck;
    inputVirtualRR.StartTradeRRLossOpenTrade = Pattern5StartTradeRRLossOpenTrade;
    inputVirtualRR.StopWhenWinXXRR = Pattern5StopWhenWinXXRR;
    inputVirtualRR.StopWhenLossXXRR = Pattern5StopWhenLossXXRR;
    inputVirtualRR.StopAfterAction = Pattern5StopAfterAction;
    break;
  case 3:
    inputVirtualRR.StartTradeNumberVirtualTradeLoss = MACDStartTradeNumberVirtualTradeLoss;
    inputVirtualRR.CheckRecentVirtualTrade = MACDStartTradeNumberVirtualTradeCheck;
    inputVirtualRR.StartTradeRRLossOpenTrade = MACDStartTradeRRLossOpenTrade;
    inputVirtualRR.StopWhenWinXXRR = MACDStopWhenWinXXRR;
    inputVirtualRR.StopWhenLossXXRR = MACDStopWhenLossXXRR;
    inputVirtualRR.StopAfterAction = MACDStopAfterAction;
    break;
  case 4:
    inputVirtualRR.StartTradeNumberVirtualTradeLoss = MALineStartTradeNumberVirtualTradeLoss;
    inputVirtualRR.CheckRecentVirtualTrade = MALineStartTradeNumberVirtualTradeCheck;
    inputVirtualRR.StartTradeRRLossOpenTrade = MALineStartTradeRRLossOpenTrade;
    inputVirtualRR.StopWhenWinXXRR = MALineStopWhenWinXXRR;
    inputVirtualRR.StopWhenLossXXRR = MALineStopWhenLossXXRR;
    inputVirtualRR.StopAfterAction = MALineStopAfterAction;
    break;
  default:
    break;
  }
  return inputVirtualRR;
}
//+------------------------------------------------------------------+
//| End Update when new signal                                       |
//+------------------------------------------------------------------+