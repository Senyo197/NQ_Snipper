#ifndef __NQ_SNIPPER_TAIL_BODY__
#define __NQ_SNIPPER_TAIL_BODY__

#include <Trade/Trade.mqh>
#include "..\\NQ_Snipper_ConfigState.mqh"
#include "..\\NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_TailBodyLegs.mqh"
#include "..\\NQ_Snipper_Orders.mqh"
#include "..\\NQ_Snipper_Spread.mqh"
#include "..\\NQ_Snipper_TurningPoint.mqh"

// Rebuild the first pullback from oldest to newest.  Until a valid first turn
// appears, every deeper configured pullback price extends the pullback and
// invalidates any earlier provisional arrival/turn. Once the first turn is valid, later movement is
// deliberately left to the existing second-pullback logic.
bool UpdateTailBodyFirstPullback(bool firstLegBullish,int tailEndpointShift,
   int firstPullbackShift,int pullbackShift,double bodyLow,double bodyHigh,
   int &updatedPullbackShift,int &firstArrivalSearchShift)
{
   updatedPullbackShift=pullbackShift;
   firstArrivalSearchShift=pullbackShift-1;
   if(!InpEnableTailBodyFirstPullbackUpdater)
      return true;
   if(_Point<=0.0 || tailEndpointShift<2 || firstPullbackShift<1 ||
      pullbackShift<1 || firstPullbackShift<pullbackShift)
      return false;

   double extreme=firstLegBullish ? DBL_MAX : -DBL_MAX;
   int extremeShift=-1;
   // Seed the moving pullback with the original two qualifying pullback candles.
   for(int shift=tailEndpointShift-1;shift>=pullbackShift;shift--)
   {
      double barOpen=iOpen(_Symbol,PERIOD_M5,shift);
      double barClose=iClose(_Symbol,PERIOD_M5,shift);
      double pullbackPrice=InpTailBodyFirstPullbackUpdaterUseWicks
         ? (firstLegBullish ? iLow(_Symbol,PERIOD_M5,shift)
                            : iHigh(_Symbol,PERIOD_M5,shift))
         : (firstLegBullish ? MathMin(barOpen,barClose)
                            : MathMax(barOpen,barClose));
      if(barOpen<=0.0 || barClose<=0.0 || pullbackPrice<=0.0)
         return false;
      bool extends=firstLegBullish ? pullbackPrice<extreme : pullbackPrice>extreme;
      if(extends)
      {
         extreme=pullbackPrice;
         extremeShift=shift;
      }
   }
   if(extremeShift<1)
      return false;

   double updateTolerance=MathMax(0.0,
      InpTailBodyFirstPullbackUpdateTolerancePoints)*_Point;
   int stableFirstTurnShift=-1;
   for(int turn= pullbackShift-1;turn>=1;turn--)
   {
      double barOpen=iOpen(_Symbol,PERIOD_M5,turn);
      double barClose=iClose(_Symbol,PERIOD_M5,turn);
      double pullbackPrice=InpTailBodyFirstPullbackUpdaterUseWicks
         ? (firstLegBullish ? iLow(_Symbol,PERIOD_M5,turn)
                            : iHigh(_Symbol,PERIOD_M5,turn))
         : (firstLegBullish ? MathMin(barOpen,barClose)
                            : MathMax(barOpen,barClose));
      if(barOpen<=0.0 || barClose<=0.0 || pullbackPrice<=0.0)
         return false;
      bool extends=firstLegBullish ? pullbackPrice<extreme-updateTolerance
                                   : pullbackPrice>extreme+updateTolerance;
      if(extends)
      {
         extreme=pullbackPrice;
         extremeShift=turn;
         continue;
      }

      int arrival=turn+1;
      if(arrival>=extremeShift)
         continue;
      double arrivalOpen=iOpen(_Symbol,PERIOD_M5,arrival);
      double arrivalClose=iClose(_Symbol,PERIOD_M5,arrival);
      double turnOpen=iOpen(_Symbol,PERIOD_M5,turn);
      double turnClose=iClose(_Symbol,PERIOD_M5,turn);
      if(arrivalOpen<=0.0 || arrivalClose<=0.0 || turnOpen<=0.0 || turnClose<=0.0)
         return false;
      bool inside=arrivalClose>=bodyLow && arrivalClose<=bodyHigh;
      bool isDoji=IsNQDoji(arrivalOpen,arrivalClose,_Point,InpTailBodyDojiMaxBodyPoints);
      bool arrivalMatches=firstLegBullish ? arrivalClose>arrivalOpen
                                          : arrivalClose<arrivalOpen;
      bool turnsAway=firstLegBullish ? turnClose<turnOpen : turnClose>turnOpen;
      double gapTolerance=InpTurningPointGapTolerancePoints*_Point;
      if(inside && !isDoji && arrivalMatches && turnsAway &&
         MathAbs(turnOpen-arrivalClose)<=gapTolerance)
      {
         stableFirstTurnShift=turn;
         break;
      }
   }

   updatedPullbackShift=extremeShift;
   firstArrivalSearchShift=extremeShift-1;
   if(stableFirstTurnShift<0)
      ClearFirstTurnMarker(firstLegBullish ? "_TB_BULL" : "_TB_BEAR");
   return firstArrivalSearchShift>=2;
}

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
   int updatedPullbackShift=pullbackShift;
   int firstArrivalSearchShift=pullbackShift-1;
   if(!UpdateTailBodyFirstPullback(firstLegBullish,tailLegEndpointShift,
      firstPullbackShift,pullbackShift,bodyLow,bodyHigh,updatedPullbackShift,
      firstArrivalSearchShift))
      return false;
   // The broad extreme can occur in an opposite-colour candle after the
   // directional pair. Do not count earlier wicks before that extreme.
   int firstMeasuredShift=(int)MathMin(tailLegEndpointShift-1,firstLegShift);
   if(!TailBodyPullbackWithinMax(firstLegBullish,firstLegExtreme,
      firstMeasuredShift,updatedPullbackShift,InpTailBodyFirstPullbackMaxPoints))
      return false;

   // The arrival must follow both the moving pullback extreme and the second
   // initial pullback candle. Smaller shifts are newer.
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
      -1,
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
   if(!g_patternEngineActive || g_tradePlacedForCycle ||
      PatternFamilyDailyLimitReached(PATTERN_FAMILY_TAIL_BODY)) return;
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
         RegisterSuccessfulEntry(PATTERN_FAMILY_TAIL_BODY);
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
         RegisterSuccessfulEntry(PATTERN_FAMILY_TAIL_BODY);
         Print("Tail & Body Bottom BUY opened. First leg shift=",firstLegShift,
            " Tail shift=",tailShift," Second Turning Point entry shift=",entryTurnShift);
      }
   }
}


#endif
