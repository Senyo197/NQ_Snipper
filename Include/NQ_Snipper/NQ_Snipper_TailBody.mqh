#ifndef __NQ_SNIPPER_TAIL_BODY__
#define __NQ_SNIPPER_TAIL_BODY__

#include <Trade/Trade.mqh>

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_BarsSwings.mqh"
#include "NQ_Snipper_Orders.mqh"
#include "NQ_Snipper_Spread.mqh"


//==================================================
// BODY CANDLE LIMITS
//==================================================

#define TAIL_BODY_MIN_CANDLES 3


//==================================================
// GET CANDLE RANGE
//==================================================

double TailBodyCandleRange(
   int shift
)
{
   double high =
      iHigh(
         _Symbol,
         PERIOD_M5,
         shift
      );

   double low =
      iLow(
         _Symbol,
         PERIOD_M5,
         shift
      );

   if(high <= 0 || low <= 0)
      return 0.0;

   return high - low;
}


//==================================================
// CHECK BODY RANGE
//==================================================

bool TailBodyRangeValid(
   int newestShift,
   int oldestShift,
   double &bodyHigh,
   double &bodyLow
)
{
   bodyHigh =
      -DBL_MAX;

   bodyLow =
      DBL_MAX;


   for(
      int shift = newestShift;
      shift <= oldestShift;
      shift++
   )
   {
      double high =
         iHigh(
            _Symbol,
            PERIOD_M5,
            shift
         );

      double low =
         iLow(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(high <= 0 || low <= 0)
         return false;


      if(high > bodyHigh)
         bodyHigh = high;

      if(low < bodyLow)
         bodyLow = low;
   }


   double range =
      bodyHigh - bodyLow;

   double maximumRange =
      InpDoubleTolerancePoints * _Point;


   if(range > maximumRange)
      return false;


   return true;
}


//==================================================
// CHECK BODY CLOSE CLUSTER
//==================================================

bool TailBodyClosesClustered(
   int newestShift,
   int oldestShift
)
{
   double highestClose =
      -DBL_MAX;

   double lowestClose =
      DBL_MAX;


   for(
      int shift = newestShift;
      shift <= oldestShift;
      shift++
   )
   {
      double close =
         iClose(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(close <= 0)
         return false;


      if(close > highestClose)
         highestClose = close;

      if(close < lowestClose)
         lowestClose = close;
   }


   double closeRange =
      highestClose - lowestClose;

   double maximumCloseRange =
      InpDoubleTolerancePoints * _Point;


   if(closeRange > maximumCloseRange)
      return false;


   return true;
}


//==================================================
// CHECK BODY CONTINUATION
//==================================================

bool TailBodyNoStrongContinuation(
   int newestShift,
   int oldestShift
)
{
   double maximumRange =
      InpDoubleTolerancePoints * _Point;


   for(
      int shift = newestShift;
      shift <= oldestShift;
      shift++
   )
   {
      double candleRange =
         TailBodyCandleRange(
            shift
         );

      if(candleRange <= 0)
         return false;


      if(candleRange > maximumRange)
         return false;
   }


   return true;
}


bool FindTailBodyFormation(
   int newestShift,
   int &bodyOldestShift,
   double &bodyHigh,
   double &bodyLow
)
{
   bodyOldestShift =
      -1;

   bodyHigh =
      0.0;

   bodyLow =
      0.0;


   int totalBars =
      Bars(
         _Symbol,
         PERIOD_M5
      );


   //================================================
   // START AT THE MINIMUM BODY SIZE
   //================================================

   for(
      int candleCount = TAIL_BODY_MIN_CANDLES;
      ;
      candleCount++
   )
   {
      int oldestShift =
         newestShift +
         candleCount -
         1;


      //================================================
      // NO MORE HISTORY
      //================================================

      if(oldestShift >= totalBars)
         break;


      //================================================
      // CHECK BODY RANGE
      //================================================

      double testHigh =
         0.0;

      double testLow =
         0.0;


      if(
         !TailBodyRangeValid(
            newestShift,
            oldestShift,
            testHigh,
            testLow
         )
      )
      {
         break;
      }


      //================================================
      // CHECK CLOSE CLUSTER
      //================================================

      if(
         !TailBodyClosesClustered(
            newestShift,
            oldestShift
         )
      )
      {
         break;
      }


      //================================================
      // CHECK FOR STRONG CONTINUATION
      //================================================

      if(
         !TailBodyNoStrongContinuation(
            newestShift,
            oldestShift
         )
      )
      {
         break;
      }


      //================================================
      // BODY STILL VALID
      //================================================

      bodyOldestShift =
         oldestShift;

      bodyHigh =
         testHigh;

      bodyLow =
         testLow;


      // Continue checking older candles.
   }


   //================================================
   // BODY MUST CONTAIN AT LEAST THE MINIMUM CANDLES
   //================================================

   if(bodyOldestShift < 0)
      return false;


   return true;
}


//==================================================
// CHECK PRICE INSIDE BODY ZONE
//==================================================

bool TailBodyPriceInsideZone(
   double price,
   double bodyHigh,
   double bodyLow
)
{
   double tolerance =
      InpDoubleTolerancePoints * _Point;


   if(
      price >= bodyLow - tolerance &&
      price <= bodyHigh + tolerance
   )
   {
      return true;
   }


   return false;
}


//==================================================
// COUNT BODY RETESTS
//==================================================

int CountTailBodyRetests(
   int newestShift,
   int oldestShift,
   double bodyHigh,
   double bodyLow
)
{
   int retests =
      0;

   bool wasOutside =
      false;


   for(
      int shift = oldestShift;
      shift >= newestShift;
      shift--
   )
   {
      double high =
         iHigh(
            _Symbol,
            PERIOD_M5,
            shift
         );

      double low =
         iLow(
            _Symbol,
            PERIOD_M5,
            shift
         );

      if(high <= 0 || low <= 0)
         continue;


      bool inside =
         (
            high >= bodyLow &&
            low <= bodyHigh
         );


      if(!inside)
      {
         wasOutside =
            true;

         continue;
      }


      if(wasOutside)
      {
         retests++;

         wasOutside =
            false;
      }
   }


   return retests;
}


//==================================================
// FIND TAIL & BODY TOP
//==================================================

bool FindTailAndBodyTop(
   int &breakShift,
   int &reversalShift,
   int &retestCount
)
{
   breakShift =
      -1;

   reversalShift =
      -1;

   retestCount =
      0;


   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );


   if(bars < InpMaxPatternBars + 10)
      return false;


   //================================================
   // SEARCH FOR KEY SWING HIGH
   //================================================

   for(
      int keyShift = InpSwingStrength + 1;
      keyShift <= InpMaxPatternBars;
      keyShift++
   )
   {
      if(
         !IsSwingHigh(
            keyShift
         )
      )
      {
         continue;
      }


      double keyLevel =
         iHigh(
            _Symbol,
            PERIOD_M5,
            keyShift
         );


      if(keyLevel <= 0)
         continue;


      //================================================
      // SEARCH FOR BREAK ABOVE KEY LEVEL
      //================================================

      for(
         int candidateShift = keyShift - 1;
         candidateShift >= 3;
         candidateShift--
      )
      {
         double candidateHigh =
            iHigh(
               _Symbol,
               PERIOD_M5,
               candidateShift
            );

         double candidateClose =
            iClose(
               _Symbol,
               PERIOD_M5,
               candidateShift
            );


         if(
            candidateHigh <=
            keyLevel +
            InpEntryBufferPoints * _Point
         )
         {
            continue;
         }


         //================================================
         // BREAK MUST HAVE SUFFICIENT EXTENSION
         //
         // Existing InpMinRetracementPoints is reused
         // as the minimum tail extension.
         //================================================

         double extension =
            candidateHigh -
            keyLevel;


         if(
            extension <
            InpMinRetracementPoints * _Point
         )
         {
            continue;
         }


         //================================================
         // SEARCH FOR REJECTION
         //================================================

         for(
            int reversalCandidate =
               candidateShift - 1;

            reversalCandidate >= 2;

            reversalCandidate--
         )
         {
            double reversalClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  reversalCandidate
               );


            if(
               reversalClose >= keyLevel
            )
            {
               continue;
            }


            //================================================
            // BODY MUST FORM AFTER REJECTION
            //================================================

            int bodyOldestShift =
               -1;

            double bodyHigh =
               0.0;

            double bodyLow =
               0.0;


            int bodyNewestShift =
               reversalCandidate - 1;


            if(bodyNewestShift < 1)
               continue;


            if(
               !FindTailBodyFormation(
                  bodyNewestShift,
                  bodyOldestShift,
                  bodyHigh,
                  bodyLow
               )
            )
            {
               continue;
            }


            //================================================
            // BODY MUST BE RELATED TO BREAK AREA
            //================================================

            if(
               keyLevel <
                  bodyLow -
                  InpDoubleTolerancePoints * _Point
            )
            {
               continue;
            }


            if(
               keyLevel >
                  bodyHigh +
                  InpDoubleTolerancePoints * _Point
            )
            {
               continue;
            }


            //================================================
            // SEARCH FOR RETEST AFTER BODY
            //================================================

            int retestStart =
               bodyNewestShift - 1;


            if(retestStart < 1)
               continue;


            retestCount =
               CountTailBodyRetests(
                  retestStart,
                  1,
                  bodyHigh,
                  bodyLow
               );


            if(retestCount < 2)
               continue;


            //================================================
            // CONFIRM PRICE MOVED AWAY DOWN
            //================================================

            double latestClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  1
               );


            if(
               latestClose >= bodyLow
            )
            {
               continue;
            }


            breakShift =
               candidateShift;

            reversalShift =
               reversalCandidate;

            return true;
         }
      }
   }


   return false;
}


//==================================================
// FIND TAIL & BODY BOTTOM
//==================================================

bool FindTailAndBodyBottom(
   int &breakShift,
   int &reversalShift,
   int &retestCount
)
{
   breakShift =
      -1;

   reversalShift =
      -1;

   retestCount =
      0;


   int bars =
      Bars(
         _Symbol,
         PERIOD_M5
      );


   if(bars < InpMaxPatternBars + 10)
      return false;


   //================================================
   // SEARCH FOR KEY SWING LOW
   //================================================

   for(
      int keyShift = InpSwingStrength + 1;
      keyShift <= InpMaxPatternBars;
      keyShift++
   )
   {
      if(
         !IsSwingLow(
            keyShift
         )
      )
      {
         continue;
      }


      double keyLevel =
         iLow(
            _Symbol,
            PERIOD_M5,
            keyShift
         );


      if(keyLevel <= 0)
         continue;


      //================================================
      // SEARCH FOR BREAK BELOW KEY LEVEL
      //================================================

      for(
         int candidateShift = keyShift - 1;
         candidateShift >= 3;
         candidateShift--
      )
      {
         double candidateLow =
            iLow(
               _Symbol,
               PERIOD_M5,
               candidateShift
            );


         if(
            candidateLow >=
            keyLevel -
            InpEntryBufferPoints * _Point
         )
         {
            continue;
         }


         //================================================
         // BREAK MUST HAVE SUFFICIENT EXTENSION
         //================================================

         double extension =
            keyLevel -
            candidateLow;


         if(
            extension <
            InpMinRetracementPoints * _Point
         )
         {
            continue;
         }


         //================================================
         // SEARCH FOR REJECTION
         //================================================

         for(
            int reversalCandidate =
               candidateShift - 1;

            reversalCandidate >= 2;

            reversalCandidate--
         )
         {
            double reversalClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  reversalCandidate
               );


            if(
               reversalClose <= keyLevel
            )
            {
               continue;
            }


            //================================================
            // BODY MUST FORM AFTER REJECTION
            //================================================

            int bodyOldestShift =
               -1;

            double bodyHigh =
               0.0;

            double bodyLow =
               0.0;


            int bodyNewestShift =
               reversalCandidate - 1;


            if(bodyNewestShift < 1)
               continue;


            if(
               !FindTailBodyFormation(
                  bodyNewestShift,
                  bodyOldestShift,
                  bodyHigh,
                  bodyLow
               )
            )
            {
               continue;
            }


            //================================================
            // BODY MUST BE RELATED TO BREAK AREA
            //================================================

            if(
               keyLevel <
                  bodyLow -
                  InpDoubleTolerancePoints * _Point
            )
            {
               continue;
            }


            if(
               keyLevel >
                  bodyHigh +
                  InpDoubleTolerancePoints * _Point
            )
            {
               continue;
            }


            //================================================
            // SEARCH FOR RETEST AFTER BODY
            //================================================

            int retestStart =
               bodyNewestShift - 1;


            if(retestStart < 1)
               continue;


            retestCount =
               CountTailBodyRetests(
                  retestStart,
                  1,
                  bodyHigh,
                  bodyLow
               );


            if(retestCount < 2)
               continue;


            //================================================
            // CONFIRM PRICE MOVED AWAY UP
            //================================================

            double latestClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  1
               );


            if(
               latestClose <= bodyHigh
            )
            {
               continue;
            }


            breakShift =
               candidateShift;

            reversalShift =
               reversalCandidate;

            return true;
         }
      }
   }


   return false;
}


//==================================================
// DETECT TAIL & BODY PATTERN
//==================================================

void DetectTailAndBodyPattern(
   CTrade &trade
)
{
   //================================================
   // ENGINE MUST BE ACTIVE
   //================================================

   if(!g_patternEngineActive)
      return;


   //================================================
   // ONLY ONE TRADE PER NEWS CYCLE
   //================================================

   if(g_tradePlacedForCycle)
      return;


   if(!SpreadIsAllowed())
   {
      Print("Tail & Body entry skipped: spread exceeds the configured limit.");
      return;
   }

   int breakShift =
      -1;

   int reversalShift =
      -1;

   int retestCount =
      0;


   //================================================
   // TAIL & BODY TOP
   //================================================

   if(
      FindTailAndBodyTop(
         breakShift,
         reversalShift,
         retestCount
      )
   )
   {
      g_detectedPattern =
         PATTERN_TAIL_BODY_TOP;

      if(ExecuteTailBodyTopSell(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Tail & Body Top SELL opened. Break shift=",
            breakShift,
            " Reversal shift=",
            reversalShift,
            " Retests=",
            retestCount
         );
      }

      return;
   }


   //================================================
   // TAIL & BODY BOTTOM
   //================================================

   if(
      FindTailAndBodyBottom(
         breakShift,
         reversalShift,
         retestCount
      )
   )
   {
      g_detectedPattern =
         PATTERN_TAIL_BODY_BOTTOM;

      if(ExecuteTailBodyBottomBuy(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Tail & Body Bottom BUY opened. Break shift=",
            breakShift,
            " Reversal shift=",
            reversalShift,
            " Retests=",
            retestCount
         );
      }


      return;
   }
}

//==================================================
// V TAIL & BODY: TWO-STAGE NECKLINE RETEST
//==================================================

bool IsTailBodyVSwing(bool high, int shift)
{
   return high ? IsSwingHigh(shift) : IsSwingLow(shift);
}


double TailBodyVSwingPrice(bool high, int shift)
{
   return high
      ? iHigh(_Symbol, PERIOD_M5, shift)
      : iLow(_Symbol, PERIOD_M5, shift);
}


bool FindTailBodyVRetest(
   bool bearish,
   int breakShift,
   double neckline,
   double necklineTolerancePoints,
   int &retestShift,
   int &confirmationShift
)
{
   retestShift = -1;
   confirmationShift = -1;

   if(InpTailBodyVRetestCandles < 2)
      return false;

   double necklineTolerance =
      necklineTolerancePoints * _Point;

   double closeRangeTolerance =
      InpTailBodyVRetestTolerancePoints * _Point;

   double confirmationLevel = bearish
      ? neckline - InpEntryBufferPoints * _Point
      : neckline + InpEntryBufferPoints * _Point;

   for(
      int newest = breakShift - InpTailBodyVRetestCandles;
      newest >= 2;
      newest--
   )
   {
      double highestClose = -DBL_MAX;
      double lowestClose = DBL_MAX;
      bool atNeckline = true;

      for(
         int shift = newest;
         shift < newest + InpTailBodyVRetestCandles;
         shift++
      )
      {
         double close = iClose(_Symbol, PERIOD_M5, shift);

         if(
            close <= 0 ||
            MathAbs(close - neckline) > necklineTolerance
         )
         {
            atNeckline = false;
            break;
         }

         if(close > highestClose)
            highestClose = close;

         if(close < lowestClose)
            lowestClose = close;
      }

      if(!atNeckline)
         continue;

      if(highestClose - lowestClose > closeRangeTolerance)
         continue;

      int candidateConfirmationShift = newest - 1;
      double confirmationClose =
         iClose(
            _Symbol,
            PERIOD_M5,
            candidateConfirmationShift
         );

      bool movedAway = bearish
         ? confirmationClose < confirmationLevel
         : confirmationClose > confirmationLevel;

      if(!movedAway)
         continue;

      retestShift = newest;
      confirmationShift = candidateConfirmationShift;
      return true;
   }

   return false;
}


bool FindTailAndBodyVPattern(
   bool bearish,
   int &tailShift,
   double &firstNeckline,
   int &firstRetestShift,
   double &secondNeckline,
   int &secondRetestShift
)
{
   tailShift = -1;
   firstNeckline = 0.0;
   firstRetestShift = -1;
   secondNeckline = 0.0;
   secondRetestShift = -1;

   int bars = Bars(_Symbol, PERIOD_M5);

   if(bars < InpMaxPatternBars + InpSwingStrength + 10)
      return false;

   for(
      int keyShift = InpSwingStrength + 1;
      keyShift <= InpMaxPatternBars;
      keyShift++
   )
   {
      if(!IsTailBodyVSwing(bearish, keyShift))
         continue;

      double keyPrice = TailBodyVSwingPrice(bearish, keyShift);

      for(
         int candidateTailShift = keyShift - 1;
         candidateTailShift >= 4;
         candidateTailShift--
      )
      {
         double candidateTailPrice =
            TailBodyVSwingPrice(
               bearish,
               candidateTailShift
            );

         double extension = bearish
            ? candidateTailPrice - keyPrice
            : keyPrice - candidateTailPrice;

         if(extension < InpMinRetracementPoints * _Point)
            continue;

         double candidateFirstNeckline = bearish
            ? LowestBetween(candidateTailShift, keyShift)
            : HighestBetween(candidateTailShift, keyShift);

         if(candidateFirstNeckline <= 0)
            continue;

         for(
            int firstBreakShift = candidateTailShift - 1;
            firstBreakShift >= InpTailBodyVRetestCandles + 2;
            firstBreakShift--
         )
         {
            double firstBreakClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  firstBreakShift
               );

            bool brokeFirstNeckline = bearish
               ? firstBreakClose <
                 candidateFirstNeckline - InpEntryBufferPoints * _Point
               : firstBreakClose >
                 candidateFirstNeckline + InpEntryBufferPoints * _Point;

            if(!brokeFirstNeckline)
               continue;

            int candidateFirstRetestShift = -1;
            int firstConfirmationShift = -1;

            if(
               !FindTailBodyVRetest(
                  bearish,
                  firstBreakShift,
                  candidateFirstNeckline,
                  InpTailBodyVRetestTolerancePoints,
                  candidateFirstRetestShift,
                  firstConfirmationShift
               )
            )
            {
               continue;
            }

            double firstRetestClose =
               iClose(
                  _Symbol,
                  PERIOD_M5,
                  candidateFirstRetestShift
               );

            if(firstRetestClose <= 0)
               continue;

            double candidateSecondNeckline =
               (keyPrice + firstRetestClose) / 2.0;

            for(
               int secondBreakShift = firstConfirmationShift - 1;
               secondBreakShift >= InpTailBodyVRetestCandles + 2;
               secondBreakShift--
            )
            {
               double secondBreakClose =
                  iClose(
                     _Symbol,
                     PERIOD_M5,
                     secondBreakShift
                  );

               bool brokeSecondNeckline = bearish
                  ? secondBreakClose <
                    candidateSecondNeckline - InpEntryBufferPoints * _Point
                  : secondBreakClose >
                    candidateSecondNeckline + InpEntryBufferPoints * _Point;

               if(!brokeSecondNeckline)
                  continue;

               int candidateSecondRetestShift = -1;
               int secondConfirmationShift = -1;

               if(
                  !FindTailBodyVRetest(
                     bearish,
                     secondBreakShift,
                     candidateSecondNeckline,
                     InpTailBodyVSecondNecklineTolerancePoints,
                     candidateSecondRetestShift,
                     secondConfirmationShift
                  )
               )
               {
                  continue;
               }

               tailShift = candidateTailShift;
               firstNeckline = candidateFirstNeckline;
               firstRetestShift = candidateFirstRetestShift;
               secondNeckline = candidateSecondNeckline;
               secondRetestShift = candidateSecondRetestShift;
               return true;
            }
         }
      }
   }

   return false;
}


bool FindTailAndBodyVTop(
   int &tailShift,
   double &firstNeckline,
   int &firstRetestShift,
   double &secondNeckline,
   int &secondRetestShift
)
{
   return FindTailAndBodyVPattern(
      true,
      tailShift,
      firstNeckline,
      firstRetestShift,
      secondNeckline,
      secondRetestShift
   );
}


bool FindTailAndBodyVBottom(
   int &tailShift,
   double &firstNeckline,
   int &firstRetestShift,
   double &secondNeckline,
   int &secondRetestShift
)
{
   return FindTailAndBodyVPattern(
      false,
      tailShift,
      firstNeckline,
      firstRetestShift,
      secondNeckline,
      secondRetestShift
   );
}


void DetectTailAndBodyVPattern(CTrade &trade)
{
   if(!g_patternEngineActive || g_tradePlacedForCycle)
      return;

   if(!SpreadIsAllowed())
   {
      Print("Tail & Body V entry skipped: spread exceeds the configured limit.");
      return;
   }

   int tailShift = -1;
   int firstRetestShift = -1;
   int secondRetestShift = -1;
   double firstNeckline = 0.0;
   double secondNeckline = 0.0;

   if(
      FindTailAndBodyVTop(
         tailShift,
         firstNeckline,
         firstRetestShift,
         secondNeckline,
         secondRetestShift
      )
   )
   {
      g_detectedPattern = PATTERN_TAIL_BODY_TOP;

      if(ExecuteTailBodyTopSell(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Tail & Body V Top SELL opened. First neckline=",
            DoubleToString(firstNeckline, _Digits),
            " Second neckline=",
            DoubleToString(secondNeckline, _Digits),
            " Tail shift=",
            tailShift,
            " First retest shift=",
            firstRetestShift,
            " Second retest shift=",
            secondRetestShift
         );
      }

      return;
   }

   if(
      FindTailAndBodyVBottom(
         tailShift,
         firstNeckline,
         firstRetestShift,
         secondNeckline,
         secondRetestShift
      )
   )
   {
      g_detectedPattern = PATTERN_TAIL_BODY_BOTTOM;

      if(ExecuteTailBodyBottomBuy(trade))
      {
         g_tradePlacedForCycle = true;

         Print(
            "Tail & Body V Bottom BUY opened. First neckline=",
            DoubleToString(firstNeckline, _Digits),
            " Second neckline=",
            DoubleToString(secondNeckline, _Digits),
            " Tail shift=",
            tailShift,
            " First retest shift=",
            firstRetestShift,
            " Second retest shift=",
            secondRetestShift
         );
      }
   }
}

#endif
