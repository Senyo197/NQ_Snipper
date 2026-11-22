#ifndef __NQ_SNIPPER_LEG_KNEE__
#define __NQ_SNIPPER_LEG_KNEE__

#include "NQ_Snipper_Doubles.mqh"
#include "NQ_Snipper_BaseMarker.mqh"
#include "NQ_Snipper_Positions.mqh"

// Leg & Knee: a First Base within the First Leg's movement, the existing
// Double Second Base, then Double confirmation aligned with the First Leg.
struct NQLegKneeBaseCache
{
   datetime movementStart;
   datetime movementEnd;
   bool loaded;
   NQBaseZone bases[];
};
NQLegKneeBaseCache g_legKneeTopBases;
NQLegKneeBaseCache g_legKneeBottomBases;
datetime g_legKneeMarkerDay=0;
NQDoubleSharedFirstLegFreeze g_legKneeBullishLeg;
NQDoubleSharedFirstLegFreeze g_legKneeBearishLeg;
bool g_legKneeBullishReady=false;
bool g_legKneeBearishReady=false;

string LegKneeMarkerPrefix(bool top)
{
   return top ? "NQ_LEG_KNEE_TOP_" : "NQ_LEG_KNEE_BOTTOM_";
}

string LegKneeTurnSuffix(bool top)
{
   return top ? "_LEG_KNEE_TOP" : "_LEG_KNEE_BOTTOM";
}

void ClearLegKneeSideMarkers(bool top)
{
   string prefix=LegKneeMarkerPrefix(top);
   ObjectDelete(0,prefix+"FIRST_BASE");
   ObjectDelete(0,prefix+"FIRST_BASE_L");
   ObjectDelete(0,prefix+"SECOND_BASE");
   ObjectDelete(0,prefix+"SECOND_BASE_L");
   ObjectDelete(0,prefix+"FIRST_LEG_ARROW");
   ObjectDelete(0,prefix+"ENTRY_ZONE");
   ObjectDelete(0,prefix+"ENTRY_ZONE_LABEL");
   ClearFirstTurnMarker(LegKneeTurnSuffix(top));
}

void ClearLegKneeMarkers()
{
   ClearLegKneeSideMarkers(true);
   ClearLegKneeSideMarkers(false);
}

void UpdateLegKneeMovementState()
{
   datetime day=GMTDayStart(NQGMTNow());
   if(day!=g_legKneeMarkerDay)
   {
      g_legKneeMarkerDay=day;
      g_legKneeTopBases.loaded=false;
      g_legKneeBottomBases.loaded=false;
      ArrayResize(g_legKneeTopBases.bases,0);
      ArrayResize(g_legKneeBottomBases.bases,0);
      ResetDoubleFirstLegReference(g_legKneeBullishLeg,day);
      ResetDoubleFirstLegReference(g_legKneeBearishLeg,day);
      ClearLegKneeMarkers();
   }
   g_legKneeBullishReady=false;
   g_legKneeBearishReady=false;
   if(!InpEnableLegKneeExtendedFirstLegContext || !g_firstLegReady || _Point<=0)
      return;
   if(!InpEnableDoublePattern && !InpEnableTailBodyPattern && !InpEnableTailBodyVPattern)
   {
      // The shared opening classification can differ from this model's
      // independent context. Do not show it as Leg & Knee's active reference.
      ObjectDelete(0,"NQ_SNIPPER_FIRST_LEG_ARROW");
      ObjectDelete(0,"NQ_SNIPPER_FIRST_LEG_LABEL");
      ClearFirstLegBodySpaceMarker();
   }
   datetime opening=GMTToServerTime(day+NQEntryStartSeconds());
   datetime fallback=GMTToServerTime(day+NQFallbackSeconds());
   int newest=iBarShift(_Symbol,PERIOD_M5,opening-1,false);
   if(newest<1)
      return;
   datetime oldBullStart=g_legKneeBullishLeg.movementStartTime;
   datetime oldBearStart=g_legKneeBearishLeg.movementStartTime;
   double freeze=DoubleFirstLegFreezeDistance();
   g_legKneeBullishReady=UpdateDoubleContextLeg(g_legKneeBullishLeg,true,
      day,newest+29,newest+59,fallback,freeze,false);
   g_legKneeBearishReady=UpdateDoubleContextLeg(g_legKneeBearishLeg,false,
      day,newest+29,newest+59,fallback,freeze,false);
   if(oldBullStart!=g_legKneeBullishLeg.movementStartTime)
      ClearLegKneeSideMarkers(true);
   if(oldBearStart!=g_legKneeBearishLeg.movementStartTime)
      ClearLegKneeSideMarkers(false);
}

bool GetLegKneeFirstLegReference(bool top,int &shift,double &openPrice,double &closePrice)
{
   if(!InpEnableLegKneeExtendedFirstLegContext)
      return GetDoubleFirstLegReference(top,shift,openPrice,closePrice);
   shift=-1;
   openPrice=0.0;
   closePrice=0.0;
   if(top ? !g_legKneeBullishReady : !g_legKneeBearishReady)
      return false;
   NQDoubleSharedFirstLegFreeze reference;
   if(top)
      reference=g_legKneeBullishLeg;
   else
      reference=g_legKneeBearishLeg;
   shift=iBarShift(_Symbol,PERIOD_M5,reference.candleTime,true);
   openPrice=reference.candleOpen;
   closePrice=reference.candleClose;
   return shift>=3 && openPrice>0 && closePrice>0;
}

datetime LegKneeMovementStart(bool top)
{
   if(InpEnableLegKneeExtendedFirstLegContext)
      return top ? g_legKneeBullishLeg.movementStartTime : g_legKneeBearishLeg.movementStartTime;
   if(InpEnableDoubleExtendedFirstLegContext)
      return top ? g_doubleBullishContextLeg.movementStartTime
                 : g_doubleBearishContextLeg.movementStartTime;
   return g_doubleSharedFirstLegFreeze.movementStartTime;
}

bool IsLegKneeBaseSequenceValid(const NQBaseZone &firstBase,
   const NQBaseZone &secondBase,datetime finalLegTime)
{
   return firstBase.firstCandleTime>0 &&
      firstBase.lastCandleTime>=firstBase.firstCandleTime &&
      firstBase.lastCandleTime<=finalLegTime &&
      secondBase.firstCandleTime>finalLegTime &&
      secondBase.lastCandleTime>=secondBase.firstCandleTime;
}

bool CollectLegKneeFirstBases(NQLegKneeBaseCache &cache,
   datetime movementStart,int firstLegShift,NQBaseZone &bases[])
{
   ArrayResize(bases,0);
   datetime movementEnd=iTime(_Symbol,PERIOD_M5,firstLegShift);
   if(movementStart<=0 || movementEnd<movementStart || firstLegShift<1 || _Point<=0)
      return false;
   if(cache.loaded && cache.movementStart==movementStart && cache.movementEnd==movementEnd)
   {
      ArrayCopy(bases,cache.bases);
      return true;
   }

   int oldestShift=iBarShift(_Symbol,PERIOD_M5,movementStart,true);
   int count=oldestShift-firstLegShift+1;
   int minimumCandles=MathMax(NQ_BASE_MIN_ALLOWED_CANDLES,InpBaseMinimumCandles);
   if(oldestShift<firstLegShift || count<1)
      return false;
   MqlRates candles[];
   if(CopyRates(_Symbol,PERIOD_M5,firstLegShift,count,candles)!=count)
      return false;

   // Newest anchors are tried first. Older qualifying groups are retained,
   // so a newer group cannot hide a valid return against an earlier base.
   for(int anchor=count-minimumCandles;anchor>=0;anchor--)
   {
      MqlRates suffix[];
      if(ArrayCopy(suffix,candles,0,anchor,count-anchor)!=count-anchor)
         return false;
      NQBaseZone base;
      bool found=false;
      if(!FindNQTwoEndedBase(suffix,_Point,minimumCandles,
         InpBaseOpenTolerancePoints,InpBaseCloseTolerancePoints,
         InpBaseValidityMinutes,base,found,0,0.0,true))
         return false;
      if(!found || base.firstCandleTime<movementStart || base.lastCandleTime>movementEnd)
         continue;
      int size=ArraySize(bases);
      ArrayResize(bases,size+1);
      bases[size]=base;
   }
   cache.movementStart=movementStart;
   cache.movementEnd=movementEnd;
   cache.loaded=true;
   ArrayResize(cache.bases,0);
   ArrayCopy(cache.bases,bases);
   return true;
}

void MarkLegKneeBase(bool top,int number,const NQBaseZone &base)
{
   if(!InpShowBaseMarker)
      return;
   string name=number==1 ? "FIRST_BASE" : "SECOND_BASE";
   string description=number==1 ? "LEG & KNEE FIRST BASE" : "LEG & KNEE SECOND BASE";
   MarkNQBase(base,description,LegKneeMarkerPrefix(top)+name);
}

bool IsLegKneeBasePairEligible(const NQBaseZone &firstBase,
   const NQBaseZone &secondBase,datetime finalLegTime)
{
   if(_Point<=0 || !IsLegKneeBaseSequenceValid(firstBase,secondBase,finalLegTime))
      return false;
   double points=MathAbs(DoubleBaseAnchorMidpoint(secondBase)-
      DoubleBaseAnchorMidpoint(firstBase))/_Point;
   return IsDoubleBaseSeparationAllowed(points);
}

void MarkLegKneeFirstLeg(bool top,int shift,double openPrice,double closePrice)
{
   string prefix=LegKneeMarkerPrefix(top);
   datetime start=iTime(_Symbol,PERIOD_M5,shift);
   double price=top ? iHigh(_Symbol,PERIOD_M5,shift) : iLow(_Symbol,PERIOD_M5,shift);
   if(InpShowFirstLegMarker && start>0 && price>0 &&
      ObjectCreate(0,prefix+"FIRST_LEG_ARROW",OBJ_ARROW,0,start,price))
   {
      ObjectSetInteger(0,prefix+"FIRST_LEG_ARROW",OBJPROP_ARROWCODE,top ? 234 : 233);
      ObjectSetInteger(0,prefix+"FIRST_LEG_ARROW",OBJPROP_COLOR,top ? clrTomato : clrLimeGreen);
      ObjectSetInteger(0,prefix+"FIRST_LEG_ARROW",OBJPROP_WIDTH,2);
      ObjectSetInteger(0,prefix+"FIRST_LEG_ARROW",OBJPROP_SELECTABLE,false);
      ObjectSetString(0,prefix+"FIRST_LEG_ARROW",OBJPROP_TOOLTIP,
         top ? "LEG & KNEE FIRST LEG: BULLISH" : "LEG & KNEE FIRST LEG: BEARISH");
   }
   if(!InpShowFirstLegBodySpaceMarker || start<=0)
      return;
   double low,high;
   GetDoubleEntryZone(top,openPrice,closePrice,low,high);
   datetime end=iTime(_Symbol,PERIOD_M5,0);
   if(end<=start)end=start+PeriodSeconds(PERIOD_M5);
   if(ObjectCreate(0,prefix+"ENTRY_ZONE",OBJ_RECTANGLE,0,start,high,end,low))
   {
      ObjectSetInteger(0,prefix+"ENTRY_ZONE",OBJPROP_COLOR,top ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE",OBJPROP_STYLE,STYLE_DOT);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE",OBJPROP_FILL,false);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE",OBJPROP_BACK,true);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE",OBJPROP_SELECTABLE,false);
   }
   if(ObjectCreate(0,prefix+"ENTRY_ZONE_LABEL",OBJ_TEXT,0,start,high))
   {
      ObjectSetString(0,prefix+"ENTRY_ZONE_LABEL",OBJPROP_TEXT,"LEG & KNEE FIRST LEG ENTRY ZONE");
      ObjectSetInteger(0,prefix+"ENTRY_ZONE_LABEL",OBJPROP_COLOR,top ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE_LABEL",OBJPROP_FONTSIZE,8);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE_LABEL",OBJPROP_ANCHOR,ANCHOR_LOWER);
      ObjectSetInteger(0,prefix+"ENTRY_ZONE_LABEL",OBJPROP_SELECTABLE,false);
   }
}

string LegKneeFirstLegSummary()
{
   string summary="";
   for(int direction=0;direction<2;direction++)
   {
      bool top=direction==0;
      int shift;
      double openPrice,closePrice;
      if(!GetLegKneeFirstLegReference(top,shift,openPrice,closePrice))
         continue;
      summary+="Leg & Knee "+(top ? "bullish" : "bearish")+" First Leg: "+
         TimeToString(iTime(_Symbol,PERIOD_M5,shift),TIME_MINUTES)+" | body "+
         DoubleToString(MathMin(openPrice,closePrice),_Digits)+" - "+
         DoubleToString(MathMax(openPrice,closePrice),_Digits)+"\n";
   }
   return summary!="" ? summary : "Leg & Knee First Leg: waiting for movement / pullback\n";
}

bool SelectLegKneeFirstBase(const NQBaseZone &firstBases[],
   const NQBaseZone &secondBase,datetime legTime,NQBaseZone &selected)
{
   bool found=false;
   for(int i=0;i<ArraySize(firstBases);i++)
   {
      NQBaseZone candidate=firstBases[i];
      if(!IsLegKneeBasePairEligible(candidate,secondBase,legTime))
         continue;
      if(!found || candidate.widthPoints<selected.widthPoints ||
         (candidate.widthPoints==selected.widthPoints && candidate.candleCount>selected.candleCount))
      {
         selected=candidate;
         found=true;
      }
   }
   return found;
}

bool FindLegKneeBaseSetup(bool top,NQBaseZone &firstBase,NQBaseZone &secondBase)
{
   ZeroMemory(firstBase);
   ZeroMemory(secondBase);
   int firstLegShift=-1;
   double legOpen=0.0,legClose=0.0;
   if(!GetLegKneeFirstLegReference(top,firstLegShift,legOpen,legClose))
      return false;
   datetime start=LegKneeMovementStart(top);
   // A tree belongs to this GMT day, including its pre-entry context.
   start=(datetime)MathMax((long)start,(long)GMTToServerTime(GMTDayStart(NQGMTNow())));
   NQBaseZone firstBases[];
   bool collected=top
      ? CollectLegKneeFirstBases(g_legKneeTopBases,start,firstLegShift,firstBases)
      : CollectLegKneeFirstBases(g_legKneeBottomBases,start,firstLegShift,firstBases);
   if(!collected || ArraySize(firstBases)==0)
      return false;
   firstBase=firstBases[0];
   MarkLegKneeBase(top,1,firstBase);

   NQBaseZone secondBases[];
   if(!CollectDoubleSecondBases(top,firstLegShift,secondBases,true))
      return false;
   // Prefer recent Second Base anchors for the display, while retaining all
   // candidates for execution. Base extension does not change its anchor.
   for(int i=0;i<ArraySize(secondBases)-1;i++)
      for(int j=i+1;j<ArraySize(secondBases);j++)
         if(secondBases[j].firstCandleTime>secondBases[i].firstCandleTime)
         {
            NQBaseZone swap=secondBases[i];
            secondBases[i]=secondBases[j];
            secondBases[j]=swap;
         }
   datetime legTime=iTime(_Symbol,PERIOD_M5,firstLegShift);
   bool havePair=false;
   for(int secondIndex=0;secondIndex<ArraySize(secondBases);secondIndex++)
   {
      NQBaseZone candidateSecond=secondBases[secondIndex];
      NQBaseZone candidateFirst;
      if(!SelectLegKneeFirstBase(firstBases,candidateSecond,legTime,candidateFirst))
         continue;
      // Display the tightest eligible First Base, then its most recent
      // eligible Second Base. All pairs still get the same entry checks.
      if(!havePair || candidateFirst.widthPoints<firstBase.widthPoints ||
         (candidateFirst.widthPoints==firstBase.widthPoints &&
          candidateSecond.firstCandleTime>secondBase.firstCandleTime))
      {
         firstBase=candidateFirst;
         secondBase=candidateSecond;
         havePair=true;
      }
      // Pair separation is already validated. Confirmation still uses the
      // widened First Leg zone, shared gaps, arrival distance and reach rule.
      if(!IsDoubleEntryMethodReady(top,legOpen,legClose,candidateSecond,
         LegKneeTurnSuffix(top),false))
         continue;
      firstBase=candidateFirst;
      secondBase=candidateSecond;
      MarkLegKneeBase(top,1,firstBase);
      MarkLegKneeBase(top,2,secondBase);
      MarkLegKneeFirstLeg(top,firstLegShift,legOpen,legClose);
      return true;
   }
   ClearFirstTurnMarker(LegKneeTurnSuffix(top));
   if(havePair)
   {
      MarkLegKneeBase(top,1,firstBase);
      MarkLegKneeBase(top,2,secondBase);
      MarkLegKneeFirstLeg(top,firstLegShift,legOpen,legClose);
      IsDoubleEntryMethodReady(top,legOpen,legClose,secondBase,LegKneeTurnSuffix(top),false);
   }
   return false;
}


void DetectLegKneePattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle || HasOurOpenPosition() ||
      PatternFamilyDailyLimitReached(PATTERN_FAMILY_LEG_KNEE))
      return;
   if(!SpreadIsAllowed())
   {
      Print("Leg & Knee entry skipped: spread exceeds the configured limit.");
      return;
   }
   ClearLegKneeMarkers();
   NQBaseZone firstBase,secondBase;
   for(int direction=0;direction<2;direction++)
   {
      bool top=direction==0;
      if(!FindLegKneeBaseSetup(top,firstBase,secondBase))
         continue;
      g_detectedPattern=top ? PATTERN_LEG_KNEE_TOP : PATTERN_LEG_KNEE_BOTTOM;
      bool executed=top ? ExecuteLegKneeTopSell(trade) : ExecuteLegKneeBottomBuy(trade);
      if(executed)
      {
         RegisterSuccessfulEntry(PATTERN_FAMILY_LEG_KNEE);
         Print("Leg & Knee ",top ? "SELL" : "BUY",
            " opened: First Base ",TimeToString(firstBase.firstCandleTime,TIME_DATE|TIME_MINUTES),
            "; Second Base ",TimeToString(secondBase.firstCandleTime,TIME_DATE|TIME_MINUTES),
            " (server time); return/confirmation aligned with First Leg");
      }
      return;
   }
}
#endif
