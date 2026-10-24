#property strict
#property version   "1.00"
#property description "NQ Snipper - M5 Double Top/Bottom EA with high-impact news timing"

#include <Trade/Trade.mqh>


#include <NQ_Snipper/NQ_Snipper_ConfigState.mqh>
#include <NQ_Snipper/NQ_Snipper_TimeCalendar.mqh>
#include <NQ_Snipper/NQ_Snipper_BarsSwings.mqh>
#include <NQ_Snipper/NQ_Snipper_Spread.mqh>
#include <NQ_Snipper/NQ_Snipper_Positions.mqh>
#include <NQ_Snipper/NQ_Snipper_NewsController.mqh>
#include <NQ_Snipper/NQ_Snipper_RangeFilter.mqh>
#include <NQ_Snipper/NQ_Snipper_Patterns.mqh>
#include <NQ_Snipper/NQ_Snipper_Panel.mqh>

CTrade g_nqTrade;

//==================================================
// INITIALIZATION
//==================================================

int OnInit()
{
   if(!MathIsValidNumber(InpTailBodyDojiMaxBodyPoints) ||
      InpTailBodyDojiMaxBodyPoints < 0.0)
   {
      Print("TailBody doji maximum body size must be a non-negative number of points.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpEnableTailBodyPullbackSpacing && InpTailBodyPullbackSpacingCandles < 0)
   {
      Print("TailBody pullback spacing must be a non-negative number of candles.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpEnableTailBodyBodyToEntryTimeLimit &&
      InpTailBodyBodyToEntryMaxMinutes < 0)
   {
      Print("TailBody body-to-entry time limit must be a non-negative number of minutes.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(!MathIsValidNumber(InpTailBodyFirstPullbackUpdateTolerancePoints) ||
      InpTailBodyFirstPullbackUpdateTolerancePoints < 0.0)
   {
      Print("TailBody first-pullback update tolerance must be a non-negative number of points.");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(InpEnableBaseFilter &&
      (InpBaseMinimumCandles < 3 ||
       !MathIsValidNumber(InpBaseOpenTolerancePoints) ||
       InpBaseOpenTolerancePoints < 0.0 ||
       !MathIsValidNumber(InpBaseCloseTolerancePoints) ||
       InpBaseCloseTolerancePoints < 0.0 ||
       InpBaseValidityMinutes < 1))
   {
      Print("Base filter requires at least 3 candles, non-negative open/close tolerances, and a positive validity duration.");
      return INIT_PARAMETERS_INCORRECT;
   }

   g_nqTrade.SetExpertMagicNumber(InpMagicNumber);
   g_nqTrade.SetDeviationInPoints(20);
   ObjectDelete(0, "NQ_SNIPPER_FIRST_SWING_ARROW");
   ObjectDelete(0, "NQ_SNIPPER_FIRST_SWING_LABEL");
   ClearTailBodyLegObjects("BULL");
   ClearTailBodyLegObjects("BEAR");

   if(_Period != PERIOD_M5)
   {
      Print(
         "WARNING: NQ Snipper is designed for M5. "
         "Current timeframe = ",
         EnumToString((ENUM_TIMEFRAMES)_Period)
      );
   }

   Print("NQ Snipper initialized.");

   return INIT_SUCCEEDED;
}


//==================================================
// DEINITIALIZATION
//==================================================

void OnDeinit(const int reason)
{
   Comment("");
}


//==================================================
// MAIN TICK
//==================================================

void OnTick()
{
   if(InpEnableBreakEvenManagement)
      MoveOurStopsToBreakeven(g_nqTrade);

   // All entry-related logic works from completed M5 candles. Keep only
   // open-position stop management on every tick.
   if(_Period != PERIOD_M5)
      return;

   if(!IsNewM5Bar())
      return;

   UpdateFirstLeg();
   if(InpEnableTailBodyPattern)
      UpdateTailBodyFirstLegs();

   if(InpEnableNewsTimingFilter)
   {
      UpdateNewsController();
   }
   else
   {
      g_patternEngineActive = true;
      g_activationTimeGMT = TimeGMT();
   }

   UpdateDailyTradeLimit();
   // Keep a successfully traded pattern for the current day, but do not
   // carry an unexecuted signal forward into subsequent bars.
   if(!g_tradePlacedForCycle)
      g_detectedPattern = PATTERN_NONE;

   if(InpEnableHourlyMomentumFilter)
      UpdateHourlyMomentumFilter();

   if(g_patternEngineActive &&
      (!InpEnableTradingHoursFilter || IsNQSnipperExecutionTime()) &&
      !g_tradePlacedForCycle && !HasOurOpenPosition())
   {
      if(InpEnableDoublePattern)
         DetectDoublePattern(g_nqTrade);

      if(InpEnableLegKneePattern)
         DetectLegKneePattern(g_nqTrade);

      if(InpEnableTailBodyPattern)
         DetectTailAndBodyPattern(g_nqTrade);

      if(InpEnableTailBodyVPattern)
         DetectTailAndBodyVPattern(g_nqTrade);
   }

   // Render after detection so a new signal or trade appears on this bar.
   UpdatePanel();
}
