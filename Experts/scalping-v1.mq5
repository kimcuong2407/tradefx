//+------------------------------------------------------------------+
//|                                                  scalping-v1.mq5 |
//|                                  Copyright 2023, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"

double ArrayBuffer[];

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
   onStart();
  // for (int i = 0; i < ArraySize(Array); i++)
  // {
  //   Print("element - " + i+" -" + Array[i]);
  // }
}
//+------------------------------------------------------------------+
//| Trade function                                                   |
//+------------------------------------------------------------------+
void OnTrade()
{
  //---
}
//+------------------------------------------------------------------+

void onStart()
{
  int supportResistance = iCustom(_Symbol, _Period, "Support-and-Resistance-Lines/MQL5/Indicators/MQLTA MT5 Support Resistance Lines");
  int totalCopy = CopyBuffer(supportResistance, "Array", 0, 10, ArrayBuffer);
  printf("EA totalCopy - %d", totalCopy);
  for (int i = 0; i < totalCopy; i++)
  {
    printf("EA element - %d - value: %f", i,  ArrayBuffer[i]);
  }
}