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

//==================================================
// FIND TODAY'S HIGH-IMPACT NEWS
//==================================================

bool FindHighImpactNewsToday(
   datetime dayStartGMT,
   datetime dayEndGMT,
   string &newsName,
   datetime &newsTimeGMT,
   bool ignoreMinutes = false
)
{
   newsName =
      "";

   newsTimeGMT =
      0;

   if(dayStartGMT > dayEndGMT)
      return false;


   //================================================
   // CONVERT GMT RANGE TO SERVER TIME
   //================================================

   datetime fromServer =
      GMTToServerTime(
         dayStartGMT
      );

   datetime toServer =
      GMTToServerTime(
         dayEndGMT
      );


   //================================================
   // LOAD CALENDAR VALUES
   //================================================

   MqlCalendarValue values[];

   ResetLastError();

   int count =
      CalendarValueHistory(
         values,
         fromServer,
         toServer
      );


   if(count <= 0)
   {
      Print(
         "NEWS: No calendar values found. Error=",
         GetLastError()
      );

      return false;
   }


   //================================================
   // CHECK EACH EVENT
   //================================================

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(
            values[i].event_id,
            event
         ))
      {
         continue;
      }


      //================================================
      // ONLY HIGH-IMPACT EVENTS
      //================================================

      if(
         event.importance !=
         CALENDAR_IMPORTANCE_HIGH
      )
      {
         continue;
      }


      //================================================
      // CONVERT EVENT TIME TO GMT
      //================================================

      if(ignoreMinutes && IsFOMCMinutesEventName(event.name))
         continue;

      datetime eventGMT =
         ServerToGMTTime(
            values[i].time
         );


      //================================================
      // VERIFY EVENT IS ACTUALLY TODAY IN GMT
      //================================================

      if(eventGMT < dayStartGMT)
         continue;

      if(eventGMT > dayEndGMT)
         continue;


      //================================================
      // STORE EVENT
      //================================================

      newsName =
         event.name;

      newsTimeGMT =
         eventGMT;


      Print(
         "HIGH IMPACT NEWS FOUND: ",
         newsName,
         " | GMT=",
         FormatGMT(
            newsTimeGMT
         )
      );


      return true;
   }


   return false;
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


bool FindFOMCToday(
   datetime dayStartGMT,
   datetime dayEndGMT
)
{
   MqlCalendarValue values[];
   int count = CalendarValueHistory(
      values,
      GMTToServerTime(dayStartGMT),
      GMTToServerTime(dayEndGMT)
   );

   if(count <= 0)
      return false;

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;

      if(
         CalendarEventById(
            values[i].event_id,
            event
         ) &&
         IsFOMCRateDecisionName(event.name)
      )
      {
         return true;
      }
   }

   return false;
}


//==================================================
// FIND LATEST HIGH-IMPACT NEWS
// BETWEEN GMT TIMES
//==================================================

datetime FindLatestHighImpactNewsGMT(
   datetime fromGMT,
   datetime toGMT,
   bool ignoreMinutes = false
)
{
   if(fromGMT > toGMT)
      return 0;


   //================================================
   // CONVERT GMT RANGE TO SERVER TIME
   //================================================

   datetime fromServer =
      GMTToServerTime(
         fromGMT
      );

   datetime toServer =
      GMTToServerTime(
         toGMT
      );


   MqlCalendarValue values[];

   ResetLastError();

   int count =
      CalendarValueHistory(
         values,
         fromServer,
         toServer
      );


   if(count <= 0)
      return 0;


   datetime latestNewsGMT =
      0;


   //================================================
   // CHECK EACH EVENT
   //================================================

   for(int i = 0; i < count; i++)
   {
      MqlCalendarEvent event;

      if(!CalendarEventById(
            values[i].event_id,
            event
         ))
      {
         continue;
      }


      //================================================
      // ONLY HIGH-IMPACT EVENTS
      //================================================

      if(
         event.importance !=
         CALENDAR_IMPORTANCE_HIGH
      )
      {
         continue;
      }


      //================================================
      // CONVERT EVENT TIME TO GMT
      //================================================

      datetime eventGMT =
         ServerToGMTTime(
            values[i].time
         );


      //================================================
      // VERIFY EVENT IS INSIDE REQUESTED RANGE
      //================================================

      if(ignoreMinutes && IsFOMCMinutesEventName(event.name))
         continue;

      if(eventGMT < fromGMT)
         continue;

      if(eventGMT > toGMT)
         continue;


      //================================================
      // KEEP LATEST EVENT
      //================================================

      if(eventGMT > latestNewsGMT)
      {
         latestNewsGMT =
            eventGMT;
      }
   }


   return latestNewsGMT;
}


//==================================================
// UPDATE NEWS CONTROLLER
//==================================================

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


   //================================================
   // FIND TODAY'S HIGH-IMPACT NEWS
   //================================================

   string todayNewsName =
      "";

   datetime todayNewsTimeGMT =
      0;


   datetime entryStartGMT =
      dayStartGMT +
      InpEntryStartHourGMT * 3600 +
      InpEntryStartMinuteGMT * 60;

   // Minutes alone do not delay the normal session or extend its close.
   string otherNewsName = "";
   datetime otherNewsTimeGMT = 0;
   bool ignoreMinutes = !FindHighImpactNewsToday(
      entryStartGMT,
      dayEndGMT,
      otherNewsName,
      otherNewsTimeGMT,
      true
   );

   bool anyNewsToday =
      FindHighImpactNewsToday(
         dayStartGMT,
         dayEndGMT,
         todayNewsName,
         todayNewsTimeGMT,
         ignoreMinutes
      );


   g_hasHighImpactNewsToday =
      anyNewsToday;

   g_isFOMCToday =
      FindFOMCToday(
         dayStartGMT,
         dayEndGMT
      );


   //================================================
   // STORE TODAY'S NEWS NAME
   //================================================

   if(anyNewsToday)
   {
      g_latestHighImpactNewsName =
         todayNewsName;
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

   datetime latestNewsGMT =
      FindLatestHighImpactNewsGMT(
         dayStartGMT,
         nowGMT,
         ignoreMinutes
      );


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
