#ifndef __NQ_SNIPPER_BARS_SWINGS__
#define __NQ_SNIPPER_BARS_SWINGS__

#include "NQ_Snipper_ConfigState.mqh"

//==================================================
// CHECK NEW M5 BAR
//==================================================

bool IsNewM5Bar()
{
   datetime currentBarTime =
      iTime(_Symbol, PERIOD_M5, 0);

   if(currentBarTime <= 0)
      return false;

   if(currentBarTime == g_lastBarTime)
      return false;

   g_lastBarTime = currentBarTime;

   return true;
}


//==================================================
// SWING HIGH
//==================================================

bool IsSwingHigh(int shift)
{
   if(shift < InpSwingStrength)
      return false;

   double center =
      iHigh(_Symbol, PERIOD_M5, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      double left =
         iHigh(_Symbol, PERIOD_M5, shift + i);

      double right =
         iHigh(_Symbol, PERIOD_M5, shift - i);

      if(center <= left)
         return false;

      if(center <= right)
         return false;
   }

   return true;
}


//==================================================
// SWING LOW
//==================================================

bool IsSwingLow(int shift)
{
   if(shift < InpSwingStrength)
      return false;

   double center =
      iLow(_Symbol, PERIOD_M5, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      double left =
         iLow(_Symbol, PERIOD_M5, shift + i);

      double right =
         iLow(_Symbol, PERIOD_M5, shift - i);

      if(center >= left)
         return false;

      if(center >= right)
         return false;
   }

   return true;
}


//==================================================
// LOWEST PRICE BETWEEN TWO SWINGS
//==================================================

double LowestBetween(
   int newerShift,
   int olderShift
)
{
   double lowest = DBL_MAX;

   for(
      int shift = newerShift;
      shift <= olderShift;
      shift++
   )
   {
      double low =
         iLow(_Symbol, PERIOD_M5, shift);

      if(low < lowest)
         lowest = low;
   }

   return lowest;
}


//==================================================
// HIGHEST PRICE BETWEEN TWO SWINGS
//==================================================

double HighestBetween(
   int newerShift,
   int olderShift
)
{
   double highest = -DBL_MAX;

   for(
      int shift = newerShift;
      shift <= olderShift;
      shift++
   )
   {
      double high =
         iHigh(_Symbol, PERIOD_M5, shift);

      if(high > highest)
         highest = high;
   }

   return highest;
}

#endif