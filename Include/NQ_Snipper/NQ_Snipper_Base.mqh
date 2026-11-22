#ifndef __NQ_SNIPPER_BASE__
#define __NQ_SNIPPER_BASE__

// A two-ended Base matches lower and upper candle body edges to the anchor's
// corresponding edges within separate tolerances and a formation window.
// Candles can be non-consecutive. Directional progression is filtered after
// matching the body edges.
#define NQ_BASE_MIN_ALLOWED_CANDLES 2

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


// Match both body edges regardless of whether the open or close made them.
bool IsNQTwoEndedBaseMatch(const MqlRates &candle,double anchorBodyLow,
   double anchorBodyHigh,double pointSize,double lowerTolerancePoints,
   double upperTolerancePoints)
{
   if(candle.time<=0 || candle.open<=0.0 || candle.close<=0.0)
      return false;
   double bodyLow=MathMin(candle.open,candle.close);
   double bodyHigh=MathMax(candle.open,candle.close);
   return MathAbs(bodyLow-anchorBodyLow)/pointSize<=lowerTolerancePoints+0.0000001 &&
      MathAbs(bodyHigh-anchorBodyHigh)/pointSize<=upperTolerancePoints+0.0000001;
}

bool FindNQTwoEndedBase(const MqlRates &candles[],const double pointSize,
   const int minimumCandles,const double lowerTolerancePoints,
   const double upperTolerancePoints,const int validityMinutes,
   NQBaseZone &base,bool &found,const int returnDirection=0,
   const double minimumReturnPoints=0.0)
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
   if(minimumCandles<NQ_BASE_MIN_ALLOWED_CANDLES ||
      !MathIsValidNumber(pointSize) || pointSize<=0.0 ||
      !MathIsValidNumber(lowerTolerancePoints) || lowerTolerancePoints<0.0 ||
       !MathIsValidNumber(upperTolerancePoints) || upperTolerancePoints<0.0 ||
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
      double anchorBodyLow=MathMin(anchorOpen,anchorClose);
      double anchorBodyHigh=MathMax(anchorOpen,anchorClose);
       double anchorMidpoint=(anchorOpen+anchorClose)*0.5;
       int matchingIndexes[];
       if(ArrayResize(matchingIndexes,count)!=count)
         return false;
       int matchingCount=1;
       matchingIndexes[0]=anchor;

       for(int candidate=anchor+step;candidate>=0 && candidate<count;candidate+=step)
       {
          MqlRates candle=candles[candidate];
          if(MathAbs((long)(candle.time-candles[anchor].time))>maximumDurationSeconds)
             break;

          // A completed close far enough toward the First Leg ends the
          // search from this anchor, even if it never formed a valid Base.
          if(returnDirection!=0)
          {
             double returnPoints=returnDirection*(candle.close-anchorMidpoint)/pointSize;
             if(returnPoints>0.0 && returnPoints+0.000001>=minimumReturnPoints)
                break;
          }
          if(IsNQTwoEndedBaseMatch(candle,anchorBodyLow,anchorBodyHigh,
             pointSize,lowerTolerancePoints,upperTolerancePoints))
             matchingIndexes[matchingCount++]=candidate;
       }
       if(matchingCount<minimumCandles)
         continue;

       // Directional progress is checked only among qualifying Base candles.
       // Opposite-colour candles and dojis can intervene without breaking a
       // bullish or bearish sequence. The first candle remains eligible; the
       // second and third candles are removed only after the third successive
       // higher bullish close (or lower bearish close) confirms the sequence.
       bool eligible[];
       if(ArrayResize(eligible,matchingCount)!=matchingCount)
         return false;
       ArrayInitialize(eligible,true);
       int bullishRun=0;
       int bearishRun=0;
       int previousBullishPosition=-1;
       int previousBearishPosition=-1;
       double lastBullishClose=0.0;
       double lastBearishClose=0.0;
       for(int position=0;position<matchingCount;position++)
       {
          MqlRates candle=candles[matchingIndexes[position]];
          if(candle.close>candle.open)
          {
             if(bullishRun==0 || candle.close<=lastBullishClose)
             {
                bullishRun=1;
                lastBullishClose=candle.close;
             }
             else
             {
                bullishRun++;
                if(bullishRun==3)
                {
                   eligible[previousBullishPosition]=false;
                   eligible[position]=false;
                }
                else if(bullishRun>3)
                   eligible[position]=false;
                previousBullishPosition=position;
                lastBullishClose=candle.close;
             }
          }
          else if(candle.close<candle.open)
          {
             if(bearishRun==0 || candle.close>=lastBearishClose)
             {
                bearishRun=1;
                lastBearishClose=candle.close;
             }
             else
             {
                bearishRun++;
                if(bearishRun==3)
                {
                   eligible[previousBearishPosition]=false;
                   eligible[position]=false;
                }
                else if(bearishRun>3)
                   eligible[position]=false;
                previousBearishPosition=position;
                lastBearishClose=candle.close;
             }
          }
       }

       int matched=0;
       datetime lastMatchTime=0;
       double lowest=0.0;
       double highest=0.0;
       for(int position=0;position<matchingCount;position++)
       {
          if(!eligible[position])
             continue;
          MqlRates candle=candles[matchingIndexes[position]];
          if(matched==0)
          {
             lowest=MathMin(candle.open,candle.close);
             highest=MathMax(candle.open,candle.close);
          }
          else
          {
             lowest=MathMin(lowest,MathMin(candle.open,candle.close));
             highest=MathMax(highest,MathMax(candle.open,candle.close));
          }
          matched++;
          lastMatchTime=candle.time;
       }
       if(matched<minimumCandles)
          continue;

       datetime completionTime=lastMatchTime;
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
