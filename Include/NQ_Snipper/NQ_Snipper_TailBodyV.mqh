#ifndef __NQ_SNIPPER_TAIL_BODY_V__
#define __NQ_SNIPPER_TAIL_BODY_V__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"

// TailBody V retains its original three-candle neckline interaction.
bool FindTailBodyVTurningPoint(
   bool bullish,
   int firstArrivalShift,
   double referenceLow,
   double referenceHigh,
   int &arrivalShift,
   int &turnShift,
   int &confirmationShift
)
{
   arrivalShift = -1;
   turnShift = -1;
   confirmationShift = -1;
   double gapTolerance = InpTurningPointGapTolerancePoints * _Point;

   for(int arrival = firstArrivalShift; arrival >= 3; arrival--)
   {
      double arrivalOpen = iOpen(_Symbol, PERIOD_M5, arrival);
      double arrivalClose = iClose(_Symbol, PERIOD_M5, arrival);
      if(arrivalOpen <= 0 || arrivalClose <= 0 ||
         arrivalClose < referenceLow || arrivalClose > referenceHigh)
         continue;

      bool arrivalMatches = bullish
         ? arrivalClose < arrivalOpen
         : arrivalClose > arrivalOpen;
      if(!arrivalMatches)
         continue;

      int turn = arrival - 1;
      double turnOpen = iOpen(_Symbol, PERIOD_M5, turn);
      double turnClose = iClose(_Symbol, PERIOD_M5, turn);
      if(turnOpen <= 0 || turnClose <= 0 ||
         MathAbs(turnOpen - arrivalClose) > gapTolerance)
         continue;

      bool turnsAway = bullish
         ? turnClose > turnOpen
         : turnClose < turnOpen;
      if(!turnsAway)
         continue;

      for(int confirmation = turn - 1; confirmation >= 1; confirmation--)
      {
         double confirmationOpen = iOpen(_Symbol, PERIOD_M5, confirmation);
         double confirmationClose = iClose(_Symbol, PERIOD_M5, confirmation);
         if(confirmationOpen <= 0 || confirmationClose <= 0)
            continue;

         bool confirms = bullish
            ? confirmationClose > confirmationOpen
            : confirmationClose < confirmationOpen;
         if(!confirms)
            continue;

         arrivalShift = arrival;
         turnShift = turn;
         confirmationShift = confirmation;
         return true;
      }
   }

   return false;
}

bool FindFirstLegTailAndBodyVPattern(bool bearish,int &keySwingShift,
   int &tailShift,double &firstNeckline,int &firstRetestShift,
   double &secondNeckline,int &secondRetestShift)
{
   keySwingShift=-1; tailShift=-1; firstNeckline=0.0; firstRetestShift=-1;
   secondNeckline=0.0; secondRetestShift=-1;
   bool firstLegBullish=bearish;
   double firstLegOpen=0.0,firstLegClose=0.0;
   if(!GetFirstLegCandle(firstLegBullish,keySwingShift,firstLegOpen,firstLegClose)) return false;
   int firstNecklineShift=-1;
   if(!GetFirstLegNeckline(firstLegBullish,firstNeckline,firstNecklineShift)) return false;

   int firstArrivalShift=-1;
   int firstTurnShift=-1;
   if(!FindTailBodyVTurningPoint(firstLegBullish,keySwingShift-1,firstNeckline,
      firstNeckline,firstArrivalShift,firstTurnShift,firstRetestShift))
      return false;

   secondNeckline=iOpen(_Symbol,PERIOD_M5,firstArrivalShift);
   if(secondNeckline<=0)
      return false;

   int secondArrivalShift=-1;
   int secondTurnShift=-1;
   if(!FindTailBodyVTurningPoint(!bearish,firstRetestShift-1,secondNeckline,
      secondNeckline,secondArrivalShift,secondTurnShift,secondRetestShift))
      return false;

   if(secondRetestShift!=1)
      return false;

   tailShift=firstArrivalShift;
   return true;
}

void DetectTailAndBodyVPattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle ||
      PatternFamilyDailyLimitReached(PATTERN_FAMILY_TAIL_BODY_V)) return;
   if(!SpreadIsAllowed())
   {
      Print("Tail & Body V entry skipped: spread exceeds the configured limit.");
      return;
   }
   int keySwingShift=-1,tailShift=-1,firstRetestShift=-1,secondRetestShift=-1;
   double firstNeckline=0.0,secondNeckline=0.0;
   if(FindFirstLegTailAndBodyVPattern(true,keySwingShift,tailShift,firstNeckline,firstRetestShift,secondNeckline,secondRetestShift))
   {
      g_detectedPattern=PATTERN_TAIL_BODY_TOP;
      if(ExecuteTailBodyTopSell(trade,PATTERN_FAMILY_TAIL_BODY_V))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_TAIL_BODY_V);
         Print("Tail & Body V Top SELL opened. First neckline=",DoubleToString(firstNeckline,_Digits)," Second neckline=",DoubleToString(secondNeckline,_Digits)," First Turning Point arrival shift=",tailShift," First Turning Point confirmation shift=",firstRetestShift," Second Turning Point confirmation shift=",secondRetestShift);
      }
      return;
   }
   if(FindFirstLegTailAndBodyVPattern(false,keySwingShift,tailShift,firstNeckline,firstRetestShift,secondNeckline,secondRetestShift))
   {
      g_detectedPattern=PATTERN_TAIL_BODY_BOTTOM;
      if(ExecuteTailBodyBottomBuy(trade,PATTERN_FAMILY_TAIL_BODY_V))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_TAIL_BODY_V);
         Print("Tail & Body V Bottom BUY opened. First neckline=",DoubleToString(firstNeckline,_Digits)," Second neckline=",DoubleToString(secondNeckline,_Digits)," First Turning Point arrival shift=",tailShift," First Turning Point confirmation shift=",firstRetestShift," Second Turning Point confirmation shift=",secondRetestShift);
      }
   }
}

#endif
