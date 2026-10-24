#ifndef __NQ_SNIPPER_RANGE_FILTER__
#define __NQ_SNIPPER_RANGE_FILTER__

#include "NQ_Snipper_TimeCalendar.mqh"
#include "NQ_Snipper_ConfigState.mqh"

// 0 = pending, 1 = monitoring, 2 = pre-NY block, 3 = blocked all day,
// 4 = one-time post-NY H1 cooldown.
// State 2 remains after a successful NY recheck to retain its news behavior.
int g_hourlyOpeningDecision = 0;
bool g_hourlyNYRecheckPassed = false;
bool g_hourlyPostNYCooldownUsed = false;
bool g_hourlyPostNYAwaitStrongClear = false;
datetime g_hourlyPostNYCooldownEndsGMT = 0;

int NextHourlyDecision(int previousDecision, bool strong, bool beforeNY)
{
   if(previousDecision == 3)
      return 3;
   if(previousDecision == 4)
      return 4;
   if(strong)
      return beforeNY ? 2 : 3;
   if(previousDecision == 2)
      return 2;
   return 1;
}

bool HourlyDecisionBlocksTrading(int decision, bool beforeNY)
{
   return decision == 3 || decision == 4 || (decision == 2 && beforeNY);
}

string HourlyOpeningStateKey(datetime dayStart)
{
   return StringFormat("NQH1.%I64d.%I64u.%s.%I64d",
      AccountInfoInteger(ACCOUNT_LOGIN), InpMagicNumber, _Symbol,
      (long)dayStart);
}

string HourlyPostNYCooldownStateKey(datetime dayStart,string suffix)
{
   return HourlyOpeningStateKey(dayStart)+suffix;
}

void PersistHourlyPostNYCooldownState(datetime dayStart,bool persist)
{
   if(!persist)
      return;
   GlobalVariableSet(HourlyOpeningStateKey(dayStart),g_hourlyOpeningDecision);
   GlobalVariableSet(HourlyPostNYCooldownStateKey(dayStart,".CooldownEnd"),
      (double)g_hourlyPostNYCooldownEndsGMT);
   GlobalVariableSet(HourlyPostNYCooldownStateKey(dayStart,".CooldownUsed"),
      g_hourlyPostNYCooldownUsed ? 1.0 : 0.0);
   GlobalVariableSet(HourlyPostNYCooldownStateKey(dayStart,".AwaitClear"),
      g_hourlyPostNYAwaitStrongClear ? 1.0 : 0.0);
   GlobalVariablesFlush();
}

void AlertHourlyMomentumState(string message)
{
   Print(message);
   Alert(message);
}

bool ReadOpeningHourlyBodies(double &largestBodyPoints)
{
   largestBodyPoints = 0.0;
   if(_Point <= 0)
      return false;

   // Always check the previous completed H1 candle; include the current
   // forming candle only when its separate toggle is enabled.
   int firstShift = InpCheckCurrentH1Candle ? 0 : 1;
   int candleCount = InpCheckCurrentH1Candle ? 2 : 1;
   MqlRates hourly[];
   if(CopyRates(_Symbol, PERIOD_H1, firstShift, candleCount, hourly) != candleCount)
      return false;

   for(int i = 0; i < candleCount; i++)
   {
      if(hourly[i].open <= 0 || hourly[i].close <= 0)
         return false;
      largestBodyPoints = MathMax(largestBodyPoints,
         MathAbs(hourly[i].close - hourly[i].open) / _Point);
   }
   return true;
}

void UpdateHourlyMomentumFilter()
{
   datetime nowGMT = TimeGMT();
   datetime dayStartGMT = GMTDayStart(nowGMT);
   datetime nyStartGMT = dayStartGMT +
      InpNYStartHourGMT * 3600 + InpNYStartMinuteGMT * 60;
   bool persist = !MQLInfoInteger(MQL_TESTER);

   if(g_rangeFilterDayStartGMT != dayStartGMT)
   {
      g_rangeFilterDayStartGMT = dayStartGMT;
      g_hourlyOpeningDecision = 0;
      g_hourlyNYRecheckPassed = false;
      g_hourlyPostNYCooldownUsed = false;
      g_hourlyPostNYAwaitStrongClear = false;
      g_hourlyPostNYCooldownEndsGMT = 0;
      g_rangeBlockedForDay = false;
      string key = HourlyOpeningStateKey(dayStartGMT);
      if(persist && GlobalVariableCheck(key))
      {
         g_hourlyOpeningDecision = (int)GlobalVariableGet(key);
         string endKey=HourlyPostNYCooldownStateKey(dayStartGMT,".CooldownEnd");
         string usedKey=HourlyPostNYCooldownStateKey(dayStartGMT,".CooldownUsed");
         string clearKey=HourlyPostNYCooldownStateKey(dayStartGMT,".AwaitClear");
         if(GlobalVariableCheck(endKey))
            g_hourlyPostNYCooldownEndsGMT=(datetime)GlobalVariableGet(endKey);
         if(GlobalVariableCheck(usedKey))
            g_hourlyPostNYCooldownUsed=GlobalVariableGet(usedKey)>0.5;
         if(GlobalVariableCheck(clearKey))
            g_hourlyPostNYAwaitStrongClear=GlobalVariableGet(clearKey)>0.5;
      }
   }

   bool beforeNY = nowGMT < nyStartGMT;
   g_rangeBlockedForDay = g_hourlyOpeningDecision == 3;
   if(g_rangeBlockedForDay)
   {
      g_patternEngineActive = false;
      return;
   }

   datetime sessionStart = dayStartGMT +
      InpEntryStartHourGMT * 3600 + InpEntryStartMinuteGMT * 60;
   datetime sessionEnd = dayStartGMT + (g_isFOMCToday
      ? InpFOMCEntryEndHourGMT * 3600 + InpFOMCEntryEndMinuteGMT * 60
      : InpEntryEndHourGMT * 3600 + InpEntryEndMinuteGMT * 60);

   if(g_hourlyOpeningDecision == 4)
   {
      if(nowGMT < g_hourlyPostNYCooldownEndsGMT)
      {
         g_activationTimeGMT=g_hourlyPostNYCooldownEndsGMT;
         g_patternEngineActive=false;
         return;
      }

      g_hourlyOpeningDecision=1;
      g_hourlyPostNYCooldownEndsGMT=0;
      g_hourlyPostNYAwaitStrongClear=true;
      PersistHourlyPostNYCooldownState(dayStartGMT,persist);
      if(nowGMT < sessionStart || nowGMT > sessionEnd ||
         (InpEnableTradingHoursFilter && !IsNQSnipperExecutionTime()))
      {
         g_patternEngineActive=false;
         return;
      }
      AlertHourlyMomentumState("H1 momentum cooldown ended; engine reopened while the trading window is open.");
   }

   if(nowGMT < sessionStart || nowGMT > sessionEnd)
   {
      if(HourlyDecisionBlocksTrading(g_hourlyOpeningDecision, beforeNY))
      {
         g_activationTimeGMT = nyStartGMT;
         g_patternEngineActive = false;
      }
      return;
   }

   double bodyPoints = 0.0;
   if(InpHourlyStrongCandleMinPoints > 0 &&
      !ReadOpeningHourlyBodies(bodyPoints))
   {
      // History may still be loading; do not allow an unchecked entry.
      if(g_hourlyOpeningDecision == 2 && beforeNY)
         g_activationTimeGMT = nyStartGMT;
      g_patternEngineActive = false;
      return;
   }

   bool strong = InpHourlyStrongCandleMinPoints > 0 &&
      bodyPoints >= InpHourlyStrongCandleMinPoints;

   // The candle that triggered the one-hour cooldown is not a new breach.
   // It must first fall back below the threshold before another breach can
   // permanently lock the day.
   if(g_hourlyPostNYAwaitStrongClear)
   {
      if(strong)
         return;
      g_hourlyPostNYAwaitStrongClear=false;
      PersistHourlyPostNYCooldownState(dayStartGMT,persist);
   }

   int previousDecision = g_hourlyOpeningDecision;
   if(strong && !beforeNY && g_hourlyNYRecheckPassed)
   {
      if(InpEnablePostNYH1CooldownReopen && !g_hourlyPostNYCooldownUsed)
      {
         g_hourlyOpeningDecision=4;
         g_hourlyPostNYCooldownUsed=true;
         g_hourlyPostNYCooldownEndsGMT=nowGMT+60*60;
         PersistHourlyPostNYCooldownState(dayStartGMT,persist);
         g_patternEngineActive=false;
         AlertHourlyMomentumState("H1 momentum threshold crossed after NY reopening; engine paused for one hour.");
         return;
      }
      g_hourlyOpeningDecision=3;
      PersistHourlyPostNYCooldownState(dayStartGMT,persist);
      AlertHourlyMomentumState("H1 momentum threshold crossed again after the post-NY cooldown; engine locked until next GMT day.");
   }
   else
      g_hourlyOpeningDecision = NextHourlyDecision(previousDecision, strong, beforeNY);
   if(g_hourlyOpeningDecision != previousDecision)
   {
       PersistHourlyPostNYCooldownState(dayStartGMT,persist);

      Print("H1 CHECK: largest body=", DoubleToString(bodyPoints, 1),
         " points. ",
         g_hourlyOpeningDecision == 1 ? "Below threshold; monitoring continues."
         : g_hourlyOpeningDecision == 2 ? "Blocked until NY start; will recheck."
         : "Blocked until next GMT day.");
   }

   g_rangeBlockedForDay = g_hourlyOpeningDecision == 3;
   if(HourlyDecisionBlocksTrading(g_hourlyOpeningDecision, beforeNY))
   {
      if(g_hourlyOpeningDecision == 2)
         g_activationTimeGMT = nyStartGMT;
      g_patternEngineActive = false;
      return;
   }

   if(g_hourlyOpeningDecision == 2)
   {
      if(!g_hourlyNYRecheckPassed)
      {
         Print("H1 NY RECHECK: largest body=", DoubleToString(bodyPoints, 1),
            " points. Below threshold; monitoring continues.");
         g_hourlyNYRecheckPassed = true;
      }

      // The scheduled reopening bypasses waits for news at/before NY start.
      // Subsequent releases retain their normal news-controller timing.
      if(g_latestRedNewsGMT <= nyStartGMT)
      {
         g_activationTimeGMT = nyStartGMT;
         g_patternEngineActive = true;
      }
   }
}

#endif
