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

CTrade trade;

//==================================================
// INITIALIZATION
//==================================================

int OnInit()
{
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(20);

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
   MoveOurStopsToBreakeven(trade);
   UpdateNewsController();
   UpdateDailyTradeLimit();
   UpdateHourlyMomentumFilter();
   UpdatePanel();
   if(!g_patternEngineActive)
      return;
   if(_Period != PERIOD_M5)
      return;
   if(!IsNQSnipperExecutionTime())
      return;
   if(!IsNewM5Bar())
      return;
   if(g_tradePlacedForCycle)
      return;
   if(HasOurOpenPosition())
      return;
   DetectDoublePattern(trade);
   DetectLegKneePattern(trade);
   DetectTailAndBodyPattern(trade);
   DetectTailAndBodyVPattern(trade);
}
