#ifndef __NQ_SNIPPER_DOUBLES__
#define __NQ_SNIPPER_DOUBLES__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"
#include "NQ_Snipper_Base.mqh"

void ClearDoublePhaseMarkers()
{
   ObjectDelete(0,"NQ_DOUBLE_PHASE_1");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_1_LABEL");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_2");
   ObjectDelete(0,"NQ_DOUBLE_PHASE_2_LABEL");
}

void MarkDoublePhase(int phase,const NQBaseZone &base,bool top)
{
   if(!InpShowBaseMarker || base.firstCandleTime<=0 ||
      base.lastCandleTime<base.firstCandleTime || base.anchorOpen<=0.0 ||
      base.anchorClose<=0.0)
      return;

   string suffix=IntegerToString(phase);
   string zone="NQ_DOUBLE_PHASE_"+suffix;
   string label=zone+"_LABEL";
   double low=MathMin(base.anchorOpen,base.anchorClose);
   double high=MathMax(base.anchorOpen,base.anchorClose);
   if(high==low)
   {
      low-=_Point*0.5;
      high+=_Point*0.5;
   }
   datetime endTime=base.lastCandleTime+PeriodSeconds(PERIOD_M5);
   color phaseColor=phase==1 ? (top ? clrTomato : clrLimeGreen) : clrGold;
   ObjectDelete(0,zone);
   ObjectDelete(0,label);
   if(ObjectCreate(0,zone,OBJ_RECTANGLE,0,base.firstCandleTime,high,endTime,low))
   {
      ObjectSetInteger(0,zone,OBJPROP_COLOR,phaseColor);
      ObjectSetInteger(0,zone,OBJPROP_STYLE,STYLE_DASH);
      ObjectSetInteger(0,zone,OBJPROP_WIDTH,2);
      ObjectSetInteger(0,zone,OBJPROP_FILL,false);
      ObjectSetInteger(0,zone,OBJPROP_BACK,false);
      ObjectSetInteger(0,zone,OBJPROP_SELECTABLE,false);
   }
   if(ObjectCreate(0,label,OBJ_TEXT,0,base.firstCandleTime,high))
   {
      ObjectSetString(0,label,OBJPROP_TEXT,"DOUBLE PHASE "+suffix);
      ObjectSetInteger(0,label,OBJPROP_COLOR,phaseColor);
      ObjectSetInteger(0,label,OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(0,label,OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,label,OBJPROP_SELECTABLE,false);
   }
}

bool FindDoubleBaseBetweenShifts(int oldestShift,int newestShift,NQBaseZone &base)
{
   if(oldestShift<newestShift || newestShift<1)
      return false;
   int count=oldestShift-newestShift+1;
   MqlRates candles[];
   if(CopyRates(_Symbol,PERIOD_M5,newestShift,count,candles)!=count)
      return false;
   bool found=false;
   if(!FindNQTwoEndedBase(candles,_Point,InpBaseMinimumCandles,
      InpBaseOpenTolerancePoints,InpBaseCloseTolerancePoints,
      InpBaseValidityMinutes,base,found))
      return false;
   return found;
}

// Phase 1 is the latest completed base before Phase 2. Phase 2 is the latest
// completed base before the return candle. Their relative body centres decide
// whether the structure is a Double Top or Double Bottom.
bool FindDoublePhaseSetup(bool top,NQBaseZone &phaseOne,NQBaseZone &phaseTwo)
{
   datetime nowGMT=TimeGMT();
   datetime dayStartGMT=GMTDayStart(nowGMT);
   datetime sessionStartGMT=dayStartGMT+InpEntryStartHourGMT*3600+
      InpEntryStartMinuteGMT*60;
   int oldestShift=iBarShift(_Symbol,PERIOD_M5,GMTToServerTime(sessionStartGMT),true);
   if(oldestShift<4)
      return false;

   // Shift 1 is the return candle. Both phases must already be complete.
   if(!FindDoubleBaseBetweenShifts(oldestShift,2,phaseTwo))
      return false;
   int phaseTwoFirstShift=iBarShift(_Symbol,PERIOD_M5,phaseTwo.firstCandleTime,true);
   if(phaseTwoFirstShift<2 || oldestShift<phaseTwoFirstShift+1)
      return false;
   if(!FindDoubleBaseBetweenShifts(oldestShift,phaseTwoFirstShift+1,phaseOne))
      return false;

   double phaseOneCentre=(phaseOne.anchorOpen+phaseOne.anchorClose)*0.5;
   double phaseTwoCentre=(phaseTwo.anchorOpen+phaseTwo.anchorClose)*0.5;
   bool phasesMoveAsExpected=top ? phaseTwoCentre<phaseOneCentre
                                  : phaseTwoCentre>phaseOneCentre;
   if(!phasesMoveAsExpected)
      return false;

   MarkDoublePhase(1,phaseOne,top);
   MarkDoublePhase(2,phaseTwo,top);
   double phaseOneLow=MathMin(phaseOne.anchorOpen,phaseOne.anchorClose);
   double phaseOneHigh=MathMax(phaseOne.anchorOpen,phaseOne.anchorClose);
   double returnClose=iClose(_Symbol,PERIOD_M5,1);
   return returnClose>=phaseOneLow && returnClose<=phaseOneHigh;
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

   ClearDoublePhaseMarkers();
   NQBaseZone phaseOne;
   NQBaseZone phaseTwo;
   if(FindDoublePhaseSetup(true,phaseOne,phaseTwo))
   {
      g_detectedPattern = PATTERN_DOUBLE_TOP;
      if(ExecuteDoubleTopSell(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_DOUBLE);
         Print("Double Top SELL opened from Phase 1/Phase 2 return. Phase 1 ",
            DoubleToString(MathMin(phaseOne.anchorOpen,phaseOne.anchorClose),_Digits),
            " to ",DoubleToString(MathMax(phaseOne.anchorOpen,phaseOne.anchorClose),_Digits));
      }
      return;
   }

   if(FindDoublePhaseSetup(false,phaseOne,phaseTwo))
   {
      g_detectedPattern = PATTERN_DOUBLE_BOTTOM;
      if(ExecuteDoubleBottomBuy(trade))
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_DOUBLE);
         Print("Double Bottom BUY opened from Phase 1/Phase 2 return. Phase 1 ",
            DoubleToString(MathMin(phaseOne.anchorOpen,phaseOne.anchorClose),_Digits),
            " to ",DoubleToString(MathMax(phaseOne.anchorOpen,phaseOne.anchorClose),_Digits));
      }
   }
}

#endif
