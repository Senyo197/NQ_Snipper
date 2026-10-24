#ifndef __NQ_SNIPPER_TAIL_BODY_LEGS__
#define __NQ_SNIPPER_TAIL_BODY_LEGS__

#include "..\\NQ_Snipper_ConfigState.mqh"
#include "..\\NQ_Snipper_TimeCalendar.mqh"
#include "..\\NQ_Snipper_BarsSwings.mqh"

struct TailBodyLegState
{
   bool active;
   datetime startTime;
   datetime extremeTime;
   double extremePrice;
};

TailBodyLegState g_tailBodyBullLeg;
TailBodyLegState g_tailBodyBearLeg;
datetime g_tailBodyLegDay = 0;
datetime g_tailBodyLastBar = 0;
bool g_tailBodyLegInitialized = false;
double g_tailBodyOpeningHigh = 0.0;
double g_tailBodyOpeningLow = 0.0;
double g_tailBodyLowestOpen = 0.0;
double g_tailBodyHighestOpen = 0.0;
datetime g_tailBodyLowestOpenTime = 0;
datetime g_tailBodyHighestOpenTime = 0;

void ClearTailBodyLegObjects(string side)
{
   ObjectDelete(0, "NQ_TB_LEG_" + side);
   ObjectDelete(0, "NQ_TB_LEG_LABEL_" + side);
   ObjectDelete(0, "NQ_TB_BODY_" + side);
   ObjectDelete(0, "NQ_TB_BODY_LABEL_" + side);
   ObjectDelete(0, "NQ_SNIPPER_FIRST_TURN_ARROW_TB_" + side);
   ObjectDelete(0, "NQ_SNIPPER_FIRST_TURN_LABEL_TB_" + side);
}

void ResetTailBodyLegs(datetime dayStartGMT)
{
   g_tailBodyLegDay = dayStartGMT;
   g_tailBodyLastBar = 0;
   g_tailBodyLegInitialized = false;
   g_tailBodyBullLeg.active = false;
   g_tailBodyBearLeg.active = false;
   g_tailBodyLowestOpen = 0.0;
   g_tailBodyHighestOpen = 0.0;
   g_tailBodyLowestOpenTime = 0;
   g_tailBodyHighestOpenTime = 0;
   ClearTailBodyLegObjects("BULL");
   ClearTailBodyLegObjects("BEAR");
}

void RememberTailBodyOpen(double price, datetime time)
{
   if(g_tailBodyLowestOpenTime == 0 || price < g_tailBodyLowestOpen)
   {
      g_tailBodyLowestOpen = price;
      g_tailBodyLowestOpenTime = time;
   }
   if(g_tailBodyHighestOpenTime == 0 || price > g_tailBodyHighestOpen)
   {
      g_tailBodyHighestOpen = price;
      g_tailBodyHighestOpenTime = time;
   }
}

void SetTailBodyLeg(TailBodyLegState &leg, datetime startTime,
   datetime extremeTime, double extremePrice)
{
   leg.active = true;
   leg.startTime = startTime;
   leg.extremeTime = extremeTime;
   leg.extremePrice = extremePrice;
}

bool InitializeTailBodyLegs(datetime openingServerTime)
{
   int newest = iBarShift(_Symbol, PERIOD_M5, openingServerTime - 1, false);
   if(newest < 1 || newest + 29 >= Bars(_Symbol, PERIOD_M5) || _Point <= 0)
      return false;
   datetime latestTime = iTime(_Symbol, PERIOD_M5, newest);
   if(latestTime <= 0 || latestTime + PeriodSeconds(PERIOD_M5) != openingServerTime)
      return false;

   double opens[30], closes[30];
   double high = -DBL_MAX, low = DBL_MAX;
   datetime highTime = 0, lowTime = 0, firstTime = 0;
   for(int i = 0; i < 30; i++)
   {
      int shift = newest + 29 - i;
      datetime time = iTime(_Symbol, PERIOD_M5, shift);
      double barOpen = iOpen(_Symbol, PERIOD_M5, shift);
      double barClose = iClose(_Symbol, PERIOD_M5, shift);
      double barHigh = iHigh(_Symbol, PERIOD_M5, shift);
      double barLow = iLow(_Symbol, PERIOD_M5, shift);
      if(time <= 0 || barOpen <= 0 || barClose <= 0 ||
         barHigh <= 0 || barLow <= 0)
         return false;
      if(i == 0) firstTime = time;
      opens[i] = barOpen;
      closes[i] = barClose;
      if(barHigh > high) { high = barHigh; highTime = time; }
      if(barLow < low) { low = barLow; lowTime = time; }
   }

   bool bullishMove = false, bearishMove = false;
   double minimum = MathMax(0.0, InpFirstLegMinimumMovePoints) * _Point;
   for(int earlier = 0; earlier < 29; earlier++)
      for(int later = earlier + 1; later < 30; later++)
      {
         double move = closes[later] - opens[earlier];
         if(move >= minimum) bullishMove = true;
         if(move <= -minimum) bearishMove = true;
      }

   // Apply the same open-to-later-close rule independently to each side.
   if(bullishMove)
      SetTailBodyLeg(g_tailBodyBullLeg, firstTime, highTime, high);
   if(bearishMove)
      SetTailBodyLeg(g_tailBodyBearLeg, firstTime, lowTime, low);

   g_tailBodyOpeningHigh = high;
   g_tailBodyOpeningLow = low;
   for(int i = 0; i < 30; i++)
      RememberTailBodyOpen(opens[i], iTime(_Symbol, PERIOD_M5, newest + 29 - i));
   g_tailBodyLastBar = latestTime;
   g_tailBodyLegInitialized = true;
   return true;
}

bool BuildTailBodyLegFromMove(bool bullish, datetime startTime,
   int lastShift, TailBodyLegState &leg)
{
   int startShift = iBarShift(_Symbol, PERIOD_M5, startTime, true);
   if(startShift <= lastShift || lastShift < 1)
      return false;
   double extreme = bullish ? -DBL_MAX : DBL_MAX;
   datetime extremeTime = 0;
   for(int shift = startShift; shift >= lastShift; shift--)
   {
      double price = bullish ? iHigh(_Symbol, PERIOD_M5, shift)
                             : iLow(_Symbol, PERIOD_M5, shift);
      datetime time = iTime(_Symbol, PERIOD_M5, shift);
      if(price <= 0 || time <= 0)
         return false;
      if((bullish && price > extreme) || (!bullish && price < extreme))
      {
         extreme = price;
         extremeTime = time;
      }
   }
   if(extremeTime <= 0)
      return false;
   SetTailBodyLeg(leg, startTime, extremeTime, extreme);
   return true;
}

void ProcessTailBodyLegBar(int shift)
{
   datetime time = iTime(_Symbol, PERIOD_M5, shift);
   if(time <= g_tailBodyLastBar)
      return;
   double barOpen = iOpen(_Symbol, PERIOD_M5, shift);
   double barClose = iClose(_Symbol, PERIOD_M5, shift);
   double barHigh = iHigh(_Symbol, PERIOD_M5, shift);
   double barLow = iLow(_Symbol, PERIOD_M5, shift);
   if(barOpen <= 0 || barClose <= 0 || barHigh <= 0 || barLow <= 0)
      return;

   // Preserve the existing NEITHER breakout rule for the initial leg.
   if(!g_tailBodyBullLeg.active && !g_tailBodyBearLeg.active)
   {
      if(barClose > g_tailBodyOpeningHigh)
         SetTailBodyLeg(g_tailBodyBullLeg, time, time, barHigh);
      else if(barClose < g_tailBodyOpeningLow)
         SetTailBodyLeg(g_tailBodyBearLeg, time, time, barLow);
   }

   if(g_tailBodyBullLeg.active || g_tailBodyBearLeg.active)
   {
      double minimum = MathMax(0.0, InpFirstLegMinimumMovePoints) * _Point;
      // Only earlier opens are eligible; this bar's open is recorded below.
      if(!g_tailBodyBullLeg.active && g_tailBodyLowestOpenTime > 0 &&
         barClose - g_tailBodyLowestOpen >= minimum)
         BuildTailBodyLegFromMove(true, g_tailBodyLowestOpenTime, shift, g_tailBodyBullLeg);
      if(!g_tailBodyBearLeg.active && g_tailBodyHighestOpenTime > 0 &&
         g_tailBodyHighestOpen - barClose >= minimum)
         BuildTailBodyLegFromMove(false, g_tailBodyHighestOpenTime, shift, g_tailBodyBearLeg);
   }

   if(g_tailBodyBullLeg.active && barHigh > g_tailBodyBullLeg.extremePrice)
   {
      g_tailBodyBullLeg.extremePrice = barHigh;
      g_tailBodyBullLeg.extremeTime = time;
   }
   if(g_tailBodyBearLeg.active && barLow < g_tailBodyBearLeg.extremePrice)
   {
      g_tailBodyBearLeg.extremePrice = barLow;
      g_tailBodyBearLeg.extremeTime = time;
   }
   RememberTailBodyOpen(barOpen, time);
   g_tailBodyLastBar = time;
}

bool GetTailBodyLeg(bool bullish, int &shift, datetime &startTime)
{
   shift = -1;
   startTime = bullish ? g_tailBodyBullLeg.startTime : g_tailBodyBearLeg.startTime;
   bool active = bullish ? g_tailBodyBullLeg.active : g_tailBodyBearLeg.active;
   datetime extremeTime = bullish ? g_tailBodyBullLeg.extremeTime : g_tailBodyBearLeg.extremeTime;
   if(!active || startTime <= 0 || extremeTime <= 0)
      return false;
   shift = iBarShift(_Symbol, PERIOD_M5, extremeTime, true);
   return shift >= 1;
}

void MarkTailBodyLeg(bool bullish)
{
   string side = bullish ? "BULL" : "BEAR";
   string arrow = "NQ_TB_LEG_" + side;
   string arrowLabel = "NQ_TB_LEG_LABEL_" + side;
   string zone = "NQ_TB_BODY_" + side;
   string zoneLabel = "NQ_TB_BODY_LABEL_" + side;
   ObjectDelete(0, arrow); ObjectDelete(0, arrowLabel);
   ObjectDelete(0, zone); ObjectDelete(0, zoneLabel);

   int shift = -1;
   datetime startTime = 0;
   if(!GetTailBodyLeg(bullish, shift, startTime))
      return;
   datetime extremeTime = iTime(_Symbol, PERIOD_M5, shift);
   double extremePrice = bullish ? g_tailBodyBullLeg.extremePrice : g_tailBodyBearLeg.extremePrice;
   color legColor = bullish ? clrTomato : clrLimeGreen;
   if(InpShowFirstLegMarker && ObjectCreate(0, arrow, OBJ_ARROW, 0, extremeTime, extremePrice))
   {
      ObjectSetInteger(0, arrow, OBJPROP_ARROWCODE, bullish ? 234 : 233);
      ObjectSetInteger(0, arrow, OBJPROP_COLOR, legColor);
      ObjectSetInteger(0, arrow, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrow, OBJPROP_SELECTABLE, false);
   }
   if(InpShowFirstLegMarker && ObjectCreate(0, arrowLabel, OBJ_TEXT, 0, extremeTime, extremePrice))
   {
      ObjectSetString(0, arrowLabel, OBJPROP_TEXT, bullish ? "TAILBODY FIRST LEG: BULLISH" : "TAILBODY FIRST LEG: BEARISH");
      ObjectSetInteger(0, arrowLabel, OBJPROP_COLOR, legColor);
      ObjectSetInteger(0, arrowLabel, OBJPROP_ANCHOR, bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, arrowLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, arrowLabel, OBJPROP_SELECTABLE, false);
   }

   int bodyShift = -1, endpointShift = -1;
   double bodyOpen = 0.0, bodyClose = 0.0;
   if(!InpShowFirstLegBodySpaceMarker ||
      !GetBodySpaceForFirstLeg(bullish, shift, startTime, bodyShift, endpointShift, bodyOpen, bodyClose))
      return;
   datetime bodyTime = iTime(_Symbol, PERIOD_M5, bodyShift);
   datetime zoneEnd = iTime(_Symbol, PERIOD_M5, 0);
   if(bodyTime <= 0) return;
   if(zoneEnd <= bodyTime) zoneEnd = bodyTime + PeriodSeconds(PERIOD_M5);
   double high = MathMax(bodyOpen, bodyClose);
   double low = MathMin(bodyOpen, bodyClose);
   color bodyColor = bullish ? clrDodgerBlue : clrOrangeRed;
   if(ObjectCreate(0, zone, OBJ_RECTANGLE, 0, bodyTime, high, zoneEnd, low))
   {
      ObjectSetInteger(0, zone, OBJPROP_COLOR, bodyColor);
      ObjectSetInteger(0, zone, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, zone, OBJPROP_FILL, false);
      ObjectSetInteger(0, zone, OBJPROP_BACK, true);
      ObjectSetInteger(0, zone, OBJPROP_SELECTABLE, false);
   }
   if(ObjectCreate(0, zoneLabel, OBJ_TEXT, 0, bodyTime, high))
   {
      ObjectSetString(0, zoneLabel, OBJPROP_TEXT, bullish ? "TAILBODY BODY: BULLISH LEG" : "TAILBODY BODY: BEARISH LEG");
      ObjectSetInteger(0, zoneLabel, OBJPROP_COLOR, bodyColor);
      ObjectSetInteger(0, zoneLabel, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, zoneLabel, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, zoneLabel, OBJPROP_SELECTABLE, false);
   }
}

void UpdateTailBodyFirstLegs()
{
   datetime nowGMT = TimeGMT();
   datetime dayStart = GMTDayStart(nowGMT);
   if(g_tailBodyLegDay != dayStart)
      ResetTailBodyLegs(dayStart);
   if(!g_firstLegReady || g_firstLegDayStartGMT != dayStart)
      return;
   datetime openingGMT = dayStart + InpEntryStartHourGMT * 3600 + InpEntryStartMinuteGMT * 60;
   datetime openingServer = GMTToServerTime(openingGMT);
   if(!g_tailBodyLegInitialized && !InitializeTailBodyLegs(openingServer))
      return;
   int newestPreOpen = iBarShift(_Symbol, PERIOD_M5, openingServer - 1, false);
   if(newestPreOpen < 1) return;
   for(int shift = newestPreOpen - 1; shift >= 1; shift--)
      ProcessTailBodyLegBar(shift);
   MarkTailBodyLeg(true);
   MarkTailBodyLeg(false);
}

#endif
