#ifndef __NQ_SNIPPER_CONFIG_STATE__
#define __NQ_SNIPPER_CONFIG_STATE__

//==================================================
// PATTERN CONSTANTS
//==================================================

enum PatternType
{
   PATTERN_NONE = 0,

   PATTERN_DOUBLE_TOP,
   PATTERN_DOUBLE_BOTTOM,

   PATTERN_TAIL_BODY_TOP,
   PATTERN_TAIL_BODY_BOTTOM,

   PATTERN_LEG_KNEE_TOP,
   PATTERN_LEG_KNEE_BOTTOM
};


//==================================================
// TRADING INPUTS
//==================================================

input double InpLotSize = 1.0;
input ulong  InpMagicNumber = 26091901;

input int InpStopLossPoints = 3000;
input int InpTakeProfitPoints = 15000;
input int InpBreakEvenTriggerPoints = 5000;

input int InpMaxSpreadPoints = 200;


//==================================================
// NEWS TIMING
//==================================================

input int InpPreNYWaitMinutes = 20;
input int InpPostNYWaitMinutes = 10;

input int InpFallbackHourGMT = 11;
input int InpFallbackMinuteGMT = 50;

input int InpNYStartHourGMT = 13;
input int InpNYStartMinuteGMT = 30;

input int InpEntryStartHourGMT = 11;
input int InpEntryStartMinuteGMT = 50;
input int InpEntryEndHourGMT = 15;
input int InpEntryEndMinuteGMT = 30;
input int InpFOMCEntryEndHourGMT = 19;
input int InpFOMCEntryEndMinuteGMT = 30;

input double InpHourlyStrongCandleMinPoints = 10000.0;


//==================================================
// PATTERN SETTINGS
//==================================================

input int InpSwingStrength = 2;

input int InpMinPatternBars = 10;
input int InpMaxPatternBars = 60;

input double InpDoubleTolerancePoints = 2000.0;
input double InpDoubleSweepAllowancePoints = 2000.0;
input double InpDoubleRetestTolerancePoints = 100.0;
input double InpDoubleRetestSetMaxDistancePoints = 1500.0;
input int    InpDoubleRetestSetMaxBars = 25;
input double InpMinRetracementPoints = 100.0;

input double InpEntryBufferPoints = 0.0;
input double InpLegKneeSwingTolerancePoints = 2000.0;
input int InpLegKneeRetestCandles = 2;
input double InpLegKneeRetestTolerancePoints = 100.0;
input int InpLegKneeRetestMaxBars = 25;
input double InpLegKneeReversalBufferPoints = 0.0;

input int InpTailBodyVRetestCandles = 2;
input double InpTailBodyVRetestTolerancePoints = 100.0;
input double InpTailBodyVSecondNecklineTolerancePoints = 500.0;


//==================================================
// GLOBAL STATE
//==================================================

datetime g_latestRedNewsGMT = 0;
datetime g_activationTimeGMT = 0;

bool g_patternEngineActive = false;

int g_detectedPattern = PATTERN_NONE;

datetime g_lastBarTime = 0;

bool g_tradePlacedForCycle = false;
datetime g_tradeLimitDayStartGMT = 0;

bool g_hasHighImpactNewsToday = false;
bool g_isFOMCToday = false;

string g_latestHighImpactNewsName = "";

datetime g_rangeFilterDayStartGMT = 0;
bool g_rangeBlockedForDay = false;

#endif
