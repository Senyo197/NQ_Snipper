#ifndef __NQ_SNIPPER_LEG_KNEE__
#define __NQ_SNIPPER_LEG_KNEE__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"
#include "NQ_Snipper_TurningPoint.mqh"


bool IsLegKneeSwing(bool top, int shift)
{
   return top ? IsSwingHigh(shift) : IsSwingLow(shift);
}


double LegKneeSwingPrice(bool top, int shift)
{
   return top
      ? iHigh(_Symbol, PERIOD_M5, shift)
      : iLow(_Symbol, PERIOD_M5, shift);
}


bool FindLegKneePattern(
   bool top,
   int &firstShift,
   int &kneeShift,
   double &neckline,
   int &breakShift,
   int &retestShift,
   int &reversalShift
)
{
   firstShift = -1;
   kneeShift = -1;
   neckline = 0.0;
   breakShift = -1;
   retestShift = -1;
   reversalShift = -1;

   double firstLegOpen = 0.0;
   double firstLegClose = 0.0;
   if(!GetFirstLegCandle(top, firstShift, firstLegOpen, firstLegClose))
      return false;

   int necklineShift = -1;
   if(!GetFirstLegNeckline(top, neckline, necklineShift))
      return false;

   double firstPrice = LegKneeSwingPrice(top, firstShift);
   if(firstPrice <= 0)
      return false;

   // The shared first leg replaces the historical first-pivot scan. The knee
   // must still be a confirmed local swing and at least the configured number
   // of M5 candles after the final first-leg candle.
   for(
      int knee = firstShift - InpMinPatternBars;
      knee >= InpSwingStrength + 1;
      knee--
   )
   {
      if(!IsLegKneeSwing(top, knee))
         continue;

      double kneePrice = LegKneeSwingPrice(top, knee);

      if(kneePrice <= 0)
         continue;

      if(
         MathAbs(firstPrice - kneePrice) >
         InpLegKneeSwingTolerancePoints * _Point
      )
      {
         continue;
      }

      // The opening price of the final same-direction candle within the
      // first leg replaces the old high/low-between-pivots neckline.
      double candidateNeckline = neckline;

      double legDepth = top
         ? MathMin(firstPrice, kneePrice) - candidateNeckline
         : candidateNeckline - MathMax(firstPrice, kneePrice);

      if(legDepth < InpMinRetracementPoints * _Point)
         continue;

      double breakLevel = top
         ? candidateNeckline - InpEntryBufferPoints * _Point
         : candidateNeckline + InpEntryBufferPoints * _Point;

      for(
         int candidateBreakShift = knee - 1;
         candidateBreakShift >=
         4;
         candidateBreakShift--
      )
      {
         double breakClose =
            iClose(_Symbol, PERIOD_M5, candidateBreakShift);

         bool brokeNeckline = top
            ? breakClose < breakLevel
            : breakClose > breakLevel;

         if(!brokeNeckline)
            continue;

         int candidateArrival = -1;
         int candidateTurn = -1;
         int candidateSecondArrival = -1;
         int candidateEntryTurn = -1;
         if(!FindTurningPoint(!top, candidateBreakShift - 1,
            candidateNeckline, candidateNeckline, candidateArrival,
            candidateTurn, candidateSecondArrival, candidateEntryTurn) ||
            candidateEntryTurn != 0)
         {
            continue;
         }

         kneeShift = knee;
         neckline = candidateNeckline;
         breakShift = candidateBreakShift;
         retestShift = candidateTurn;
         reversalShift = candidateEntryTurn;
         return true;
      }
   }

   return false;
}


bool FindLegKneeTop(
   int &firstShift,
   int &kneeShift,
   double &neckline,
   int &breakShift,
   int &retestShift,
   int &reversalShift
)
{
   return FindLegKneePattern(
      true,
      firstShift,
      kneeShift,
      neckline,
      breakShift,
      retestShift,
      reversalShift
   );
}


bool FindLegKneeBottom(
   int &firstShift,
   int &kneeShift,
   double &neckline,
   int &breakShift,
   int &retestShift,
   int &reversalShift
)
{
   return FindLegKneePattern(
      false,
      firstShift,
      kneeShift,
      neckline,
      breakShift,
      retestShift,
      reversalShift
   );
}


void DetectLegKneePattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle ||
      PatternFamilyDailyLimitReached(PATTERN_FAMILY_LEG_KNEE))
      return;

   if(!SpreadIsAllowed())
   {
      Print("Leg & Knee entry skipped: spread exceeds the configured limit.");
      return;
   }

   int firstShift = -1;
   int kneeShift = -1;
   int breakShift = -1;
   int retestShift = -1;
   int reversalShift = -1;
   double neckline = 0.0;

   if(
      FindLegKneeTop(
         firstShift,
         kneeShift,
         neckline,
         breakShift,
         retestShift,
         reversalShift
      )
   )
   {
      g_detectedPattern = PATTERN_LEG_KNEE_TOP;

      if(ExecuteLegKneeTopSell(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_LEG_KNEE);

         Print(
            "Leg & Knee Top SELL opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " First Turning Point turn shift=",
            retestShift,
            " Second Turning Point entry shift=",
            reversalShift
         );
      }
      return;
   }

   if(
      FindLegKneeBottom(
         firstShift,
         kneeShift,
         neckline,
         breakShift,
         retestShift,
         reversalShift
      )
   )
   {
      g_detectedPattern = PATTERN_LEG_KNEE_BOTTOM;

      if(ExecuteLegKneeBottomBuy(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_LEG_KNEE);

         Print(
            "Leg & Knee Bottom BUY opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " First Turning Point turn shift=",
            retestShift,
            " Second Turning Point entry shift=",
            reversalShift
         );
      }
   }
}

#endif
