//+------------------------------------------------------------------+
//|                                                          DCA.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

#include <Trade/TerminalInfo.mqh>
#include <Trade/Trade.mqh>
#include <Trade/PositionInfo.mqh>
#include <Trade/SymbolInfo.mqh>
#include <Files/File.mqh>
CFile file;
CTrade trade;

input double Points = 200; // số point = biên độ giao động
input double Money1R = 10; // 1R = 10$
input int RiskReward = 2;
input int MaxTrade = 5;
input double TakeProfitFixed = 30;
input string lotSizes = "0.05|0.09|0.09|0.12|0.16|0.21|0.28|0.37|0.49|0.66|0.88|1.17|1.56|2.08|2.78";
input int StartHour = 17; // Bắt đầu vào lệnh từ
input int EndHour = 23;   // Kết thúc vào lệnh từ
input ENUM_TIMEFRAMES IndicatorTimeFrame = PERIOD_M15;
input ulong magicNumberCurrent = 33323;

const int ModeBuy = 1;
const int ModeSell = 2;
const int ModePending = 0;
struct ContentFile
{
  int BuySell;
  double Entry;
  double Sl;
  double Tp;
  double Lot;
  double Volume;
  double Ticket;
};
string fileNameHedge = "hedge.txt";
const string fileNameLog = "log.txt";
const string fileTicket = "checkTicket.txt";
datetime lastCandleTime = 0;
bool clearTrade = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  fileNameHedge = Symbol() + "_" + "_" + string(magicNumberCurrent) + "_hedge.txt";
  CreateFileIfNotExists(fileNameHedge);
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  DeleteFileContents(fileNameHedge);
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
  if (!IsTradeTime())
    return;

  // kiểm tra position hiện tại có lệnh không
  int totalPosition = GetTotalPositionOpenByMagicNumber(magicNumberCurrent);
  // Todo: sau này kiểm tra có signal thì vào lệnh sau
  if (totalPosition == 0)
  {
    if (!CheckCloseBar())
      return;
    DeleteFileContents(fileNameHedge);
    int mode = CheckRsi();
    if (CheckAdx() && (mode == ModeBuy || mode == ModeSell))
    {
      handleOpenTrade(mode);
    }
    return;
  }

  ContentFile contents[];
  ReadFile(fileNameHedge, contents);

  if (totalPosition >= MaxTrade)
  {
    if (GetProfitOpenningByMagicNumber() > TakeProfitFixed)
    {
      CloseAllOpenPositions();
    }
    return;
  }
  ContentFile lastTrade = contents[ArraySize(contents) - 1];
  if (lastTrade.BuySell == ModeBuy)
  {
    if (SymbolInfoDouble(_Symbol, SYMBOL_BID) <= lastTrade.Sl) // kiểm tra lệnh trc đó chạm sl thì vào lệnh mới
    {
      handleOpenTrade(ModeSell);
    }
  }
  else if (lastTrade.BuySell == ModeSell) // sell
  {
    if (SymbolInfoDouble(_Symbol, SYMBOL_ASK) >= lastTrade.Sl)
    {
      handleOpenTrade(ModeBuy);
    }
  }
  // nếu đang không có lệnh thì vào lệnh`∑
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
  IsAnyTradeClosedByTP();
}

bool IsTradeTime()
{
  MqlDateTime rightNow;
  TimeCurrent(rightNow);
  int hour = rightNow.hour;

  return hour >= StartHour && hour < EndHour;
}

void handleOpenTrade(int mode)
{
  ContentFile content = GetDefaultContentFileBuySell(mode);
  OpenTrade(content);
}
//+------------------------------------------------------------------+
void IsAnyTradeClosedByTP()
{

  datetime timeAgo = TimeCurrent() - 1; // 30 phút được tính bằng giây
  if (HistorySelect(timeAgo, TimeCurrent()))
  {
    int totalDeals = HistoryDealsTotal();
    // Duyệt qua từng giao dịch trong lịch sử
    for (int i = totalDeals - 1; i >= 0; i--)
    {
      ulong dealTicket = HistoryDealGetTicket(i);
      // kiểm tra xem giao dịch này có phải là giao dịch đóng theo take profit không
      if (HistoryDealGetInteger(dealTicket, DEAL_REASON) == DEAL_REASON_TP)
      {
        CloseAllOpenPositions();
        break;
      }
    }
  }
  else
  {
    printf("Không có lệnh nào trong 30 phút gần đây");
  }
}
bool CheckCloseBar()
{
  datetime currentCandleTime = iTime(_Symbol, PERIOD_M1, 0); // Lấy thời gian của nến hiện tại

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

double GetProfitOpenningByMagicNumber()
{
  double totalProfit = 0.0;

  for (int i = 0; i < PositionsTotal(); i++)
  {
    ulong positionTicket = PositionGetTicket(i);
    double profit = 0;
    double swap = 0.0;

    PositionGetDouble(POSITION_PROFIT, profit);
    PositionGetDouble(POSITION_SWAP, swap);
    totalProfit += profit + swap;
  }
  return totalProfit;
}
// Đóng tất cả các lệnh đang mở
void CloseAllOpenPositions()
{
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    trade.PositionClose(positionTicket);
  }

  DeleteFileContents(fileNameHedge);
}

double CalculateStopLoss(int BuySell)
{
  double pointValue = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
  double result;
  if (BuySell == ModeBuy)
    result = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - Points * pointValue;
  else
    result = SymbolInfoDouble(Symbol(), SYMBOL_BID) + Points * pointValue;
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
    result = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + Points * RiskReward * pointValue;
  else
    result = SymbolInfoDouble(Symbol(), SYMBOL_BID) - Points * RiskReward * pointValue;

  int digits = int(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
  return NormalizeDouble(result, digits);
}

double CalculateLotSize()
{
  ContentFile content[];
  ReadFile(fileNameHedge, content);
  string lotVolumeArray[];
  ConvertStringToArray(lotSizes, lotVolumeArray);
  return StringToDouble(lotVolumeArray[ArraySize(content)]);
}
bool CheckAdx()
{
  double bufferADX[];
  ArraySetAsSeries(bufferADX, true);
  int total = CopyBuffer(iADX(_Symbol, IndicatorTimeFrame, 14), 0, 0, 2, bufferADX);
  double buffer = bufferADX[1];
  int range = 30;
  if (buffer > range)
  {
    return true;
  }
  return false;
}
int CheckRsi()
{
  double bufferRSI[];
  ArraySetAsSeries(bufferRSI, true);
  int total = CopyBuffer(iRSI(_Symbol, IndicatorTimeFrame, 14, PRICE_CLOSE), 0, 0, 4, bufferRSI);

  double buffer = bufferRSI[1];
  double buffer1 = bufferRSI[2];
  if (buffer1 >= 70 && buffer < 70)
  {
    return ModeSell;
  }
  if (buffer1 <= 30 && buffer > 30)
  {
    return ModeBuy;
  }
  return ModePending;
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
string ConvertStructContentFileToString(ContentFile &content)
{
  string result = "";
  string character = "|";
  result += string(content.BuySell) + character;
  result += string(content.Entry) + character;
  result += string(content.Sl) + character;
  result += string(content.Tp) + character;
  result += string(content.Lot);
  return result;
}

ContentFile GetDefaultContentFileBuySell(int BuySell)
{
  ContentFile content;
  content.BuySell = BuySell;
  content.Entry = CalculatePrice(BuySell);
  content.Sl = CalculateStopLoss(BuySell);
  content.Tp = CalculateTakeProfit(BuySell);
  content.Lot = CalculateLotSize();
  return content;
}
ContentFile ConvertStringToStructContentFile(string content)
{
  ContentFile result;
  string contentArray[];
  ConvertStringToArray(content, contentArray);
  result.BuySell = int(contentArray[0]);
  result.Entry = StringToDouble(contentArray[1]);
  result.Sl = StringToDouble(contentArray[2]);
  result.Tp = StringToDouble(contentArray[3]);
  result.Lot = StringToDouble(contentArray[4]);
  return result;
}
void ConvertStringToArray(string str, string &subString[], string delimiter = "|")
{
  StringSplit(str, StringGetCharacter(delimiter, 0), subString);
}

void OpenTrade(ContentFile &ContentFile)
{
  MqlTradeRequest request = {};
  MqlTradeResult result = {};
  request.type = ContentFile.BuySell == ModeBuy ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
  request.price = ContentFile.Entry;
  request.magic = magicNumberCurrent;
  request.symbol = _Symbol;
  request.action = TRADE_ACTION_DEAL;
  request.tp = ContentFile.Tp;
  // request.sl = ContentFile.Sl;
  request.volume = ContentFile.Lot;
  bool status = OrderSend(request, result);
  if (!status)
  {
    printf("Trade is not opened. Error: %d", GetLastError());
  }
  else
  {
    WriteStringToFile(fileNameHedge, ConvertStructContentFileToString(ContentFile));
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

void CloseAllPositions()
{
  CPositionInfo positionInfo;
  for (int i = PositionsTotal() - 1; i >= 0; i--)
  {
    ulong positionTicket = PositionGetTicket(i);
    if (positionInfo.SelectByTicket(positionTicket))
    {
      string symbol = positionInfo.Symbol();
      if (positionInfo.PositionType() == POSITION_TYPE_BUY)
      {
        trade.PositionClose(symbol, positionTicket); // Đóng vị thế mua
      }
      else if (positionInfo.PositionType() == POSITION_TYPE_SELL)
      {
        trade.PositionClose(symbol, positionTicket); // Đóng vị thế bán
      }
    }
    printf("lastError = %d", GetLastError());
  }
}
