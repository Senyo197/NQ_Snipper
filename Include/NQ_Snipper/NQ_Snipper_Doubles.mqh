#ifndef __NQ_SNIPPER_DOUBLES__
#define __NQ_SNIPPER_DOUBLES__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"
#include "NQ_Snipper_Base.mqh"
#include "NQ_Snipper_TurningPoint.mqh"

void ClearDoubleBaseMarkers()
{
   ObjectDelete(0,"NQ_DOUBLE_FIRST_BASE");
   ObjectDelete(0,"NQ_DOUBLE_FIRST_BASE_LABEL");
   ObjectDelete(0,"NQ_DOUBLE_SECOND_BASE");
   ObjectDelete(0,"NQ_DOUBLE_SECOND_BASE_LABEL");
   // Remove markers produced by earlier builds after recompilation.
   ObjectDelete(0,"NQ_DOUBLE_PHASE_1");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_1_LABEL");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_2");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_2_LABEL");
}

void ClearDoubleTwoTurnMarkers()
{
   ClearFirstTurnMarker("_DOUBLE_TOP");
   ClearFirstTurnMarker("_DOUBLE_BOTTOM");
}

void MarkDoubleBase(int baseNumber,const NQBaseZone &base,bool top)
{
   if(!InpShowBaseMarker || base.firstCandleTime<=0 ||
      base.lastCandleTime<base.firstCandleTime || base.anchorOpen<=0.0 ||
      base.anchorClose<=0.0)
      return;

   string baseName=baseNumber==1 ? "FIRST_BASE" : "SECOND_BASE";
   string displayName=baseNumber==1 ? "FIRST BASE" : "SECOND BASE";
   string zone="NQ_DOUBLE_"+baseName;
   string label=zone+"_LABEL";
   double low=MathMin(base.anchorOpen,base.anchorClose);
   double high=MathMax(base.anchorOpen,base.anchorClose);
   if(high==low)
   {
      low-=_Point*0.5;
      high+=_Point*0.5;
   }
   datetime endTime=base.lastCandleTime+PeriodSeconds(PERIOD_M5);
   color baseColor=baseNumber==1 ? (top ? clrTomato : clrLimeGreen) : clrGold;
   ObjectDelete(0,zone);
   ObjectDelete(0,label);
   if(ObjectCreate(0,zone,OBJ_RECTANGLE,0,base.firstCandleTime,high,endTime,low))
   {
      ObjectSetInteger(0,zone,OBJPROP_COLOR,baseColor);
      ObjectSetInteger(0,zone,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,zone,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,zone,OBJPROP_FILL,false);
      ObjectSetInteger(0,zone,OBJPROP_BACK,false);
      ObjectSetInteger(0,zone,OBJPROP_SELECTABLE,false);
   }
   if(ObjectCreate(0,label,OBJ_TEXT,0,base.firstCandleTime,high))
   {
      ObjectSetString(0,label,OBJPROP_TEXT,"DOUBLE "+displayName);
      ObjectSetInteger(0,label,OBJPROP_COLOR,baseColor);
      ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
   }
}

// A Double reference follows a running wick extreme until a pullback freezes
// it. An out-of-zone close can start a new leg in the same direction.
struct NQDoubleSharedFirstLegFreeze
{
   datetime dayStartGMT;
   bool initialized;
   bool frozen;
   bool bullish;
   datetime lastProcessedBarTime;
   datetime candleTime;
   double candleOpen;
   double candleClose;
   double wickExtreme;
};

NQDoubleSharedFirstLegFreeze g_doubleSharedFirstLegFreeze;
NQDoubleSharedFirstLegFreeze g_doubleBullishContextLeg;
NQDoubleSharedFirstLegFreeze g_doubleBearishContextLeg;
bool g_doubleBullishContextReady=false;
bool g_doubleBearishContextReady=false;

void ResetDoubleFirstLegReference(NQDoubleSharedFirstLegFreeze &reference,
   datetime dayStartGMT)
{
   ZeroMemory(reference);
   reference.dayStartGMT=dayStartGMT;
}

bool GetCurrentSharedFirstLeg(bool &bullish,int &shift,double &openPrice,
   double &closePrice)
{
   bullish=false;
   shift=-1;
   openPrice=0.0;
   closePrice=0.0;
   if(GetFirstLegCandle(true,shift,openPrice,closePrice))
   {
      bullish=true;
      return true;
   }
   return GetFirstLegCandle(false,shift,openPrice,closePrice);
}

void GetDoubleEntryZone(bool top,double firstLegOpen,double firstLegClose,
   double &zoneLow,double &zoneHigh)
{
   double bodyLow=MathMin(firstLegOpen,firstLegClose);
   double bodyHigh=MathMax(firstLegOpen,firstLegClose);
   double tolerance=MathMax(0.0,InpDoubleTolerancePoints)*_Point;
   double sweep=MathMax(0.0,InpDoubleSweepAllowancePoints)*_Point;
   zoneLow=bodyLow-(top ? sweep : tolerance);
   zoneHigh=bodyHigh+(top ? tolerance : sweep);
}

void SetDoubleFirstLegCandle(NQDoubleSharedFirstLegFreeze &reference,
   const MqlRates &candle)
{
   reference.candleTime=candle.time;
   reference.candleOpen=candle.open;
   reference.candleClose=candle.close;
   reference.wickExtreme=reference.bullish ? candle.high : candle.low;
}

bool TryRestartDoubleFirstLeg(NQDoubleSharedFirstLegFreeze &reference,
   const MqlRates &candle)
{
   if(reference.candleTime<=0 || candle.time<=reference.candleTime)
      return false;

   double zoneLow,zoneHigh;
   GetDoubleEntryZone(reference.bullish,reference.candleOpen,
      reference.candleClose,zoneLow,zoneHigh);
   // Only an extension in the First Leg's direction can replace it.
   // A move past the opposite edge is part of the pullback.
   bool extendsBeyondZone=reference.bullish ? candle.close>zoneHigh
                                            : candle.close<zoneLow;
   if(!extendsBeyondZone)
      return false;

   reference.frozen=false;
   SetDoubleFirstLegCandle(reference,candle);
   ClearDoubleBaseMarkers();
   ClearDoubleTwoTurnMarkers();
   Print("Double First Leg restarted at ",
      TimeToString(candle.time,TIME_DATE|TIME_MINUTES),
      " (server time). Breakout close ",DoubleToString(candle.close,_Digits),
      " outside prior zone ",DoubleToString(zoneLow,_Digits),
      " to ",DoubleToString(zoneHigh,_Digits));
   return true;
}

bool ReplayDoubleFirstLeg(NQDoubleSharedFirstLegFreeze &reference,
   double freezeDistance,datetime firstCandidateTime)
{
   bool ready=reference.frozen || freezeDistance<=0.0;
   datetime replayFrom=reference.lastProcessedBarTime>0
      ? reference.lastProcessedBarTime : firstCandidateTime;
   int oldestShift=iBarShift(_Symbol,PERIOD_M5,replayFrom,true);
   if(oldestShift<1)
      return false;
   if(reference.lastProcessedBarTime>0)
      oldestShift--;
   if(oldestShift<1)
      return ready;

   MqlRates completed[];
   // CopyRates places the oldest completed bar first. Replay the opening
   // window once, then process only the bars that have closed since.
   if(CopyRates(_Symbol,PERIOD_M5,1,oldestShift,completed)!=oldestShift)
      return false;

   for(int index=0;index<oldestShift;index++)
   {
      MqlRates candle=completed[index];
      if(candle.time<=0 || candle.open<=0.0 || candle.close<=0.0 ||
         candle.high<=0.0 || candle.low<=0.0)
         return false;
      reference.lastProcessedBarTime=candle.time;

      if(ready && TryRestartDoubleFirstLeg(reference,candle))
      {
         ready=freezeDistance<=0.0;
         continue;
      }
      if(reference.frozen)
         continue;

      // Match shared First Leg selection: a strictly more extreme wick
      // replaces the endpoint. Its own candle cannot also be its pullback.
      double wick=reference.bullish ? candle.high : candle.low;
      bool extendsLeg=reference.bullish ? wick>reference.wickExtreme
                                        : wick<reference.wickExtreme;
      if(reference.candleTime==0 || extendsLeg)
      {
         SetDoubleFirstLegCandle(reference,candle);
         continue;
      }
      if(freezeDistance<=0.0)
         continue;

      double pullbackDistance=reference.bullish
         ? MathMax(reference.candleOpen,reference.candleClose)-
            MathMin(candle.open,candle.close)
         : MathMax(candle.open,candle.close)-
            MathMin(reference.candleOpen,reference.candleClose);
      if(pullbackDistance+0.000001*_Point<freezeDistance)
         continue;

      reference.frozen=true;
      ready=true;
      Print("Double First Leg frozen: ",reference.bullish ? "BULLISH" : "BEARISH",
         "; First Leg candle (server time) ",
         TimeToString(reference.candleTime,TIME_DATE|TIME_MINUTES),
         "; pullback candle ",TimeToString(candle.time,TIME_DATE|TIME_MINUTES),
         "; body distance ",DoubleToString(pullbackDistance/_Point,1)," points");
   }
   return ready;
}

double DoubleFirstLegFreezeDistance()
{
   return InpEnableDoubleFirstLegPullbackFreeze
      ? MathMax(0.0,InpDoubleFirstLegPullbackFreezePoints)*_Point : 0.0;
}

bool UpdateDoubleSharedFirstLegFreeze()
{
   datetime dayStartGMT=GMTDayStart(NQGMTNow());
   if(g_doubleSharedFirstLegFreeze.dayStartGMT!=dayStartGMT)
      ResetDoubleFirstLegReference(g_doubleSharedFirstLegFreeze,dayStartGMT);

   bool bullish=false;
   int sharedShift=-1;
   double sharedOpen=0.0;
   double sharedClose=0.0;
   if(!GetCurrentSharedFirstLeg(bullish,sharedShift,sharedOpen,sharedClose))
      return false;

   datetime sharedTime=iTime(_Symbol,PERIOD_M5,sharedShift);
   if(sharedTime<=0)
      return false;

   double freezeDistance=DoubleFirstLegFreezeDistance();
   if(!g_doubleSharedFirstLegFreeze.initialized ||
      g_doubleSharedFirstLegFreeze.bullish!=bullish)
   {
      ResetDoubleFirstLegReference(g_doubleSharedFirstLegFreeze,dayStartGMT);
      g_doubleSharedFirstLegFreeze.initialized=true;
      g_doubleSharedFirstLegFreeze.bullish=bullish;
   }

   if(freezeDistance<=0.0 && g_doubleSharedFirstLegFreeze.candleTime==0)
   {
      g_doubleSharedFirstLegFreeze.candleTime=sharedTime;
      g_doubleSharedFirstLegFreeze.candleOpen=sharedOpen;
      g_doubleSharedFirstLegFreeze.candleClose=sharedClose;
      g_doubleSharedFirstLegFreeze.wickExtreme=bullish
         ? iHigh(_Symbol,PERIOD_M5,sharedShift)
         : iLow(_Symbol,PERIOD_M5,sharedShift);
      if(g_doubleSharedFirstLegFreeze.wickExtreme<=0.0)
      {
         g_doubleSharedFirstLegFreeze.candleTime=0;
         return false;
      }
      g_doubleSharedFirstLegFreeze.lastProcessedBarTime=sharedTime;
   }
   return ReplayDoubleFirstLeg(g_doubleSharedFirstLegFreeze,freezeDistance,
      g_firstLegStartTime);
}

// Candidates before Fallback use the extended context. Starting at Fallback,
// new candidates qualify from the standard 30-candle context.
bool UpdateDoubleContextLeg(NQDoubleSharedFirstLegFreeze &reference,
   bool bullish,datetime dayStartGMT,int firstCandidateShift,
   int oldestContextShift,datetime fallbackServer,double freezeDistance)
{
   if(reference.dayStartGMT!=dayStartGMT)
      ResetDoubleFirstLegReference(reference,dayStartGMT);
   if(reference.initialized)
      return ReplayDoubleFirstLeg(reference,freezeDistance,reference.candleTime);

   int oldestShift=firstCandidateShift;
   if(reference.lastProcessedBarTime>0)
   {
      int lastShift=iBarShift(_Symbol,PERIOD_M5,reference.lastProcessedBarTime,true);
      if(lastShift<1)
         return false;
      oldestShift=lastShift-1;
   }
   if(oldestShift<1)
      return false;

   const int extendedEarlierBars=59;
   const int standardEarlierBars=29;
   datetime oldestCandidateTime=iTime(_Symbol,PERIOD_M5,oldestShift);
   if(oldestCandidateTime<=0)
      return false;
   int maxEarlierBars=oldestCandidateTime<fallbackServer
      ? extendedEarlierBars : standardEarlierBars;
   int count=(int)MathMin(oldestContextShift,oldestShift+maxEarlierBars);
   MqlRates candles[];
   if(CopyRates(_Symbol,PERIOD_M5,1,count,candles)!=count)
      return false;

   double minimumMove=MathMax(0.0,InpFirstLegMinimumMovePoints)*_Point;
   for(int index=count-oldestShift;index<count;index++)
   {
      MqlRates candle=candles[index];
      if(candle.time<=0 || candle.open<=0.0 || candle.close<=0.0 ||
         candle.high<=0.0 || candle.low<=0.0)
         return false;

      bool extended=candle.time<fallbackServer;
      int earlierBars=extended ? extendedEarlierBars : standardEarlierBars;
      int firstContextIndex=(int)MathMax(0,index-earlierBars);
      double contextOpen=candles[firstContextIndex].open;
      for(int earlier=firstContextIndex+1;earlier<index;earlier++)
      {
         double open=candles[earlier].open;
         contextOpen=bullish ? MathMin(contextOpen,open) : MathMax(contextOpen,open);
      }
      reference.lastProcessedBarTime=candle.time;
      double move=bullish ? candle.close-contextOpen : contextOpen-candle.close;
      if(contextOpen<=0.0 || move+0.000001*_Point<minimumMove)
         continue;

      reference.initialized=true;
      reference.bullish=bullish;
      SetDoubleFirstLegCandle(reference,candle);
      Print("Double First Leg qualified (",extended ? 60 : 30,
         "-candle context): ",bullish ? "BULLISH" : "BEARISH",
         "; candidate candle (server time) ",TimeToString(candle.time,TIME_DATE|TIME_MINUTES),
         "; body move ",DoubleToString(move/_Point,1)," points");
      return ReplayDoubleFirstLeg(reference,freezeDistance,candle.time);
   }
   return false;
}

bool GetDoubleFirstLegReference(bool bullish,int &shift,double &openPrice,
   double &closePrice)
{
   shift=-1;
   openPrice=0.0;
   closePrice=0.0;
   NQDoubleSharedFirstLegFreeze reference;
   if(InpEnableDoubleExtendedFirstLegContext)
   {
      if(bullish)
      {
         if(!g_doubleBullishContextReady)
            return false;
         reference=g_doubleBullishContextLeg;
      }
      else
      {
         if(!g_doubleBearishContextReady)
            return false;
         reference=g_doubleBearishContextLeg;
      }
   }
   else
   {
      if(!UpdateDoubleSharedFirstLegFreeze() ||
         g_doubleSharedFirstLegFreeze.bullish!=bullish)
         return false;
      reference=g_doubleSharedFirstLegFreeze;
   }

   shift=iBarShift(_Symbol,PERIOD_M5,reference.candleTime,true);
   if(shift<3 || reference.candleOpen<=0.0 || reference.candleClose<=0.0)
      return false;
   openPrice=reference.candleOpen;
   closePrice=reference.candleClose;
   return true;
}

// Keep the same-day shared-leg reference current even while a news, hours,
// spread, or position gate temporarily prevents new entries.
void UpdateDoubleSharedFirstLegReference()
{
   if(!InpEnableDoubleExtendedFirstLegContext)
   {
      UpdateDoubleSharedFirstLegFreeze();
      return;
   }

   g_doubleBullishContextReady=false;
   g_doubleBearishContextReady=false;
   if(!g_firstLegReady || _Point<=0.0)
      return;

   datetime dayStartGMT=GMTDayStart(NQGMTNow());
   datetime entryStartGMT=dayStartGMT+NQEntryStartSeconds();
   datetime entryStartServer=GMTToServerTime(entryStartGMT);
   datetime fallbackGMT=dayStartGMT+NQFallbackSeconds();
   datetime fallbackServer=GMTToServerTime(fallbackGMT);
   int newestPreOpenShift=iBarShift(_Symbol,PERIOD_M5,entryStartServer-1,false);
   if(newestPreOpenShift<1)
      return;

   // The first eligible endpoint is the oldest of the 30 pre-entry bars.
   // Once open, both directions can qualify on newly completed candles too.
   int firstCandidateShift=newestPreOpenShift+29;
   int oldestContextShift=newestPreOpenShift+59;
   double freezeDistance=DoubleFirstLegFreezeDistance();
   g_doubleBullishContextReady=UpdateDoubleContextLeg(g_doubleBullishContextLeg,
      true,dayStartGMT,firstCandidateShift,oldestContextShift,fallbackServer,freezeDistance);
   g_doubleBearishContextReady=UpdateDoubleContextLeg(g_doubleBearishContextLeg,
      false,dayStartGMT,firstCandidateShift,oldestContextShift,fallbackServer,freezeDistance);
}

bool FindDoubleBaseBetweenShifts(bool top,int oldestShift,int newestShift,
   int minimumCandles,NQBaseZone &base)
{
   if(oldestShift<newestShift || newestShift<1)
      return false;
   int count=oldestShift-newestShift+1;
   MqlRates candles[];
   if(CopyRates(_Symbol,PERIOD_M5,newestShift,count,candles)!=count)
      return false;
   bool found=false;
   if(!FindNQTwoEndedBase(candles,_Point,MathMax(1,minimumCandles),
      InpBaseOpenTolerancePoints,InpBaseCloseTolerancePoints,
      InpBaseValidityMinutes,base,found,top ? 1 : -1,
      MathMax(0.0,InpDoubleMinBaseSeparationPoints)))
      return false;
   return found;
}

bool IsDoubleBaseSeparationAllowed(double separationPoints)
{
   double minimumSeparation=MathMax(0.0,InpDoubleMinBaseSeparationPoints);
   double maximumSeparation=MathMax(0.0,InpDoubleMaxBaseSeparationPoints);
   // Allow for floating-point rounding at either inclusive limit.
   const double roundingMargin=0.000001;
   return separationPoints>0.0 &&
      separationPoints>=minimumSeparation-roundingMargin &&
      separationPoints<=maximumSeparation+roundingMargin;
}

double DoubleBaseAnchorMidpoint(const NQBaseZone &base)
{
   return (base.anchorOpen+base.anchorClose)*0.5;
}

bool IsDoubleSecondBaseEligible(bool top,double firstLegOpen,
   double firstLegClose,const NQBaseZone &secondBase)
{
   double midpoint=DoubleBaseAnchorMidpoint(secondBase);
   double separationPoints=(top ? MathMax(firstLegOpen,firstLegClose)-midpoint
                                : midpoint-MathMin(firstLegOpen,firstLegClose))/_Point;
   return IsDoubleBaseSeparationAllowed(separationPoints);
}

// The later Base belongs to the pullback only when its first counted candle
// is chronologically after the final candle of the frozen shared First Leg.
bool IsDoubleSecondBaseAfterFirstLeg(int firstLegShift,
   const NQBaseZone &secondBase)
{
   datetime firstLegTime=iTime(_Symbol,PERIOD_M5,firstLegShift);
   return firstLegTime>0 && secondBase.firstCandleTime>firstLegTime;
}

bool IsDoubleEntryMethodReady(bool top,double firstLegOpen,
   double firstLegClose,
   const NQBaseZone &secondBase)
{
   double entryZoneLow,entryZoneHigh;
   GetDoubleEntryZone(top,firstLegOpen,firstLegClose,entryZoneLow,entryZoneHigh);
   // Doubles use the shared two-turn structure inside their widened entry
   // zone. Both arrival closes and both turn/entry opens must remain inside
   // this zone; each arrival-to-turn hand-off uses the shared gap tolerance.
   int secondBaseLastShift=iBarShift(_Symbol,PERIOD_M5,
      secondBase.lastCandleTime,true);
   int firstArrivalSearchShift=secondBaseLastShift-1;
   if(firstArrivalSearchShift<2)
      return false;

   // Apply the return-distance limits to the First Turn candle's open.
   double midpoint=DoubleBaseAnchorMidpoint(secondBase);
   double minimumDistance=MathMax(0.000001,InpDoubleMinBaseSeparationPoints-0.000001)*_Point;
   double maximumDistance=(MathMax(0.0,InpDoubleMaxBaseSeparationPoints)+0.000001)*_Point;
   double firstTurnOpenLow=top ? midpoint+minimumDistance : midpoint-maximumDistance;
   double firstTurnOpenHigh=top ? midpoint+maximumDistance : midpoint-minimumDistance;
   double requiredReturnPrice=0.0;
   if(InpEnableDoubleFirstLegReach)
   {
      double reachAllowance=MathMax(0.0,InpDoubleFirstLegReachAllowancePoints)*_Point;
      requiredReturnPrice=top ? MathMax(firstLegOpen,firstLegClose)-reachAllowance
                             : MathMin(firstLegOpen,firstLegClose)+reachAllowance;
   }
   int firstArrivalShift=-1;
   int firstTurnShift=-1;
   int secondArrivalShift=-1;
   int entryTurnShift=-1;
   string markerSuffix=top ? "_DOUBLE_TOP" : "_DOUBLE_BOTTOM";
   return FindTurningPoint(!top,firstArrivalSearchShift,
      entryZoneLow,entryZoneHigh,firstArrivalShift,firstTurnShift,
      secondArrivalShift,entryTurnShift,markerSuffix,
      MathMax(0.0,InpDoublesArrivalCloseTolerancePoints),-1,
      InpTailBodyDojiMaxBodyPoints,true,firstTurnOpenLow,firstTurnOpenHigh,
      requiredReturnPrice)
      && entryTurnShift==0;
}

// The shared First Leg supplies the first structural reference.  The only
// Base searched by Doubles is the later pullback (Second) Base.
bool FindDoubleBaseSetup(bool top,int firstLegShift,double firstLegOpen,
   double firstLegClose,NQBaseZone &secondBase)
{
   secondBase.firstCandleTime=0;
   if(firstLegShift<3 || firstLegOpen<=0.0 || firstLegClose<=0.0)
      return false;

   // The search begins strictly after the frozen final First Leg candle, so
   // no Base from the same extending movement can be used as Second Base.
   int oldestShift=firstLegShift-1;
   int candleCount=oldestShift-1;
   MqlRates candles[];
   int secondBaseMinimumCandles=MathMax(1,InpDoublesBase2MinimumCandles);
   if(candleCount<secondBaseMinimumCandles ||
      CopyRates(_Symbol,PERIOD_M5,2,candleCount,candles)!=candleCount)
      return false;
   int step=candles[0].time<=candles[candleCount-1].time ? 1 : -1;
   int cursor=step>0 ? 0 : candleCount-1;
   NQBaseZone completedSecondBases[];
   int completedSecondBaseCount=0;
   for(;cursor>=0 && cursor<candleCount;cursor+=step)
   {
      int newestShift=iBarShift(_Symbol,PERIOD_M5,candles[cursor].time,true);
      if(newestShift<2 || newestShift>oldestShift)
         continue;

      NQBaseZone observedSecondBase;
      if(FindDoubleBaseBetweenShifts(top,oldestShift,newestShift,
         secondBaseMinimumCandles,observedSecondBase))
      {
         bool isNewSecondBase=completedSecondBaseCount==0 ||
            observedSecondBase.firstCandleTime!=completedSecondBases[completedSecondBaseCount-1].firstCandleTime ||
            observedSecondBase.anchorOpen!=completedSecondBases[completedSecondBaseCount-1].anchorOpen ||
            observedSecondBase.anchorClose!=completedSecondBases[completedSecondBaseCount-1].anchorClose;
         if(isNewSecondBase)
         {
            ArrayResize(completedSecondBases,completedSecondBaseCount+1);
            completedSecondBases[completedSecondBaseCount++]=observedSecondBase;
         }
         else
            completedSecondBases[completedSecondBaseCount-1]=observedSecondBase;
      }
   }

   // Retain the most extreme valid Base in the pullback.  A lower Base is
   // better for a Double Top; a higher Base is better for a Double Bottom.
   bool haveSecondBase=false;
   double selectedCentre=0.0;
   for(int index=0;index<completedSecondBaseCount;index++)
   {
      NQBaseZone candidateSecondBase=completedSecondBases[index];
      if(!IsDoubleSecondBaseEligible(top,firstLegOpen,firstLegClose,
         candidateSecondBase) || !IsDoubleSecondBaseAfterFirstLeg(
         firstLegShift,candidateSecondBase))
         continue;
      double candidateCentre=DoubleBaseAnchorMidpoint(candidateSecondBase);
      if(!haveSecondBase || (top ? candidateCentre<selectedCentre
                                 : candidateCentre>selectedCentre))
      {
         secondBase=candidateSecondBase;
         selectedCentre=candidateCentre;
         haveSecondBase=true;
      }
   }

   if(haveSecondBase)
      MarkDoubleBase(2,secondBase,top);
   return haveSecondBase && IsDoubleEntryMethodReady(top,firstLegOpen,
      firstLegClose,secondBase);
}


void DetectDoublePattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle ||
      PatternFamilyDailyLimitReached(PATTERN_FAMILY_DOUBLE))
      return;

   if(!SpreadIsAllowed())
   {
      Print("Double entry skipped: spread exceeds the configured limit.");
      return;
   }

   ClearDoubleBaseMarkers();
   NQBaseZone secondBase;
   int firstLegShift=-1;
   double firstLegOpen=0.0;
   double firstLegClose=0.0;
   if(GetDoubleFirstLegReference(true,firstLegShift,firstLegOpen,
      firstLegClose) && FindDoubleBaseSetup(true,firstLegShift,firstLegOpen,
      firstLegClose,secondBase))
   {
      g_detectedPattern = PATTERN_DOUBLE_TOP;
      if(ExecuteDoubleTopSell(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_DOUBLE);
         Print("Double Top SELL opened from frozen First Leg/Second Base return. First Leg ",
            DoubleToString(MathMin(firstLegOpen,firstLegClose),_Digits),
            " to ",DoubleToString(MathMax(firstLegOpen,firstLegClose),_Digits));
      }
      return;
   }

   if(GetDoubleFirstLegReference(false,firstLegShift,firstLegOpen,
      firstLegClose) && FindDoubleBaseSetup(false,firstLegShift,firstLegOpen,
      firstLegClose,secondBase))
   {
      g_detectedPattern = PATTERN_DOUBLE_BOTTOM;
      if(ExecuteDoubleBottomBuy(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_DOUBLE);
         Print("Double Bottom BUY opened from frozen First Leg/Second Base return. First Leg ",
            DoubleToString(MathMin(firstLegOpen,firstLegClose),_Digits),
            " to ",DoubleToString(MathMax(firstLegOpen,firstLegClose),_Digits));
      }
   }
}

#endif
