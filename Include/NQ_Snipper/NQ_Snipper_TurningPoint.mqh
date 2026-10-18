#ifndef __NQ_SNIPPER_TURNING_POINT__
#define __NQ_SNIPPER_TURNING_POINT__

#include "NQ_Snipper_ConfigState.mqh"

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
   double turnPrice = bullish
      ? iLow(_Symbol, PERIOD_M5, turnShift)
      : iHigh(_Symbol, PERIOD_M5, turnShift);
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

// TailBody V keeps its original three-candle neckline interaction. All other
// pattern modules use the two-stage FindTurningPoint() below.
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


// A shared Turning Point has two distinct stages at the supplied reference
// area. For a buy, the first arrival is bearish and its immediate bullish
// turn opens within the permitted gap. Later, a second arrival of either
// colour must close back in the same reference area. The trade is placed at
// the immediately following (second-turn) candle's open when that opening is
// within the permitted gap of the second arrival close. A sell is inverted.
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
   double arrivalCloseTolerancePoints = -1.0
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

   for(int arrival = firstArrivalSearchShift; arrival >= 3; arrival--)
   {
      double arrivalOpen = iOpen(_Symbol, PERIOD_M5, arrival);
      double arrivalClose = iClose(_Symbol, PERIOD_M5, arrival);
      if(arrivalOpen <= 0 || arrivalClose <= 0 ||
         arrivalClose < referenceLow || arrivalClose > referenceHigh)
      {
         continue;
      }

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
