#ifndef __NQ_SNIPPER_DOUBLES__
#define __NQ_SNIPPER_DOUBLES__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"
#include "NQ_Snipper_TurningPoint.mqh"

bool IsDoubleSwing(bool top, int shift)
{
   return top ? IsSwingHigh(shift) : IsSwingLow(shift);
}


bool FindFirstLegDoubleTop(
   int &firstLegShift,
   int &secondLegShift,
   double &neckline,
   int &firstRetestShift,
   int &secondRetestShift
)
{
   firstLegShift = -1;
   secondLegShift = -1;
   neckline = 0.0;
   firstRetestShift = -1;
   secondRetestShift = -1;

   double firstLegOpen = 0.0;
   double firstLegClose = 0.0;
   if(!GetFirstLegCandle(true, firstLegShift, firstLegOpen, firstLegClose))
      return false;

   int necklineShift = -1;
   if(!GetFirstLegNeckline(true, neckline, necklineShift))
      return false;

   double firstLegHigh = iHigh(_Symbol, PERIOD_M5, firstLegShift);
   if(firstLegHigh <= 0)
      return false;

   double lowerCloseBound = firstLegClose -
      InpDoubleTolerancePoints * _Point;
   double upperCloseBound = firstLegClose +
      InpDoubleSweepAllowancePoints * _Point;

   // Smaller shifts are newer candles. The second leg must be at least the
   // configured bar distance after the final first-leg candle.
   for(int second = firstLegShift - InpMinPatternBars;
      second >= InpSwingStrength + 1; second--)
   {
      if(!IsDoubleSwing(true, second))
         continue;

      double secondLegClose = iClose(_Symbol, PERIOD_M5, second);
      double secondLegHigh = iHigh(_Symbol, PERIOD_M5, second);
      if(secondLegClose <= 0 || secondLegHigh <= 0 ||
         secondLegClose < lowerCloseBound || secondLegClose > upperCloseBound)
         continue;

      double retracement = MathMin(firstLegHigh, secondLegHigh) - neckline;
      if(retracement < InpMinRetracementPoints * _Point)
         continue;

      int candidateArrival = -1;
      int candidateTurn = -1;
      int candidateSecondArrival = -1;
      int candidateEntryTurn = -1;
      if(!FindTurningPoint(false, second - 1, firstLegClose,
         firstLegClose, candidateArrival, candidateTurn,
         candidateSecondArrival, candidateEntryTurn) || candidateEntryTurn != 0)
         continue;

      secondLegShift = second;
      firstRetestShift = candidateTurn;
      secondRetestShift = candidateEntryTurn;
      return true;
   }

   return false;
}


bool FindFirstLegDoubleBottom(
   int &firstLegShift,
   int &secondLegShift,
   double &neckline,
   int &firstRetestShift,
   int &secondRetestShift
)
{
   firstLegShift = -1;
   secondLegShift = -1;
   neckline = 0.0;
   firstRetestShift = -1;
   secondRetestShift = -1;

   double firstLegOpen = 0.0;
   double firstLegClose = 0.0;
   if(!GetFirstLegCandle(false, firstLegShift, firstLegOpen, firstLegClose))
      return false;

   int necklineShift = -1;
   if(!GetFirstLegNeckline(false, neckline, necklineShift))
      return false;

   double firstLegLow = iLow(_Symbol, PERIOD_M5, firstLegShift);
   if(firstLegLow <= 0)
      return false;

   // Inverted from the Double Top: a deeper sweep uses the sweep allowance,
   // while a higher second-leg close uses the ordinary tolerance.
   double lowerCloseBound = firstLegClose -
      InpDoubleSweepAllowancePoints * _Point;
   double upperCloseBound = firstLegClose +
      InpDoubleTolerancePoints * _Point;

   for(int second = firstLegShift - InpMinPatternBars;
      second >= InpSwingStrength + 1; second--)
   {
      if(!IsDoubleSwing(false, second))
         continue;

      double secondLegClose = iClose(_Symbol, PERIOD_M5, second);
      double secondLegLow = iLow(_Symbol, PERIOD_M5, second);
      if(secondLegClose <= 0 || secondLegLow <= 0 ||
         secondLegClose < lowerCloseBound || secondLegClose > upperCloseBound)
         continue;

      double retracement = neckline -
         MathMax(firstLegLow, secondLegLow);
      if(retracement < InpMinRetracementPoints * _Point)
         continue;

      int candidateArrival = -1;
      int candidateTurn = -1;
      int candidateSecondArrival = -1;
      int candidateEntryTurn = -1;
      if(!FindTurningPoint(true, second - 1, firstLegClose,
         firstLegClose, candidateArrival, candidateTurn,
         candidateSecondArrival, candidateEntryTurn) || candidateEntryTurn != 0)
         continue;

      secondLegShift = second;
      firstRetestShift = candidateTurn;
      secondRetestShift = candidateEntryTurn;
      return true;
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
   return FindFirstLegDoubleTop(
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
   return FindFirstLegDoubleBottom(
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
            "Double Top SELL opened. First-leg neckline=",
            DoubleToString(neckline, _Digits),
            " First Turning Point turn shift=",
            breakShift,
            " Second Turning Point entry shift=",
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
            "Double Bottom BUY opened. First-leg neckline=",
            DoubleToString(neckline, _Digits),
            " First Turning Point turn shift=",
            breakShift,
            " Second Turning Point entry shift=",
            retestShift
         );
      }
   }
}

#endif
