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
  //int totalSize = iBars(_Symbol, _Period);
  // int totalSize = 100;
  //ArrayResize(ArrayBuffer, totalSize);
  int supportResistance = iCustom(_Symbol, _Period, "MQLTA MT5 Support Resistance Lines"); 
  int totalCopy = CopyBuffer(supportResistance, 8, 0, 1, ArrayBuffer);
  printf("totalCopy: %d", ArraySize(ArrayBuffer));
  //totalSize là số lượng record bác muốn lấy ra từ mảng định danh số 8
  // để e hỏi cái này
  for (int i = 0; i < ArrayBuffer[0]; i++)
  {
    printf("EA element - %d - value: %f", i, ArrayBuffer[i]); // bác đang bị lỗi chỗ này? đúng r bác
  }
}