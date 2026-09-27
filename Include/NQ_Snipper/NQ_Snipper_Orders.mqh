#ifndef __NQ_SNIPPER_PATTERN_ORDERS__
#define __NQ_SNIPPER_PATTERN_ORDERS__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_TimeCalendar.mqh"

bool HasOurEntryDealToday(datetime dayStartGMT)
{
   datetime fromServer = GMTToServerTime(dayStartGMT);

   if(!HistorySelect(fromServer, TimeTradeServer()))
      return false;

   int totalDeals = HistoryDealsTotal();

   for(int i = totalDeals - 1; i >= 0; i--)
   {
      ulong ticket = HistoryDealGetTicket(i);

      if(ticket == 0)
         continue;

      if(HistoryDealGetString(ticket, DEAL_SYMBOL) != _Symbol)
         continue;

      if(
         HistoryDealGetInteger(ticket, DEAL_MAGIC) !=
         (long)InpMagicNumber
      )
      {
         continue;
      }

      long entryType =
         HistoryDealGetInteger(ticket, DEAL_ENTRY);

      if(entryType == DEAL_ENTRY_IN)
         return true;
   }

   return false;
}


void UpdateDailyTradeLimit()
{
   datetime dayStartGMT = GMTDayStart(TimeGMT());

   if(g_tradeLimitDayStartGMT == dayStartGMT)
      return;

   g_tradeLimitDayStartGMT = dayStartGMT;
   g_tradePlacedForCycle =
      HasOurEntryDealToday(dayStartGMT);
}


//==================================================
// EXECUTE DOUBLE TOP SELL
//==================================================

bool ExecuteDoubleTopSell(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Double Top SELL rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Double Top SELL rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.bid + InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.bid - InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Sell(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Double Top SELL failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Double Top SELL opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}


//==================================================
// EXECUTE DOUBLE BOTTOM BUY
//==================================================

bool ExecuteDoubleBottomBuy(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Double Bottom BUY rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Double Bottom BUY rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.ask - InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.ask + InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Buy(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Double Bottom BUY failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Double Bottom BUY opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}


//==================================================
// EXECUTE TAIL & BODY TOP SELL
//==================================================

bool ExecuteTailBodyTopSell(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Tail & Body Top SELL rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Tail & Body Top SELL rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.bid + InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.bid - InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Sell(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Tail & Body Top SELL failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Tail & Body Top SELL opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}


//==================================================
// EXECUTE TAIL & BODY BOTTOM BUY
//==================================================

bool ExecuteTailBodyBottomBuy(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Tail & Body Bottom BUY rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Tail & Body Bottom BUY rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.ask - InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.ask + InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Buy(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Tail & Body Bottom BUY failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Tail & Body Bottom BUY opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}


//==================================================
// EXECUTE LEG & KNEE TOP SELL
//==================================================

bool ExecuteLegKneeTopSell(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Leg & Knee Top SELL rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Leg & Knee Top SELL rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.bid + InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.bid - InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Sell(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Leg & Knee Top SELL failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Leg & Knee Top SELL opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}


//==================================================
// EXECUTE LEG & KNEE BOTTOM BUY
//==================================================

bool ExecuteLegKneeBottomBuy(
   CTrade &trade
)
{
   double volume =
      InpLotSize;

   if(volume <= 0)
   {
      Print(
         "Leg & Knee Bottom BUY rejected: ",
         "invalid lot size."
      );

      return false;
   }

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Leg & Knee Bottom BUY rejected: unable to obtain symbol tick.");
      return false;
   }

   double stopLoss =
      (InpStopLossPoints > 0)
      ? NormalizeDouble(
           tick.ask - InpStopLossPoints * _Point,
           _Digits
        )
      : 0.0;

   double takeProfit =
      (InpTakeProfitPoints > 0)
      ? NormalizeDouble(
           tick.ask + InpTakeProfitPoints * _Point,
           _Digits
        )
      : 0.0;

   bool result =
      trade.Buy(
         volume,
         _Symbol,
         0.0,
         stopLoss,
         takeProfit
      );

   if(!result)
   {
      Print(
         "Leg & Knee Bottom BUY failed. ",
         "Retcode=",
         trade.ResultRetcode(),
         " Description=",
         trade.ResultRetcodeDescription()
      );

      return false;
   }

   Print(
      "Leg & Knee Bottom BUY opened successfully. ",
      "Ticket=",
      trade.ResultOrder()
   );

   return true;
}

//==================================================
// EXECUTION WINDOW
//==================================================

bool IsNQSnipperExecutionTime()
{
   datetime nowGMT = TimeGMT();

   MqlDateTime tm;
   TimeToStruct(nowGMT, tm);

   int minutesNow =
      tm.hour * 60 +
      tm.min;

   int startMinutes =
      InpEntryStartHourGMT * 60 +
      InpEntryStartMinuteGMT;

   int endMinutes = g_isFOMCToday
      ? InpFOMCEntryEndHourGMT * 60 +
        InpFOMCEntryEndMinuteGMT
      : InpEntryEndHourGMT * 60 +
        InpEntryEndMinuteGMT;

   return (
      minutesNow >= startMinutes &&
      minutesNow <= endMinutes
   );
}

#endif
