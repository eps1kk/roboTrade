//+------------------------------------------------------------------+
//|                                          BolligerBandsTrader.mq4 |
//|                                         Das ist meine WATERMELON |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#include <MovingAverages.mqh>
#property copyright "Das ist meine WASSERMELON"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict


input int    InpBandsPeriod = 20;      // Bands Period
input int    InpBandsShift = 0;        // Bands Shift
input double InpBandsDeviations = 2.0; // Bands Deviations 
input int rsiBandsPeriod = 4; // На один больше чем надо
input int MA = 0; // Choose MA (Simple - 0, Exp - 1);

MqlRates rates[2];
double rsi;
double diffClosedPriceArrayUp[];
double diffClosedPriceArrayDown[];
// Main parameteres  
double difference = 0.0006;
double expMAUp = 0;
double expMADown = 0;
double simpleMAUp = 0;
double simpleMADown = 0;
int slippage = 100;
int lastDayOfWeek = -1;
int lastMonth = -1;
int ordersCount = 0;
double close_array[20];
double closeArrayDaily[];
// С КЛОЗ АРРЭЙ ВОЗМОЖНЫ БАГИ!!!!!!!
double Lots_New = 0;
double Lots_New_Loss = 0;
double oneLot = MarketInfo(_Symbol, MODE_MARGINREQUIRED);
int currentTicket = 0;
bool banTrade = false;
double StdDev;    
//--- стандартное отклонение
double middleLine, topLine, bottomLine;
//--- скользящее среднее, верхняя и нижния линии
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {   
   expMADown = expMAUp = Close[rsiBandsPeriod + 1];
   ArrayResize(diffClosedPriceArrayUp, rsiBandsPeriod);
   ArrayResize(diffClosedPriceArrayDown, rsiBandsPeriod);
   ArrayResize(closeArrayDaily, rsiBandsPeriod + 1);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   //EventKillTimer();
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick(void)
  {
   for (int i = 0; i < 20; i++)
   {
      close_array[i] = Close[i];
   }
   StdDev = sqrt ( SumDiffMAClosed(InpBandsPeriod) / InpBandsPeriod);
   middleLine = SimpleMA( InpBandsPeriod - 1, InpBandsPeriod, close_array);
   topLine = middleLine + (InpBandsDeviations * StdDev);
   bottomLine = middleLine - (InpBandsDeviations * StdDev);
   //-- посчитали границы
   Lots_New = (AccountFreeMargin() / oneLot) * 0.2;
   //-- объем посчитали
   Lots_New_Loss = Bid - ((AccountFreeMargin() * 0.0006) / (AccountFreeMargin() * 0.2));
   //-- посчитали тэйк профит
   double Lots_New_Loss2 = Ask + ((AccountFreeMargin() * 0.0006) / (AccountFreeMargin() * 0.2));
   //double TP1 = Bid + ((AccountFreeMargin() * 0.04) / (AccountFreeMargin() * 0.2))*2;
   //double TP2 = Ask - ((AccountFreeMargin() * 0.0007) / (AccountFreeMargin() * 0.2))*2;
   //--- посчитали стоп луз
   double pivotPoint = 0;
   if(DayOfWeek() != lastDayOfWeek)
   {
       CopyRates(_Symbol, PERIOD_D1, 1, 2, rates);
       lastDayOfWeek = DayOfWeek();
      while (_LastError == 4066)
      {
         Sleep(300);
         CopyRates(_Symbol, PERIOD_D1, 1, 2, rates);
      }
      //-- скопировали рэйты
      pivotPoint = (rates[0].high + rates[0].low + rates[0].close) / 3;
      double R1 = 2*pivotPoint - rates[0].low;
      double S1 = 2*pivotPoint - rates[0].high;
      double R2 = pivotPoint + (R1 - S1);
      double S2 = pivotPoint - (R1 - S1);
      double R3 = rates[0].high + 2*(pivotPoint - rates[0].low);
      double S3 = rates[0].low - 2*(rates[0].high - pivotPoint);
   }   
   CopyRates(_Symbol, PERIOD_D1, 0, 1, rates);
   double _rsi = getRSI();
   if(banTrade && OrderSelect(currentTicket, SELECT_BY_TICKET, MODE_HISTORY))
   {
      if (OrderCloseTime() != 0)
      {  
         Print("Order closed");
         banTrade = false;
      }
      else
      {
         if(OrderModify(currentTicket, OrderOpenPrice(), OrderStopLoss(), middleLine, OrderExpiration(), clrBeige))
         {
            Print("Order modified");
         };
      }
   }
   //--- коррекция ордеров
   if (MathAbs (Bid - bottomLine) < difference && !banTrade && rates[0].open > pivotPoint && _rsi < 30)
   {  
      currentTicket = OrderSend(_Symbol, OP_BUY, Lots_New, Bid, slippage, Lots_New_Loss, middleLine, "Robot order", ordersCount++, 0, clrRed);
      if(currentTicket != -1)
      {  
         banTrade = true;
         Print("Robot kupil!!!");
      };
   }
   else if (MathAbs (Ask - topLine) < difference && !banTrade && rates[0].open < pivotPoint && _rsi > 70)
   {  
      currentTicket = OrderSend(_Symbol, OP_SELL, Lots_New, Ask, slippage, Lots_New_Loss2, middleLine, "Robot order", ordersCount++, 0, clrGreen);
      if(currentTicket != -1)
      {
         banTrade = true;
         Alert("Robot prodal!!");
      };
   }
  }
double SumClosed( int amount)
{  
   double sum = 0;
   for (int i = 0; i < amount; i++)
   {
      sum = sum +  Close[i];
   }
   return (sum);
};
double SumDiffMAClosed(int amount)
{  
   double diffSum = 0;
   for (int i = InpBandsPeriod-1; i >= 0; i--)
   {
      diffSum += pow(close_array[i] - SimpleMA(InpBandsPeriod - 1, InpBandsPeriod, close_array),2);
   }
   return (diffSum);
};
double getRSI()
{
   // 0 - SimpleMA;
   // 1 - ExponentialMA;
   if (Month() != lastMonth)
   {
      while(CopyClose(_Symbol, PERIOD_MN1, 0, rsiBandsPeriod + 1, closeArrayDaily) == -1)
      {
   
      };
      lastMonth = Month();
      Print(_LastError, " - Error");
      for (int i = 0 ; i < rsiBandsPeriod; i++)
      {  
         if (closeArrayDaily[i + 1] > closeArrayDaily[i])
         {
            diffClosedPriceArrayUp[i] = closeArrayDaily[i + 1] - closeArrayDaily[i];
            diffClosedPriceArrayDown[i] = 0;
         }
         else if (closeArrayDaily[i + 1] < closeArrayDaily[i])
         {
            diffClosedPriceArrayDown[i] = closeArrayDaily[i] - closeArrayDaily[i + 1];
            diffClosedPriceArrayUp[i] = 0;
         }
         else
         {
            diffClosedPriceArrayDown[i] = 0;
            diffClosedPriceArrayUp[i] = 0;
            Print (" else");
         }
         Print(diffClosedPriceArrayDown[i], " down");
         Print(diffClosedPriceArrayUp[i], " up");
      }
      if (MA == 0)
      {
         simpleMAUp = SimpleMA(rsiBandsPeriod - 1, rsiBandsPeriod, diffClosedPriceArrayUp);
         simpleMADown = SimpleMA(rsiBandsPeriod - 1, rsiBandsPeriod, diffClosedPriceArrayDown);
         rsi = 100 - 100/(1 + (simpleMAUp / simpleMADown));
      }
      else if (MA == 1)
      {  
         expMAUp = ExponentialMA(rsiBandsPeriod - 1, rsiBandsPeriod, expMAUp, diffClosedPriceArrayUp);
         expMADown = ExponentialMA(rsiBandsPeriod - 1, rsiBandsPeriod, expMADown, diffClosedPriceArrayDown);
         Print(expMAUp, " - driveUP");
         Print(expMADown, " - driveDOWN");
         rsi = 100 - 100/(1 + (expMAUp / expMADown));
      }
      Print(simpleMAUp, " - UP");
      Print(simpleMADown, " - Down");
      Print(rsi, " - RSI");
   } 
   return rsi;
};
void checkOrders()
{
   
}
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+