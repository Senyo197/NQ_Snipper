#ifndef __NQ_SNIPPER_POSITIONS__
#define __NQ_SNIPPER_POSITIONS__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"

//==================================================
// CHECK OUR OPEN POSITION
//==================================================

bool HasOurOpenPosition()
{
   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket =
         PositionGetTicket(i);

      if(ticket == 0)
         continue;

      string symbol =
         PositionGetString(POSITION_SYMBOL);

      long magic =
         PositionGetInteger(POSITION_MAGIC);

      if(symbol != _Symbol)
         continue;

      if(magic != (long)InpMagicNumber)
         continue;

      return true;
   }

   return false;
}


//==================================================
// MOVE A PROFITABLE POSITION STOP TO BREAKEVEN
//==================================================

void MoveOurStopsToBreakeven(CTrade &trade)
{
   if(InpBreakEvenTriggerPoints <= 0 || _Point <= 0)
      return;

   MqlTick tick;

   if(!SymbolInfoTick(_Symbol, tick))
      return;

   int total = PositionsTotal();

   for(int i = total - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);

      if(ticket == 0)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != (long)InpMagicNumber)
         continue;

      long type = PositionGetInteger(POSITION_TYPE);
      double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double stopLoss = PositionGetDouble(POSITION_SL);
      double takeProfit = PositionGetDouble(POSITION_TP);

      if(entryPrice <= 0)
         continue;

      double favorableMove =
         (type == POSITION_TYPE_BUY)
         ? tick.bid - entryPrice
         : entryPrice - tick.ask;

      if(favorableMove < InpBreakEvenTriggerPoints * _Point)
         continue;

      bool alreadyProtected =
         (type == POSITION_TYPE_BUY)
         ? stopLoss >= entryPrice
         : stopLoss > 0 && stopLoss <= entryPrice;

      if(alreadyProtected)
         continue;

      double breakevenPrice = NormalizeDouble(entryPrice, _Digits);

      if(!trade.PositionModify(ticket, breakevenPrice, takeProfit))
      {
         Print(
            "Breakeven move failed. Ticket=",
            ticket,
            " Retcode=",
            trade.ResultRetcode(),
            " Description=",
            trade.ResultRetcodeDescription()
         );

         continue;
      }

      Print(
         "Stop moved to breakeven. Ticket=",
         ticket,
         " Price=",
         DoubleToString(breakevenPrice, _Digits)
      );
   }
}

#endif
