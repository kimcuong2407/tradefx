//+----------------------------------------------------------------------------+
//|                                              SmartMoneyConcept Order Block |
//|                                                Copyright 2023, CompanyName |
//|                                                 http://www.companyname.net |
//+----------------------------------------------------------------------------+
#property copyright "Copyright © 2023"
#property link "alickhillpark@gmail.com"
#property version "3.0"
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\Trade.mqh> CTrade trade; // trading object
#include <Trade/Trade.mqh>
CTrade Trade;
CTrade m_trade;       // trading object
CSymbolInfo m_symbol; // symbol info object
COrderInfo m_order;   // object of COrderInfo class

input group "Parameters For Order Block Trading "
input bool DrawAnnOrderBlock = true; // Draw ANN Order Block
input bool DrawSMCOrderBlock = true;                                                   // Draw SMC Order Block
input bool TradeAnn = true;                                                            // Execute Ann Order Block Trades
input bool TradeSmc = true;                                                            // Execute SMC Order Block Trades
input ENUM_TIMEFRAMES BigAnnOBtimeframe = PERIOD_CURRENT;                                   // Higher TimeFrame of ANN OB
input ENUM_TIMEFRAMES BigSMCOBtimeframe = PERIOD_CURRENT;                                   // Higher TimeFrame of SMC OB
input ENUM_TIMEFRAMES TinyOBtimeframe = PERIOD_CURRENT;                                     // Lower TimeFrame of OB
input int showlder = 4;                                                                // Shoulder
input int startbar = 5;                                                                // StartBar
input int PeaksLookBack = 199;                                                         // Look Back How Far To Find Order Block

input group "Parameters For Open Trades With No SL TP Or Trail " input int InpTakeProfitPoints = 2520;                                                                  // TakeProfit points Added to open Trade with NO TP
input int InpStopLossPoints = 150;                                                                                                                                      // StopLoss points Added to open Trade with NO SL
input int InpTriggerBEStopLossPoints = 210;                                                                                                                             // TriggerBEStopLossPoints
input int InpBEStopLossPoints = 50;                                                                                                                                     // BEStopLossPoints
input int InpTrailStopLossPoints = 320;                                                                                                                                 // TrailPoints
input double TrailMultiplier = 1.1;                                                                                                                                     // TrailMultiplier
input group "Enter the Price at which you want A Pending Order To Open "
input group "Pending parameters Either Sell Stop is Zero or BuyStop"
 input double Lots = 0.01; // Lots
input uchar InpBuySellQuantity = 5;                                                                                                                                     // Max Buy Or Sell u want
input uchar InpUpQuantity = 1;                                                                                                                                          // Pending quantity How many Pending u want
input ushort InpUpStep = 10;                                                                                                                                            // Step/Gap between orders (in points)Distance Between Order's'
input ENUM_TIMEFRAMES TS_period = PERIOD_M10;                                                                                                                           // Pend Price Trig Timeframe
input group "When the market moves near the pending order price above you put a grid of pending can be sent "

    input int InpMagicNumber = 0;
input int PositionOpenWithin = 300; // Open Within Seconds Applies 2 SL

input group "Time Filter" input string StartTradingi = "07:00";
input string EndTradingi = "11:00";
input string StartTradingii = "13:00";
input string EndTradingii = "17:00";
input bool OrderTest = false;                                                                                        // Enable Tester Order (in Backtest Only)
input int Slippage = 10;                                                                                             // Slippage
input group "Equity parameters Based on 0.01 Lot. Then EA ratio's on your Lot Size"
 input bool EquityManager = true; // Turn Euity Manager On True Off False
input double MaxFloatLoss = 1.3;                                                                                     // Money Equity Loss Stop
input double EquityBEStopLoss = 2.5;                                                                                 // Money Equity BE Stop
input double EquityTrigBEStop = 7;                                                                                   // Money To Trig BE Stop
input double EquityTrail = 10;                                                                                       // Money To Trail After BE
//+----------------------------------------------+
bool Stop, Profit;
double Percentage;
double EquitySL;
double TakeProfit;
double StopLoss;
double BETrail;
double BETrigger;
double BESL;
string CurrentTime;
bool TradingIsAllowed = false;
double m_adjusted_point; // point value adjusted for 3 or 5 points
ulong m_slippage = 30;   // slippage
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit(void)
{

   //   if(ObjectFind(0,"HLineSL") == 0)// Exists
   createBackground();
   createObject("Profit", "Money P/L is: $" + DoubleToString(CalculateTotalProfit(), 2));
   createObject2("Percent", "Percentage P/L is: " + DoubleToString(Percentage, 2) + "%");
   createObject4("Equity HL", "Equity Stop/L is: $" + DoubleToString(HLineSLprice(), 2));
   //----
   Stop = false;
   Profit = false;
   //---- завершение инициализации
   return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //----
   ObjectDelete(0, "Background");
   ObjectDelete(0, "Profit");
   ObjectDelete(0, "Percent");
   ObjectDelete(0, "Equity HL");
   return;
   //----
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
{

   string symbol = PositionGetString(POSITION_SYMBOL);
   Percentage = (CalculateTotalProfit() * 100) / AccountInfoDouble(ACCOUNT_BALANCE);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double Spred = NormalizeDouble(Ask() - Bid(), digits);

   int lowbari = lowestBar(TinyOBtimeframe, 35 - startbar, startbar);
   int lowbarii = lowestBar(TinyOBtimeframe, 35 - lowbari + 4, lowbari + 4);

   //// if()
   int bar19 = barscann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar);
   int bar19i = OBbarann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19);
   double hi19 = OBhighann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19);
   double lo19 = OBlowann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19);
   ObjectDelete(0, "ANNbuy");                                            // 210
   ChartWrite("ANNbuy", "ANNbuy" + (string)hi19, 100, 14, 10, clrWhite); // Write Number of Orders on the Chart

   int xbar19 = barscann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar);
   int xbar19i = OBbarann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar, xbar19);
   double xhi19 = OBhighann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar, xbar19);
   double xlo19 = OBlowann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar, xbar19);
   ObjectDelete(0, "ANNsellz");                                                 // 210
   ChartWritei("ANNsellz", "ANNsellz" + (string)xlo19, 100, 28, 10, clrYellow); // Write Number of Orders on the Chart
   ///--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   //---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0, "bullOBhi19");
   ObjectDelete(0, "bullOBlo19");
   datetime t_th19 = iTime(NULL, BigAnnOBtimeframe, bar19i);
   datetime f_ti19 = iTime(NULL, BigAnnOBtimeframe, bar19i - bar19i);
   if (DrawAnnOrderBlock)
   {
      ObjectCreate(0, "bullOBhi19", OBJ_TREND, 0, t_th19, hi19, f_ti19, hi19);
      ObjectSetInteger(0, "bullOBhi19", OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, "bullOBhi19", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBhi19", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bullOBlo19", OBJ_TREND, 0, t_th19, lo19, f_ti19, lo19);
      ObjectSetInteger(0, "bullOBlo19", OBJPROP_COLOR, clrPink);
      ObjectSetInteger(0, "bullOBlo19", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBlo19", OBJPROP_WIDTH, 3);
   }
   // xxxxx
   ObjectDelete(0, "bearOBhi19");
   ObjectDelete(0, "bearOBlo19");
   datetime t_t19 = iTime(NULL, BigAnnOBtimeframe, xbar19i);
   datetime f_t19 = iTime(NULL, BigAnnOBtimeframe, xbar19i - xbar19i);
   if (DrawAnnOrderBlock)
   {
      ObjectCreate(0, "bearOBhi19", OBJ_TREND, 0, t_t19, xhi19, f_t19, xhi19);
      ObjectSetInteger(0, "bearOBhi19", OBJPROP_COLOR, clrKhaki);
      ObjectSetInteger(0, "bearOBhi19", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBhi19", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bearOBlo19", OBJ_TREND, 0, t_t19, xlo19, f_t19, xlo19);
      ObjectSetInteger(0, "bearOBlo19", OBJPROP_COLOR, clrKhaki);
      ObjectSetInteger(0, "bearOBlo19", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBlo19", OBJPROP_WIDTH, 3);
   }
   // xxxxx ///
   //// if()
   int bar20 = barscasmc(BigSMCOBtimeframe, MODE_HIGH, showlder, startbar);
   int bar20i = OBbarsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, startbar, bar20);
   double hi20 = OBhighsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, startbar, bar20);
   double lo20 = OBlowsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, startbar, bar20);
   ObjectDelete(0, "SMCsellz");                                                // 210
   ChartWriteii("SMCsellz", "SMCsellz" + (string)hi20, 100, 44, 10, clrWhite); // Write Number of Orders on the Chart

   int xbar20 = barscasmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar);
   int xbar20i = OBbarsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20);
   double xhi20 = OBhighsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20);
   double xlo20 = OBlowsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20);
   ObjectDelete(0, "SMCbuy");                                                 // 210
   ChartWriteiii("SMCbuy", "SMCbuy" + (string)xlo20, 100, 60, 10, clrYellow); // Write Number of Orders on the Chart
   ///--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   //---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0, "bearOBhi20");
   ObjectDelete(0, "bearOBlo20");
   datetime t_th20 = iTime(NULL, BigSMCOBtimeframe, bar20i);
   datetime f_ti20 = iTime(NULL, BigSMCOBtimeframe, bar20i - bar20i);
   if (DrawSMCOrderBlock)
   {
      ObjectCreate(0, "bearOBhi20", OBJ_TREND, 0, t_th20, hi20, f_ti20, hi20);
      ObjectSetInteger(0, "bearOBhi20", OBJPROP_COLOR, clrMagenta);
      ObjectSetInteger(0, "bearOBhi20", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBhi20", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bearOBlo20", OBJ_TREND, 0, t_th20, lo20, f_ti20, lo20);
      ObjectSetInteger(0, "bearOBlo20", OBJPROP_COLOR, clrMagenta);
      ObjectSetInteger(0, "bearOBlo20", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBlo20", OBJPROP_WIDTH, 3);
   }
   // xxxxx
   ObjectDelete(0, "bullOBhi20");
   ObjectDelete(0, "bullOBlo20");
   datetime t_t20i = iTime(NULL, BigSMCOBtimeframe, xbar20i);
   datetime f_t20i = iTime(NULL, BigSMCOBtimeframe, xbar20i - xbar20i);
   if (DrawSMCOrderBlock)
   {
      ObjectCreate(0, "bullOBhi20", OBJ_TREND, 0, t_t20i, xhi20, f_t20i, xhi20);
      ObjectSetInteger(0, "bullOBhi20", OBJPROP_COLOR, clrGoldenrod);
      ObjectSetInteger(0, "bullOBhi20", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBhi20", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bullOBlo20", OBJ_TREND, 0, t_t20i, xlo20, f_t20i, xlo20);
      ObjectSetInteger(0, "bullOBlo20", OBJPROP_COLOR, clrGoldenrod);
      ObjectSetInteger(0, "bullOBlo20", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBlo20", OBJPROP_WIDTH, 3);
   }
   // xxxxx ///
   //// if()
   int bar21 = barscasmc(TinyOBtimeframe, MODE_HIGH, showlder, startbar);
   int bar21i = OBbarsmc(TinyOBtimeframe, MODE_HIGH, showlder, startbar, bar21);
   double hi21 = OBhighsmc(TinyOBtimeframe, MODE_HIGH, showlder, startbar, bar21);
   double lo21 = OBlowsmc(TinyOBtimeframe, MODE_HIGH, showlder, startbar, bar21);
   ObjectDelete(0, "TinySMCsellz");                                                    // 210
   ChartWriteiv("TinySMCsellz", "TinySMCsellz" + (string)hi21, 100, 74, 10, clrWhite); // Write Number of Orders on the Chart

   int xbar21 = barscasmc(TinyOBtimeframe, MODE_LOW, showlder, startbar);
   int xbar21i = OBbarsmc(TinyOBtimeframe, MODE_LOW, showlder, startbar, xbar21);
   double xhi21 = OBhighsmc(TinyOBtimeframe, MODE_LOW, showlder, startbar, xbar21);
   double xlo21 = OBlowsmc(TinyOBtimeframe, MODE_LOW, showlder, startbar, xbar21);
   ObjectDelete(0, "TinySMCbuy");                                                   // 210
   ChartWritev("TinySMCbuy", "TinySMCbuy" + (string)xlo21, 100, 88, 10, clrYellow); // Write Number of Orders on the Chart
   ///--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ///--- xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   //---xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   ObjectDelete(0, "bearOBhi21");
   ObjectDelete(0, "bearOBlo21");
   datetime t_th21 = iTime(NULL, TinyOBtimeframe, bar21i);
   datetime f_ti21 = iTime(NULL, TinyOBtimeframe, bar21i - bar21i);
   if (DrawSMCOrderBlock)
   {
      ObjectCreate(0, "bearOBhi21", OBJ_TREND, 0, t_th21, hi21, f_ti21, hi21);
      ObjectSetInteger(0, "bearOBhi21", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "bearOBhi21", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBhi21", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bearOBlo21", OBJ_TREND, 0, t_th21, lo21, f_ti21, lo21);
      ObjectSetInteger(0, "bearOBlo21", OBJPROP_COLOR, clrRed);
      ObjectSetInteger(0, "bearOBlo21", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bearOBlo21", OBJPROP_WIDTH, 3);
   }
   // xxxxx
   ObjectDelete(0, "bullOBhi21");
   ObjectDelete(0, "bullOBlo21");
   datetime t_t21i = iTime(NULL, TinyOBtimeframe, xbar21i);
   datetime f_t21i = iTime(NULL, TinyOBtimeframe, xbar21i - xbar21i);
   if (DrawSMCOrderBlock)
   {
      ObjectCreate(0, "bullOBhi21", OBJ_TREND, 0, t_t21i, xhi21, f_t21i, xhi21);
      ObjectSetInteger(0, "bullOBhi21", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, "bullOBhi21", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBhi21", OBJPROP_WIDTH, 3);
      // xxxxx
      ObjectCreate(0, "bullOBlo21", OBJ_TREND, 0, t_t21i, xlo21, f_t21i, xlo21);
      ObjectSetInteger(0, "bullOBlo21", OBJPROP_COLOR, clrGreen);
      ObjectSetInteger(0, "bullOBlo21", OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, "bullOBlo21", OBJPROP_WIDTH, 3);
   }

   //----
   if (CalculateTotalProfit() != 0)
      ObjectSetString(0, "Profit", OBJPROP_TEXT, "Money P/L is: $" + DoubleToString(CalculateTotalProfit(), 2));

   if (Percentage != 0)
      ObjectSetString(0, "Percent", OBJPROP_TEXT, "Percentage P/L is: " + DoubleToString(Percentage, 2) + "%");

   // if(ObjectFind(0,"HLineSL") == 0)
   ObjectSetString(0, "Equity HL", OBJPROP_TEXT, "Equity Stop/L is: $" + DoubleToString(HLineSLprice(), 2));

   ////-----------------
   if (CalculateTotalProfit() >= EquityTrigBEStop * 100 * Lots && ObjectFind(0, "HLineSL") < 0)
   {
      createObject3("HLineSL", EquityBEStopLoss * 100 * Lots);
      //      createBackground();
   }

   //----
   if (CalculateTotalProfit() <= -MaxFloatLoss * 100 * Lots && CalculateTotalProfit() < 0 && MaxFloatLoss > 0 && EquityManager)
   {
      ClosePositions();
      Print("Positions Closed At Profit");
   }
   ///----
   if (TradingIsAllowed == false)
      if (CountPendingOrders() > 0)
      {
         DeletePendingOrders();
         Print("Expired Pending Orders");
      }
   // XXXXXX////----
   if (CountPendingOrders() > 0)
      if (CountPendingOrder(ORDER_TYPE_BUY_STOP) > 0)
         if (Ask() < PendingSLPrice(ORDER_TYPE_BUY_STOP) - SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (150 + InpStopLossPoints))
         {
            DeletePendingOrder(ORDER_TYPE_BUY_STOP);
            Print("Price Away From SL Pending Orders");
         }
   // XXXXXX////----
   if (CountPendingOrders() > 0)
      if (CountPendingOrder(ORDER_TYPE_SELL_STOP) > 0)
         if (Bid() > PendingSLPrice(ORDER_TYPE_SELL_STOP) + SymbolInfoDouble(_Symbol, SYMBOL_POINT) * (150 + InpStopLossPoints))
         {
            DeletePendingOrder(ORDER_TYPE_SELL_STOP);
            Print("Price Away From SL Pending Orders");
         }
   //----
   if (buySignal() == false)
      if (CountPendingOrders() > 0)
      {
         DeletePendingOrder(ORDER_TYPE_BUY_STOP);
         Print("Expired Buy Pending Orders");
      }
   //----
   if (sellSignal() == false)
      if (CountPendingOrders() > 0)
      {
         DeletePendingOrder(ORDER_TYPE_SELL_STOP);
         Print("Expired Sell Pending Orders");
      } ////-----------------
   ApplyTakeProfit(Symbol(), InpMagicNumber, TakeProfit);
   ApplyStopLoss(Symbol(), InpMagicNumber, StopLoss);
   ApplyTrailingStop();
   ApplyBE();
   PendCond();
   ////-----------------
   if (CalculateTotalProfit() > HLineSLprice() + (EquityTrail * 100 * Lots * 2))
   {
      ObjectMove(0, "HLineSL", 0, 0, CalculateTotalProfit() - (EquityTrail * 100 * Lots));
   }
   ////-----------------
   if (CalculateTotalProfit() <= HLineSLprice() && CalculateTotalProfit() > 0 && HLineSLprice() > 0 && HLineSLprice() > EquityBEStopLoss * Lots * 100 && CalculateTotalProfit() > EquityBEStopLoss * Lots * 100 && EquityManager)
   {
      ClosePositions();
      Print("Positions Closed At Profit");
   }
   ////-----------------
   if (CalculateTotalProfit() <= HLineSLprice() && CalculateTotalProfit() > 0 && HLineSLprice() > 0 && HLineSLprice() == EquityBEStopLoss * Lots * 100 && CalculateTotalProfit() <= EquityBEStopLoss * Lots * 100 && EquityManager)
   {
      ClosePositions();
      Print("Positions Closed At Profit");
   }
   ////-----------------
   if (!IsPositionExists() && ObjectFind(0, "HLineSL") == 0) // There are positions and Line exists
   {
      ObjectDelete(0, "HLineSL");
      ObjectDelete(0, "Equity HL");
      //      ObjectDelete(0,"Background");
   }
   //-----------------
   if (Stop)
   {
      ClosePositions();
      Print("Positions Closed At Loss");
      if (!IsPositionExists())
         Stop = false;
   }
   if (Profit)
   {
      ClosePositions();
      Print("Positions Closed At Profit");
      if (!IsPositionExists())
         Profit = false;
   }
   if (OrderTest)
   {
      if (MQLInfoInteger(MQL_TESTER) && !IsPositionExists())
      {
         trade.Sell(0.1, Symbol(), Bid(), 0, 0, NULL);
         trade.Buy(0.1, Symbol(), Ask(), 0, 0, NULL);
      }
   }

   return;
}
//

//+------------------------------------------------------------------+
//| Pending function                                             |
//+------------------------------------------------------------------+
void PendCond()
{ // a5
   datetime time = TimeLocal();
   CurrentTime = TimeToString(time, TIME_MINUTES);

   int StopsLevel = m_symbol.StopsLevel();
   if (StopsLevel == 0)
      StopsLevel = m_symbol.Spread() * 3;

   for (int i = 1; i <= InpUpQuantity; i++)
   { // a4
      string symbol = PositionGetString(POSITION_SYMBOL);
      int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
      double Spred = NormalizeDouble(Ask() - Bid(), digits);
      if (InpUpStep * i > StopsLevel)
      { // a3
         if (Lots > 0.0)
            if (CheckTradingTime() == true)
            { // a2
               if (IsPositionExisting(ORDER_TYPE_BUY) < InpBuySellQuantity)
                  if (CountPendingOrder(ORDER_TYPE_BUY_STOP) < InpUpQuantity)
                     if (buySignal())
                     { // a1
                        double price_ask = (Ask() + (Spred * 2)) + (double)CountPendingOrders() * (double)(InpUpStep)*SymbolInfoDouble(symbol, SYMBOL_POINT);
                        //               double Price=m_symbol.NormalizePrice(+(double)InpUpStep*(double)i*m_symbol.Point());
                        double sl = 0;
                        double tp = 0;
                        m_trade.BuyStop(Lots, price_ask, m_symbol.Name(), sl, tp);
                     } // a1
               if (IsPositionExisting(ORDER_TYPE_SELL) < InpBuySellQuantity)
                  if (CountPendingOrder(ORDER_TYPE_SELL_STOP) < InpUpQuantity)
                     if (sellSignal())
                     { // aa1
                        double price_bid = (Bid() - (Spred * 2)) - (double)CountPendingOrders() * (double)(InpUpStep + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                        //               double Price=m_symbol.NormalizePrice(iLow(NULL,PERIOD_M5,1)-(double)InpUpStep*(double)i*m_symbol.Point());
                        double sl = 0;
                        double tp = 0;
                        m_trade.SellStop(Lots, price_bid, m_symbol.Name(), sl, tp);
                     } // aa1
            }          // a2
      }                // a3
   }                   // a4
} // a5
//+------------------------------------------------------------------+
///+------------------------------------------------------------------+
bool buySignal()
{
   bool ReturnValue = false;
   double Maximum = iHigh(NULL, PERIOD_M20, PikBar(PERIOD_M20, MODE_LOW, 2, 5, 1) + 1);
   double Minimum = iLow(NULL, PERIOD_M20, PikBar(PERIOD_M20, MODE_LOW, 2, 5, 1));
   double Fifty = ((Maximum - Minimum) * 5 / 100) + Minimum;
   int xbar20 = barscasmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar);
   int xbar20i = barscasmc(TinyOBtimeframe, MODE_LOW, showlder, startbar);
   int bar19 = barscann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar);
   int scabar = OBbarann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19);

   if (TradeAnn)
      if (iClose(Symbol(), TinyOBtimeframe, 1) > OBlowann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19) &&
          (iLow(Symbol(), TinyOBtimeframe, 1) < OBhighann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19) ||
           iLow(Symbol(), TinyOBtimeframe, 1) < OBhighann(BigAnnOBtimeframe, MODE_HIGH, showlder, startbar, bar19)) &&
          EngulfBuy(TinyOBtimeframe, 8, 105))
      {
         ReturnValue = true;
      } // schematic 25 BUY

   if (TradeSmc)
      if (iClose(Symbol(), TinyOBtimeframe, 1) > OBlowsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20) &&
          (iLow(Symbol(), TinyOBtimeframe, 1) < OBhighsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20) ||
           iLow(Symbol(), TinyOBtimeframe, 1) < OBhighsmc(BigSMCOBtimeframe, MODE_LOW, showlder, startbar, xbar20)) &&
          EngulfBuy(TinyOBtimeframe, 8, 105))
      {
         ReturnValue = true;
      } // schematic 25 BUY

   return ReturnValue;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
bool sellSignal()
{ // SymbolInfoDouble(_Symbol, SYMBOL_POINT)*300
   bool ReturnValue = false;
   double Maximum = iHigh(NULL, PERIOD_M20, PikBar(PERIOD_M20, MODE_HIGH, 2, 5, 1));
   double Minimum = iLow(NULL, PERIOD_M20, PikBar(PERIOD_M20, MODE_HIGH, 2, 5, 1) + 1);
   double Fifty = ((Maximum - Minimum) * 5 / 100) + Minimum;
   int bar20 = barscasmc(BigSMCOBtimeframe, MODE_HIGH, showlder, startbar);
   int bar20i = barscasmc(TinyOBtimeframe, MODE_HIGH, showlder, startbar);
   int xbar19 = barscann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar);
   int xbar19i = OBbarann(BigAnnOBtimeframe, MODE_LOW, showlder, startbar, xbar19);

   if (TradeAnn)
      if (iClose(Symbol(), TinyOBtimeframe, 1) < OBhighann(BigAnnOBtimeframe, MODE_LOW, showlder, showlder, xbar19) &&
          (iHigh(Symbol(), TinyOBtimeframe, 1) > OBlowann(BigAnnOBtimeframe, MODE_LOW, showlder, showlder, xbar19) ||
           iHigh(Symbol(), BigAnnOBtimeframe, 1) > OBlowann(BigAnnOBtimeframe, MODE_LOW, showlder, showlder, xbar19)) &&
          EngulfSell(TinyOBtimeframe, 8, 105))
      {
         ReturnValue = true;
      } // schematic 25 SELL

   if (TradeSmc)
      if (iClose(Symbol(), TinyOBtimeframe, 1) < OBhighsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, showlder, bar20) &&
          (iHigh(Symbol(), TinyOBtimeframe, 1) > OBlowsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, showlder, bar20) ||
           iHigh(Symbol(), BigSMCOBtimeframe, 1) > OBlowsmc(BigSMCOBtimeframe, MODE_HIGH, showlder, showlder, bar20)) &&
          EngulfSell(TinyOBtimeframe, 8, 105))
      {
         ReturnValue = true;
      } // schematic 25 SELL

   return ReturnValue;
}

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool CheckTradingTime()
{
   return true;
   if (StringSubstr(CurrentTime, 0, 5) == StartTradingi)
      TradingIsAllowed = true;

   if (StringSubstr(CurrentTime, 0, 5) == EndTradingi)
      TradingIsAllowed = false;

   if (StringSubstr(CurrentTime, 0, 5) == StartTradingii)
      TradingIsAllowed = true;

   if (StringSubstr(CurrentTime, 0, 5) == EndTradingii)
      TradingIsAllowed = false;

   return TradingIsAllowed;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void ApplyTakeProfit(string symbol, int magicNumber, double takeprofit)
{
   static int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tp = 0;
   double tpb = 0;
   double tps = 0;
   double tpi = 0;
   double tpbi = 0;
   double tpii = 0;
   double tpsii = 0;
   double Spred = NormalizeDouble(Ask() - Bid(), digits);
   datetime checkTime = TimeCurrent() - PositionOpenWithin;
   // Trailing from the close prices
   int count = PositionsTotal();
   for (int i = count - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magicNumber)
            if (PositionGetInteger(POSITION_TIME) > checkTime)
            {
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_TP) == 0)
               {
                  tp = PositionGetDouble(POSITION_PRICE_OPEN) + (InpTakeProfitPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  tpb = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  tpi = Ask() + (InpTakeProfitPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  tpbi = NormalizeDouble(tpi, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if (tpb > Ask())
                     Trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpb);
                  else if (tpb < Ask())
                     Trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpbi);
               }
               else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_TP) == 0)
               {
                  tp = PositionGetDouble(POSITION_PRICE_OPEN) - (InpTakeProfitPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  tps = NormalizeDouble(tp, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  tpii = Bid() - (InpStopLossPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  tpsii = NormalizeDouble(tpii, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if (tps < Bid())
                     Trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tps);
                  else if (tps > Bid())
                     Trade.PositionModify(ticket, PositionGetDouble(POSITION_SL), tpsii);
               }
            }
      }
   }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void ApplyStopLoss(string symbol, int magicNumber, double stopLoss)
{
   static int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double sl = 0;
   double slb = 0;
   double sls = 0;
   double sli = 0;
   double slbi = 0;
   double slii = 0;
   double slsii = 0;
   double Spred = NormalizeDouble(Ask() - Bid(), digits);
   datetime checkTime = TimeCurrent() - PositionOpenWithin;
   // Trailing from the close prices
   int count = PositionsTotal();
   for (int i = count - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetString(POSITION_SYMBOL) == symbol && PositionGetInteger(POSITION_MAGIC) == magicNumber)
            if (PositionGetInteger(POSITION_TIME) > checkTime)
            {
               if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_SL) == 0)
               {
                  sl = PositionGetDouble(POSITION_PRICE_OPEN) - (InpStopLossPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  slb = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  sli = Bid() - (InpStopLossPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  slbi = NormalizeDouble(sli, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if (slb < Bid())
                     Trade.PositionModify(ticket, slb, PositionGetDouble(POSITION_TP));
                  else if (slb > Bid())
                     Trade.PositionModify(ticket, slbi, PositionGetDouble(POSITION_TP));
               }
               else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_SL) == 0)
               {
                  sl = PositionGetDouble(POSITION_PRICE_OPEN) + (InpStopLossPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  sls = NormalizeDouble(sl, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  slii = Ask() + (InpStopLossPoints + Spred) * SymbolInfoDouble(symbol, SYMBOL_POINT);
                  slsii = NormalizeDouble(slii, (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS));
                  if (sls > Ask())
                     Trade.PositionModify(ticket, sls, PositionGetDouble(POSITION_TP));
                  else if (sls < Ask())
                     Trade.PositionModify(ticket, slsii, PositionGetDouble(POSITION_TP));
               }
            }
      }
   }
}
//+------------------------------------------------------------------+
void ApplyBE()
{
   int count = PositionsTotal();
   for (int i = count - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            // Trailing from the close prices
            //  StopLoss =  SymbolInfoDouble(symbol, SYMBOL_POINT)*InpTrailingStopPoints;
            BETrigger = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpTriggerBEStopLossPoints;
            BESL = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpBEStopLossPoints;
            double Spred = NormalizeDouble(Ask() - Bid(), digits);
            double buyStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), digits);
            double sellStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), digits);
            double Trigger = NormalizeDouble(BETrigger + Spred, digits);
            double BEStopLoss = NormalizeDouble(BESL + Spred, digits);

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_PRICE_CURRENT) > PositionGetDouble(POSITION_PRICE_OPEN) + Trigger && (PositionGetDouble(POSITION_SL) == 0 || PositionGetDouble(POSITION_PRICE_OPEN) > PositionGetDouble(POSITION_SL)))
            {
               Trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN) + BEStopLoss, PositionGetDouble(POSITION_TP));
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_PRICE_CURRENT) < PositionGetDouble(POSITION_PRICE_OPEN) - Trigger && (PositionGetDouble(POSITION_SL) == 0 || PositionGetDouble(POSITION_PRICE_OPEN) < PositionGetDouble(POSITION_SL)))
            {
               Trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_OPEN) - BEStopLoss, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void ApplyTrailingStop()
{
   int count = PositionsTotal();
   for (int i = count - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if (ticket > 0)
      {
         if (PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
         {
            string symbol = PositionGetString(POSITION_SYMBOL);
            int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
            // Trailing from the close prices
            //  StopLoss =  SymbolInfoDouble(symbol, SYMBOL_POINT)*InpTrailingStopPoints;
            BETrail = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpTrailStopLossPoints;
            BETrigger = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpTriggerBEStopLossPoints;
            BESL = SymbolInfoDouble(symbol, SYMBOL_POINT) * InpBEStopLossPoints;
            double buyStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_BID), digits);
            double sellStopLoss = NormalizeDouble(SymbolInfoDouble(symbol, SYMBOL_ASK), digits);
            double Trigger = NormalizeDouble(BETrigger, digits);
            double BEStopLoss = NormalizeDouble(BESL, digits);

            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY && PositionGetDouble(POSITION_PRICE_CURRENT) > PositionGetDouble(POSITION_SL) + (BETrail * TrailMultiplier) && PositionGetDouble(POSITION_PRICE_OPEN) < PositionGetDouble(POSITION_SL))
            {
               Trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_CURRENT) - BETrail, PositionGetDouble(POSITION_TP));
            }
            else if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL && PositionGetDouble(POSITION_PRICE_CURRENT) < PositionGetDouble(POSITION_SL) - (BETrail * TrailMultiplier) && PositionGetDouble(POSITION_PRICE_OPEN) > PositionGetDouble(POSITION_SL))
            {
               Trade.PositionModify(ticket, PositionGetDouble(POSITION_PRICE_CURRENT) + BETrail, PositionGetDouble(POSITION_TP));
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
//| Is pending orders exists                                         |
//+------------------------------------------------------------------+
bool IsPendingOrderExist(ENUM_ORDER_TYPE type)
{
   for (int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if (m_order.SelectByIndex(i))             // selects the pending order by index for further access to its properties
         if (m_order.Symbol() == m_symbol.Name())
            if (OrderGetInteger(ORDER_TYPE) == type)
               return (true);
   //---
   return (false);
} //+------------------------------------------------------------------+
//| Is pending orders exists                                         |
//+------------------------------------------------------------------+
bool IsPendingOrdersExists(void)
{
   for (int i = OrdersTotal() - 1; i >= 0; i--) // returns the number of current orders
      if (m_order.SelectByIndex(i))             // selects the pending order by index for further access to its properties
         if (m_order.Symbol() == m_symbol.Name())
            return (true);
   //---
   return (false);
}
//+------------------------------------------------------------------+
double PendingSLPrice(ENUM_ORDER_TYPE type)
{
   double open_price = -1;

   for (int i = 0; i <= OrdersTotal(); i++)
   { // a
      OrderSelect(OrderGetTicket(i));
      string OrderSymbol = OrderGetString(ORDER_SYMBOL);
      if (OrderSymbol == Symbol())
      { // b
         ENUM_ORDER_TYPE typeB = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
         if (typeB == type)
         { // c

            open_price = NormalizeDouble((OrderGetDouble(ORDER_PRICE_OPEN)), _Digits);
         } // a
      }    // b
   }       // c
   return (open_price);
} //}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int IsPositionExisting(ENUM_ORDER_TYPE type)
{
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
      if (PositionGetTicket(i))
         if (PositionGetString(POSITION_SYMBOL) == Symbol())
            if (PositionGetInteger(POSITION_TYPE) == type)
            {
               count++;
            }
   //---
   return (count);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int IsPositionExists()
{
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
      if (PositionGetTicket(i))
         if (PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            count++;
         }
   //---
   return (count);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountPendingOrders()

{
   int TodayslimitedOrders = 0;

   for (int i = 0; i < OrdersTotal(); i++)
      if (OrderSelect(OrderGetTicket(i)) && OrderGetString(ORDER_SYMBOL) == _Symbol)
      {
         TodayslimitedOrders += 1;
      }
   return (TodayslimitedOrders);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CountPendingOrder(ENUM_ORDER_TYPE type)

{
   int TodayslimitedOrders = 0;

   for (int i = 0; i < OrdersTotal(); i++)
      if (OrderSelect(OrderGetTicket(i)) && OrderGetString(ORDER_SYMBOL) == _Symbol)
         if (OrderGetInteger(ORDER_TYPE) == type)
         {
            TodayslimitedOrders += 1;
         }
   return (TodayslimitedOrders);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Delete Pending Orders                                      |
//+------------------------------------------------------------------+
void DeletePendingOrders()
{ // zi
   for (int i = OrdersTotal() - 1; i >= 0; i--)
   { // yi
      ulong OrderTicket = OrderGetTicket(i);
      trade.OrderDelete(OrderTicket);
   } // yi
} // zi
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
void DeletePendingOrder(ENUM_ORDER_TYPE type)
{

   long order_ticket;

   HistorySelect(0, TimeCurrent());

   for (int i = OrdersTotal() - 1; i >= 0; i--)
      if (order_ticket = OrderGetTicket(i))

         if (OrderGetString(ORDER_SYMBOL) == Symbol() && OrderGetInteger(ORDER_TYPE) == type)
         {
            MqlTradeResult result;
            MqlTradeRequest request;
            request.order = order_ticket;
            request.action = TRADE_ACTION_REMOVE;
            OrderSend(request, result);
         }
}
//+------------------------------------------------------------------+
//| Get H Line                                            |
//+------------------------------------------------------------------+
double HLineSLprice()
{
   return (ObjectGetDouble(0, "HLineSL", OBJPROP_PRICE));
}
//+------------------------------------------------------------------+
//| Get current bid value                                            |
//+------------------------------------------------------------------+
double Bid()
{
   return (SymbolInfoDouble(Symbol(), SYMBOL_BID));
}

//+------------------------------------------------------------------+
//| Get current ask value                                            |
//+------------------------------------------------------------------+
double Ask()
{
   return (SymbolInfoDouble(Symbol(), SYMBOL_ASK));
}
//+------------------------------------------------------------------+
//| Get H Line                                            |
//+------------------------------------------------------------------+
double PikHii(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{
   double High = iHigh(_Symbol, timeframe, PikBar(timeframe, MODE_HIGH, shoulder, startBar, peakNo));
   return High;
}
//+------------------------------------------------------------------+
//| Get H Line                                            |
//+------------------------------------------------------------------+
double PikLoo(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{
   double Low = iLow(_Symbol, timeframe, PikBar(timeframe, MODE_LOW, shoulder, startBar, peakNo));
   return Low;
}
//+------------------------------------------------------------------+
//| Get H Line                                            |
//+------------------------------------------------------------------+
int PikBar(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{
   int barIndex = 0;
   int ar[];                           // Array
   ArrayResize(ar, PeaksLookBack + 1); // Prepare the array
   for (int y = 3; y <= PeaksLookBack; y++)
   {
      ar[0] = 0; // Set the values
      ar[1] = FindPeak(timeframe, mode, shoulder, startBar);

      ar[2] = FindPeak(timeframe, mode, shoulder, ar[1] + 1); // Set the value for the new array element
      ar[y] = FindPeak(timeframe, mode, shoulder, ar[y - 1] + 1);
      ; // Set the value for the new array element
   }

   for (int x = 1; x <= PeaksLookBack; x++)
   {
      if (peakNo == x)
         barIndex = ar[x];
   }
   return barIndex;
}

//+------------------------------------------------------------------+
//|                                              |
//+------------------------------------------------------------------+
int FindPeak(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar)
{ // a1
   if (mode != MODE_HIGH && mode != MODE_LOW)
      return (-1);
   int currentBar = startBar;
   int foundBar = FindNextPeak(timeframe, mode, shoulder * 2 + 1, currentBar - shoulder);
   while (foundBar != currentBar)
   { // while1
      currentBar = FindNextPeak(timeframe, mode, shoulder, currentBar + 1);
      foundBar = FindNextPeak(timeframe, mode, shoulder * 2 + 1, currentBar - shoulder);
   } // while1
   return (currentBar);
} // a1
//+------------------------------------------------------------------+
int FindNextPeak(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar)
{ // a2
   if (startBar < 0)
   { // a3
      shoulder += startBar;
      startBar = 0;
   } // a3
   return ((mode == MODE_HIGH) ? iHighest(Symbol(), timeframe, (ENUM_SERIESMODE)mode, shoulder, startBar) : iLowest(Symbol(), timeframe, (ENUM_SERIESMODE)MODE_LOW, shoulder, startBar));
} // a2
//+------------------------------------------------------------------+
/////+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Find High Peak                                            |
///+------------------------------------------------------------------+
double PikHi(int shoulder, ENUM_TIMEFRAMES timeframe)
{ // PikHi
   double HighestHigh = 0;
   for (int i = 0; i < 200; i++)
   {
      double High = iHigh(_Symbol, timeframe, i);
      if (i > shoulder &&
          iHighest(_Symbol, timeframe, MODE_HIGH, shoulder * 2 + 1, i - shoulder) == i)
      { // Is it highest of prev & Following Shoulder
         // HighestHigh of x Bars
         if (High > HighestHigh)
         {
            return High;
         } // if(High)
      }    // if(Highest)
      HighestHigh = MathMax(High, HighestHigh);
   } // for
   return -1;
} // PikHi/
//+------------------------------------------------------------------+
//| Find Low Peak                                            |
/////| Find Low Peak                                            |
///+------------------------------------------------------------------+
double PikLo(int shoulder, ENUM_TIMEFRAMES timeframe)
{ // PikLo
   double LowestLow = DBL_MAX;
   for (int i = 0; i < 200; i++)
   {
      double Low = iLow(_Symbol, timeframe, i);
      if (i > shoulder &&
          iLowest(_Symbol, timeframe, MODE_LOW, shoulder * 2 + 1, i - shoulder) == i)
      { // Is it lowest of prev & Following Shoulder
         if (Low < LowestLow)
         {
            return Low;
         } // if(Lowh)
      }    // if(Lowest)
      LowestLow = MathMin(Low, LowestLow);
   } // for
   return -1;
} // PikHi/
//+------------------------------------------------------------------+
//| Get  highest value                                            |
//+------------------------------------------------------------------+
double hiclo(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int hiBar = iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_CLOSE, count, startBar);
   double eLow = NormalizeDouble(iClose(Symbol(), timeFrame, hiBar), _Digits);
   return (eLow);
}
//+------------------------------------------------------------------+
//| Get  lowest value                                            |
//+------------------------------------------------------------------+
double lowclo(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int loBar = iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_CLOSE, count, startBar);
   double eHigh = NormalizeDouble(iClose(Symbol(), timeFrame, loBar), _Digits);
   return (eHigh);
}
//+------------------------------------------------------------------+
//| Get  highest value                                            |
//+------------------------------------------------------------------+
double highestlo(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int hiBar = iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_LOW, count, startBar);
   double eLow = NormalizeDouble(iLow(Symbol(), timeFrame, hiBar), _Digits);
   return (eLow);
}
//+------------------------------------------------------------------+
//| Get  lowest value                                            |
//+------------------------------------------------------------------+
double lowesthi(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int loBar = iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_HIGH, count, startBar);
   double eHigh = NormalizeDouble(iHigh(Symbol(), timeFrame, loBar), _Digits);
   return (eHigh);
}
//+------------------------------------------------------------------+
//| Get  highest value                                            |
//+------------------------------------------------------------------+
double high(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int hiBar = iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_HIGH, count, startBar);
   double eHigh = NormalizeDouble(iHigh(Symbol(), timeFrame, hiBar), _Digits);
   return (eHigh);
}
//+------------------------------------------------------------------+
//| Get  lowest value                                            |
//+------------------------------------------------------------------+
double low(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   int loBar = iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_LOW, count, startBar);
   double eLow = NormalizeDouble(iLow(Symbol(), timeFrame, loBar), _Digits);
   return (eLow);
}
//+------------------------------------------------------------------+
//| Get HighestBar                                            |
//+------------------------------------------------------------------+
int highestBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_HIGH, count, startBar));
}
//+------------------------------------------------------------------+
//| Get LowestBar                                            |
//+------------------------------------------------------------------+
int lowestBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_LOW, count, startBar));
}
//+------------------------------------------------------------------+
int highestloBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_LOW, count, startBar));
}
//+------------------------------------------------------------------+
//| Get LowestBar                                            |
//+------------------------------------------------------------------+
int lowesthiBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_HIGH, count, startBar));
}
//+------------------------------------------------------------------+
//| Get HighestBar                                            |
//+------------------------------------------------------------------+
int highestCloBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iHighest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_CLOSE, count, startBar));
}
//+------------------------------------------------------------------+
//| Get LowestBar                                            |
//+------------------------------------------------------------------+
int lowestcloBar(ENUM_TIMEFRAMES timeFrame, int count, int startBar)
{
   return (iLowest(Symbol(), timeFrame, (ENUM_SERIESMODE)MODE_CLOSE, count, startBar));
}
////+------------------------------------------------------------------+
//| Get  Order Block High Line                                            |
//+------------------------------------------------------------------+
double OBhighann(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // OBhigh
   double annline = 0;
   int annbar = OBbarann(timeframe, mode, shoulder, startBar, peakNo);

   if (mode == MODE_HIGH)
      if (!bearcandle(timeframe, annbar + 1))
         annline = iHigh(Symbol(), timeframe, annbar);

   if (mode == MODE_LOW)
      if (!bullcandle(timeframe, annbar + 1))
         annline = iHigh(Symbol(), timeframe, annbar);

   if (mode == MODE_HIGH)
      if (bearcandle(timeframe, annbar + 1))
         if (!bearcandle(timeframe, annbar + 2))
            annline = high(timeframe, 2, annbar);

   if (mode == MODE_LOW)
      if (bullcandle(timeframe, annbar + 1))
         if (!bullcandle(timeframe, annbar + 2))
            annline = high(timeframe, 2, annbar);

   if (mode == MODE_HIGH)
      if (bearcandle(timeframe, annbar + 1))
         if (bearcandle(timeframe, annbar + 2))
            if (!bearcandle(timeframe, annbar + 3))
               annline = high(timeframe, 3, annbar);

   if (mode == MODE_LOW)
      if (bullcandle(timeframe, annbar + 1))
         if (bullcandle(timeframe, annbar + 2))
            if (!bullcandle(timeframe, annbar + 3))
               annline = high(timeframe, 3, annbar);

   return (annline);

} // OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block Low Line                                            |
//+------------------------------------------------------------------+
double OBlowann(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // OBhigh
   double annline = 0;
   int annbar = OBbarann(timeframe, mode, shoulder, startBar, peakNo);

   if (mode == MODE_HIGH)
      if (!bearcandle(timeframe, annbar + 1))
         annline = iLow(Symbol(), timeframe, annbar);

   if (mode == MODE_LOW)
      if (!bullcandle(timeframe, annbar + 1))
         annline = iLow(Symbol(), timeframe, annbar);

   if (mode == MODE_HIGH)
      if (bearcandle(timeframe, annbar + 1))
         if (!bearcandle(timeframe, annbar + 2))
            annline = low(timeframe, 2, annbar);

   if (mode == MODE_LOW)
      if (bullcandle(timeframe, annbar + 1))
         if (!bullcandle(timeframe, annbar + 2))
            annline = low(timeframe, 2, annbar);

   if (mode == MODE_HIGH)
      if (bearcandle(timeframe, annbar + 1))
         if (bearcandle(timeframe, annbar + 2))
            if (!bearcandle(timeframe, annbar + 3))
               annline = low(timeframe, 3, annbar);

   if (mode == MODE_LOW)
      if (bullcandle(timeframe, annbar + 1))
         if (bullcandle(timeframe, annbar + 2))
            if (!bullcandle(timeframe, annbar + 3))
               annline = low(timeframe, 3, annbar);

   return (annline);

} // OBhigh
//======
int barscann(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar)
{ // int barscan
   int scan = -1;
   int count = 0;
   for (int i = 1; i <= PeaksLookBack; i++)
   {                                                               // for
      int bar1 = OBbarann(timeframe, mode, shoulder, startBar, i); // what bar is peak i  ?
      if (bar1 > 0)
         if (mode == MODE_LOW)
            if (OBhighann(timeframe, mode, shoulder, startBar, i) > high(timeframe, bar1 - 6, 4))
            // if( high(timeframe,45,1) - low(timeframe,45,1) >  SymbolInfoDouble(_Symbol, SYMBOL_POINT)*200 )
            {
               scan = i;
               break;
            }
      if (bar1 > 0)
         if (mode == MODE_HIGH)
            if (OBlowann(timeframe, mode, shoulder, startBar, i) < low(timeframe, bar1 - 6, 4))
            // if( high(timeframe,45,1) - low(timeframe,45,1) >  SymbolInfoDouble(_Symbol, SYMBOL_POINT)*200 )
            {
               scan = i;
               break;
            }
      // return( scan);
   } // for(int)
   return (scan);
} // int barscan
////+------------------------------------------------------------------+
//| Get  Order Block Bar                                            |
//+------------------------------------------------------------------+
int OBbarann(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // blocktop
   double peakline = PikLine(timeframe, mode, shoulder, startBar, peakNo);
   int peaklinebar = PikBar(timeframe, mode, shoulder, startBar, peakNo);
   int peaklinebarprev = 0;
   if (peakNo > 1)
      peaklinebarprev = PikBar(timeframe, mode, shoulder, startBar, peakNo - 1);
   if (peakNo == 1)
      peaklinebarprev = startBar;
   int peakbardiff = EngulfDown(timeframe, peaklinebar, peaklinebarprev) - peaklinebarprev;
   int peakbardiffi = EngulfUp(timeframe, peaklinebar, peaklinebarprev) - peaklinebarprev;

   int crossstart = 0;
   if (peakNo > 1)
      crossstart = peaklinebarprev;
   if (peakNo == 1)
      crossstart = 1;
   int xbar = BarCrossUp(timeframe, peakline, peaklinebar, crossstart);
   int xbari = BarCrossDown(timeframe, peakline, peaklinebar, crossstart);
   int xbar2 = BarCrossUp(timeframe, peakline, xbar - 1, crossstart);
   int xbari2 = BarCrossDown(timeframe, peakline, xbari - 1, crossstart);
   int xbar3 = BarCrossUp(timeframe, peakline, xbar2 - 1, crossstart);
   int xbari3 = BarCrossDown(timeframe, peakline, xbari2 - 1, crossstart);
   int bearB4cross = -1;
   int bullB4cross = -1;
   bool ann1bu = false, ann1be = false;
   bool ann2bu = false, ann2be = false;
   bool ann3bu = false, ann3be = false;
   /// ANN OB bullish 01
   if (xbar > 0)                                                        // Swing High formed then price breaks that swing Hi. Look for bear before cross
                                                                        // if(iLow(Symbol(),timeframe,xbar-1) > iHigh(Symbol(),timeframe,xbar+1))//Imbalance
      if (iClose(Symbol(), timeframe, xbar - 1) > peakline)             //
         if (iClose(Symbol(), timeframe, xbar - 2) > peakline)          //
            if (iClose(Symbol(), timeframe, xbar - 3) > peakline)       //
               if (iClose(Symbol(), timeframe, xbar - 4) > peakline)    //
                  if (iClose(Symbol(), timeframe, xbar - 5) > peakline) //
                  {                                                     // bearB4cross
                     ann1be = true;
                     bearB4cross = FindBear(timeframe, xbar + 1, peaklinebar - 1);
                  } // bearB4cross Bullish OB
   // ANN OB  bearish 01
   if (xbari > 0) // Swing Low formed then price breaks that swing Lo. Look for bull before cross
      // if(iHigh(Symbol(),timeframe,xbari-1) < iLow(Symbol(),timeframe,xbari+1))//Imbalance
      if (iClose(Symbol(), timeframe, xbari - 1) < peakline)             //
         if (iClose(Symbol(), timeframe, xbari - 2) < peakline)          //
            if (iClose(Symbol(), timeframe, xbari - 3) < peakline)       //
               if (iClose(Symbol(), timeframe, xbari - 4) < peakline)    //
                  if (iClose(Symbol(), timeframe, xbari - 5) < peakline) //
                  {                                                      // bullB4cross
                     ann1bu = true;
                     bullB4cross = FindBull(timeframe, xbari + 1, peaklinebar - 1);
                  } // bullB4cross Bearish OB
   /// ANN OB bullish 02
   if (xbar2 > 0)
      if (!ann1be)                                                          // Swing High formed then price breaks that swing Hi. Look for bear before cross
                                                                            // if(iLow(Symbol(),timeframe,xbar-1) > iHigh(Symbol(),timeframe,xbar+1))//Imbalance
         if (iClose(Symbol(), timeframe, xbar2 - 1) > peakline)             //
            if (iClose(Symbol(), timeframe, xbar2 - 2) > peakline)          //
               if (iClose(Symbol(), timeframe, xbar2 - 3) > peakline)       //
                  if (iClose(Symbol(), timeframe, xbar2 - 4) > peakline)    //
                     if (iClose(Symbol(), timeframe, xbar2 - 5) > peakline) //
                     {                                                      // bearB4cross
                        ann2be = true;
                        bearB4cross = FindBear(timeframe, xbar2 + 1, peaklinebar - 1);
                     } // bearB4cross Bullish OB
   // ANN OB  bearish 02
   if (xbari2 > 0)
      if (!ann1bu) // Swing Low formed then price breaks that swing Lo. Look for bull before cross
         // if(iHigh(Symbol(),timeframe,xbari-1) < iLow(Symbol(),timeframe,xbari+1))//Imbalance
         if (iClose(Symbol(), timeframe, xbari2 - 1) < peakline)             //
            if (iClose(Symbol(), timeframe, xbari2 - 2) < peakline)          //
               if (iClose(Symbol(), timeframe, xbari2 - 3) < peakline)       //
                  if (iClose(Symbol(), timeframe, xbari2 - 4) < peakline)    //
                     if (iClose(Symbol(), timeframe, xbari2 - 5) < peakline) //
                     {                                                       // bullB4cross
                        ann2bu = true;
                        bullB4cross = FindBull(timeframe, xbari2 + 1, peaklinebar - 1);
                     } // bullB4cross Bearish OB
   /// ANN OB bullish 03
   if (xbar3 > 0)
      if (!ann2be)                                                          // Swing High formed then price breaks that swing Hi. Look for bear before cross
                                                                            // if(iLow(Symbol(),timeframe,xbar-1) > iHigh(Symbol(),timeframe,xbar+1))//Imbalance
         if (iClose(Symbol(), timeframe, xbar3 - 1) > peakline)             //
            if (iClose(Symbol(), timeframe, xbar3 - 2) > peakline)          //
               if (iClose(Symbol(), timeframe, xbar3 - 3) > peakline)       //
                  if (iClose(Symbol(), timeframe, xbar3 - 4) > peakline)    //
                     if (iClose(Symbol(), timeframe, xbar3 - 5) > peakline) //
                     {                                                      // bearB4cross
                        ann3be = true;
                        bearB4cross = FindBear(timeframe, xbar3 + 1, peaklinebar - 1);
                     } // bearB4cross Bullish OB
   // ANN OB  bearish 03
   if (xbari3 > 0)
      if (!ann2bu) // Swing Low formed then price breaks that swing Lo. Look for bull before cross
         // if(iHigh(Symbol(),timeframe,xbari-1) < iLow(Symbol(),timeframe,xbari+1))//Imbalance
         if (iClose(Symbol(), timeframe, xbari3 - 1) < peakline)             //
            if (iClose(Symbol(), timeframe, xbari3 - 2) < peakline)          //
               if (iClose(Symbol(), timeframe, xbari3 - 3) < peakline)       //
                  if (iClose(Symbol(), timeframe, xbari3 - 4) < peakline)    //
                     if (iClose(Symbol(), timeframe, xbari3 - 5) < peakline) //
                     {                                                       // bullB4cross
                        ann3bu = true;
                        bullB4cross = FindBull(timeframe, xbari3 + 1, peaklinebar - 1);
                     } // bullB4cross Bearish OB
   /// xxxxxxxxxxxxxxxxxxxxxxxxxxxxx
   double peaklinext = PikLine(timeframe, mode, shoulder, startBar, peakNo + 1);
   int peaklinebarxt = PikBar(timeframe, mode, shoulder, startBar, peakNo + 1);
   int xbarxt = BarCrossUp(timeframe, peaklinext, peaklinebarxt, peaklinebarprev);
   int xbarixt = BarCrossDown(timeframe, peaklinext, peaklinebarxt, peaklinebarprev);
   if (xbarxt > 0)
      if (xbar < 0)
         if (iClose(Symbol(), timeframe, xbarxt - 1) > iHigh(Symbol(), timeframe, xbarxt + 1))   //
            if (iOpen(Symbol(), timeframe, xbarxt - 1) > iHigh(Symbol(), timeframe, xbarxt + 1)) //
               if (iClose(Symbol(), timeframe, xbarxt - 2) > peaklinext)                         //
                  if (iClose(Symbol(), timeframe, xbarxt - 3) > peaklinext)                      //
                     if (iClose(Symbol(), timeframe, xbarxt - 4) > peaklinext)                   //
                        if (iClose(Symbol(), timeframe, xbarxt - 5) > peaklinext)                //
                        {                                                                        // bearB4cross
                           bearB4cross = FindBear(timeframe, xbarxt + 1, peaklinebarxt - 1);
                        } // bearB4cross Bullish OB

   if (xbarixt > 0)
      if (xbari < 0)
         if (iClose(Symbol(), timeframe, xbarixt - 1) < iLow(Symbol(), timeframe, xbarixt + 1))   //
            if (iOpen(Symbol(), timeframe, xbarixt - 1) < iLow(Symbol(), timeframe, xbarixt + 1)) //
               if (iClose(Symbol(), timeframe, xbarixt - 2) < peaklinext)                         //
                  if (iClose(Symbol(), timeframe, xbarixt - 3) < peaklinext)                      //
                     if (iClose(Symbol(), timeframe, xbarixt - 4) < peaklinext)                   //
                        if (iClose(Symbol(), timeframe, xbarixt - 5) < peaklinext)                //
                        {                                                                         // bearB4cross
                           bullB4cross = FindBull(timeframe, xbarixt + 1, peaklinebarxt - 1);
                        } // bearB4cross Bullish OB

   return ((mode == MODE_HIGH) ? bearB4cross : bullB4cross);
} // blocktop END OF ANN
////+------------------------------------------------------------------+
//| Get  Order Block Bar                                            |
//+------------------------------------------------------------------+
////+------------------------------------------------------------------+
//| Get  Order Block High Line                                            |
//+------------------------------------------------------------------+
double OBhighsmc(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // OBhigh
   return (iHigh(Symbol(), timeframe, OBbarsmc(timeframe, mode, shoulder, startBar, peakNo)));
} // OBhigh
////+------------------------------------------------------------------+
//| Get  Order Block Low Line                                            |
//+------------------------------------------------------------------+
double OBlowsmc(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // OBhigh
   return (iLow(Symbol(), timeframe, OBbarsmc(timeframe, mode, shoulder, startBar, peakNo)));
} // OBhigh
////+------------------------------------------------------------------+
//======
//======
int barscasmc(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar)
{ // int barscan
   int scan = -1;
   int count = 0;
   for (int i = 1; i <= PeaksLookBack; i++)
   {                                                               // for
      int bar1 = OBbarsmc(timeframe, mode, shoulder, startBar, i); // what bar is peak i  ?
      if (bar1 > 0)
         if (mode == MODE_HIGH)
            if (OBhighsmc(timeframe, mode, shoulder, startBar, i) > high(timeframe, bar1 - 6, 4))
               if (iClose(Symbol(), timeframe, i + shoulder) < OBlowsmc(timeframe, mode, shoulder, startBar, i))
                  if (iClose(Symbol(), timeframe, i + shoulder + 1) < OBlowsmc(timeframe, mode, shoulder, startBar, i))
                     if (iClose(Symbol(), timeframe, i + shoulder + 2) < OBlowsmc(timeframe, mode, shoulder, startBar, i))
                        if (high(timeframe, 45, 1) - low(timeframe, 45, 1) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 200)
                        {
                           scan = i;
                           break;
                        }
      if (bar1 > 0)
         if (mode == MODE_LOW)
            if (OBlowsmc(timeframe, mode, shoulder, startBar, i) < low(timeframe, bar1 - 6, 4))
               if (iClose(Symbol(), timeframe, i + shoulder) > OBhighsmc(timeframe, mode, shoulder, startBar, i))
                  if (iClose(Symbol(), timeframe, i + shoulder + 1) > OBhighsmc(timeframe, mode, shoulder, startBar, i))
                     if (iClose(Symbol(), timeframe, i + shoulder + 2) > OBhighsmc(timeframe, mode, shoulder, startBar, i))
                        if (high(timeframe, 45, 1) - low(timeframe, 45, 1) > SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 200)
                        {
                           scan = i;
                           break;
                        }
      // return( scan);
   } // for(int)
   return (scan);
} // int barscan
////+------------------------------------------------------------------+
////+------------------------------------------------------------------+
//| Get  Order Block Bar                                            |
//+------------------------------------------------------------------+
int OBbarsmc(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // blocktop
   double peakline = PikLine(timeframe, mode, shoulder, startBar, peakNo);
   int peaklinebar = PikBar(timeframe, mode, shoulder, startBar, peakNo);
   int peaklinebarprev = 0;
   if (peakNo > 1)
      peaklinebarprev = PikBar(timeframe, mode, shoulder, startBar, peakNo - 1);
   if (peakNo == 1)
      peaklinebarprev = startBar;
   int peakbardiff = EngulfDown(timeframe, peaklinebar, peaklinebarprev) - peaklinebarprev;
   int peakbardiffi = EngulfUp(timeframe, peaklinebar, peaklinebarprev) - peaklinebarprev;
   int peakengdiff = peaklinebar - EngulfDown(timeframe, peaklinebar, peaklinebarprev);
   int peakengdiffi = peaklinebar - EngulfUp(timeframe, peaklinebar, peaklinebarprev);
   int nextengfUp = EngulfUp(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev) - 1, peaklinebarprev);
   int nextengfDown = EngulfDown(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) - 1, peaklinebarprev);
   int nextpeakengdiff = peaklinebar - nextengfDown;
   int nextpeakengdiffi = peaklinebar - nextengfUp;

   int nextengfUp2 = EngulfUp(timeframe, nextengfUp - 1, peaklinebarprev);
   int nextengfDown2 = EngulfDown(timeframe, nextengfDown - 1, peaklinebarprev);
   int nextpeakengdiff2 = peaklinebar - nextengfDown2;
   int nextpeakengdiffi2 = peaklinebar - nextengfUp2;

   int nextengfUp3 = EngulfUp(timeframe, nextengfUp2 - 1, peaklinebarprev);
   int nextengfDown3 = EngulfDown(timeframe, nextengfDown2 - 1, peaklinebarprev);
   int nextpeakengdiff3 = peaklinebar - nextengfDown3;
   int nextpeakengdiffi3 = peaklinebar - nextengfUp3;

   int peakbardiffext = nextengfDown - peaklinebarprev;
   int peakbardiffext2 = nextengfDown2 - peaklinebarprev;
   int peakbardiffext3 = nextengfDown3 - peaklinebarprev;
   int peakbardiffiext = nextengfUp - peaklinebarprev;
   int peakbardiffiext2 = nextengfUp2 - peaklinebarprev;
   int peakbardiffiext3 = nextengfUp3 - peaklinebarprev;

   int xbar = BarCrossUp(timeframe, peakline, peaklinebar, 1);
   int xbari = BarCrossDown(timeframe, peakline, peaklinebar, 1);
   int bearB4cross = -1;
   int bullB4cross = -1;
   bool smc1bu = false, smc1be = false;
   bool smc2bu = false, smc2be = false;
   /// bool smc2bu=false, smc2be=false;
   /// SMC OB bearish 01
   if (EngulfDown(timeframe, peaklinebar, peaklinebarprev) > 0
       /// swing hi formed then impulse break. Find highest bull candle between swing Hi and impulse move
       && high(timeframe, peakbardiff - 1, peaklinebarprev) <= iClose(NULL, timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1) && high(timeframe, peakbardiff - 1, peaklinebarprev) <= iOpen(NULL, timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1))
      /// Above is Highest High after engulfing is below the candle body before engulf
      if (iLow(NULL, timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev))                  // break of structure
          < low(timeframe, peakengdiff + 1, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1)) // break of structure

      // if( low(timeframe, EngulfUp(timeframe,peaklinebar,peaklinebarprev) - 2 , 2 )
      // > iClose( Symbol(),timeframe,  EngulfUp(timeframe,peaklinebar,peaklinebarprev)  ) )
      { // bearB4cross
         smc1be = true;
         bearB4cross = swinghibullbar(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
      } // bearB4cross
   // SMC OB bullish 01
   if (EngulfUp(timeframe, peaklinebar, peaklinebarprev) > 0
       // swing lo formed then impulse break. Find lowest bear candle between swing Lo and impulse move
       && low(timeframe, peakbardiffi - 1, peaklinebarprev) >= iClose(NULL, timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1) && low(timeframe, peakbardiffi - 1, peaklinebarprev) >= iOpen(NULL, timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1))
      // Above is lowest low after engulfing is above the candle body before engulf
      if (iHigh(NULL, timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev))                   // break of structure)
          > high(timeframe, peakengdiffi + 1, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1)) // break of structure)

      { // bearB4cross
         smc1bu = true;
         bullB4cross = swinglobearbar(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
      } // bearB4cross

   // SMC OB bearish vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 02
   if (EngulfDown(timeframe, peaklinebar, peaklinebarprev) > 0
       /// swing hi formed then impulse break. Find highest bull candle between swing Hi and impulse move
       && high(timeframe, peakbardiffext - 1, peaklinebarprev) <= iClose(NULL, timeframe, nextengfDown + 1) && high(timeframe, peakbardiffext - 1, peaklinebarprev) <= iOpen(NULL, timeframe, nextengfDown + 1))
      /// Above is Highest High after engulfing is below the candle body before engulf
      if (iLow(NULL, timeframe, nextengfDown)                      // break of structure
          < low(timeframe, nextpeakengdiff + 1, nextengfDown + 1)) // break of structure

         if (high(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) - 2, 2) < iClose(Symbol(), timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev)))
         { // bearB4cross
            smc1be = true;
            bearB4cross = swinghibullbar(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
         } // bearB4cross
   // SMC OB bearish vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 03
   if (EngulfDown(timeframe, peaklinebar, peaklinebarprev) > 0
       /// swing hi formed then impulse break. Find highest bull candle between swing Hi and impulse move
       && high(timeframe, peakbardiffext2 - 1, peaklinebarprev) <= iClose(NULL, timeframe, nextengfDown2 + 1) && high(timeframe, peakbardiffext2 - 1, peaklinebarprev) <= iOpen(NULL, timeframe, nextengfDown2 + 1))
      /// Above is Highest High after engulfing is below the candle body before engulf
      if (iLow(NULL, timeframe, nextengfDown2)                       // break of structure
          < low(timeframe, nextpeakengdiff2 + 1, nextengfDown2 + 1)) // break of structure

         if (high(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) - 2, 2) < iClose(Symbol(), timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev)))
         { // bearB4cross
            smc1be = true;
            bearB4cross = swinghibullbar(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
         } // bearB4cross
   // SMC OB bearish vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv 04
   if (EngulfDown(timeframe, peaklinebar, peaklinebarprev) > 0
       /// swing hi formed then impulse break. Find highest bull candle between swing Hi and impulse move
       && high(timeframe, peakbardiffext3 - 1, peaklinebarprev) <= iClose(NULL, timeframe, nextengfDown3 + 1) && high(timeframe, peakbardiffext3 - 1, peaklinebarprev) <= iOpen(NULL, timeframe, nextengfDown2 + 1))
      /// Above is Highest High after engulfing is below the candle body before engulf
      if (iLow(NULL, timeframe, nextengfDown3)                       // break of structure
          < low(timeframe, nextpeakengdiff3 + 1, nextengfDown3 + 1)) // break of structure

         if (high(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) - 2, 2) < iClose(Symbol(), timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev)))
         { // bearB4cross
            smc1be = true;
            bearB4cross = swinghibullbar(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
         } // bearB4cross
   /// xxxxx
   // SMC OB bullish 02
   if (EngulfUp(timeframe, peaklinebar, peaklinebarprev) > 0
       // swing lo formed then impulse break. Find lowest bear candle between swing Lo and impulse move
       && low(timeframe, peakbardiffiext - 1, peaklinebarprev) >= iClose(NULL, timeframe, nextengfUp + 1) && low(timeframe, peakbardiffiext - 1, peaklinebarprev) >= iOpen(NULL, timeframe, nextengfUp + 1))
      // Above is lowest low after engulfing is above the candle body before engulf
      if (iHigh(NULL, timeframe, nextengfUp)                       // break of structure
          > high(timeframe, nextpeakengdiffi + 1, nextengfUp + 1)) // break of structure
      {                                                            // bearB4cross
         smc1bu = true;
         bullB4cross = swinglobearbar(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
      } // bearB4cross
   // SMC OB bullish 03
   if (EngulfUp(timeframe, peaklinebar, peaklinebarprev) > 0
       // swing lo formed then impulse break. Find lowest bear candle between swing Lo and impulse move
       && low(timeframe, peakbardiffiext2 - 1, peaklinebarprev) >= iClose(NULL, timeframe, nextengfUp2 + 1) && low(timeframe, peakbardiffiext2 - 1, peaklinebarprev) >= iOpen(NULL, timeframe, nextengfUp2 + 1))
      // Above is lowest low after engulfing is above the candle body before engulf
      if (iHigh(NULL, timeframe, nextengfUp2)                        // break of structure
          > high(timeframe, nextpeakengdiffi2 + 1, nextengfUp2 + 1)) // break of structure
      {                                                              // bearB4cross
         smc1bu = true;
         bullB4cross = swinglobearbar(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
      } // bearB4cross
   // SMC OB bullish 04
   if (EngulfUp(timeframe, peaklinebar, peaklinebarprev) > 0
       // swing lo formed then impulse break. Find lowest bear candle between swing Lo and impulse move
       && low(timeframe, peakbardiffiext3 - 1, peaklinebarprev) >= iClose(NULL, timeframe, nextengfUp3 + 1) && low(timeframe, peakbardiffiext3 - 1, peaklinebarprev) >= iOpen(NULL, timeframe, nextengfUp3 + 1))
      // Above is lowest low after engulfing is above the candle body before engulf
      if (iHigh(NULL, timeframe, nextengfUp3)                        // break of structure
          > high(timeframe, nextpeakengdiffi3 + 1, nextengfUp3 + 1)) // break of structure
      {                                                              // bearB4cross
         smc1bu = true;
         bullB4cross = swinglobearbar(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev), peaklinebar + 3);
      } // bearB4cross
   // xxxxx
   // wwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwwww
   // SMC OB bearish
   if (                                                                                                                                                  // xbar<0 &&
       EngulfDown(timeframe, peaklinebar, peaklinebarprev) > 0 && high(timeframe, peakbardiff - 2, peaklinebarprev)                                      // Imbalance
                                                                      <= iLow(NULL, timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1)) // imbalance
      if (bearcandle(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1))                                                                // bear candle before engulf
         if (iLow(NULL, timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev))                                                                  // break of structure
             < low(timeframe, peakengdiff + 1, EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1))                                                 // break of structure
            if (!smc1be)

               if (high(timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev) - 2, 2) < iClose(Symbol(), timeframe, EngulfDown(timeframe, peaklinebar, peaklinebarprev)))
               { // bearB4cross
                  smc2be = true;
                  bearB4cross = EngulfDown(timeframe, peaklinebar, peaklinebarprev) + 1;
               } // bearB4cross BEARISH OB
   // SMC OB   bullish
   if (                                                                                                  // xbari<0 &&
       EngulfUp(timeframe, peaklinebar, peaklinebarprev) > 0                                             //
       && low(timeframe, peakbardiffi - 2, peaklinebarprev)                                              // imbalance
              >= iHigh(NULL, timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1))          // imbalance
      if (bullcandle(timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1))                  // bull candle before engulf
         if (iHigh(NULL, timeframe, EngulfUp(timeframe, peaklinebar, peaklinebarprev))                   // break of structure)
             > high(timeframe, peakengdiffi + 1, EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1)) // break of structure)
            if (!smc1bu)
            { // bearB4cross
               smc2bu = true;
               bullB4cross = EngulfUp(timeframe, peaklinebar, peaklinebarprev) + 1;
            } // bearB4cross BULLISH OB
   /// WWWWWWWWWWWWWWWWWWW
   // WWWWWWWWWWWWWWWWWWW
   if (EngulfDowni(timeframe, peaklinebar, peaklinebarprev) > 0)
      if (high(timeframe, EngulfDowni(timeframe, peaklinebar, peaklinebarprev) - 3, 2) < iClose(Symbol(), timeframe, EngulfDowni(timeframe, peaklinebar, peaklinebarprev)))
         if (!smc1be)
         { // bearB4cross
            smc2be = true;
            bearB4cross = EngulfDowni(timeframe, peaklinebar, peaklinebarprev) + 1;
         } // bearB4cross BEARISH OB
   // SMC OB   bullish
   if (EngulfUpi(timeframe, peaklinebar, peaklinebarprev) > 0) //
      if (low(timeframe, EngulfUpi(timeframe, peaklinebar, peaklinebarprev) - 3, 2) > iClose(Symbol(), timeframe, EngulfUpi(timeframe, peaklinebar, peaklinebarprev)))
         if (!smc1bu)
         { // bearB4cross
            smc2bu = true;
            bullB4cross = EngulfUpi(timeframe, peaklinebar, peaklinebarprev) + 1;
         } // bearB4cross BULLISH OB

   return ((mode == MODE_HIGH) ? bearB4cross : bullB4cross);
} // blocktop END SMC OB
////+------------------------------------------------------------------+

////+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int EngulfDown(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iLow(Symbol(), timeframe, i + 1) > iClose(Symbol(), timeframe, i))
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
} // bar
//+------------------------------------------------------------------+
int EngulfUp(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iHigh(Symbol(), timeframe, i + 1) < iClose(Symbol(), timeframe, i))
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
} // bar
////+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int EngulfDowni(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iLow(Symbol(), timeframe, i + 1) > iClose(Symbol(), timeframe, i))
         if (iClose(Symbol(), timeframe, i) < low(timeframe, 3, i + 1))
         {
            currentbar = i;
            break;
         }
   } // for
   return (currentbar);
} // bar
//+------------------------------------------------------------------+
int EngulfUpi(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iHigh(Symbol(), timeframe, i + 1) < iClose(Symbol(), timeframe, i))
         if (iClose(Symbol(), timeframe, i) > high(timeframe, 3, i + 1))
         {
            currentbar = i;
            break;
         }
   } // for
   return (currentbar);
} // bar
//+------------------------------------------------------------------+
bool EngulfBuy(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   bool ReturnValue = false;
   for (int i = start; i <= end; i++)
   { // for
      double gapi = 0, gapxi = 0;
      double bodi = iOpen(Symbol(), timeframe, i) - iClose(Symbol(), timeframe, i);
      double bodii = iClose(Symbol(), timeframe, i) - iOpen(Symbol(), timeframe, i);
      double bodxi = iOpen(Symbol(), timeframe, i + 1) - iClose(Symbol(), timeframe, i + 1);
      double bodxii = iClose(Symbol(), timeframe, i + 1) - iOpen(Symbol(), timeframe, i + 1);
      if (bodi > 0)
         gapi = bodi;
      if (bodii > 0)
         gapi = bodii;
      if (bodxi > 0)
         gapxi = bodxi;
      if (bodxii > 0)
         gapxi = bodxii;

      if (lowclo(PERIOD_M5, i - 2, 2) > iLow(Symbol(), PERIOD_M5, i + 1))             // Imbalance
         if (bodii > gapxi * 1)                                                       // Impulse Up
            if (iLow(Symbol(), PERIOD_M5, 1) < iHigh(Symbol(), PERIOD_M5, i + 1))     // Dip to Imbalance
               if (low(PERIOD_M5, 3, 3) > iHigh(Symbol(), PERIOD_M5, i + 1))          // Dip to Imbalance
                  if (lowclo(PERIOD_M5, 3, i + 2) > iLow(Symbol(), PERIOD_M5, i + 1)) // Swing Low before imbalance
                     if (highestlo(PERIOD_M5, i - 4, 3) > iHigh(Symbol(), PERIOD_M5, i + 1) + (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15.0))
                     {
                        ReturnValue = true;
                     } // schematic BUY
   }                   // for

   return (ReturnValue);
} // bar
//+------------------------------------------------------------------+
bool EngulfSell(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   bool ReturnValue = false;
   for (int i = start; i <= end; i++)
   { // for
      double gapi = 0, gapxi = 0;
      double bodi = iOpen(Symbol(), timeframe, i) - iClose(Symbol(), timeframe, i);
      double bodii = iClose(Symbol(), timeframe, i) - iOpen(Symbol(), timeframe, i);
      double bodxi = iOpen(Symbol(), timeframe, i + 1) - iClose(Symbol(), timeframe, i + 1);
      double bodxii = iClose(Symbol(), timeframe, i + 1) - iOpen(Symbol(), timeframe, i + 1);
      if (bodi > 0)
         gapi = bodi;
      if (bodii > 0)
         gapi = bodii;
      if (bodxi > 0)
         gapxi = bodxi;
      if (bodxii > 0)
         gapxi = bodxii;

      if (hiclo(PERIOD_M5, i - 2, 2) < iHigh(Symbol(), PERIOD_M5, i + 1))             // Imbalance
         if (bodi > gapxi * 1)                                                        // Impulse Up
            if (iHigh(Symbol(), PERIOD_M5, 1) > iLow(Symbol(), PERIOD_M5, i + 1))     // Dip to Imbalance
               if (high(PERIOD_M5, 3, 3) < iLow(Symbol(), PERIOD_M5, i + 1))          // Dip to Imbalance
                  if (hiclo(PERIOD_M5, 3, i + 2) < iHigh(Symbol(), PERIOD_M5, i + 1)) // Swing Low before imbalance
                     if (lowesthi(PERIOD_M5, i - 4, 3) < iLow(Symbol(), PERIOD_M5, i + 1) - (SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 15.0))
                     {
                        ReturnValue = true;
                     } // schematic BUY

   } // for

   return (ReturnValue);
} // bar

////+------------------------------------------------------------------+
double PikLine(ENUM_TIMEFRAMES timeframe, int mode, int shoulder, int startBar, int peakNo)
{ // PikLine
   return ((mode == MODE_HIGH) ? iHigh(Symbol(), timeframe, PikBar(timeframe, (ENUM_SERIESMODE)mode, shoulder, startBar, peakNo)) : iLow(Symbol(), timeframe, PikBar(timeframe, (ENUM_SERIESMODE)MODE_LOW, shoulder, startBar, peakNo)));
} // PikLine
//+------------------------------------------------------------------+
//|                                              |
//+------------------------------------------------------------------+
int BarCrossUp(ENUM_TIMEFRAMES timeframe, double linecross, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iClose(Symbol(), timeframe, i) > linecross &&
          iOpen(Symbol(), timeframe, i) < linecross)
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
} // bar
//+------------------------------------------------------------------+
int BarCrossDown(ENUM_TIMEFRAMES timeframe, double linecross, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i > end; i--)
   { // for
      if (iClose(Symbol(), timeframe, i) < linecross &&
          iOpen(Symbol(), timeframe, i) > linecross)
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
} // bar
//+------------------------------------------------------------------+
int FindBull(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i <= end; i++)
   { // for
      if (bullcandle(timeframe, i))
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
}
//+------------------------------------------------------------------+
int FindBear(ENUM_TIMEFRAMES timeframe, int start, int end)
{ // bar
   int currentbar = -1;
   for (int i = start; i <= end; i++)
   { // for
      if (bearcandle(timeframe, i))
      {
         currentbar = i;
         break;
      }
   } // for
   return (currentbar);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int swinghibullbar(ENUM_TIMEFRAMES timeframe, int candleStart, int candleEnd)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars_to_copy = (candleEnd - candleStart) + 1;
   int bar_index = 0;
   double highest_high = 0;
   int copied = CopyRates(Symbol(), timeframe, candleStart, bars_to_copy, rates);
   if (copied > 0)
   {
      for (int x = 0; x < copied; x++)
      {
         if (rates[x].close > rates[x].open) // Is bullish
         {
            if (rates[x].high > highest_high)
            {
               bar_index = x + candleStart;
               highest_high = rates[x].high;
            }
         }
      }
   }
   return (bar_index);
}
//+------------------------------------------------------------------+
int swinglobearbar(ENUM_TIMEFRAMES timeframe, int candleStart, int candleEnd)
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int bars_to_copy = (candleEnd - candleStart) + 1;
   int bar_index = 0;
   double lowest_low = 9999999999;
   int copied = CopyRates(Symbol(), timeframe, candleStart, bars_to_copy, rates);
   if (copied > 0)
   {
      for (int x = 0; x < copied; x++)
      {
         if (rates[x].close < rates[x].open) // Is bearish
         {
            if (rates[x].low < lowest_low)
            {
               bar_index = x + candleStart;
               lowest_low = rates[x].low;
            }
         }
      }
   }
   return (bar_index);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
int FindNextBull(ENUM_TIMEFRAMES timeframe, int startBar, int endBar)
{ // a2
   int count = 0;
   if (FindBull(timeframe, startBar, endBar) == 0)
      return (0);

   if (FindBull(timeframe, startBar, endBar) > 0)
   {
      count = FindBull(timeframe, FindBull(timeframe, startBar, endBar) + 1, endBar);
   }

   //   for(int i = FindBull(timeframe,startBar,endBar)+1; i < endBar; i++)
   //   if(bullcandle(timeframe,i) )
   // {count = i;  }
   //---
   return (count);
}
// a2//+------------------------------------------------------------------+
// a2//+------------------------------------------------------------------+
///+------------------------------------------------------------------+
bool bullcandle(ENUM_TIMEFRAMES timeframe, int shift)
{
   bool ReturnValue = false;

   if (iClose(NULL, timeframe, shift) > iOpen(NULL, timeframe, shift))
   {
      ReturnValue = true;
   } // sch
   return ReturnValue;
}
///+------------------------------------------------------------------+
bool bearcandle(ENUM_TIMEFRAMES timeframe, int shift)
{
   bool ReturnValue = false;

   if (iClose(NULL, timeframe, shift) < iOpen(NULL, timeframe, shift))
   {
      ReturnValue = true;
   } // sch
   return ReturnValue;
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| count bull candles                                           |
//+------------------------------------------------------------------+
int bullcount(ENUM_TIMEFRAMES timeFrame, int start, int end)
{ // bullcount
   int barcount = 0;
   for (int i = start; i <= end; i++)
   { // for
      if (iClose(Symbol(), timeFrame, i) > iOpen(Symbol(), timeFrame, i))
         barcount++;
   } // for
   return (barcount);
} // bullcount
//+------------------------------------------------------------------+
//| count bull candles                                           |
//+------------------------------------------------------------------+
int bearcount(ENUM_TIMEFRAMES timeFrame, int start, int end)
{ // bullcount
   int barcount = 0;
   for (int i = start; i <= end; i++)
   { // for
      if (iClose(Symbol(), timeFrame, i) < iOpen(Symbol(), timeFrame, i))
         barcount++;
   } // for
   return (barcount);
} // bullcount

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int digits()
{
   return ((int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ClosePositions()
{
   int total = PositionsTotal();
   for (int k = total - 1; k >= 0; k--)
      if (PositionGetTicket(k))
         if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY || PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL)
         {
            if (PositionGetString(POSITION_SYMBOL) == Symbol())
               // position with appropriate ORDER_MAGIC, symbol and order type
               trade.PositionClose(PositionGetInteger(POSITION_TICKET), Slippage);
         }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CalculateTotalProfit()
{
   double val = 0;
   double profit = 0, swap = 0, comm = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (PositionGetTicket(i))
         if (PositionGetString(POSITION_SYMBOL) == Symbol())
         {
            profit = PositionGetDouble(POSITION_PROFIT);
            swap = PositionGetDouble(POSITION_SWAP);
            comm = AccountInfoDouble(ACCOUNT_COMMISSION_BLOCKED);
            val += profit + swap + comm;
         }
   }

   return (NormalizeDouble(val, 2));
}

//+------------------------------------------------------------------+
//|                                                                  |
///+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool createObject(string name, string text)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 33);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrRed);

   return (true);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool createObject2(string name, string text)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 62);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);

   return (true);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool createObject4(string name, string text)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 30);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 90);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 14);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDodgerBlue);

   return (true);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool createObject3(string name, double val)
{
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, val);

   return (true);
}
//+------------------------------------------------------------------+
bool createBackground()
{
   ObjectCreate(0, "Background", OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, "Background", OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, "Background", OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, "Background", OBJPROP_YDISTANCE, 100);
   ObjectSetInteger(0, "Background", OBJPROP_XSIZE, 240);
   ObjectSetInteger(0, "Background", OBJPROP_YSIZE, 100);
   ObjectSetInteger(0, "Background", OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, "Background", OBJPROP_BORDER_COLOR, clrGreenYellow);
   ObjectSetInteger(0, "Background", OBJPROP_BORDER_TYPE, BORDER_RAISED);
   ObjectSetInteger(0, "Background", OBJPROP_WIDTH, 0);
   ObjectSetInteger(0, "Background", OBJPROP_BACK, false);
   ObjectSetInteger(0, "Background", OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, "Background", OBJPROP_HIDDEN, true);
   return (true);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Checks if the specified filling mode is allowed                  |
//+------------------------------------------------------------------+
bool IsFillingTypeAllowed(int fill_type)
{
   //--- Obtain the value of the property that describes allowed filling modes
   int filling = m_symbol.TradeFillFlags();
   //--- Return true, if mode fill_type is allowed
   return ((filling & fill_type) == fill_type);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWrite(string name,
                string comment,
                int x_distance,
                int y_distance,
                int FontSize,
                color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWritei(string name,
                 string comment,
                 int x_distance,
                 int y_distance,
                 int FontSize,
                 color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWriteii(string name,
                  string comment,
                  int x_distance,
                  int y_distance,
                  int FontSize,
                  color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWriteiii(string name,
                   string comment,
                   int x_distance,
                   int y_distance,
                   int FontSize,
                   color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWriteiv(string name,
                  string comment,
                  int x_distance,
                  int y_distance,
                  int FontSize,
                  color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWritev(string name,
                 string comment,
                 int x_distance,
                 int y_distance,
                 int FontSize,
                 color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWritevi(string name,
                  string comment,
                  int x_distance,
                  int y_distance,
                  int FontSize,
                  color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChartWritevii(string name,
                   string comment,
                   int x_distance,
                   int y_distance,
                   int FontSize,
                   color clr)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_TEXT, comment);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Lucida Console");
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_distance);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y_distance);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
