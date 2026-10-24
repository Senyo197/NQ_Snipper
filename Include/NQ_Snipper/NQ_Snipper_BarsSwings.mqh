#ifndef __NQ_SNIPPER_BARS_SWINGS__
#define __NQ_SNIPPER_BARS_SWINGS__

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_TimeCalendar.mqh"

//==================================================
// CHECK NEW M5 BAR
//==================================================

bool IsNewM5Bar()
{
   datetime currentBarTime =
      iTime(_Symbol, PERIOD_M5, 0);

   if(currentBarTime <= 0)
      return false;

   if(currentBarTime == g_lastBarTime)
      return false;

   g_lastBarTime = currentBarTime;

   return true;
}


//==================================================
// TESTING MARKER: SHARED FIRST LEG
//==================================================

void ClearFirstLegBodySpaceMarker()
{
   ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_BODY_SPACE");
   ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_BODY_SPACE_LABEL");
}


void MarkFirstLegBodySpace()
{
   if(!InpShowFirstLegBodySpaceMarker || !g_firstLegReady ||
      g_firstLegDirection == FIRST_LEG_NEITHER || g_firstLegTime <= 0 ||
      g_firstLegStartTime <= 0)
   {
      ClearFirstLegBodySpaceMarker();
      return;
   }

   bool bullish = g_firstLegDirection == FIRST_LEG_BULLISH;
   int bodyShift = -1;
   int tailLegEndpointShift = -1;
   double bodyOpen = 0.0;
   double bodyClose = 0.0;
   if(!GetFirstLegBodySpace(bullish, bodyShift, tailLegEndpointShift,
      bodyOpen, bodyClose))
   {
      ClearFirstLegBodySpaceMarker();
      return;
   }

   datetime bodyTime = iTime(_Symbol, PERIOD_M5, bodyShift);
   if(bodyTime <= 0)
   {
      ClearFirstLegBodySpaceMarker();
      return;
   }

   double bodyHigh = MathMax(bodyOpen, bodyClose);
   double bodyLow = MathMin(bodyOpen, bodyClose);
   datetime zoneEndTime = iTime(_Symbol, PERIOD_M5, 0);
   if(zoneEndTime <= bodyTime)
      zoneEndTime = bodyTime + PeriodSeconds(PERIOD_M5);

   string zoneName = "NQ_SNIPPER_FIRST_LEG_BODY_SPACE";
   string labelName = "NQ_SNIPPER_FIRST_LEG_BODY_SPACE_LABEL";
   ClearFirstLegBodySpaceMarker();

   if(ObjectCreate(0, zoneName, OBJ_RECTANGLE, 0, bodyTime, bodyHigh,
      zoneEndTime, bodyLow))
   {
      ObjectSetInteger(0, zoneName, OBJPROP_COLOR,
         bullish ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, zoneName, OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, zoneName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, zoneName, OBJPROP_FILL, false);
      ObjectSetInteger(0, zoneName, OBJPROP_BACK, true);
      ObjectSetInteger(0, zoneName, OBJPROP_SELECTABLE, false);
   }

   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, bodyTime, bodyHigh))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT, "FIRST LEG BODY SPACE");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR,
         bullish ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LOWER);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}


void MarkFirstLeg()
{
   if(!InpShowFirstLegMarker || !g_firstLegReady ||
      g_firstLegDirection == FIRST_LEG_NEITHER ||
      g_firstLegTime <= 0 || g_firstLegPrice <= 0)
      return;

   bool bullish = g_firstLegDirection == FIRST_LEG_BULLISH;
   string arrowName = "NQ_SNIPPER_FIRST_LEG_ARROW";
   string labelName = "NQ_SNIPPER_FIRST_LEG_LABEL";

   ObjectDelete(0, arrowName);
   ObjectDelete(0, labelName);

   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0,
      g_firstLegTime, g_firstLegPrice))
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE, bullish ? 234 : 233);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR, bullish ? clrTomato : clrLimeGreen);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   }

   if(ObjectCreate(0, labelName, OBJ_TEXT, 0,
      g_firstLegTime, g_firstLegPrice))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT,
         bullish ? "FIRST LEG: BULLISH" : "FIRST LEG: BEARISH");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, bullish ? clrTomato : clrLimeGreen);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR,
         bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}


//==================================================
// SHARED FIRST LEG FROM THE 30 BARS BEFORE THE OPEN
//==================================================

void ResetFirstLeg(datetime dayStartGMT)
{
   g_firstLegDayStartGMT = dayStartGMT;
   g_firstLegLastProcessedBar = 0;
   g_firstLegDirection = FIRST_LEG_NEITHER;
   g_firstLegRangeHigh = 0.0;
   g_firstLegRangeLow = 0.0;
   g_firstLegPrice = 0.0;
   g_firstLegTime = 0;
   g_firstLegStartTime = 0;
   g_firstLegReady = false;

   ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_ARROW");
   ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_LABEL");
   ClearFirstLegBodySpaceMarker();
}

bool InitializeFirstLeg(datetime openingServerTime)
{
   // The bar at openingServerTime is excluded. This is the last completed
   // M5 candle immediately before the configured opening time.
   int newestPreOpenShift = iBarShift(_Symbol, PERIOD_M5,
      openingServerTime - 1, false);
   int bars = Bars(_Symbol, PERIOD_M5);
   if(newestPreOpenShift < 1 ||
      newestPreOpenShift + 29 >= bars || _Point <= 0)
      return false;

   datetime newestPreOpenTime = iTime(_Symbol, PERIOD_M5,
      newestPreOpenShift);
   if(newestPreOpenTime <= 0 ||
      newestPreOpenTime + PeriodSeconds(PERIOD_M5) != openingServerTime)
      return false;

   double opens[30];
   double closes[30];
   double rangeHigh = -DBL_MAX;
   double rangeLow = DBL_MAX;
   datetime highTime = 0;
   datetime lowTime = 0;
   datetime firstWindowBarTime = 0;

   // Array index zero is the oldest of the 30 completed pre-open bars.
   for(int i = 0; i < 30; i++)
   {
      int shift = newestPreOpenShift + 29 - i;
      double barOpen = iOpen(_Symbol, PERIOD_M5, shift);
      double barClose = iClose(_Symbol, PERIOD_M5, shift);
      double barHigh = iHigh(_Symbol, PERIOD_M5, shift);
      double barLow = iLow(_Symbol, PERIOD_M5, shift);
      datetime barTime = iTime(_Symbol, PERIOD_M5, shift);
      if(barOpen <= 0 || barClose <= 0 || barHigh <= 0 ||
         barLow <= 0 || barTime <= 0)
         return false;

      opens[i] = barOpen;
      closes[i] = barClose;
      if(i == 0)
         firstWindowBarTime = barTime;
      if(barHigh > rangeHigh)
      {
         rangeHigh = barHigh;
         highTime = barTime;
      }
      if(barLow < rangeLow)
      {
         rangeLow = barLow;
         lowTime = barTime;
      }
   }

   bool bullishMove = false;
   bool bearishMove = false;
   double minimumMove = MathMax(0.0,
      InpFirstLegMinimumMovePoints) * _Point;
   for(int earlier = 0; earlier < 29; earlier++)
   {
      for(int later = earlier + 1; later < 30; later++)
      {
         double move = closes[later] - opens[earlier];
         if(move >= minimumMove)
            bullishMove = true;
         if(move <= -minimumMove)
            bearishMove = true;
      }
   }

   g_firstLegRangeHigh = rangeHigh;
   g_firstLegRangeLow = rangeLow;
   g_firstLegDirection = bullishMove && !bearishMove
      ? FIRST_LEG_BULLISH : bearishMove && !bullishMove
      ? FIRST_LEG_BEARISH : FIRST_LEG_NEITHER;
   if(g_firstLegDirection != FIRST_LEG_NEITHER)
      g_firstLegStartTime = firstWindowBarTime;
   if(g_firstLegDirection == FIRST_LEG_BULLISH)
   {
      g_firstLegPrice = rangeHigh;
      g_firstLegTime = highTime;
   }
   else if(g_firstLegDirection == FIRST_LEG_BEARISH)
   {
      g_firstLegPrice = rangeLow;
      g_firstLegTime = lowTime;
   }

   g_firstLegReady = true;
   Print("FIRST LEG: 30-bar opening classification = ",
      g_firstLegDirection == FIRST_LEG_BULLISH ? "BULLISH" :
      g_firstLegDirection == FIRST_LEG_BEARISH ? "BEARISH" : "NEITHER",
      "; range=", DoubleToString(rangeLow, _Digits), " to ",
      DoubleToString(rangeHigh, _Digits));
   return true;
}

void ProcessFirstLegBar(int shift)
{
   datetime barTime = iTime(_Symbol, PERIOD_M5, shift);
   if(barTime <= g_firstLegLastProcessedBar)
      return;

   double barClose = iClose(_Symbol, PERIOD_M5, shift);
   double barHigh = iHigh(_Symbol, PERIOD_M5, shift);
   double barLow = iLow(_Symbol, PERIOD_M5, shift);
   if(barClose <= 0 || barHigh <= 0 || barLow <= 0)
      return;

   if(g_firstLegDirection == FIRST_LEG_NEITHER)
   {
      // A closed M5 candle beyond the original range resolves NEITHER.
      if(barClose > g_firstLegRangeHigh)
      {
         g_firstLegDirection = FIRST_LEG_BULLISH;
         g_firstLegPrice = g_firstLegRangeHigh;
         g_firstLegTime = 0;
         g_firstLegStartTime = barTime;
      }
      else if(barClose < g_firstLegRangeLow)
      {
         g_firstLegDirection = FIRST_LEG_BEARISH;
         g_firstLegPrice = g_firstLegRangeLow;
         g_firstLegTime = 0;
         g_firstLegStartTime = barTime;
      }
   }

   if(g_firstLegDirection == FIRST_LEG_BULLISH &&
      (barHigh > g_firstLegPrice || g_firstLegTime == 0))
   {
      g_firstLegPrice = barHigh;
      g_firstLegTime = barTime;
   }
   else if(g_firstLegDirection == FIRST_LEG_BEARISH &&
      (barLow < g_firstLegPrice || g_firstLegTime == 0))
   {
      g_firstLegPrice = barLow;
      g_firstLegTime = barTime;
   }

   g_firstLegLastProcessedBar = barTime;
}

void UpdateFirstLeg()
{
   datetime nowGMT = TimeGMT();
   datetime dayStartGMT = GMTDayStart(nowGMT);
   if(g_firstLegDayStartGMT != dayStartGMT)
      ResetFirstLeg(dayStartGMT);

   datetime openingGMT = dayStartGMT +
      InpEntryStartHourGMT * 3600 + InpEntryStartMinuteGMT * 60;
   if(nowGMT < openingGMT)
      return;

   datetime openingServerTime = GMTToServerTime(openingGMT);
   if(!g_firstLegReady && !InitializeFirstLeg(openingServerTime))
      return;

   int newestPreOpenShift = iBarShift(_Symbol, PERIOD_M5,
      openingServerTime - 1, false);
   if(newestPreOpenShift < 1)
      return;

   // Replays missed completed bars after restart, then processes one new bar
   // per call during normal operation.
   for(int shift = newestPreOpenShift - 1; shift >= 1; shift--)
      ProcessFirstLegBar(shift);

   // Normal TailBody owns its dynamic leg/body markers.  Showing these shared
   // opening-leg markers at the same time creates duplicate descriptions.
   if(InpEnableTailBodyPattern)
   {
      ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_ARROW");
      ObjectDelete(0, "NQ_SNIPPER_FIRST_LEG_LABEL");
      ClearFirstLegBodySpaceMarker();
   }
   else
   {
      MarkFirstLeg();
      MarkFirstLegBodySpace();
   }
}


bool GetFirstLegCandle(
   bool bullish,
   int &shift,
   double &openPrice,
   double &closePrice
)
{
   shift = -1;
   openPrice = 0.0;
   closePrice = 0.0;

   int requiredDirection = bullish
      ? FIRST_LEG_BULLISH
      : FIRST_LEG_BEARISH;

   if(!g_firstLegReady || g_firstLegDirection != requiredDirection ||
      g_firstLegTime <= 0)
      return false;

   shift = iBarShift(_Symbol, PERIOD_M5, g_firstLegTime, true);
   if(shift < 1)
      return false;

   openPrice = iOpen(_Symbol, PERIOD_M5, shift);
   closePrice = iClose(_Symbol, PERIOD_M5, shift);
   return openPrice > 0 && closePrice > 0;
}


// Finds the latest valid TailBody pair at or before the broad first-leg
// extreme. This lets a wick made by an opposite-colour extreme candle remain
// part of the broad first leg without discarding the preceding directional
// pair that defines the TailBody body space.
bool GetBodySpaceForFirstLeg(
   bool bullish,
   int broadEndpointShift,
   datetime firstLegStartTime,
   int &bodyShift,
   int &tailLegEndpointShift,
   double &bodyOpen,
   double &bodyClose
)
{
   bodyShift = -1;
   tailLegEndpointShift = -1;
   bodyOpen = 0.0;
   bodyClose = 0.0;

   if(broadEndpointShift < 1 || firstLegStartTime <= 0)
   {
      return false;
   }

   int firstLegStartShift = iBarShift(_Symbol, PERIOD_M5,
      firstLegStartTime, true);
   if(firstLegStartShift <= broadEndpointShift)
      return false;

   // Smaller shifts are newer. Start at the broad extreme and move backward
   // in time so the first matching pair is the latest valid directional pair.
   for(int endpoint = broadEndpointShift;
      endpoint < firstLegStartShift; endpoint++)
   {
      double endpointOpen = iOpen(_Symbol, PERIOD_M5, endpoint);
      double endpointClose = iClose(_Symbol, PERIOD_M5, endpoint);
      if(endpointOpen <= 0 || endpointClose <= 0 ||
         (bullish ? endpointClose <= endpointOpen
                  : endpointClose >= endpointOpen))
         continue;

      // Prefer the nearest earlier qualifying body candle. When the toggle
      // is on, only the immediately preceding M5 candle may be considered.
      int oldestBodyShift = InpTailBodyRequireConsecutiveLegCandles
         ? endpoint + 1 : firstLegStartShift;
      for(int candidateBody = endpoint + 1;
         candidateBody <= oldestBodyShift; candidateBody++)
      {
         datetime candidateBodyTime = iTime(_Symbol, PERIOD_M5,
            candidateBody);
         double candidateBodyOpen = iOpen(_Symbol, PERIOD_M5, candidateBody);
         double candidateBodyClose = iClose(_Symbol, PERIOD_M5, candidateBody);
         if(candidateBodyTime <= 0 ||
             candidateBodyTime < firstLegStartTime ||
            candidateBodyOpen <= 0 || candidateBodyClose <= 0)
         {
            continue;
         }

         bool isValidPair = bullish
            ? candidateBodyClose > candidateBodyOpen &&
              endpointClose > candidateBodyClose
            : candidateBodyClose < candidateBodyOpen &&
              endpointClose < candidateBodyClose;
         if(!isValidPair)
            continue;

         bodyShift = candidateBody;
         tailLegEndpointShift = endpoint;
         bodyOpen = candidateBodyOpen;
         bodyClose = candidateBodyClose;
         return true;
      }
   }

   return false;
}


bool GetFirstLegBodySpace(
   bool bullish, int &bodyShift, int &tailLegEndpointShift,
   double &bodyOpen, double &bodyClose)
{
   bodyShift = -1;
   tailLegEndpointShift = -1;
   bodyOpen = 0.0;
   bodyClose = 0.0;
   int broadEndpointShift = -1;
   double ignoredOpen = 0.0, ignoredClose = 0.0;
   if(!GetFirstLegCandle(bullish, broadEndpointShift, ignoredOpen,
      ignoredClose))
      return false;
   return GetBodySpaceForFirstLeg(bullish, broadEndpointShift,
      g_firstLegStartTime, bodyShift, tailLegEndpointShift, bodyOpen, bodyClose);
}


bool GetFirstLegNeckline(
   bool bullish,
   double &neckline,
   int &necklineShift
)
{
   neckline = 0.0;
   necklineShift = -1;

   int firstLegShift = -1;
   double ignoredOpen = 0.0;
   double ignoredClose = 0.0;
   if(!GetFirstLegCandle(bullish, firstLegShift,
      ignoredOpen, ignoredClose) || g_firstLegStartTime <= 0)
      return false;

   int startShift = iBarShift(_Symbol, PERIOD_M5,
      g_firstLegStartTime, true);
   if(startShift < firstLegShift)
      return false;

   // Search backwards from the final first-leg candle. The first matching
   // candle is therefore the last bullish/bearish candle of that first leg.
   for(int shift = firstLegShift; shift <= startShift; shift++)
   {
      double barOpen = iOpen(_Symbol, PERIOD_M5, shift);
      double barClose = iClose(_Symbol, PERIOD_M5, shift);
      if(barOpen <= 0 || barClose <= 0)
         continue;

      bool sameDirection = bullish
         ? barClose > barOpen
         : barClose < barOpen;
      if(!sameDirection)
         continue;

      neckline = barOpen;
      necklineShift = shift;
      return true;
   }

   return false;
}


//==================================================
// SWING HIGH
//==================================================

bool IsSwingHigh(int shift)
{
   if(shift < InpSwingStrength)
      return false;

   double center =
      iHigh(_Symbol, PERIOD_M5, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      double left =
         iHigh(_Symbol, PERIOD_M5, shift + i);

      double right =
         iHigh(_Symbol, PERIOD_M5, shift - i);

      if(center <= left)
         return false;

      if(center <= right)
         return false;
   }

   return true;
}


//==================================================
// SWING LOW
//==================================================

bool IsSwingLow(int shift)
{
   if(shift < InpSwingStrength)
      return false;

   double center =
      iLow(_Symbol, PERIOD_M5, shift);

   if(center <= 0)
      return false;

   for(int i = 1; i <= InpSwingStrength; i++)
   {
      double left =
         iLow(_Symbol, PERIOD_M5, shift + i);

      double right =
         iLow(_Symbol, PERIOD_M5, shift - i);

      if(center >= left)
         return false;

      if(center >= right)
         return false;
   }

   return true;
}


#endif
