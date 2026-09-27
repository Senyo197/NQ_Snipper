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


   //================================================
   // NEWS STATUS
   //================================================

   panel +=
      "High Impact Today: " +
      (
         g_hasHighImpactNewsToday
         ? "YES"
         : "NO"
      ) +
      "\n";


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
         "ENGINE: ACTIVE\n";

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