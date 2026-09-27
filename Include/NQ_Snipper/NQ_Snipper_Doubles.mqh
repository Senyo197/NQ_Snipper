#ifndef __NQ_SNIPPER_DOUBLES__
#define __NQ_SNIPPER_DOUBLES__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"

bool IsDoubleSwing(bool top, int shift)
{
   return top ? IsSwingHigh(shift) : IsSwingLow(shift);
}


double DoublePrice(bool top, int shift)
{
   return top
      ? iHigh(_Symbol, PERIOD_M5, shift)
      : iLow(_Symbol, PERIOD_M5, shift);
}


bool IsRetestClosePair(
   int newestShift,
   double &pairCenter
)
{
   pairCenter = 0.0;

   double newestClose =
      iClose(_Symbol, PERIOD_M5, newestShift);

   double olderClose =
      iClose(_Symbol, PERIOD_M5, newestShift + 1);

   if(newestClose <= 0 || olderClose <= 0)
      return false;

   if(
      MathAbs(newestClose - olderClose) >
      InpDoubleRetestTolerancePoints * _Point
   )
   {
      return false;
   }

   pairCenter = (newestClose + olderClose) / 2.0;
   return true;
}


bool HasTwoSetRetest(
   int breakShift,
   int &retestShift
)
{
   retestShift = -1;

   if(InpDoubleRetestSetMaxBars < 2)
      return false;

   for(
      int firstSetNewest = breakShift - 2;
      firstSetNewest >= 3;
      firstSetNewest--
   )
   {
      double firstSetCenter = 0.0;

      if(!IsRetestClosePair(firstSetNewest, firstSetCenter))
         continue;

      for(
         int secondSetNewest = firstSetNewest - 2;
         secondSetNewest >= 1;
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

         if(!IsRetestClosePair(secondSetNewest, secondSetCenter))
            continue;

         if(
            MathAbs(firstSetCenter - secondSetCenter) >
            InpDoubleRetestSetMaxDistancePoints * _Point
         )
         {
            continue;
         }

         retestShift = secondSetNewest;
         return true;
      }
   }

   return false;
}


bool FindDoubleConfirmation(
   bool top,
   int secondShift,
   double neckline,
   int &breakShift,
   int &retestShift
)
{
   breakShift = -1;
   retestShift = -1;

   double breakLevel = top
      ? neckline - InpEntryBufferPoints * _Point
      : neckline + InpEntryBufferPoints * _Point;

   for(
      int shift = secondShift - 1;
      shift >= 5;
      shift--
   )
   {
      double close = iClose(_Symbol, PERIOD_M5, shift);
      bool brokeStructure = top
         ? close < breakLevel
         : close > breakLevel;

      if(!brokeStructure)
         continue;

      int candidateRetestShift = -1;

      if(
         HasTwoSetRetest(
            shift,
            candidateRetestShift
         )
      )
      {
         breakShift = shift;
         retestShift = candidateRetestShift;
         return true;
      }
   }

   return false;
}


bool FindDoublePattern(
   bool top,
   int &firstShift,
   int &secondShift,
   double &neckline,
   int &breakShift,
   int &retestShift
)
{
   firstShift = -1;
   secondShift = -1;
   neckline = 0.0;
   breakShift = -1;
   retestShift = -1;

   int bars = Bars(_Symbol, PERIOD_M5);

   if(bars < InpMaxPatternBars + InpSwingStrength + 10)
      return false;

   for(
      int second = InpSwingStrength + 1;
      second <= InpMaxPatternBars;
      second++
   )
   {
      if(!IsDoubleSwing(top, second))
         continue;

      for(
         int first = second + 1;
         first <= InpMaxPatternBars;
         first++
      )
      {
         if(!IsDoubleSwing(top, first))
            continue;

         if(first - second < InpMinPatternBars)
            continue;

         double firstPrice = DoublePrice(top, first);
         double secondPrice = DoublePrice(top, second);

         if(firstPrice <= 0 || secondPrice <= 0)
            continue;

         double lowerBound = top
            ? firstPrice - InpDoubleTolerancePoints * _Point
            : firstPrice - InpDoubleSweepAllowancePoints * _Point;

         double upperBound = top
            ? firstPrice + InpDoubleSweepAllowancePoints * _Point
            : firstPrice + InpDoubleTolerancePoints * _Point;

         if(secondPrice < lowerBound || secondPrice > upperBound)
            continue;

         double candidateNeckline = top
            ? LowestBetween(second, first)
            : HighestBetween(second, first);

         double retracement = top
            ? MathMin(firstPrice, secondPrice) - candidateNeckline
            : candidateNeckline - MathMax(firstPrice, secondPrice);

         if(retracement / _Point < InpMinRetracementPoints)
            continue;

         int candidateBreakShift = -1;
         int candidateRetestShift = -1;

         if(
            !FindDoubleConfirmation(
               top,
               second,
               candidateNeckline,
               candidateBreakShift,
               candidateRetestShift
            )
         )
         {
            continue;
         }

         firstShift = first;
         secondShift = second;
         neckline = candidateNeckline;
         breakShift = candidateBreakShift;
         retestShift = candidateRetestShift;
         return true;
      }
   }

   return false;
}


bool FindDoubleTop(
   int &firstShift,
   int &secondShift,
   double &neckline,
   int &breakShift,
   int &retestShift
)
{
   return FindDoublePattern(
      true,
      firstShift,
      secondShift,
      neckline,
      breakShift,
      retestShift
   );
}


bool FindDoubleBottom(
   int &firstShift,
   int &secondShift,
   double &neckline,
   int &breakShift,
   int &retestShift
)
{
   return FindDoublePattern(
      false,
      firstShift,
      secondShift,
      neckline,
      breakShift,
      retestShift
   );
}


void DetectDoublePattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle)
      return;

   if(!SpreadIsAllowed())
   {
      Print("Double entry skipped: spread exceeds the configured limit.");
      return;
   }

   int firstShift = -1;
   int secondShift = -1;
   int breakShift = -1;
   int retestShift = -1;
   double neckline = 0.0;

   if(
      FindDoubleTop(
         firstShift,
         secondShift,
         neckline,
         breakShift,
         retestShift
      )
   )
   {
      g_detectedPattern = PATTERN_DOUBLE_TOP;

      if(ExecuteDoubleTopSell(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Double Top SELL opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " Retest shift=",
            retestShift
         );
      }

      return;
   }

   if(
      FindDoubleBottom(
         firstShift,
         secondShift,
         neckline,
         breakShift,
         retestShift
      )
   )
   {
      g_detectedPattern = PATTERN_DOUBLE_BOTTOM;

      if(ExecuteDoubleBottomBuy(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Double Bottom BUY opened. Neckline=",
            DoubleToString(neckline, _Digits),
            " Break shift=",
            breakShift,
            " Retest shift=",
            retestShift
         );
      }
   }
}

#endif
