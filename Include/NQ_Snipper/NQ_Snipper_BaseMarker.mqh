#ifndef __NQ_SNIPPER_BASE_MARKER__
#define __NQ_SNIPPER_BASE_MARKER__

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_Base.mqh"

// Shared display component: callers decide whether and why the base matters.
// Identity depends on the base itself, not on the calling pattern.
void MarkNQBase(const NQBaseZone &base, string explanation = "")
{
   if(!InpShowBaseMarker || _Point <= 0 || base.firstCandleTime <= 0 ||
      base.lastCandleTime < base.firstCandleTime || base.low <= 0 ||
      base.high < base.low)
      return;

   string zone = StringFormat("NQ_BASE_%I64d_%I64d_%I64d_%I64d",
      (long)base.firstCandleTime, (long)base.lastCandleTime,
      (long)MathRound(base.low / _Point), (long)MathRound(base.high / _Point));
   string label = zone + "_L";
   datetime endTime = base.lastCandleTime + PeriodSeconds(PERIOD_M5);
   double visualLow = base.low;
   double visualHigh = base.high;
   if(visualHigh == visualLow)
   {
      visualLow -= _Point * 0.5;
      visualHigh += _Point * 0.5;
   }

   if(ObjectFind(0, zone) < 0 &&
      ObjectCreate(0, zone, OBJ_RECTANGLE, 0, base.firstCandleTime,
         visualHigh, endTime, visualLow))
   {
      ObjectSetInteger(0, zone, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, zone, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, zone, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, zone, OBJPROP_FILL, false);
      ObjectSetInteger(0, zone, OBJPROP_BACK, false);
      ObjectSetInteger(0, zone, OBJPROP_SELECTABLE, false);
   }
   string tooltip = StringFormat("Base: %d selected candles", base.candleCount);
   if(explanation != "")
      tooltip += "; " + explanation;
   if(ObjectFind(0, zone) >= 0)
      ObjectSetString(0, zone, OBJPROP_TOOLTIP, tooltip);

   if(ObjectFind(0, label) < 0 &&
      ObjectCreate(0, label, OBJ_TEXT, 0, base.firstCandleTime, visualHigh))
   {
      ObjectSetInteger(0, label, OBJPROP_COLOR, clrGold);
      ObjectSetInteger(0, label, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, label, OBJPROP_SELECTABLE, false);
   }
   if(ObjectFind(0, label) >= 0)
      ObjectSetString(0, label, OBJPROP_TEXT,
         explanation == "" ? "BASE" : "BASE: " + explanation);
}

#endif
