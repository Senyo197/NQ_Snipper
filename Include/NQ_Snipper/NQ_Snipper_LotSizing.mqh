#ifndef __NQ_SNIPPER_LOT_SIZING__
#define __NQ_SNIPPER_LOT_SIZING__
#include "NQ_Snipper_ConfigState.mqh"

double g_nqLotStartingBalance=0.0;
double g_nqLotInitialStopLossMoney=0.0;
bool g_nqLotSizingInitialized=false;
string g_nqLotStateKey="";
string g_nqLotSizingError="";

// Pure balance-band calculation. Recompute from balance on every new order,
// so a jump across several bands and a falling balance both work immediately.
// Example: start=10000, base lot=1, initial cash SL=500, multiplier=40:
// [below 30000]=1; [30000,70000)=2; [70000,150000)=4; etc.
double NQBalanceBandVolume(double balance,double startBalance,double baseLot,
   double initialLoss,double multiple)
{
   if(!MathIsValidNumber(balance) || !MathIsValidNumber(startBalance) ||
      !MathIsValidNumber(baseLot) || !MathIsValidNumber(initialLoss) ||
      !MathIsValidNumber(multiple) || startBalance<=0 || baseLot<=0 ||
      initialLoss<=0 || multiple<=0)
      return 0.0;
   double volume=baseLot;
   double loss=initialLoss;
   double lower=startBalance;
   for(int level=0;level<100;level++)
   {
      double upper=lower+loss*multiple;
      if(!MathIsValidNumber(upper) || upper<=lower || balance<upper)
         return volume;
      lower=upper;
      loss*=2.0;
      volume*=2.0;
      if(!MathIsValidNumber(volume) || !MathIsValidNumber(loss))
         return 0.0;
   }
   return 0.0;
}

// Broker limits are applied after choosing the band. Never round UP risk or
// raise a below-minimum requested volume to the broker's minimum.
double NQBrokerVolume(double requested,double minimum,double maximum,double step)
{
   if(!MathIsValidNumber(requested) || !MathIsValidNumber(minimum) ||
      !MathIsValidNumber(maximum) || !MathIsValidNumber(step) ||
      requested<=0 || minimum<=0 || maximum<minimum || step<=0)
      return 0.0;
   double capped=MathMin(requested,maximum);
   double volume=NormalizeDouble(MathFloor(capped/step+1e-9)*step,8);
   if(volume<minimum-1e-9 || volume>maximum+1e-9)
      return 0.0;
   return volume;
}

string NQLotStateKey()
{
   // Separate anchors for account/server, symbol, magic and sizing settings.
   string settings=AccountInfoString(ACCOUNT_SERVER)+"|"+_Symbol+"|"+
      DoubleToString(InpLotSize,8)+"|"+IntegerToString(InpStopLossPoints)+"|"+
      DoubleToString(InpBalanceLotStartingBalance,8)+"|"+
      DoubleToString(InpBalanceLotInitialStopLossMoney,8)+"|"+
      DoubleToString(InpBalanceLotThresholdMultiplier,8);
   uint hash=2166136261;
   for(int i=0;i<StringLen(settings);i++)
      hash=(hash^(uint)StringGetCharacter(settings,i))*16777619;
   return StringFormat("NQLot.%I64d.%I64u.%08X",
      AccountInfoInteger(ACCOUNT_LOGIN),InpMagicNumber,hash);
}

bool InitializeNQLotSizing()
{
   if(!InpEnableBalanceLotSizing)
      return true;
   if(!MathIsValidNumber(InpLotSize) || InpLotSize<=0 ||
      !MathIsValidNumber(InpBalanceLotStartingBalance) || InpBalanceLotStartingBalance<0 ||
      !MathIsValidNumber(InpBalanceLotInitialStopLossMoney) || InpBalanceLotInitialStopLossMoney<0 ||
      !MathIsValidNumber(InpBalanceLotThresholdMultiplier) || InpBalanceLotThresholdMultiplier<=0 ||
      InpStopLossPoints<=0)
   {
      Print("BALANCE LOTS: Requires a positive starting lot, stop distance and multiplier; balance/cash-loss overrides must be non-negative.");
      return false;
   }
   g_nqLotStateKey=NQLotStateKey();
   bool persist=!MQLInfoInteger(MQL_TESTER);
   g_nqLotStartingBalance=InpBalanceLotStartingBalance;
   g_nqLotInitialStopLossMoney=InpBalanceLotInitialStopLossMoney;
   if(persist)
   {
      if(g_nqLotStartingBalance==0 && GlobalVariableCheck(g_nqLotStateKey+".Balance"))
         g_nqLotStartingBalance=GlobalVariableGet(g_nqLotStateKey+".Balance");
      if(g_nqLotInitialStopLossMoney==0 && GlobalVariableCheck(g_nqLotStateKey+".Loss"))
         g_nqLotInitialStopLossMoney=GlobalVariableGet(g_nqLotStateKey+".Loss");
   }
   if(g_nqLotStartingBalance==0)
      g_nqLotStartingBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(!MathIsValidNumber(g_nqLotStartingBalance) || g_nqLotStartingBalance<=0 ||
      !MathIsValidNumber(g_nqLotInitialStopLossMoney) || g_nqLotInitialStopLossMoney<0)
   {
      Print("BALANCE LOTS: Invalid starting balance or saved monetary loss. Set explicit overrides.");
      return false;
   }
   double minimum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN);
   double maximum=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX);
   double step=SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
   double base=NQBrokerVolume(InpLotSize,minimum,maximum,step);
   if(base<=0 || MathAbs(base-InpLotSize)>1e-8)
   {
      Print("BALANCE LOTS: Starting InpLotSize must be within the broker's volume limits and on its volume step.");
      return false;
   }
   if(persist)
   {
      if(GlobalVariableSet(g_nqLotStateKey+".Balance",g_nqLotStartingBalance)==0)
         return false;
      GlobalVariablesFlush();
   }
   g_nqLotSizingInitialized=true;
   Print("BALANCE LOTS: Starting balance=",DoubleToString(g_nqLotStartingBalance,2),
      ", starting lots=",DoubleToString(InpLotSize,8),
      ", multiplier=",DoubleToString(InpBalanceLotThresholdMultiplier,2));
   return true;
}

bool EnsureNQLotCashLoss()
{
   if(!g_nqLotSizingInitialized)
      return false;
   if(g_nqLotInitialStopLossMoney>0)
      return true;
   // Quotes/conversion rates may not exist in OnInit. Retry when an entry or
   // the panel requests sizing, keeping the original captured balance fixed.
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=0 || tick.bid<=0 || _Point<=0)
      return false;
   double buyLoss=0.0,sellLoss=0.0;
   double buyStop=NormalizeDouble(tick.ask-InpStopLossPoints*_Point,_Digits);
   double sellStop=NormalizeDouble(tick.bid+InpStopLossPoints*_Point,_Digits);
   if(buyStop<=0 || !OrderCalcProfit(ORDER_TYPE_BUY,_Symbol,InpLotSize,tick.ask,buyStop,buyLoss) ||
      !OrderCalcProfit(ORDER_TYPE_SELL,_Symbol,InpLotSize,tick.bid,sellStop,sellLoss) ||
      !MathIsValidNumber(buyLoss) || !MathIsValidNumber(sellLoss) || buyLoss>=0 || sellLoss>=0)
      return false;
   double loss=MathMax(-buyLoss,-sellLoss);
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(GlobalVariableSet(g_nqLotStateKey+".Loss",loss)==0)
         return false;
      GlobalVariablesFlush();
   }
   g_nqLotInitialStopLossMoney=loss;
   Print("BALANCE LOTS: Fixed initial monetary SL=",DoubleToString(loss,2)," ",
      AccountInfoString(ACCOUNT_CURRENCY),"; excludes commission/slippage.");
   return true;
}

double NQEntryLotSize()
{
   if(!InpEnableBalanceLotSizing)
      return InpLotSize;
   g_nqLotSizingError="";
   if(!EnsureNQLotCashLoss())
   {
      g_nqLotSizingError="waiting for starting balance / monetary SL";
      return 0.0;
   }
   // Refresh terminal-global access so an actively used live anchor does not
   // expire after four weeks. Tests use run-local state only.
   if(!MQLInfoInteger(MQL_TESTER))
   {
      if(GlobalVariableCheck(g_nqLotStateKey+".Balance"))
         GlobalVariableGet(g_nqLotStateKey+".Balance");
      if(GlobalVariableCheck(g_nqLotStateKey+".Loss"))
         GlobalVariableGet(g_nqLotStateKey+".Loss");
   }
   double requested=NQBalanceBandVolume(AccountInfoDouble(ACCOUNT_BALANCE),
      g_nqLotStartingBalance,InpLotSize,g_nqLotInitialStopLossMoney,InpBalanceLotThresholdMultiplier);
   double volume=NQBrokerVolume(requested,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),
      SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   if(volume<InpLotSize-1e-8)
      volume=0.0;
   if(volume<=0)
      g_nqLotSizingError="invalid balance or broker volume limits";
   return volume;
}

string NQLotSizingPanel()
{
   if(!InpEnableBalanceLotSizing)
      return "Lots: "+DoubleToString(InpLotSize,4)+" (fixed)\n";
   double volume=NQEntryLotSize();
   if(volume<=0)
      return "Balance lots: "+g_nqLotSizingError+"\n";
   return "Balance lots: "+DoubleToString(volume,4)+
      " | Start balance: "+DoubleToString(g_nqLotStartingBalance,2)+
      " | Initial SL money: "+DoubleToString(g_nqLotInitialStopLossMoney,2)+"\n";
}
#endif
