#ifndef __NQ_SNIPPER_BASE__
#define __NQ_SNIPPER_BASE__

// A base is a selected group of distinct candles whose opens and closes all
// fit inside independently-toleranced open and close bands. Matching candles
// must form within the configured validity duration.
// Candle colour and wicks do not affect the result. Selected candles need
// not be consecutive, and candles not selected are not checked here.
#define NQ_BASE_MIN_CANDLES 3
#define NQ_BASE_MAX_POINTS  2000.0

struct NQBaseZone
{
   double low;
   double high;
   double widthPoints;
   double anchorOpen;
   double anchorClose;
   datetime firstCandleTime;
   datetime lastCandleTime;
   int candleCount;
};

// Evaluate an already-qualified selection of candles. This function checks
// the price band only; FindNQBase performs the consecutive-candle rule.
// The selected candles must be distinct
// and ordered consistently by time, either oldest-first or newest-first.
// The caller chooses the symbol, timeframe, history window, candle selection,
// and whether to include a forming candle. pointSize must be that symbol's
// point size; no trading state, orders, chart objects, or inputs are changed.
bool EvaluateNQBase(const MqlRates &candles[], const double pointSize,
   NQBaseZone &base, const int minimumCandles = NQ_BASE_MIN_CANDLES,
   const double maxPoints = NQ_BASE_MAX_POINTS)
{
   base.low = 0.0;
   base.high = 0.0;
   base.widthPoints = 0.0;
   base.firstCandleTime = 0;
   base.lastCandleTime = 0;
   base.candleCount = 0;

   int count = ArraySize(candles);
   if(minimumCandles < NQ_BASE_MIN_CANDLES || count < minimumCandles ||
      !MathIsValidNumber(pointSize) || pointSize <= 0.0 ||
      !MathIsValidNumber(maxPoints) || maxPoints < 0.0)
      return false;

   double lowest = 0.0;
   double highest = 0.0;
   int timeDirection = 0;

   for(int i = 0; i < count; i++)
   {
      if(candles[i].time <= 0 || !MathIsValidNumber(candles[i].open) ||
         !MathIsValidNumber(candles[i].close) ||
         candles[i].open <= 0.0 || candles[i].close <= 0.0)
         return false;

      if(i > 0)
      {
         if(candles[i].time == candles[i-1].time)
            return false;
         int currentDirection = candles[i].time > candles[i-1].time ? 1 : -1;
         if(timeDirection != 0 && timeDirection != currentDirection)
            return false;
         timeDirection = currentDirection;
      }

      double candleLow = MathMin(candles[i].open, candles[i].close);
      double candleHigh = MathMax(candles[i].open, candles[i].close);
      if(i == 0)
      {
         lowest = candleLow;
         highest = candleHigh;
      }
      else
      {
         lowest = MathMin(lowest, candleLow);
         highest = MathMax(highest, candleHigh);
      }
   }

   double widthPoints = (highest - lowest) / pointSize;
   // Allow only a tiny rounding margin at the configured boundary.
   if(!MathIsValidNumber(widthPoints) || widthPoints > maxPoints + 0.0000001)
      return false;

   base.low = lowest;
   base.high = highest;
   base.widthPoints = widthPoints;
   base.firstCandleTime = timeDirection > 0 ? candles[0].time : candles[count-1].time;
   base.lastCandleTime = timeDirection > 0 ? candles[count-1].time : candles[0].time;
   base.candleCount = count;
   return true;
}

// Find any qualifying subset of a complete, time-ordered interval. Selected
// candles may be separated by others. If a bullish candle immediately follows
// a bullish candle and closes higher, it is ineligible. Likewise, a bearish
// candle immediately following a bearish candle and closing lower is ineligible.
// Compare against the actual previous candle, even if it was itself excluded.
// Returning
// false means the search could not be performed; found=false means it was
// performed successfully and no base was present.
bool FindNQBase(const MqlRates &candles[], const double pointSize,
   const int minimumCandles, const double maxPoints, NQBaseZone &base,
   bool &found)
{
   found = false;
   base.low = 0.0;
   base.high = 0.0;
   base.widthPoints = 0.0;
   base.firstCandleTime = 0;
   base.lastCandleTime = 0;
   base.candleCount = 0;

   if(minimumCandles < NQ_BASE_MIN_CANDLES || !MathIsValidNumber(pointSize) ||
      pointSize <= 0.0 || !MathIsValidNumber(maxPoints) || maxPoints < 0.0)
      return false;

   int count = ArraySize(candles);
   if(count < minimumCandles)
      return true;

   int timeDirection = 0;
   for(int i = 0; i < count; i++)
   {
      if(candles[i].time <= 0 || !MathIsValidNumber(candles[i].open) ||
         !MathIsValidNumber(candles[i].close) ||
         candles[i].open <= 0.0 || candles[i].close <= 0.0)
         return false;
      if(i > 0)
      {
         if(candles[i].time == candles[i-1].time)
            return false;
         int currentDirection = candles[i].time > candles[i-1].time ? 1 : -1;
         if(timeDirection != 0 && timeDirection != currentDirection)
            return false;
         timeDirection = currentDirection;
      }
   }

   bool eligible[];
   if(ArrayResize(eligible, count) != count)
      return false;
   int eligibleCount = 0;
   for(int i = 0; i < count; i++)
   {
      int previous = timeDirection > 0 ? i - 1 : i + 1;
      bool progressive = false;
      if(previous >= 0 && previous < count)
      {
         bool risingBullish = candles[i].close > candles[i].open &&
            candles[previous].close > candles[previous].open &&
            candles[i].close > candles[previous].close;
         bool fallingBearish = candles[i].close < candles[i].open &&
            candles[previous].close < candles[previous].open &&
            candles[i].close < candles[previous].close;
         progressive = risingBullish || fallingBearish;
      }
      eligible[i] = !progressive;
      if(eligible[i])
         eligibleCount++;
   }
   if(eligibleCount < minimumCandles)
      return true;

   MqlRates selected[];
   if(ArrayResize(selected, minimumCandles) != minimumCandles)
      return false;

   // Every possible base has one candle with the lowest body price.
   // Try each body low as the band floor; the first matching subset is enough.
   for(int anchor = 0; anchor < count; anchor++)
   {
      if(!eligible[anchor])
         continue;

      double floorPrice = MathMin(candles[anchor].open, candles[anchor].close);
      int selectedCount = 0;
      for(int i = 0; i < count; i++)
      {
         if(!eligible[i])
            continue;
         double candleLow = MathMin(candles[i].open, candles[i].close);
         double candleHigh = MathMax(candles[i].open, candles[i].close);
         if(candleLow < floorPrice ||
            (candleHigh - floorPrice) / pointSize > maxPoints + 0.0000001)
            continue;
         selected[selectedCount++] = candles[i];
         if(selectedCount == minimumCandles)
         {
            if(!EvaluateNQBase(selected, pointSize, base, minimumCandles, maxPoints))
               return false;
            found = true;
            return true;
         }
      }
   }
   return true;
}

// New shared base definition: the first selected candle anchors two separate
// price ends. Later matching candles do not need to be consecutive; candles
// that miss either end are ignored rather than ending the search.
bool IsNQTwoEndedBaseMatch(const MqlRates &candle,double anchorOpen,
   double anchorClose,double pointSize,double openTolerancePoints,
   double closeTolerancePoints)
{
   if(candle.time<=0 || candle.open<=0.0 || candle.close<=0.0)
      return false;
   return MathAbs(candle.open-anchorOpen)/pointSize<=openTolerancePoints+0.0000001 &&
      MathAbs(candle.close-anchorClose)/pointSize<=closeTolerancePoints+0.0000001;
}

bool FindNQTwoEndedBase(const MqlRates &candles[],const double pointSize,
   const int minimumCandles,const double openTolerancePoints,
   const double closeTolerancePoints,const int validityMinutes,
   NQBaseZone &base,bool &found)
{
   found=false;
   base.low=0.0;
   base.high=0.0;
   base.widthPoints=0.0;
   base.anchorOpen=0.0;
   base.anchorClose=0.0;
   base.firstCandleTime=0;
   base.lastCandleTime=0;
   base.candleCount=0;

   int count=ArraySize(candles);
   if(minimumCandles<NQ_BASE_MIN_CANDLES ||
      !MathIsValidNumber(pointSize) || pointSize<=0.0 ||
      !MathIsValidNumber(openTolerancePoints) || openTolerancePoints<0.0 ||
       !MathIsValidNumber(closeTolerancePoints) || closeTolerancePoints<0.0 ||
       validityMinutes<1)
      return false;
   if(count<minimumCandles)
      return true;

   int timeDirection=0;
   for(int i=0;i<count;i++)
   {
      if(candles[i].time<=0 || !MathIsValidNumber(candles[i].open) ||
         !MathIsValidNumber(candles[i].close) || candles[i].open<=0.0 ||
         candles[i].close<=0.0)
         return false;
      if(i>0)
      {
         if(candles[i].time==candles[i-1].time)
            return false;
         int direction=candles[i].time>candles[i-1].time ? 1 : -1;
         if(timeDirection!=0 && timeDirection!=direction)
            return false;
         timeDirection=direction;
      }
   }

   int step=timeDirection>=0 ? 1 : -1;
   long maximumDurationSeconds=(long)validityMinutes*60;
   datetime latestCompletionTime=0;
   NQBaseZone latestBase;
   latestBase.low=0.0;
   latestBase.high=0.0;
   latestBase.widthPoints=0.0;
   latestBase.anchorOpen=0.0;
   latestBase.anchorClose=0.0;
   latestBase.firstCandleTime=0;
   latestBase.lastCandleTime=0;
   latestBase.candleCount=0;
   for(int anchor=step>0 ? 0 : count-1;
      anchor>=0 && anchor<count;anchor+=step)
   {
      double anchorOpen=candles[anchor].open;
      double anchorClose=candles[anchor].close;
      int matched=1;
      datetime lastMatchTime=candles[anchor].time;
       datetime completionTime=0;
      double lowest=MathMin(anchorOpen,anchorClose);
      double highest=MathMax(anchorOpen,anchorClose);

      for(int candidate=anchor+step;
         candidate>=0 && candidate<count;candidate+=step)
      {
          if(MathAbs((long)(candles[candidate].time-candles[anchor].time))>
             maximumDurationSeconds)
             break;
         if(!IsNQTwoEndedBaseMatch(candles[candidate],anchorOpen,anchorClose,
            pointSize,openTolerancePoints,closeTolerancePoints))
            continue;
         matched++;
         lastMatchTime=candles[candidate].time;
         lowest=MathMin(lowest,MathMin(candles[candidate].open,candles[candidate].close));
         highest=MathMax(highest,MathMax(candles[candidate].open,candles[candidate].close));
          if(matched==minimumCandles)
             completionTime=lastMatchTime;
      }

      if(matched<minimumCandles)
         continue;
       // A freshly completed three-candle group replaces an older base. A
       // newer matching candle still extends the selected group's end time.
       if(completionTime>latestCompletionTime)
       {
          latestCompletionTime=completionTime;
          latestBase.low=lowest;
          latestBase.high=highest;
          latestBase.widthPoints=(highest-lowest)/pointSize;
          latestBase.anchorOpen=anchorOpen;
          latestBase.anchorClose=anchorClose;
          latestBase.firstCandleTime=timeDirection>=0 ? candles[anchor].time : lastMatchTime;
          latestBase.lastCandleTime=timeDirection>=0 ? lastMatchTime : candles[anchor].time;
          latestBase.candleCount=matched;
       }
   }
   if(latestCompletionTime>0)
   {
      base=latestBase;
      found=true;
   }
   return true;
}

#endif
