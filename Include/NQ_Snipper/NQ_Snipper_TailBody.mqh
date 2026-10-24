#ifndef __NQ_SNIPPER_TAIL_BODY__
#define __NQ_SNIPPER_TAIL_BODY__

#include <Trade/Trade.mqh>
#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_TailBodyLegs.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"
#include "NQ_Snipper_TurningPoint.mqh"

bool FindTailBodyPullback(bool firstLegBullish,int firstShift,
   int &firstPullbackShift,int &finalPullbackShift)
{
   firstPullbackShift=-1;
   finalPullbackShift=-1;
   if(firstShift<2) return false;
   for(int shift=firstShift;shift>=1;shift--)
   {
      double barOpen=iOpen(_Symbol,PERIOD_M5,shift);
      double barClose=iClose(_Symbol,PERIOD_M5,shift);
      if(barOpen<=0 || barClose<=0) return false;
      bool oppositeCandle=firstLegBullish ? barClose<barOpen : barClose>barOpen;
      if(!oppositeCandle) continue;
      if(firstPullbackShift<0)
      {
         firstPullbackShift=shift;
         continue;
      }
      finalPullbackShift=shift;
      return true;
   }
   return false;
}

// From the first qualifying arrival until the first valid turn, every
// intervening completed candle must close within the body space. The turn
// candle itself is exempt, provided its direction and opening gap qualify.
bool TailBodyFirstTurnPathAllowed(bool firstLegBullish,int firstShift,
   double bodyLow,double bodyHigh)
{
   bool trackingArrival=false;
   bool previousIsArrival=false;
   double previousClose=0.0;
   double gapTolerance=InpTurningPointGapTolerancePoints*_Point;
   for(int shift=firstShift;shift>=1;shift--)
   {
      double barOpen=iOpen(_Symbol,PERIOD_M5,shift);
      double barClose=iClose(_Symbol,PERIOD_M5,shift);
      if(barOpen<=0 || barClose<=0) return false;

      bool inside=barClose>=bodyLow && barClose<=bodyHigh;
      bool isArrival=inside &&
         !IsNQDoji(barOpen,barClose,_Point,InpTailBodyDojiMaxBodyPoints) && (firstLegBullish
         ? barClose>barOpen : barClose<barOpen);
      if(!trackingArrival)
      {
         if(isArrival)
         {
            trackingArrival=true;
            previousIsArrival=true;
            previousClose=barClose;
         }
         continue;
      }

      bool turnsAway=firstLegBullish ? barClose<barOpen : barClose>barOpen;
      if(previousIsArrival && turnsAway &&
         MathAbs(barOpen-previousClose)<=gapTolerance)
         return true;
      if(!inside)
         return false;

      previousIsArrival=isArrival;
      previousClose=barClose;
   }
   return true;
}


// Include every completed candle's wick between the anchor and the end of
// the pullback. A bullish first leg pulls down; a bearish first leg pulls up.
bool TailBodyPullbackWithinMax(bool downward, double anchor, int firstShift,
   int lastShift, double maxPoints)
{
   if(_Point<=0 || anchor<=0 || firstShift<lastShift || lastShift<1)
      return false;
   double farthest=anchor;
   for(int shift=firstShift;shift>=lastShift;shift--)
   {
      double wick=downward ? iLow(_Symbol,PERIOD_M5,shift)
                           : iHigh(_Symbol,PERIOD_M5,shift);
      if(wick<=0) return false;
      farthest=downward ? MathMin(farthest,wick) : MathMax(farthest,wick);
   }
   double distancePoints=(downward ? anchor-farthest : farthest-anchor)/_Point;
   return distancePoints<=MathMax(0.0,maxPoints)+0.000001;
}

// The body candle completes at the end of its M5 period. The entry candle
// begins at its bar-open time, so this measures the elapsed structural time
// without using an intrabar tick timestamp.
bool TailBodyBodyToEntryTimeIsAllowed(int bodyCandleShift,int entryCandleShift)
{
   if(!InpEnableTailBodyBodyToEntryTimeLimit)
      return true;
   if(InpTailBodyBodyToEntryMaxMinutes < 0)
      return false;

   datetime bodyOpenTime=iTime(_Symbol,PERIOD_M5,bodyCandleShift);
   datetime entryOpenTime=iTime(_Symbol,PERIOD_M5,entryCandleShift);
   if(bodyOpenTime<=0 || entryOpenTime<=0)
      return false;

   datetime bodyCloseTime=bodyOpenTime+PeriodSeconds(PERIOD_M5);
   if(entryOpenTime<bodyCloseTime)
      return false;

   long elapsedSeconds=(long)(entryOpenTime-bodyCloseTime);
   long maximumSeconds=(long)InpTailBodyBodyToEntryMaxMinutes*60;
   return elapsedSeconds<=maximumSeconds;
}


bool FindFirstLegTailAndBodyPattern(bool bearish,int &firstLegShift,
   int &tailShift,int &entryTurnShift)
{
   firstLegShift=-1; tailShift=-1; entryTurnShift=-1;
   bool firstLegBullish=bearish;
   datetime firstLegStartTime=0;
   if(!GetTailBodyLeg(firstLegBullish,firstLegShift,firstLegStartTime))
      return false;

   int bodyCandleShift=-1;
   int tailLegEndpointShift=-1;
   double bodyOpen=0.0,bodyClose=0.0;
   if(!GetBodySpaceForFirstLeg(firstLegBullish,firstLegShift,firstLegStartTime,bodyCandleShift,
      tailLegEndpointShift,bodyOpen,bodyClose))
      return false;

   double bodyHigh=MathMax(bodyOpen,bodyClose);
   double bodyLow=MathMin(bodyOpen,bodyClose);

   int firstPullbackShift=-1;
   int pullbackShift=-1;
   if(!FindTailBodyPullback(firstLegBullish,tailLegEndpointShift-1,
      firstPullbackShift,pullbackShift))
      return false;

   double firstLegExtreme=firstLegBullish
      ? iHigh(_Symbol,PERIOD_M5,firstLegShift)
      : iLow(_Symbol,PERIOD_M5,firstLegShift);
   // The broad extreme can occur in an opposite-colour candle after the
   // directional pair. Do not count earlier wicks before that extreme.
   int firstMeasuredShift=(int)MathMin(tailLegEndpointShift-1,firstLegShift);
   if(!TailBodyPullbackWithinMax(firstLegBullish,firstLegExtreme,
      firstMeasuredShift,pullbackShift,InpTailBodyFirstPullbackMaxPoints))
      return false;

   // The arrival must follow the second pullback candle, regardless of
   // whether the optional spacing rule is enabled. Smaller shifts are newer.
   int firstArrivalSearchShift=pullbackShift-1;
   if(InpEnableTailBodyPullbackSpacing)
      firstArrivalSearchShift=(int)MathMin(firstArrivalSearchShift,
         firstPullbackShift-1-InpTailBodyPullbackSpacingCandles);

   if(InpTailBodyInvalidateOnInterveningCloseOutsideBody &&
      !TailBodyFirstTurnPathAllowed(firstLegBullish,firstArrivalSearchShift,
         bodyLow,bodyHigh))
   {
      ClearFirstTurnMarker(firstLegBullish ? "_TB_BULL" : "_TB_BEAR");
      return false;
   }

   int arrivalShift=-1;
   int turnShift=-1;
   int secondArrivalShift=-1;
   if(!FindTurningPoint(!bearish,firstArrivalSearchShift,bodyLow,bodyHigh,
      arrivalShift,turnShift,secondArrivalShift,entryTurnShift,
      firstLegBullish ? "_TB_BULL" : "_TB_BEAR",
      MathMax(0.0, InpTailBodyArrivalCloseTolerancePoints),
      (InpEnableBaseFilter && InpEnableTailBodyBaseFilter) ? firstLegShift : -1,
      InpTailBodyDojiMaxBodyPoints))
      return false;

   // The second-pullback distance begins at the actual first Turning Point:
   // the turn candle's open.  Do not use that candle's wick, because it is
   // not part of the arrival-close / turn-open gap that defines the turn.
   double firstTurnPrice=iOpen(_Symbol,PERIOD_M5,turnShift);
   if(firstTurnPrice<=0.0)
      return false;
   if(!TailBodyPullbackWithinMax(firstLegBullish,firstTurnPrice,
      turnShift,secondArrivalShift,InpTailBodySecondPullbackMaxPoints))
      return false;

   // Trade at the open of the second Turning Point's turn candle.
   if(entryTurnShift!=0)
      return false;
   if(!TailBodyBodyToEntryTimeIsAllowed(bodyCandleShift,entryTurnShift))
      return false;

   tailShift=tailLegEndpointShift;
   return true;
}


void DetectTailAndBodyPattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle) return;
   if(!SpreadIsAllowed())
   {
      Print("Tail & Body entry skipped: spread exceeds the configured limit.");
      return;
   }
   int firstLegShift=-1,tailShift=-1,entryTurnShift=-1;
   if(FindFirstLegTailAndBodyPattern(true,firstLegShift,tailShift,entryTurnShift))
   {
      g_detectedPattern=PATTERN_TAIL_BODY_TOP;
      if(ExecuteTailBodyTopSell(trade))
      {
         g_tradePlacedForCycle=true;
         Print("Tail & Body Top SELL opened. First leg shift=",firstLegShift,
            " Tail shift=",tailShift," Second Turning Point entry shift=",entryTurnShift);
      }
      return;
   }
   if(FindFirstLegTailAndBodyPattern(false,firstLegShift,tailShift,entryTurnShift))
   {
      g_detectedPattern=PATTERN_TAIL_BODY_BOTTOM;
      if(ExecuteTailBodyBottomBuy(trade))
      {
         g_tradePlacedForCycle=true;
         Print("Tail & Body Bottom BUY opened. First leg shift=",firstLegShift,
            " Tail shift=",tailShift," Second Turning Point entry shift=",entryTurnShift);
      }
   }
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

   // First neckline Turning Point forms the second neckline from the arrival
   // candle's open. Its direction follows the first leg's direction.
   int firstArrivalShift=-1;
   int firstTurnShift=-1;
   if(!FindTailBodyVTurningPoint(firstLegBullish,keySwingShift-1,firstNeckline,
      firstNeckline,firstArrivalShift,firstTurnShift,firstRetestShift))
      return false;

   secondNeckline=iOpen(_Symbol,PERIOD_M5,firstArrivalShift);
   if(secondNeckline<=0)
      return false;

   // Second neckline Turning Point uses the final trade direction.
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
   if(!g_patternEngineActive || g_tradePlacedForCycle) return;
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
      if(ExecuteTailBodyTopSell(trade))
      {
         g_tradePlacedForCycle=true;
         Print("Tail & Body V Top SELL opened. First neckline=",DoubleToString(firstNeckline,_Digits)," Second neckline=",DoubleToString(secondNeckline,_Digits)," First Turning Point arrival shift=",tailShift," First Turning Point confirmation shift=",firstRetestShift," Second Turning Point confirmation shift=",secondRetestShift);
      }
      return;
   }
   if(FindFirstLegTailAndBodyVPattern(false,keySwingShift,tailShift,firstNeckline,firstRetestShift,secondNeckline,secondRetestShift))
   {
      g_detectedPattern=PATTERN_TAIL_BODY_BOTTOM;
      if(ExecuteTailBodyBottomBuy(trade))
      {
         g_tradePlacedForCycle=true;
         Print("Tail & Body V Bottom BUY opened. First neckline=",DoubleToString(firstNeckline,_Digits)," Second neckline=",DoubleToString(secondNeckline,_Digits)," First Turning Point arrival shift=",tailShift," First Turning Point confirmation shift=",firstRetestShift," Second Turning Point confirmation shift=",secondRetestShift);
      }
   }
}

#endif
