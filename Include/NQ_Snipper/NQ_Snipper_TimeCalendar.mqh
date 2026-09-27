#ifndef __NQ_SNIPPER_TIME_CALENDAR__
#define __NQ_SNIPPER_TIME_CALENDAR__

//==================================================
// GMT -> SERVER TIME
//==================================================

datetime GMTToServerTime(datetime gmtTime)
{
   datetime serverNow = TimeTradeServer();
   datetime gmtNow = TimeGMT();

   int offset = (int)(serverNow - gmtNow);

   return gmtTime + offset;
}


//==================================================
// SERVER TIME -> GMT
//==================================================

datetime ServerToGMTTime(datetime serverTime)
{
   datetime serverNow = TimeTradeServer();
   datetime gmtNow = TimeGMT();

   int offset = (int)(serverNow - gmtNow);

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

#endif