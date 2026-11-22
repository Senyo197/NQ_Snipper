#ifndef __NQ_SNIPPER_TESTER_CLOCK__
#define __NQ_SNIPPER_TESTER_CLOCK__

// Optional broker-offset history. Timestamps are GMT effective-from instants,
// not news release times. No US/broker DST dates are assumed here.
datetime g_nqTesterOffsetFrom[];
int g_nqTesterOffsets[];

bool LoadNQTesterOffsets()
{
   if(InpTesterServerGMTOffsetsFile == "")
      return true;
   int handle=FileOpen(InpTesterServerGMTOffsetsFile,
      FILE_READ|FILE_CSV|FILE_ANSI|FILE_COMMON, ',');
   if(handle == INVALID_HANDLE)
   {
      Print("TESTER CLOCK: Cannot open offset history: ",InpTesterServerGMTOffsetsFile);
      return false;
   }
   bool valid=true;
   while(!FileIsEnding(handle))
   {
      string fromText=FileReadString(handle);
      string offsetText=FileReadString(handle);
      if(fromText == "GMT" || fromText == "")
         continue;
      datetime from=StringToTime(fromText);
      int offset=(int)StringToInteger(offsetText);
      int size=ArraySize(g_nqTesterOffsets);
      if(from <= 0 || MathAbs(offset)>840 ||
         IntegerToString(offset)!=offsetText ||
         (size>0 && from<=g_nqTesterOffsetFrom[size-1]))
      {
         valid=false;
         break;
      }
      ArrayResize(g_nqTesterOffsetFrom,size+1);
      ArrayResize(g_nqTesterOffsets,size+1);
      g_nqTesterOffsetFrom[size]=from;
      g_nqTesterOffsets[size]=offset;
   }
   FileClose(handle);
   if(!valid || ArraySize(g_nqTesterOffsets)==0)
   {
      Print("TESTER CLOCK: Expected ascending GMT,OffsetMinutes rows with offsets within +/-840.");
      return false;
   }
   // The first row must cover the test start; do not extrapolate backwards.
   if(TimeTradeServer()<g_nqTesterOffsetFrom[0]+g_nqTesterOffsets[0]*60)
   {
      Print("TESTER CLOCK: Offset history does not cover the test start.");
      return false;
   }
   return true;
}

int NQTesterOffsetAtGMT(datetime gmt)
{
   for(int i=ArraySize(g_nqTesterOffsets)-1;i>=0;i--)
      if(gmt>=g_nqTesterOffsetFrom[i])
         return g_nqTesterOffsets[i]*60;
   return InpTesterServerGMTOffsetMinutes*60;
}

datetime TesterServerFromGMT(datetime gmt)
{
   return gmt+NQTesterOffsetAtGMT(gmt);
}

datetime TesterGMTFromServer(datetime server)
{
   for(int i=ArraySize(g_nqTesterOffsets)-1;i>=0;i--)
   {
      datetime gmt=server-g_nqTesterOffsets[i]*60;
      if(gmt>=g_nqTesterOffsetFrom[i] &&
         (i+1==ArraySize(g_nqTesterOffsets) || gmt<g_nqTesterOffsetFrom[i+1]))
         return gmt;
   }
   return server-InpTesterServerGMTOffsetMinutes*60;
}
#endif
