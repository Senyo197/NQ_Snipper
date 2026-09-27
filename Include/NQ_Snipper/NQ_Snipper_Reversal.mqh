#ifndef __NQ_SNIPPER_REVERSAL__
#define __NQ_SNIPPER_REVERSAL__

#include "NQ_Snipper_ConfigState.mqh"

bool IsMajorReversalExtreme(
   bool top,
   double reversalPrice
)
{
   if(InpMaxPatternBars < 2 || reversalPrice <= 0)
      return false;

   if(Bars(_Symbol, PERIOD_M5) < InpMaxPatternBars + 2)
      return false;

   int extremeShift = top
      ? iHighest(
           _Symbol,
           PERIOD_M5,
           MODE_HIGH,
           InpMaxPatternBars,
           1
        )
      : iLowest(
           _Symbol,
           PERIOD_M5,
           MODE_LOW,
           InpMaxPatternBars,
           1
        );

   if(extremeShift < 0)
      return false;

   double contextExtreme = top
      ? iHigh(_Symbol, PERIOD_M5, extremeShift)
      : iLow(_Symbol, PERIOD_M5, extremeShift);

   if(contextExtreme <= 0)
      return false;

   double roundingTolerance = _Point * 0.5;

   return top
      ? reversalPrice >= contextExtreme - roundingTolerance
      : reversalPrice <= contextExtreme + roundingTolerance;
}

#endif
