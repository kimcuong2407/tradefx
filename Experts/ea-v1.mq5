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
input int StopLoss = 150;
input int TakeProfit = 450;

input group "Risk Management";
input int MaxOrderOpen = 1;
input double xxLoss = 1.0;
input int StartXXWhenLoss = 2; // StartXXWhenLoss = 0 xxLoss Invalid
input double xxProfit = 1.0;
input int StartXXWhenProfit = 2;

input group "Signal";
input string NumberSignal = "1-2-4"; // Số tín hiệu cần thỏa mãn cùng lúc

input group "RSI signal 1";
input double RSISell = 65; // Open sell when RSI > input
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

const uchar totalSignal = 4;
uint ArraySignal[4];

//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+
const string Signal1Rsi = "1";
const string Signal2Pattern5 = "2";
const string Signal3MACD = "3";
const string Signal4EMA = "4";
const string MagicNumber1Rsi = "120021";
const string MagicNumber2Pattern5 = "120022";
const string MagicNumber3MACD = "120023";
const string MagicNumber4EMA = "120024";

const string Signals[4][3] = {{Signal1Rsi, "1RSI.txt", MagicNumber1Rsi},
                              {Signal2Pattern5, "2Pattern5.txt", MagicNumber2Pattern5},
                              {Signal3MACD, "3MACD.txt", MagicNumber3MACD},
                              {Signal4EMA, "4EMA.txt", MagicNumber4EMA}};
//+------------------------------------------------------------------+
//|  end update when new signal                                      |
//+------------------------------------------------------------------+

string NumberSignalsArray[];

const int ModeBuy = 1;
const int ModeSell = 2;
const int ModePending = 0;

const string VirtualTradeWin = "1";
const string VirtualTradeLoss = "2";
const string VirtualTradePeding = "0";

datetime lastCandleTime = 0;

// double VirtualHistory[][]; // result - buy|sell - sl - tp
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

  // getHistoryTrade();
  // Convert Input and hide indicator on backtest
  ConvertStringToArray(NumberSignal, NumberSignalsArray);
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
  int total = PositionsTotal();
  if (total >= MaxOrderOpen)
  {
    return;
  }

  if (CheckCloseBar())
  {
    double high = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double low = iLow(_Symbol, PERIOD_CURRENT, 1);
    for (int i = 0; i < ArraySize(NumberSignalsArray); i++)
    {
      int numberSignal = int(NumberSignalsArray[i]);
      short statusTradeVirtual = -1;
      string fileName = GetFindNameBySignal(NumberSignalsArray[i]);
      string VirtualHistory[];
      string VirtualSignal = CheckExistsVirtualTrade(numberSignal);
      if (VirtualSignal != "")
      {
        // đọc file và check xem nó có trade ảo nào đang tồn tại không
        ReadFile(fileName, VirtualHistory);
        // statusTradeVirtual = -1 không có trade virtul nào đang tồn tại
        // statusTradeVirtual = 0 có trade virtual nhưng chưa có kết quả
        // statusTradeVirtual = 1 có trade virtual và đã có kết quả
        statusTradeVirtual = CheckTradeSLTP(VirtualHistory, low, high);
        if (statusTradeVirtual == 1)
        {
          DeleteFileContents(fileName);
          WriteArrayToFile(fileName, VirtualHistory);
        }
      }

      uint BuySell = CheckSignal(numberSignal);
      if (BuySell == 0)
        continue;

      if (VirtualSignal != "")
      {
        string VirtualTradeInput[];
        ConvertStringToArray(VirtualSignal, VirtualTradeInput);
        int numberSignalVirtual = int(VirtualTradeInput[0]);
        int maxTrade = int(VirtualTradeInput[1]);
        int totalRecentLoss = GetTotalTradeVirtualRecentWinLoss(VirtualHistory, ModeSell);
        if (totalRecentLoss < numberSignal && statusTradeVirtual != 0)
        {
          string content[] = {"0", string(BuySell), string(low), string(high)};
          WriteStringToFile(fileName, ConvertArrayToString(content));
        }
        else
        {
          OpenTrade(BuySell, numberSignal);
        }
        // insert record to HistoryVirtualTrade[][]
      }
      else
      {
        // không có dữ liệu cho lệnh ảo thì trực tiếp vào lệnh thật
        OpenTrade(BuySell, numberSignal);
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

uint CheckEMA()
{
  double buffer[];
  int inputIMA = iMA(_Symbol, _Period, MAPeriod, MAShift, MaMethod, PRICE_CLOSE);
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
int CheckMACD()
{
  double bufferMacd[];
  int iMACD = iCustom(_Symbol, _Period, "MACD", 12, 26, 9, PRICE_CLOSE);
  int copyBufferMacd = CopyBuffer(iMACD, 1, 0, 3, bufferMacd);

  for (int i = 0; i < 3; i++)
  {
    printf("MACD: %f", bufferMacd[i]);
  }
  return 0;
}
int CheckRsi()
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

double PointsToPips(double points)
{
  return points * _Point;
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
      if (dealTicket <= 0)
        break;
      long dealType = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
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

void getHistoryTrade()
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

bool OpenTrade(uint mode, int signalNumber)
{
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
  double stopLossPrice, takeProfitPrice;

  // Lấy giá trị Point cho cặp tiền tệ hiện tại
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

  request.volume = calculatorLotSize();
  if (mode == 1)
  {
    stopLossPrice = currentPrice - StopLoss * pointValue;
    takeProfitPrice = currentPrice + TakeProfit * pointValue;
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    request.type = ORDER_TYPE_BUY;
  }
  else
  {
    stopLossPrice = currentPrice + StopLoss * pointValue;
    takeProfitPrice = currentPrice - TakeProfit * pointValue;
    request.price = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    request.type = ORDER_TYPE_SELL;
  }
  request.magic = long(GetMagicNumberBySignal(string(signalNumber)));
  ;                                   // ORDER_MAGIC
  request.symbol = _Symbol;           // symbol
  request.action = TRADE_ACTION_DEAL; // setting a pending order
  request.sl = stopLossPrice;         // Stop Loss is not specified
  request.tp = takeProfitPrice;       // Take Profit is not specified
  request.comment = GetComment(signalNumber, mode);

  bool status = OrderSend(request, result);
  DeleteFileContents(GetFindNameBySignal(string(signalNumber)));

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

void AddHistoryVirtualTrade(int signalNumber, int mode, double sl, double tp)
{
  // HistoryVirtualTrade[signalNumber][mode] = {mode, sl, tp};
}
void WriteStringToFile(string FileName, string content = "hello")
{
  int h = FileOpen(FileName, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    printf("Error opening file %s", FileName);
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
short CheckTradeSLTP(string &trades[], double low, double high)
{
  short check = -1;
  for (int i = 0; i < ArraySize(trades); i++)
  {
    string content[];
    ConvertStringToArray(trades[i], content, "-");
    int result = int(content[0]);
    if (result != 0)
    {
      continue;
    }
    check++;
    int mode = int(content[1]);
    double sl = double(content[2]);
    double tp = double(content[3]);
    if (mode == ModeBuy)
    {
      if (high > tp)
      {
        content[0] = VirtualTradeWin;
      }
      else if (low < sl)
      {
        content[0] = VirtualTradeLoss;
      }
    }
    else
    {
      if (low < tp)
      {
        content[0] = VirtualTradeWin;
      }
      else if (high > sl)
      {
        content[0] = VirtualTradeLoss;
      }
    }
    if (content[0] != VirtualTradePeding)
    {
      trades[i] = ConvertArrayToString(content);
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
void WriteArrayToFile(string FileName, string &content[])
{
  int h = FileOpen(FileName, FILE_READ | FILE_WRITE | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    printf("Error opening file %s", FileName);
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

void ReadFile(string FileName, string &result[])
{
  int h = FileOpen(FileName, FILE_READ | FILE_ANSI | FILE_TXT);
  if (h == INVALID_HANDLE)
  {
    Print("Error opening file");
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

void DeleteFileContents(string fileName)
{
  // Mở file trong chế độ ghi, điều này sẽ xóa sạch nội dung của file
  int fileHandle = FileOpen(fileName, FILE_WRITE);

  // Kiểm tra xem file có mở thành công không
  if (fileHandle != INVALID_HANDLE)
  {
    FileClose(fileHandle);
  }
  else
  {
    printf("Lỗi khi mở file: %s", fileName);
  }
}

string GetFindNameBySignal(string signal)
{
  for (int i = 0; i < ArraySize(Signals); i++)
  {
    if (Signals[i][0] == signal)
    {
      return Signals[i][1];
    }
  }
  return "";
}

string GetMagicNumberBySignal(string signal)
{
  for (int i = 0; i < ArraySize(Signals); i++)
  {
    if (Signals[i][0] == signal)
    {
      return Signals[i][2];
    }
  }
  return "";
}
//+------------------------------------------------------------------+
//|  Update when new signal                                          |
//+------------------------------------------------------------------+
string GetComment(int i, uint mode)
{
  switch (i)
  {
  case 1:
    return mode == ModeBuy ? "EA buy RSI" : "EA sell RSI Sell";
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

string CheckExistsVirtualTrade(int switchCase)
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
    return "error";
  }
}

uint CheckSignal(int switchCase)
{
  switch (switchCase)
  {
  case 1:
    return CheckRsi();
  case 2:
    return checkPattern5();
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