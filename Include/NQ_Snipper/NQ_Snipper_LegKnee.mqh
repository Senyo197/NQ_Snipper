#ifndef __NQ_SNIPPER_LEG_KNEE__
#define __NQ_SNIPPER_LEG_KNEE__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"


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


bool IsLegKneeRetestSet(
   int newestShift,
   double neckline,
   double &setCenter
)
{
   setCenter = 0.0;

   double necklineTolerance =
      InpLegKneeRetestTolerancePoints * _Point;

   double highestClose = -DBL_MAX;
   double lowestClose = DBL_MAX;
   double closeTotal = 0.0;

   for(
      int shift = newestShift;
      shift < newestShift + InpLegKneeRetestCandles;
      shift++
   )
   {
      double close = iClose(_Symbol, PERIOD_M5, shift);

      if(
         close <= 0 ||
         MathAbs(close - neckline) > necklineTolerance
      )
      {
         return false;
      }

      if(close > highestClose)
         highestClose = close;

      if(close < lowestClose)
         lowestClose = close;

      closeTotal += close;
   }

   if(
      highestClose - lowestClose >
      InpDoubleRetestTolerancePoints * _Point
   )
   {
      return false;
   }

   setCenter = closeTotal / InpLegKneeRetestCandles;
   return true;
}


bool FindLegKneeNecklineRetest(
   bool top,
   int breakShift,
   double neckline,
   int &retestShift,
   int &reversalShift
)
{
   retestShift = -1;
   reversalShift = -1;

   if(InpLegKneeRetestCandles < 2)
      return false;

   if(
      InpLegKneeRetestMaxBars <
      InpLegKneeRetestCandles * 2 + 1
   )
   {
      return false;
   }

   double reversalLevel = top
      ? neckline - InpLegKneeReversalBufferPoints * _Point
      : neckline + InpLegKneeReversalBufferPoints * _Point;

   int oldestAllowedNewestShift =
      breakShift - InpLegKneeRetestMaxBars;

   if(oldestAllowedNewestShift < 2)
      oldestAllowedNewestShift = 2;

   for(
      int firstSetNewest = breakShift - InpLegKneeRetestCandles;
      firstSetNewest >=
      oldestAllowedNewestShift + InpLegKneeRetestCandles;
      firstSetNewest--
   )
   {
      double firstSetCenter = 0.0;

      if(
         !IsLegKneeRetestSet(
            firstSetNewest,
            neckline,
            firstSetCenter
         )
      )
      {
         continue;
      }

      for(
         int secondSetNewest =
         firstSetNewest - InpLegKneeRetestCandles;

         secondSetNewest >= oldestAllowedNewestShift;
         secondSetNewest--
      )
      {
         if(
            firstSetNewest - secondSetNewest >
            InpDoubleRetestSetMaxBars
         )
         {
            break;
         }

         double secondSetCenter = 0.0;

         if(
            !IsLegKneeRetestSet(
               secondSetNewest,
               neckline,
               secondSetCenter
            )
         )
         {
            continue;
         }

         if(
            MathAbs(firstSetCenter - secondSetCenter) >
            InpDoubleRetestSetMaxDistancePoints * _Point
         )
         {
            continue;
         }

         int candidateReversalShift = secondSetNewest - 1;
         double reversalClose =
            iClose(
               _Symbol,
               PERIOD_M5,
               candidateReversalShift
            );

         if(reversalClose <= 0)
            continue;

         bool rejected = top
            ? reversalClose < reversalLevel
            : reversalClose > reversalLevel;

         if(!rejected)
            continue;

         retestShift = secondSetNewest;
         reversalShift = candidateReversalShift;
         return true;
      }
   }

   return false;
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

   int bars = Bars(_Symbol, PERIOD_M5);

   if(bars < InpMaxPatternBars + InpSwingStrength + 10)
      return false;

   for(
      int first = InpMaxPatternBars;
      first >= InpSwingStrength + 1;
      first--
   )
   {
      if(!IsLegKneeSwing(top, first))
         continue;

      for(
         int knee = first - 1;
         knee >= InpSwingStrength + 1;
         knee--
      )
      {
         if(first - knee < InpMinPatternBars)
            continue;

         if(!IsLegKneeSwing(top, knee))
            continue;

         double firstPrice = LegKneeSwingPrice(top, first);
         double kneePrice = LegKneeSwingPrice(top, knee);

         if(firstPrice <= 0 || kneePrice <= 0)
            continue;

         if(
            MathAbs(firstPrice - kneePrice) >
            InpLegKneeSwingTolerancePoints * _Point
         )
         {
            continue;
         }

         double candidateNeckline = top
            ? LowestBetween(knee, first)
            : HighestBetween(knee, first);

         if(candidateNeckline <= 0)
            continue;

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
            InpLegKneeRetestCandles * 2 + 2;
            candidateBreakShift--
         )
         {
            double breakClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  candidateBreakShift
               );

            bool brokeNeckline = top
               ? breakClose < breakLevel
               : breakClose > breakLevel;

            if(!brokeNeckline)
               continue;

            int candidateRetestShift = -1;
            int candidateReversalShift = -1;

            if(
               !FindLegKneeNecklineRetest(
                  top,
                  candidateBreakShift,
                  candidateNeckline,
                  candidateRetestShift,
                  candidateReversalShift
               )
            )
            {
               continue;
            }

            firstShift = first;
            kneeShift = knee;
            neckline = candidateNeckline;
            breakShift = candidateBreakShift;
            retestShift = candidateRetestShift;
            reversalShift = candidateReversalShift;
            return true;
         }
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
   if(!g_patternEngineActive || g_tradePlacedForCycle)
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
         g_tradePlacedForCycle = true;

         Print(
            "Leg & Knee Top SELL opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " Retest shift=",
            retestShift,
            " Reversal shift=",
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
         g_tradePlacedForCycle = true;

         Print(
            "Leg & Knee Bottom BUY opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " Retest shift=",
            retestShift,
            " Reversal shift=",
            reversalShift
         );
      }
   }
}

#endif
