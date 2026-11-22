#ifndef __NQ_SNIPPER_TIME_CALENDAR__
#define __NQ_SNIPPER_TIME_CALENDAR__

#include "NQ_Snipper_ConfigState.mqh"
#include "NQ_Snipper_TesterClock.mqh"

datetime NQGMTNow()
{
   if(MQLInfoInteger(MQL_TESTER))
      return TesterGMTFromServer(TimeTradeServer());
   return TimeGMT();
}

//==================================================
// GMT -> SERVER TIME
//==================================================

datetime GMTToServerTime(datetime gmtTime)
{
   if(MQLInfoInteger(MQL_TESTER))
      return TesterServerFromGMT(gmtTime);
   int offset = (int)MathRound((double)(TimeTradeServer()-TimeGMT())/60.0)*60;
   return gmtTime + offset;
}


//==================================================
// SERVER TIME -> GMT
//==================================================

datetime ServerToGMTTime(datetime serverTime)
{
   if(MQLInfoInteger(MQL_TESTER))
      return TesterGMTFromServer(serverTime);
   int offset = (int)MathRound((double)(TimeTradeServer()-TimeGMT())/60.0)*60;
   return serverTime - offset;
}


//==================================================
// START OF GMT DAY
//==================================================

datetime GMTDayStart(datetime gmtTime)
{
   MqlDateTime dt;
   TimeToStruct(gmtTime, dt);

   dt.hour = 0;
   dt.min = 0;
   dt.sec = 0;

   return StructToTime(dt);
}


//==================================================
// END OF GMT DAY
//==================================================

datetime GMTDayEnd(datetime gmtTime)
{
   return GMTDayStart(gmtTime) + 86399;
}


//==================================================
// FORMAT GMT TIME
//==================================================

string FormatGMT(datetime value)
{
   if(value <= 0)
      return "NONE";

   return TimeToString(value, TIME_DATE | TIME_SECONDS) + " GMT";
}

#include "NQ_Snipper_TimeSchedule.mqh"

#endif