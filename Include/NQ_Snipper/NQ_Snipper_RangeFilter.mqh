#ifndef __NQ_SNIPPER_RANGE_FILTER__
#define __NQ_SNIPPER_RANGE_FILTER__

#include "NQ_Snipper_TimeCalendar.mqh"
#include "NQ_Snipper_ConfigState.mqh"

// 0 = pending, 1 = passed, 2 = blocked until NY, 3 = blocked all day.
int g_hourlyOpeningDecision = 0;

string HourlyOpeningStateKey(datetime dayStart)
{
   return StringFormat("NQH1.%I64d.%I64u.%s.%I64d",
      AccountInfoInteger(ACCOUNT_LOGIN), InpMagicNumber, _Symbol,
      (long)dayStart);
}

bool ReadOpeningHourlyBodies(double &largestBodyPoints)
{
   largestBodyPoints = 0.0;
   if(_Point <= 0)
      return false;

   MqlRates hourly[];
   if(CopyRates(_Symbol, PERIOD_H1, 0, 2, hourly) != 2)
      return false;

   for(int i = 0; i < 2; i++)
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
      g_rangeBlockedForDay = false;
      string key = HourlyOpeningStateKey(dayStartGMT);
      if(persist && GlobalVariableCheck(key))
         g_hourlyOpeningDecision = (int)GlobalVariableGet(key);
   }

   if(g_hourlyOpeningDecision == 0)
   {
      datetime sessionStart = dayStartGMT +
         InpEntryStartHourGMT * 3600 + InpEntryStartMinuteGMT * 60;
      datetime sessionEnd = dayStartGMT + (g_isFOMCToday
         ? InpFOMCEntryEndHourGMT * 3600 + InpFOMCEntryEndMinuteGMT * 60
         : InpEntryEndHourGMT * 3600 + InpEntryEndMinuteGMT * 60);

      if(!g_patternEngineActive || nowGMT < sessionStart ||
         nowGMT > sessionEnd || g_activationTimeGMT <= 0 ||
         nowGMT < g_activationTimeGMT)
         return;

      double bodyPoints = 0.0;
      if(InpHourlyStrongCandleMinPoints > 0 &&
         !ReadOpeningHourlyBodies(bodyPoints))
      {
         // History may still be loading; do not allow an unchecked entry.
         g_patternEngineActive = false;
         return;
      }

      bool strong = InpHourlyStrongCandleMinPoints > 0 &&
         bodyPoints >= InpHourlyStrongCandleMinPoints;
      g_hourlyOpeningDecision = !strong ? 1 : (nowGMT < nyStartGMT ? 2 : 3);
      if(persist)
      {
         GlobalVariableSet(HourlyOpeningStateKey(dayStartGMT),
            g_hourlyOpeningDecision);
         GlobalVariablesFlush();
      }

      Print("H1 OPENING CHECK: largest body=", DoubleToString(bodyPoints, 1),
         " points. ", g_hourlyOpeningDecision == 1 ? "Passed; no more checks today."
         : g_hourlyOpeningDecision == 2 ? "Blocked until NY start; no recheck."
         : "Blocked until next GMT day.");
   }

   g_rangeBlockedForDay = g_hourlyOpeningDecision == 3;
   if(g_rangeBlockedForDay)
   {
      g_patternEngineActive = false;
      return;
   }

   if(g_hourlyOpeningDecision == 2)
   {
      if(nowGMT < nyStartGMT)
      {
         g_activationTimeGMT = nyStartGMT;
         g_patternEngineActive = false;
         return;
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
