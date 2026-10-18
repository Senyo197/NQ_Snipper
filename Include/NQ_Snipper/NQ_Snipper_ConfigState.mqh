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
input int InpBreakEvenTriggerPoints = 4500;

input int InpMaxSpreadPoints = 200;


//==================================================
// TESTING FEATURE TOGGLES
//==================================================

input bool InpEnableNewsTimingFilter = true;
input bool InpUseTesterNewsData = true;
input string InpTesterNewsFile = "NQ_Snipper_News.csv";
input bool InpEnableTradingHoursFilter = true;
input bool InpEnableHourlyMomentumFilter = true;
input bool InpCheckCurrentH1Candle = true;
input bool InpEnableSpreadFilter = true;
input bool InpEnableBreakEvenManagement = true;

input bool InpEnableDoublePattern = true;
input bool InpEnableLegKneePattern = true;
input bool InpEnableTailBodyPattern = true;
input bool InpEnableTailBodyVPattern = true;
input bool InpShowFirstLegMarker = true;
input bool InpShowFirstTurnMarker = true;
input bool InpShowFirstLegBodySpaceMarker = true;


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
input int InpEntryEndHourGMT = 16;
input int InpEntryEndMinuteGMT = 30;
input int InpFOMCEntryEndHourGMT = 19;
input int InpFOMCEntryEndMinuteGMT = 30;

input double InpHourlyStrongCandleMinPoints = 10000.0;

input double InpFirstLegMinimumMovePoints = 8000.0;


//==================================================
// PATTERN SETTINGS
//==================================================

input int InpSwingStrength = 2;

input int InpMinPatternBars = 10;
input int InpMaxPatternBars = 30;

input double InpDoubleTolerancePoints = 2000.0;
input double InpDoubleSweepAllowancePoints = 2000.0;
input double InpTurningPointGapTolerancePoints = 100.0;
input double InpMinRetracementPoints = 100.0;

input double InpEntryBufferPoints = 0.0;
input double InpLegKneeSwingTolerancePoints = 2000.0;
input bool InpTailBodyRequireConsecutiveLegCandles = false;
input double InpTailBodyFirstPullbackMaxPoints = 8000.0;
input double InpTailBodySecondPullbackMaxPoints = 5000.0;
// Maximum distance between the first and second arrival candle closes.
input double InpTailBodyArrivalCloseTolerancePoints = 1000.0;
// Discard the current TailBody setup if an intervening close leaves its body space.
input bool InpTailBodyInvalidateOnInterveningCloseOutsideBody = true;


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

// The opening classification is shared by all pattern modules. A first leg
// has direction only after a one-sided move or a range breakout.
enum FirstLegDirection
{
   FIRST_LEG_NEITHER = 0,
   FIRST_LEG_BULLISH = 1,
   FIRST_LEG_BEARISH = -1
};

datetime g_firstLegDayStartGMT = 0;
datetime g_firstLegLastProcessedBar = 0;
int g_firstLegDirection = FIRST_LEG_NEITHER;
double g_firstLegRangeHigh = 0.0;
double g_firstLegRangeLow = 0.0;
double g_firstLegPrice = 0.0;
datetime g_firstLegTime = 0;
datetime g_firstLegStartTime = 0;
bool g_firstLegReady = false;

#endif
