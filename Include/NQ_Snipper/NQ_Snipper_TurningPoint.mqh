#ifndef __NQ_SNIPPER_TURNING_POINT__
#define __NQ_SNIPPER_TURNING_POINT__

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_Base.mqh"
#include "NQ_Snipper_BaseMarker.mqh"

void ClearFirstTurnMarker(string suffix = "")
{
   ObjectDelete(0, "NQ_SNIPPER_FIRST_TURN_ARROW" + suffix);
   ObjectDelete(0, "NQ_SNIPPER_FIRST_TURN_LABEL" + suffix);
}


void MarkFirstTurn(bool bullish, int turnShift, string suffix = "")
{
   if(!InpShowFirstTurnMarker)
   {
      ClearFirstTurnMarker(suffix);
      return;
   }

   if(turnShift < 1)
      return;

   datetime turnTime = iTime(_Symbol, PERIOD_M5, turnShift);
   // A Turning Point is the hand-off between the arrival close and the
   // turn candle's open.  Its wick is not part of that definition, so draw
   // the marker at the exact price that the gap rule validates.
   double turnPrice = iOpen(_Symbol, PERIOD_M5, turnShift);
   if(turnTime <= 0 || turnPrice <= 0)
      return;

   string arrowName = "NQ_SNIPPER_FIRST_TURN_ARROW" + suffix;
   string labelName = "NQ_SNIPPER_FIRST_TURN_LABEL" + suffix;
   ClearFirstTurnMarker(suffix);

   if(ObjectCreate(0, arrowName, OBJ_ARROW, 0, turnTime, turnPrice))
   {
      ObjectSetInteger(0, arrowName, OBJPROP_ARROWCODE,
         bullish ? 233 : 234);
      ObjectSetInteger(0, arrowName, OBJPROP_COLOR,
         bullish ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, arrowName, OBJPROP_WIDTH, 2);
      ObjectSetInteger(0, arrowName, OBJPROP_SELECTABLE, false);
   }

   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, turnTime, turnPrice))
   {
      ObjectSetString(0, labelName, OBJPROP_TEXT,
         bullish ? "FIRST TURN: BUY" : "FIRST TURN: SELL");
      ObjectSetInteger(0, labelName, OBJPROP_COLOR,
         bullish ? clrDodgerBlue : clrOrangeRed);
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR,
         bullish ? ANCHOR_LOWER : ANCHOR_UPPER);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
   }
}

// A shared Turning Point has two distinct stages at the supplied reference
// area. For a buy, the first arrival is bearish and its immediate bullish
// turn opens within the permitted gap. Later, a second arrival of either
// colour must close back in the same reference area. The trade is placed at
// the immediately following (second-turn) candle's open when that opening is
// within the permitted gap of the second arrival close. A sell is inverted.
// A tiny rounding margin avoids misclassifying prices at the exact point limit.
bool IsNQDoji(double candleOpen, double candleClose, double pointSize,
   double maxBodyPoints)
{
   return MathAbs(candleClose - candleOpen) / pointSize <=
      maxBodyPoints + 0.0000001;
}

bool FindTurningPoint(
   bool bullish,
   int firstArrivalSearchShift,
   double referenceLow,
   double referenceHigh,
   int &firstArrivalShift,
   int &firstTurnShift,
   int &secondArrivalShift,
   int &entryTurnShift,
   string markerSuffix = "",
   double arrivalCloseTolerancePoints = -1.0,
   int baseFirstLegShift = -1,
   double arrivalDojiMaxBodyPoints = -1.0
)
{
   firstArrivalShift = -1;
   firstTurnShift = -1;
   secondArrivalShift = -1;
   entryTurnShift = -1;

   double gapTolerance = InpTurningPointGapTolerancePoints * _Point;

   // Entry is made at the current M5 candle's open. Therefore the second
   // arrival must be the most recently completed bar (shift 1).
   int candidateSecondArrival = 1;
   double secondArrivalOpen = iOpen(_Symbol, PERIOD_M5,
      candidateSecondArrival);
   double secondArrivalClose = iClose(_Symbol, PERIOD_M5,
      candidateSecondArrival);
   double entryTurnOpen = iOpen(_Symbol, PERIOD_M5, 0);

   bool secondTurningPointIsReady =
      secondArrivalOpen > 0 && secondArrivalClose > 0 &&
      entryTurnOpen > 0 && secondArrivalClose >= referenceLow &&
      secondArrivalClose <= referenceHigh &&
      MathAbs(entryTurnOpen - secondArrivalClose) <= gapTolerance;

   if(!InpShowFirstTurnMarker)
      ClearFirstTurnMarker(markerSuffix);

   bool firstTurnMarked = false;

   // Shift 2 permits marking a turn that just closed at shift 1. It cannot
   // trigger an entry because the second arrival must follow the turn.
   for(int arrival = firstArrivalSearchShift; arrival >= 2; arrival--)
   {
      double arrivalOpen = iOpen(_Symbol, PERIOD_M5, arrival);
      double arrivalClose = iClose(_Symbol, PERIOD_M5, arrival);
      if(arrivalOpen <= 0 || arrivalClose <= 0 ||
         arrivalClose < referenceLow || arrivalClose > referenceHigh)
      {
         continue;
      }

      // TailBody opts in even if its base filter is disabled.
      if(arrivalDojiMaxBodyPoints >= 0.0 &&
         IsNQDoji(arrivalOpen, arrivalClose, _Point, arrivalDojiMaxBodyPoints))
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
      {
         continue;
      }

      bool turnsAway = bullish
         ? turnClose > turnOpen
         : turnClose < turnOpen;
      if(!turnsAway)
         continue;

      // TailBody alone opts in by passing its marked first-leg shift.
      // Both effective boundary candles are excluded from the search.
      if(baseFirstLegShift >= 1)
      {
         int oldestShift = baseFirstLegShift - 1;
         int newestShift = arrival + 1;
         int barCount = oldestShift - newestShift + 1;
         if(barCount >= InpBaseMinimumCandles)
         {
            double legOpen = iOpen(_Symbol, PERIOD_M5, baseFirstLegShift);
            double legClose = iClose(_Symbol, PERIOD_M5, baseFirstLegShift);
            double beforeOpen = iOpen(_Symbol, PERIOD_M5, arrival + 1);
            double beforeClose = iClose(_Symbol, PERIOD_M5, arrival + 1);
            if(legOpen <= 0 || legClose <= 0 || beforeOpen <= 0 || beforeClose <= 0)
            {
               ClearFirstTurnMarker(markerSuffix);
               return false;
            }
            if(IsNQDoji(legOpen, legClose, _Point, arrivalDojiMaxBodyPoints))
               oldestShift--;  // Exclude the candle immediately after the leg.
            if(IsNQDoji(beforeOpen, beforeClose, _Point, arrivalDojiMaxBodyPoints))
               newestShift++;  // Exclude the doji immediately before arrival.

            if(InpEnableBaseStartDistance)
            {
               // Scan chronologically from just after the marked first leg.
               // A sell's bullish leg requires an open below its close; a
               // buy's bearish leg requires an open above its close.
               bool startBoundaryFound = false;
               for(int boundary = baseFirstLegShift - 1;
                   boundary >= newestShift; boundary--)
               {
                  double boundaryOpen = iOpen(_Symbol, PERIOD_M5, boundary);
                  if(boundaryOpen <= 0)
                  {
                     ClearFirstTurnMarker(markerSuffix);
                     return false;
                  }
                  double distancePoints = (bullish
                     ? boundaryOpen - legClose : legClose - boundaryOpen) / _Point;
                  if(distancePoints >= 2000.0 - 0.0000001)
                  {
                     // The qualifying candle is a boundary, not part of the base.
                     oldestShift = (int)MathMin(oldestShift, boundary - 1);
                     startBoundaryFound = true;
                     break;
                  }
               }
               // Without a qualifying boundary there is no base to reject.
               if(!startBoundaryFound)
                  oldestShift = newestShift - 1;
            }
            barCount = oldestShift - newestShift + 1;
         }
         if(barCount >= InpBaseMinimumCandles)
         {
            MqlRates baseCandles[];
            if(CopyRates(_Symbol, PERIOD_M5, newestShift, barCount, baseCandles) != barCount)
            {
               ClearFirstTurnMarker(markerSuffix);
               return false;
            }
            NQBaseZone base;
            bool foundBase = false;
            if(!FindNQTwoEndedBase(baseCandles,_Point,InpBaseMinimumCandles,
               InpBaseOpenTolerancePoints,InpBaseCloseTolerancePoints,
               InpBaseValidityMinutes,base,foundBase))
            {
               ClearFirstTurnMarker(markerSuffix);
               return false;
            }
            if(foundBase)
            {
               MarkNQBase(base, "TailBody setup ignored");
               ClearFirstTurnMarker(markerSuffix);
               return false;
            }
         }
      }

      // Show the first completed directional turn even if the later second
      // Turning Point has not yet arrived.
      if(!firstTurnMarked)
      {
         MarkFirstTurn(bullish, turn, markerSuffix);
         firstTurnMarked = true;
      }

      // The second arrival may follow immediately or after any number of
      // intervening candles, but it must occur after the first turn.
      if(!secondTurningPointIsReady || turn <= candidateSecondArrival)
         continue;

      // TailBody optionally limits the distance between the two arrival closes.
      if(arrivalCloseTolerancePoints >= 0.0 &&
         MathAbs(arrivalClose - secondArrivalClose) >
            (arrivalCloseTolerancePoints + 0.000001) * _Point)
         continue;

      if(InpShowFirstTurnMarker && arrivalCloseTolerancePoints >= 0.0)
         MarkFirstTurn(bullish, turn, markerSuffix);

      firstArrivalShift = arrival;
      firstTurnShift = turn;
      secondArrivalShift = candidateSecondArrival;
      entryTurnShift = 0;
      return true;
   }

   return false;
}

#endif
