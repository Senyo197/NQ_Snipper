#ifndef __NQ_SNIPPER_NEWS_CONTROLLER__
#define __NQ_SNIPPER_NEWS_CONTROLLER__

#include "NQ_Snipper_TimeCalendar.mqh"
#include "NQ_Snipper_ConfigState.mqh"

bool IsFOMCMinutesEventName(string name)
{
   StringToUpper(name);
   return StringFind(name, "MINUTES") >= 0 &&
      (StringFind(name, "FOMC") >= 0 ||
       StringFind(name, "FEDERAL OPEN MARKET COMMITTEE") >= 0);
}

#include "NQ_Snipper_NewsData.mqh"

bool IsFOMCRateDecisionName(string name)
{
   StringToUpper(name);

   if(StringFind(name, "MINUTES") >= 0)
      return false;

   return (
      StringFind(name, "FEDERAL FUNDS RATE") >= 0 ||
      ((StringFind(name, "FED") >= 0 ||
        StringFind(name, "FOMC") >= 0 ||
        StringFind(name, "FEDERAL OPEN MARKET COMMITTEE") >= 0) &&
       StringFind(name, "RATE") >= 0 &&
       StringFind(name, "DECISION") >= 0)
   );
}






//==================================================
// UPDATE NEWS CONTROLLER
//==================================================

datetime g_cachedNewsDayStartGMT = 0;
datetime g_cachedHighNewsTimes[];
string g_cachedHighNewsNames[];
bool g_cachedFOMCToday = false;

void AddCachedHighImpactNews(
   datetime &times[],
   string &names[],
   datetime eventTimeGMT,
   string eventName
)
{
   int size = ArraySize(times);
   ArrayResize(times, size + 1);
   ArrayResize(names, size + 1);
   times[size] = eventTimeGMT;
   names[size] = eventName;
}

bool CacheDailyHighImpactNews(
   datetime dayStartGMT,
   datetime dayEndGMT,
   datetime entryStartGMT
)
{
   datetime rawTimes[];
   string rawNames[];
   ArrayResize(g_cachedHighNewsTimes, 0);
   ArrayResize(g_cachedHighNewsNames, 0);
   g_cachedFOMCToday = false;

   if(MQLInfoInteger(MQL_TESTER))
   {
      if(!InpUseTesterNewsData || !LoadTesterNewsData())
         return false;

      for(int i = 0; i < ArraySize(g_testerNewsEvents); i++)
      {
         datetime eventGMT = g_testerNewsEvents[i].timeGMT;
         if(eventGMT < dayStartGMT || eventGMT > dayEndGMT)
            continue;
         AddCachedHighImpactNews(rawTimes, rawNames, eventGMT,
            g_testerNewsEvents[i].name);
      }
   }
   else
   {
      MqlCalendarValue values[];
      ResetLastError();
      int count = CalendarValueHistory(
         values,
         GMTToServerTime(dayStartGMT),
         GMTToServerTime(dayEndGMT)
      );

      if(count < 0)
      {
         Print("NEWS: Calendar scan failed. Error=", GetLastError());
         return false;
      }

      for(int i = 0; i < count; i++)
      {
         MqlCalendarEvent event;
         if(!CalendarEventById(values[i].event_id, event))
            continue;
         if(event.importance != CALENDAR_IMPORTANCE_HIGH)
            continue;

         datetime eventGMT = ServerToGMTTime(values[i].time);
         if(eventGMT < dayStartGMT || eventGMT > dayEndGMT)
            continue;
         AddCachedHighImpactNews(rawTimes, rawNames, eventGMT, event.name);
      }
   }

   bool hasNonMinutesAfterEntry = false;
   for(int i = 0; i < ArraySize(rawTimes); i++)
   {
      if(
         rawTimes[i] >= entryStartGMT &&
         !IsFOMCMinutesEventName(rawNames[i])
      )
      {
         hasNonMinutesAfterEntry = true;
         break;
      }
   }

   bool ignoreMinutes = hasNonMinutesAfterEntry;
   for(int i = 0; i < ArraySize(rawTimes); i++)
   {
      if(ignoreMinutes && IsFOMCMinutesEventName(rawNames[i]))
         continue;

      AddCachedHighImpactNews(
         g_cachedHighNewsTimes,
         g_cachedHighNewsNames,
         rawTimes[i],
         rawNames[i]
      );

      if(IsFOMCRateDecisionName(rawNames[i]))
         g_cachedFOMCToday = true;
   }

   g_cachedNewsDayStartGMT = dayStartGMT;
   Print("NEWS: Cached ", ArraySize(g_cachedHighNewsTimes),
      " applicable high-impact events for ",
      TimeToString(dayStartGMT, TIME_DATE));
   return true;
}

void UpdateNewsController()
{
   datetime nowGMT =
      NQGMTNow();


   //================================================
   // TODAY'S GMT RANGE
   //================================================

   datetime dayStartGMT =
      GMTDayStart(
         nowGMT
      );

   datetime dayEndGMT =
      GMTDayEnd(
         nowGMT
      );


   datetime entryStartGMT =
      dayStartGMT +
      NQEntryStartSeconds();

   // Calendar/file data is scanned once per GMT day. Subsequent calls only
   // compare the current time with the small in-memory list for that day.
   if(g_cachedNewsDayStartGMT != dayStartGMT)
   {
      CacheDailyHighImpactNews(
         dayStartGMT,
         dayEndGMT,
         entryStartGMT
      );
   }

   bool anyNewsToday = ArraySize(g_cachedHighNewsTimes) > 0;
   g_hasHighImpactNewsToday = anyNewsToday;
   g_isFOMCToday = g_cachedFOMCToday;

   // A scheduled FOMC/Fed rate decision has priority over the general
   // high-impact schedule. No entry is allowed before the rate release; the
   // engine reopens ten minutes afterward. FOMC Minutes do not match the rate
   // decision classifier and therefore do not invoke this rule.
   datetime fomcRateDecisionGMT = 0;
   for(int i = 0; i < ArraySize(g_cachedHighNewsTimes); i++)
   {
      if(IsFOMCRateDecisionName(g_cachedHighNewsNames[i]))
      {
         fomcRateDecisionGMT = g_cachedHighNewsTimes[i];
         break;
      }
   }
   if(fomcRateDecisionGMT > 0)
   {
      g_activationTimeGMT = fomcRateDecisionGMT +
         MathMax(0,InpFOMCRatePostReleaseWaitMinutes) * 60;
      g_patternEngineActive = nowGMT >= g_activationTimeGMT;
      return;
   }


   //================================================
   // STORE TODAY'S NEWS NAME
   //================================================

   if(anyNewsToday)
   {
      g_latestHighImpactNewsName =
         g_cachedHighNewsNames[0];
   }
   else
   {
      g_latestHighImpactNewsName =
         "";
   }


   //================================================
   // NO HIGH-IMPACT NEWS TODAY
   //================================================

   if(!anyNewsToday)
   {
      datetime fallbackGMT = dayStartGMT + NQFallbackSeconds();
      g_activationTimeGMT = (datetime)MathMax((long)entryStartGMT, (long)fallbackGMT);


      g_patternEngineActive = nowGMT >= g_activationTimeGMT;
      return;
   }


   //================================================
   // FIND LATEST HIGH-IMPACT NEWS THAT HAS
   // ALREADY OCCURRED
   //================================================

   datetime latestNewsGMT = 0;
   for(int i = 0; i < ArraySize(g_cachedHighNewsTimes); i++)
   {
      datetime eventGMT = g_cachedHighNewsTimes[i];
      if(eventGMT <= nowGMT && eventGMT > latestNewsGMT)
         latestNewsGMT = eventGMT;
   }


   //================================================
   // NO HIGH-IMPACT NEWS HAS OCCURRED YET
   //================================================

   if(latestNewsGMT <= 0)
   {
      g_activationTimeGMT =
         entryStartGMT;


      g_patternEngineActive =
         nowGMT >=
         entryStartGMT;


      return;
   }


   //================================================
   // NEW LATEST NEWS RELEASE DETECTED
   //================================================

   if(
      latestNewsGMT !=
      g_latestRedNewsGMT
   )
   {
      g_latestRedNewsGMT =
         latestNewsGMT;


      Print(
         "Latest high-impact news release: ",
         FormatGMT(
            latestNewsGMT
         )
      );
   }


   //================================================
   // CHOOSE WAIT FROM THE RELEASE'S POSITION RELATIVE TO NY START
   //================================================

   datetime nyStartGMT=dayStartGMT+
      NQNYStartSeconds();
   int waitMinutes=MathMax(0,latestNewsGMT<nyStartGMT
      ? InpPreNYWaitMinutes : InpPostNYWaitMinutes);


   //================================================
   // CALCULATE POST-NEWS ACTIVATION
   //================================================

   g_activationTimeGMT =
      (datetime)MathMax((long)entryStartGMT,
         (long)(latestNewsGMT+waitMinutes*60));


   //================================================
   // UPDATE ENGINE STATE
   //================================================

   g_patternEngineActive =
      nowGMT >=
      g_activationTimeGMT;
}

#endif
