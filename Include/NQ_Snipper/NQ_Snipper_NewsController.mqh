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

struct TesterNewsEvent
{
   datetime timeGMT;
   string   name;
};

TesterNewsEvent g_testerNewsEvents[];
bool g_testerNewsLoaded = false;
bool g_testerNewsLoadFailed = false;

bool UseTesterNewsData()
{
   return InpUseTesterNewsData &&
      MQLInfoInteger(MQL_TESTER);
}

bool LoadTesterNewsData()
{
   if(g_testerNewsLoaded)
      return true;

   g_testerNewsLoaded = true;
   ArrayResize(g_testerNewsEvents, 0);

   int handle = FileOpen(
      InpTesterNewsFile,
      FILE_READ | FILE_CSV | FILE_ANSI | FILE_COMMON,
      ','
   );

   if(handle == INVALID_HANDLE)
   {
      if(!g_testerNewsLoadFailed)
      {
         Print("TESTER NEWS: Cannot open Common\\Files\\", InpTesterNewsFile,
            ". Error=", GetLastError());
         g_testerNewsLoadFailed = true;
      }
      return false;
   }

   while(!FileIsEnding(handle))
   {
      string timeText = FileReadString(handle);
      string eventName = FileReadString(handle);
      string importance = FileReadString(handle);

      datetime eventGMT = StringToTime(timeText);
      StringTrimLeft(importance);
      StringTrimRight(importance);
      StringToUpper(importance);

      // Invalid dates also skip the CSV header and comment rows.
      if(eventGMT <= 0 || importance != "HIGH")
         continue;

      int size = ArraySize(g_testerNewsEvents);
      ArrayResize(g_testerNewsEvents, size + 1);
      g_testerNewsEvents[size].timeGMT = eventGMT;
      g_testerNewsEvents[size].name = eventName;
   }

   FileClose(handle);
   Print("TESTER NEWS: Loaded ", ArraySize(g_testerNewsEvents),
      " high-impact events from ", InpTesterNewsFile);
   return true;
}



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

   if(UseTesterNewsData())
   {
      if(!LoadTesterNewsData())
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
      TimeGMT();


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
      InpEntryStartHourGMT * 3600 +
      InpEntryStartMinuteGMT * 60;

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
      g_activationTimeGMT =
         entryStartGMT;


      g_patternEngineActive =
         nowGMT >=
         entryStartGMT;


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
   // NEWS BEFORE THE ENTRY SESSION
   //================================================

   if(latestNewsGMT < entryStartGMT)
   {
      g_activationTimeGMT =
         entryStartGMT;


      g_patternEngineActive =
         nowGMT >=
         entryStartGMT;


      return;
   }


   //================================================
   // NEWS AT OR AFTER NY START
   //================================================

   int waitMinutes =
      InpPostNYWaitMinutes;


   //================================================
   // CALCULATE POST-NEWS ACTIVATION
   //================================================

   g_activationTimeGMT =
      latestNewsGMT +
      waitMinutes * 60;


   //================================================
   // UPDATE ENGINE STATE
   //================================================

   g_patternEngineActive =
      nowGMT >=
      g_activationTimeGMT;
}

#endif
