#ifndef __NQ_SNIPPER_SPREAD__
#define __NQ_SNIPPER_SPREAD__

#include "NQ_Snipper_ConfigState.mqh"

//==================================================
// SPREAD FILTER
//==================================================

bool SpreadIsAllowed()
{
   if(!InpEnableSpreadFilter)
      return true;

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print(
         "Spread check failed: "
         "unable to obtain symbol tick."
      );

      return false;
   }

   if(_Point <= 0)
      return false;

   double spreadPoints =
      (tick.ask - tick.bid) / _Point;

   return spreadPoints <= InpMaxSpreadPoints;
}

#endif
