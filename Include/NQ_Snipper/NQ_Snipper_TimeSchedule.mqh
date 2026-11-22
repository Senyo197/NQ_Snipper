#ifndef __NQ_SNIPPER_TIME_SCHEDULE__
#define __NQ_SNIPPER_TIME_SCHEDULE__
#include "NQ_Snipper_NewsData.mqh"

// -1 = manual fallback, 0 = standard (UTC-5), 1 = daylight (UTC-4).
int g_nqDetectedDaylight=-1;
string g_nqTimeScheduleStatus="UNCONFIRMED - manual GMT inputs";
datetime g_nqScheduleDay=0;
datetime g_nqScheduleLastScan=0;
int g_nqScheduleServerOffset=2147483647;

int NQScheduleRegime()
{
   if(InpEnableCalendarTimeSchedule && g_nqDetectedDaylight>=0)
      return g_nqDetectedDaylight;
   if(InpManualTimeSchedule==NQ_SCHEDULE_DAYLIGHT)
      return 1;
   if(InpManualTimeSchedule==NQ_SCHEDULE_STANDARD)
      return 0;
   return -1;
}

int NQNYStartSeconds()
{
   int regime=NQScheduleRegime();
   if(regime>=0)
      return (regime==1 ? 13 : 14)*3600+30*60;
   return InpNYStartHourGMT*3600+InpNYStartMinuteGMT*60;
}

int NQFallbackSeconds()
{
   int regime=NQScheduleRegime();
   if(regime>=0)
      return (regime==1 ? 11 : 12)*3600+50*60;
   return InpFallbackHourGMT*3600+InpFallbackMinuteGMT*60;
}

// Keep the user's configured entry window. Fallback/NY changes do not move
// independent entry start/end limits or the pre-opening First Leg search.
int NQEntryStartSeconds()
{
   return InpEntryStartHourGMT*3600+InpEntryStartMinuteGMT*60;
}

int NQEntryStartMinutes()
{
   return NQEntryStartSeconds()/60;
}

string NQScheduleClock(int seconds)
{
   return StringFormat("%02d:%02d",seconds/3600,(seconds%3600)/60);
}

datetime NQScheduleWeekStart(datetime nowGMT)
{
   MqlDateTime tm;
   TimeToStruct(nowGMT,tm);
   int daysSinceMonday=(tm.day_of_week+6)%7;
   return GMTDayStart(nowGMT)-daysSinceMonday*86400;
}

// Exact tester labels are the US series in the existing GMT news CSV.
// Live uses stable event_code values with a US country filter, not translated names.
int NQTimeReportFamily(string name,bool liveCode)
{
   StringToLower(name);
   if(liveCode)
   {
      if(name=="nonfarm-payrolls") return 0;
      if(name=="consumer-price-index-mm" || name=="consumer-price-index-yy" ||
         name=="core-consumer-price-index-mm") return 1;
      if(name=="producer-price-index-mm" || name=="producer-price-index-yy" ||
         name=="core-producer-price-index-mm") return 2;
      if(name=="initial-jobless-claims") return 3;
   }
   else
   {
      if(name=="nonfarm payrolls") return 0;
      if(name=="cpi" || name=="cpi m/m" || name=="cpi y/y" || name=="core cpi m/m") return 1;
      if(name=="ppi m/m" || name=="ppi y/y" || name=="core ppi m/m") return 2;
      if(name=="initial jobless claims") return 3;
   }
   return -1;
}

struct NQTimeEvidence
{
   int daylightMask;
   int standardMask;
   bool unexpectedTime;
};

void AddNQTimeEvidence(NQTimeEvidence &evidence,int family,datetime eventGMT,
   datetime weekStart)
{
   // Only Monday-Friday of this week. Never apply next week's regime early.
   if(family<0 || eventGMT<weekStart || eventGMT>=weekStart+5*86400)
      return;
   MqlDateTime tm;
   TimeToStruct(eventGMT,tm);
   int seconds=tm.hour*3600+tm.min*60+tm.sec;
   if(seconds==12*3600+30*60)
      evidence.daylightMask|=1<<family;
   else if(seconds==13*3600+30*60)
      evidence.standardMask|=1<<family;
   else
      evidence.unexpectedTime=true;
}

int NQCountTimeReports(int mask)
{
   int count=0;
   for(int i=0;i<4;i++)
      if((mask & (1<<i))!=0) count++;
   return count;
}

int ResolveNQTimeEvidence(const NQTimeEvidence &evidence,int minimumReports)
{
   if(evidence.unexpectedTime ||
      (evidence.daylightMask!=0 && evidence.standardMask!=0))
      return -1;
   if(NQCountTimeReports(evidence.daylightMask)>=minimumReports) return 1;
   if(NQCountTimeReports(evidence.standardMask)>=minimumReports) return 0;
   return -1;
}

bool ReadNQTimeEvidence(datetime weekStart,NQTimeEvidence &evidence)
{
   evidence.daylightMask=0;
   evidence.standardMask=0;
   evidence.unexpectedTime=false;
   if(MQLInfoInteger(MQL_TESTER))
   {
      // Never call live calendar functions in the tester, even if news is disabled.
      if(!InpUseTesterNewsData || !LoadTesterNewsData())
         return false;
      for(int i=0;i<ArraySize(g_testerNewsEvents);i++)
         AddNQTimeEvidence(evidence,NQTimeReportFamily(g_testerNewsEvents[i].name,false),
            g_testerNewsEvents[i].timeGMT,weekStart);
      return true;
   }
   MqlCalendarValue values[];
   int count=CalendarValueHistory(values,GMTToServerTime(weekStart),
      GMTToServerTime(weekStart+5*86400),"US","USD");
   if(count<0) return false;
   for(int i=0;i<count;i++)
   {
      MqlCalendarEvent event;
      if(!CalendarEventById(values[i].event_id,event))
         return false;
      if(event.time_mode!=CALENDAR_TIMEMODE_DATETIME)
         continue;
      AddNQTimeEvidence(evidence,NQTimeReportFamily(event.event_code,true),
         ServerToGMTTime(values[i].time),weekStart);
   }
   return true;
}

void UpdateNQTimeSchedule()
{
   datetime now=NQGMTNow();
   datetime day=GMTDayStart(now);
   int serverOffset=(int)(GMTToServerTime(now)-now);
   bool newDay=day!=g_nqScheduleDay;
   bool offsetChanged=serverOffset!=g_nqScheduleServerOffset;
   // Live refresh once per hour; tester's file is immutable for a run.
   if(!newDay && !offsetChanged &&
      (MQLInfoInteger(MQL_TESTER) || now<g_nqScheduleLastScan+3600))
      return;
   g_nqScheduleDay=day;
   g_nqScheduleServerOffset=serverOffset;
   g_nqScheduleLastScan=now;
   g_nqDetectedDaylight=-1;
   string reason="disabled";
   NQTimeEvidence evidence={0,0,false};
   if(InpEnableCalendarTimeSchedule)
   {
      MqlDateTime tm;
      TimeToStruct(now,tm);
      if(tm.day_of_week==0 || tm.day_of_week==6)
         reason="weekend";
      else if(!ReadNQTimeEvidence(NQScheduleWeekStart(now),evidence))
         reason="calendar/file unavailable";
      else
      {
         g_nqDetectedDaylight=ResolveNQTimeEvidence(evidence,InpCalendarTimeMinimumReports);
         reason=(evidence.unexpectedTime ||
            (evidence.daylightMask!=0 && evidence.standardMask!=0))
            ? "conflicting release times" : "insufficient independent reports";
      }
   }
   string previous=g_nqTimeScheduleStatus;
   if(g_nqDetectedDaylight>=0)
      g_nqTimeScheduleStatus=(g_nqDetectedDaylight==1 ? "Daylight" : "Standard")+
         " | calendar confirmed ("+IntegerToString(NQCountTimeReports(
            evidence.daylightMask|evidence.standardMask))+" reports)";
   else
   {
      string manual=InpManualTimeSchedule==NQ_SCHEDULE_CONFIGURED ? "configured GMT inputs" :
         (InpManualTimeSchedule==NQ_SCHEDULE_DAYLIGHT ? "Daylight" : "Standard");
      g_nqTimeScheduleStatus=(InpEnableCalendarTimeSchedule ? "UNCONFIRMED" : "MANUAL")+
         " | "+reason+" | fallback: "+manual;
   }
   if(previous!=g_nqTimeScheduleStatus || newDay)
      Print("NY SCHEDULE: ",g_nqTimeScheduleStatus," | fallback GMT ",
         NQScheduleClock(NQFallbackSeconds())," | NY start GMT ",NQScheduleClock(NQNYStartSeconds()));
}
#endif
