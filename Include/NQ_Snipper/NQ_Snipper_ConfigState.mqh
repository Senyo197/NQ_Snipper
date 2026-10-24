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

enum PatternFamily
{
   PATTERN_FAMILY_NONE = 0,
   PATTERN_FAMILY_DOUBLE,
   PATTERN_FAMILY_LEG_KNEE,
   PATTERN_FAMILY_TAIL_BODY,
   PATTERN_FAMILY_TAIL_BODY_V,
   PATTERN_FAMILY_COUNT
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
// After a successful NY reopening, allow one 60-minute post-NY H1 cooldown
// before a later breach locks the engine for the remaining GMT day.
input bool InpEnablePostNYH1CooldownReopen = false;
input bool InpEnableSpreadFilter = true;
input bool InpEnableBreakEvenManagement = true;
// Overall safety cap across all pattern families.
input bool InpEnableDailyTradeLimit = true;
input int InpMaxTradesPerDay = 2;
// Each family may place at most one successful entry per GMT day.
input bool InpEnableOneTradePerPatternPerDay = true;

input bool InpEnableDoublePattern = true;
input bool InpEnableLegKneePattern = true;
input bool InpEnableTailBodyPattern = true;
input bool InpEnableTailBodyVPattern = true;
input bool InpEnableBaseFilter = true;
input bool InpEnableBaseStartDistance = true;
input bool InpShowFirstLegMarker = true;
input bool InpShowFirstTurnMarker = true;
input bool InpShowFirstLegBodySpaceMarker = true;
input bool InpShowBaseMarker = true;


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
input int InpMaxPatternBars = 60;

input double InpDoubleTolerancePoints = 2000.0;
input double InpDoubleSweepAllowancePoints = 2000.0;
input double InpTurningPointGapTolerancePoints = 100.0;
input double InpMinRetracementPoints = 100.0;

input double InpEntryBufferPoints = 0.0;
input double InpLegKneeSwingTolerancePoints = 2000.0;
input int InpBaseMinimumCandles = 3;
input double InpBaseOpenTolerancePoints = 500.0;
input double InpBaseCloseTolerancePoints = 500.0;
input int InpBaseValidityMinutes = 45;
// Maximum open-to-close body size considered a doji for TailBody.
input double InpTailBodyDojiMaxBodyPoints = 100.0;
input bool InpTailBodyRequireConsecutiveLegCandles = true;
// Minimum completed candles strictly between the first pullback and arrival.
input bool InpEnableTailBodyPullbackSpacing = true;
input int InpTailBodyPullbackSpacingCandles = 3;
// Limit elapsed time from the body-space candle close to the entry-candle open.
input bool InpEnableTailBodyBodyToEntryTimeLimit = true;
input int InpTailBodyBodyToEntryMaxMinutes = 90;
input double InpTailBodyFirstPullbackMaxPoints = 15000.0;
input double InpTailBodySecondPullbackMaxPoints = 12000.0;
// Keep a normal TailBody first pullback moving until a valid first turn holds.
input bool InpEnableTailBodyFirstPullbackUpdater = true;
// False: update from candle bodies only. True: include wick extensions.
input bool InpTailBodyFirstPullbackUpdaterUseWicks = false;
input double InpTailBodyFirstPullbackUpdateTolerancePoints = 0.0;
// Maximum distance between the first and second arrival candle closes.
input double InpTailBodyArrivalCloseTolerancePoints = 1200.0;
// Discard the current TailBody setup if an intervening close leaves its body space.
input bool InpTailBodyInvalidateOnInterveningCloseOutsideBody = false;


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
int g_tradesPlacedToday = 0;
bool g_patternFamilyTradedToday[PATTERN_FAMILY_COUNT];

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
