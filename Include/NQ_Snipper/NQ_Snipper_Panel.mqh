#ifndef __NQ_SNIPPER_PANEL__
#define __NQ_SNIPPER_PANEL__

#include "NQ_Snipper_TimeCalendar.mqh"
#include "NQ_Snipper_Patterns.mqh"


//==================================================
// UPDATE CHART PANEL
//==================================================

void UpdatePanel()
{
   datetime nowGMT =
      TimeGMT();

   bool entryWindowOpen =
      !InpEnableTradingHoursFilter ||
      IsNQSnipperExecutionTime();

   string panel =
      "NQ SNIPPER\n";

   panel +=
      "------------------------------\n";

   panel +=
      "Symbol: " +
      _Symbol +
      "\n";

   panel +=
      "Timeframe: M5\n";

   panel +=
      "GMT: " +
      TimeToString(
         nowGMT,
         TIME_DATE | TIME_SECONDS
      ) +
      "\n";

   panel +=
      "Filters: News=" + (InpEnableNewsTimingFilter ? "ON" : "OFF") +
      ", Hours=" + (InpEnableTradingHoursFilter ? "ON" : "OFF") +
      ", H1 Momentum=" + (InpEnableHourlyMomentumFilter ? "ON" : "OFF") +
      "\n";

   panel +=
      "Filters: Spread=" + (InpEnableSpreadFilter ? "ON" : "OFF") +
      ", Breakeven=" + (InpEnableBreakEvenManagement ? "ON" : "OFF") +
      "\n";

   if(UseTesterNewsData())
   {
      panel +=
         "News source: TESTER CSV (" + InpTesterNewsFile + ")\n";
   }

   panel +=
      "Patterns: Double=" + (InpEnableDoublePattern ? "ON" : "OFF") +
      ", Leg-Knee=" + (InpEnableLegKneePattern ? "ON" : "OFF") +
      ", Tail/Body=" + (InpEnableTailBodyPattern ? "ON" : "OFF") +
      ", Tail/Body V=" + (InpEnableTailBodyVPattern ? "ON" : "OFF") +
      "\n";

   panel +=
      "High Impact Today: " +
      (
         g_hasHighImpactNewsToday
         ? "YES"
         : "NO"
      ) +
      "\n";

   panel += "First leg: ";
   if(!g_firstLegReady)
      panel += "WAITING FOR OPEN / HISTORY\n";
   else if(g_firstLegDirection == FIRST_LEG_NEITHER)
      panel += "NEITHER (waiting for range breakout)\n";
   else
      panel += (g_firstLegDirection == FIRST_LEG_BULLISH
         ? "BULLISH " : "BEARISH ") +
         DoubleToString(g_firstLegPrice, _Digits) + "\n";


   if(g_hasHighImpactNewsToday)
   {
      panel +=
         "News: " +
         g_latestHighImpactNewsName +
         "\n";
   }
   else
   {
      panel +=
         "News: NONE\n";
   }


   //================================================
   // LATEST RELEASE
   //================================================

   panel +=
      "Latest News GMT: " +
      FormatGMT(
         g_latestRedNewsGMT
      ) +
      "\n";


   //================================================
   // ACTIVATION
   //================================================

   panel +=
      "Activation GMT: " +
      FormatGMT(
         g_activationTimeGMT
      ) +
      "\n";


   //================================================
   // LOCKED STATE
   //================================================

   if(!g_patternEngineActive)
   {
      long remaining =
         (
            long
            (
               g_activationTimeGMT -
               nowGMT
            )
         );

      if(remaining < 0)
         remaining = 0;


      panel +=
         "Remaining: " +
         IntegerToString(
            (int)remaining
         ) +
         " sec\n";

      panel +=
         "ENGINE: LOCKED\n";
   }
   else
   {
      //================================================
      // ACTIVE STATE
      //================================================

      panel +=
         entryWindowOpen
         ? "ENGINE: ACTIVE\n"
         : "ENGINE: OUTSIDE TRADING HOURS\n";

      panel +=
         "Pattern: " +
         PatternName(
            g_detectedPattern
         ) +
         "\n";

      panel +=
         "Trade Placed: " +
         (
            g_tradePlacedForCycle
            ? "YES"
            : "NO"
         ) +
         "\n";
   }


   Comment(panel);
}

#endif
