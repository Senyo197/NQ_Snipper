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

   if(InpEnableHourlyMomentumFilter)
      UpdateHourlyMomentumFilter();

   UpdatePanel();
   if(!g_patternEngineActive)
      return;
   if(InpEnableTradingHoursFilter && !IsNQSnipperExecutionTime())
      return;
   if(g_tradePlacedForCycle)
      return;
   if(HasOurOpenPosition())
      return;
   if(InpEnableDoublePattern)
      DetectDoublePattern(g_nqTrade);

   if(InpEnableLegKneePattern)
      DetectLegKneePattern(g_nqTrade);

   if(InpEnableTailBodyPattern)
      DetectTailAndBodyPattern(g_nqTrade);

   if(InpEnableTailBodyVPattern)
      DetectTailAndBodyVPattern(g_nqTrade);
}
