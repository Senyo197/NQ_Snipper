#ifndef __NQ_SNIPPER_NEWS_DATA__
#define __NQ_SNIPPER_NEWS_DATA__
#include "NQ_Snipper_ConfigState.mqh"

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
   g_testerNewsLoaded = true;
   Print("TESTER NEWS: Loaded ", ArraySize(g_testerNewsEvents),
      " high-impact events from ", InpTesterNewsFile);
   return true;
}
#endif
