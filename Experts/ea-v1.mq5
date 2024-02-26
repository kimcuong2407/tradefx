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
input int MaxOrderOpen = 1;
input int StartXXWhenLoss = 2; // StartXXWhenLoss = 0 xxLoss Invalid
input double xxLoss = 1.0;
input int StartXXWhenProfit = 2;
input double xxProfit = 1.0;

input group "Signal";
input string NumberSignal = "1-2-4"; // Nhập tín hiệu vào lệnh. Example: 1-2

input group "RSI signal 1";
input double RSISell = 70; // Open sell when RSI > input
input double RSIBuy = 30;  // Open buy when RSI < input
input string RSIVirtualTrade = "2-2";

input group "Pattern 5 signal 2";
input int BodyLength = 50;
input string Pattern5VirtualTrade = "2-2";

// input group "MACD";
input group "MACD signal 3";
input string MACDVirtualTrade = "2-2";

input group "EMA signal 4";
input ENUM_MA_METHOD MaMethod = MODE_EMA;
input int MAPeriod = 25;
input int MAShift = 0;
input string MAVirtualTrade = "2-2";

//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+
const int Signal1Rsi = 1;
const int Signal2Pattern5 = 2;
const int Signal3MACD = 3;
const int Signal4EMA = 4;
const int MagicNumber1Rsi = 120021;
const int MagicNumber2Pattern5 = 120022;
const int MagicNumber3MACD = 120023;
const int MagicNumber4EMA = 120024;

struct ContentFile
{
  string VirtualTrade;
  string BuySell;
  string Entry;
  string Sl;
  string Tp;
  string StartTime;
  string EndTime;
};

struct XLot
{
  /* data */
};

struct Signal
{
  int SignalNumber;
  string FileName[4];
  ulong MagicNumber;
};

const Signal Signals[4] = {
    {Signal1Rsi,
     {"1RSI_temp",
      "1RSI_history",
      "1RSI_REAL",
      "1RSI_ALL_TRADE"},
     MagicNumber1Rsi},
    {Signal2Pattern5,
     {
         "2Pattern5_temp",
         "2Pattern5_history",
         "2Pattern5_REAL",
         "2Pattern5_ALL_TRADE",
     },
     MagicNumber2Pattern5},
    {Signal3MACD,
     {
         "3MACD_temp",
         "3MACD_history",
         "3MACD_REAL",
         "3MACD_ALL_TRADE",
     },
     MagicNumber3MACD},
    {Signal4EMA,
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

const string VirtualTradePending = "0";
const string VirtualTradeWin = "1";
const string VirtualTradeLoss = "2";

datetime lastCandleTime = 0;

// double VirtualHistory[][]; // result - buy|sell - sl - tp
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  // Convert Input and hide indicator on backtest
  ConvertStringToArray(NumberSignal, NumberSignalsArray);
  for (int i = 0; i < ArraySize(NumberSignalsArray); i++)
  {
    CreateFileIfNotExists(GetFileNameBySignal(int(NumberSignalsArray[i])));
    CreateFileIfNotExists(GetFileNameBySignal(int(NumberSignalsArray[i]), 1));
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
  for (int i = 0; i < ArrayRange(Signals, 0); i++)
  {
    // DeleteFileContents(GetFileNameBySignal(Signals[i].SignalNumber));
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
      string VirtualSignalHistory[];
      string VirtualTradeReal[];
      string InputVirtualSignal = GetInputVirtualTradeBySignal(numberSignal);

      // update file signal history
      CheckVirtualTradeStatus(VirtualSignalHistory, numberSignal, 0, 1, 100, 30);

      // update file virtual trade real
      CheckVirtualTradeStatus(VirtualTradeReal, numberSignal, 2, 3, 100, 20);

      uint BuySell = CheckSignal(numberSignal);
      if (BuySell == 0)
      {
        // note: Don't have signal
        continue;
      }

      if (totalPositionOpenWithTicket >= MaxOrderOpen)
      {
        // note: add log virtual trade when max order open
        WriteLogTradeVirtual(BuySell, numberSignal);
        continue;
      }

      if (InputVirtualSignal == "")
      {
        // note: add log virtual trade when open trade
        WriteLogTradeVirtual(BuySell, numberSignal, true);
        OpenTrade(BuySell, numberSignal);
        continue;
      }
      // convert input virtual trade to array
      string VirtualTradeInput[];
      ConvertStringToArray(InputVirtualSignal, VirtualTradeInput);

      int numberSignalVirtual = int(VirtualTradeInput[0]);

      int totalRecentLoss = GetTotalTradeVirtualRecentWinLoss(VirtualTradeReal, ModeSell);
      if (totalRecentLoss >= numberSignalVirtual)
      {
        WriteLogTradeVirtual(BuySell, numberSignal, true);
        OpenTrade(BuySell, numberSignal);
      }
      else
      {
        WriteLogTradeVirtual(BuySell, numberSignal);
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
  int iMACD = iCustom(_Symbol, _Period, "MACD", 12, 26, 9, PRICE_CLOSE);
  int copyBufferMacd = CopyBuffer(iMACD, 1, 0, 3, bufferMACD);

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

void GetHistoryTrade()
{
  if (HistorySelect(0, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();
    for (int i = 0; i < totalDeals; i++)
    {
      ulong dealTicket = HistoryDealGetTicket(totalDeals - i);
      if (dealTicket > 0)
      {

        long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
        if (dealType == DEAL_ENTRY_OUT)
        {
          double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
          Print("Deal ticket: ", dealTicket, " - Deal type: ", dealType, " - Profit: ", profit);
        }
      }
    }
  }
  else
  {
    Print("Không thể truy xuất lịch sử giao dịch.");
  }
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

double CalculatorLotSize()
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
    return xx > 0 ? MathRound(CalculateExponential(int(MathRound(xxProfit)), xx) * LotSize * 100) / 100 : LotSize;
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
bool OpenTrade(uint mode, int signalNumber)
{
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  request.volume = CalculatorLotSize();
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
  request.magic = GetMagicNumberBySignal(signalNumber);
  request.symbol = _Symbol;               // symbol
  request.action = TRADE_ACTION_DEAL;     // setting a pending order
  request.sl = CalculateStopLoss(mode);   // Stop Loss is not specified
  request.tp = CalculateTakeProfit(mode); // Take Profit is not specified
  request.comment = GetComment(signalNumber, mode);
  bool status = OrderSend(request, result);

  Print(__FUNCTION__, ":", result.comment);
  if (result.retcode == 10016)
  {
    Print(result.bid, result.ask, result.price);
    return true;
  }
  else
  {
    return false;
  }
  //--- return code of the trade server reply
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
short CheckVirtualTradeSlTp(string &trades[])
{
  double low = iLow(_Symbol, PERIOD_CURRENT, 1);
  double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
  short check = -1;
  for (int i = 0; i < ArraySize(trades); i++)
  {
    ContentFile ContentStruct = ConvertStringToStructContentFile(trades[i]);
    if (ContentStruct.VirtualTrade != VirtualTradePending)
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
        ContentStruct.VirtualTrade = VirtualTradeWin;
      }
      else if (low < sl)
      {
        ContentStruct.VirtualTrade = VirtualTradeLoss;
      }
    }
    else
    {
      if (low < tp)
      {
        ContentStruct.VirtualTrade = VirtualTradeWin;
      }
      else if (high > sl)
      {
        ContentStruct.VirtualTrade = VirtualTradeLoss;
      }
    }
    if (ContentStruct.VirtualTrade != VirtualTradePending)
    {
      ContentStruct.EndTime = string(TimeCurrent());
      string content = ConvertStructContentFileToString(ContentStruct);
      trades[i] = content;
      check++;
    }
  }

  return check;
}

int GetTotalTradeVirtualRecentWinLoss(string &trades[], int mode)
{
  int total = 0;
  int totalSizeTrade = ArraySize(trades);
  for (int i = 1; i < totalSizeTrade; i++)
  {
    string content[];
    ConvertStringToArray(trades[totalSizeTrade - i], content, "-");
    int result = int(content[0]);
    if (result != mode)
    {
      break;
    }
    total++;
  }
  return total;
}
void WriteArrayToFile(string FileName, string &content[], int signal = 0)
{
  int h = FileOpen(FileName, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    printf("Write Array Error opening file %s", FileName);
  }
  else
  {

    FileSeek(h, 0, SEEK_END);
    for (int i = 0; i < ArraySize(content); i++)
    {
      FileWrite(h, content[i]);
    }
    FileClose(h);
  }
}
void WriteLogTradeVirtual(uint BuySell, int numberSignal, bool realTrade = false)
{
  string fileName = GetFileNameBySignal(numberSignal);
  string fileNameRealTrade = GetFileNameBySignal(numberSignal, 2);
  ContentFile contentStruct;
  contentStruct.VirtualTrade = VirtualTradePending;
  contentStruct.BuySell = string(BuySell);
  contentStruct.Entry = string(CalculatePrice(BuySell));
  contentStruct.Sl = string(CalculateStopLoss(BuySell));
  contentStruct.Tp = string(CalculateTakeProfit(BuySell));
  contentStruct.StartTime = string(TimeCurrent());
  contentStruct.EndTime = "0";
  string content = ConvertStructContentFileToString(contentStruct);
  if (realTrade)
    WriteStringToFile(fileNameRealTrade, content);
  WriteStringToFile(fileName, content);
}
// Đọc file và gán giá trị file $result
void ReadFile(string FileName, string &result[])
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
    result[i] = str;
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
  for (int i = 0; i < ArrayRange(Signals, 0); i++)
  {
    if (Signals[i].SignalNumber == signal)
    {
      return Signals[i].FileName[type] + ".txt";
    }
  }
  return "";
}
string ConvertStructContentFileToString(ContentFile &content)
{
  string result = "";
  result += content.VirtualTrade + "-";
  result += content.BuySell + "-";
  result += content.Entry + "-";
  result += content.Sl + "-";
  result += content.Tp + "-";
  result += content.StartTime + "-";
  result += content.EndTime;
  return result;
}

ContentFile ConvertStringToStructContentFile(string content)
{
  ContentFile result;
  string contentArray[];
  ConvertStringToArray(content, contentArray);
  result.VirtualTrade = contentArray[0];
  result.BuySell = contentArray[1];
  result.Entry = contentArray[2];
  result.Sl = contentArray[3];
  result.Tp = contentArray[4];
  result.StartTime = contentArray[5];
  result.EndTime = contentArray[6];
  return result;
}

ulong GetMagicNumberBySignal(int signal)
{
  for (int i = 0; i < ArrayRange(Signals, 0); i++)
  {
    if (Signals[i].SignalNumber == signal)
    {
      return Signals[i].MagicNumber;
    }
  }
  return 0;
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
    string &trades[],
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
      string fileNameDestination = GetFileNameBySignal(signal, 1);
      for (int i = 0; i < numberKeepRecord; i++)
      {
        WriteStringToFile(fileNameDestination, trades[i]);
      }

      ArrayRemove(trades, 0, numberKeepRecord);
    }

    WriteArrayToFile(fileNameFrom, trades);
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

int GetTotalRRRecentHistory(int totalNumberTradeRecent = 0, int signal = 0)
{
  string fileName = GetFileNameBySignal(signal);
  string contents[];
  int resultTotalRR = 0;
  int countTradeChecked = 0;
  ReadFile(fileName, contents);
  int countContent = ArraySize(contents);
  for (int i = countContent - 1; i >= 0; i--)
  {
    string content[];
    ConvertStringToArray(contents[i], content);
    if (content[0] == VirtualTradePending)
    {
      continue;
    }
    if (countTradeChecked >= totalNumberTradeRecent)
    {
      break;
    }
    countTradeChecked++;
    if (content[0] == VirtualTradeWin)
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
//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+
string GetComment(int i, uint mode)
{
  switch (i)
  {
  case 1:
    return mode == ModeBuy ? "EA buy RSI" : "EA sell RSI";
  case 2:
    return mode == ModeBuy ? "EA buy Pattern 5" : "EA sell Pattern 5";
  case 3:
    return mode == ModeBuy ? "EA buy MACD" : "EA sell MACD";
  case 4:
    return mode == ModeBuy ? "EA buy EMA" : "EA sell EMA";
  default:
    return mode == ModeBuy ? "EA buy" : "EA sell";
  }
}

string GetInputVirtualTradeBySignal(int switchCase)
{
  switch (switchCase)
  {
  case 1:
    return RSIVirtualTrade;
  case 2:
    return Pattern5VirtualTrade;
  case 3:
    return MACDVirtualTrade;
  case 4:
    return MAVirtualTrade;
  default:
    return "";
  }
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
//+------------------------------------------------------------------+
//| End Update when new signal                                       |
//+------------------------------------------------------------------+