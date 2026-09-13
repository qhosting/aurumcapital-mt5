#ifndef AURUM_ENGINE_MQH
#define AURUM_ENGINE_MQH
#include <Trade/Trade.mqh>
#include "AurumMath.mqh"

input group "V15 - Risk / ownership"
input int InpMagicNumber=AURUM_DEFAULT_MAGIC;
input bool InpAllowLiveTrading=false;
input bool InpManageManualTrades=false;
input bool InpManageLegacyMagic=false; // Explicitly adopt 777999 on Micro only.
input double InpRiskPercent=0.25;
input double InpMaxPortfolioRiskPercent=0.5;
input double InpMaxDailyLoss=1.0;
input double InpMaxTotalDrawdown=6.0;
input int InpMaxDailyTrades=3;
input int InpMaxConsecutiveLosses=2;
input bool InpCloseManagedOnDrawdown=false; // Other EAs/manuals never forcibly closed unless owned.
input double InpInitialDayEquity=0; // Required on first REAL-account attachment.
input double InpInitialPeakEquity=0; // Verified equity baseline, adjusted for historical flows.
input int InpDeviationPoints=10;
input double InpCostReservePerLot=0.0; // Account currency, round trip fee reserve per lot.
input string InpExperimentId="baseline-v15";
input group "V15 - Signal (closed bars only)"
input int InpEMAPeriod=200;
input bool InpUseMTFFilter=true;
input int InpRSIOversold=42;
input int InpRSIOverbought=58;
input int InpADXThreshold=20;
input int InpSwingLength=5;
input int InpZoneMaxAgeBars=200;
input bool InpUseOrderBlocks=true;
input bool InpUseBreakerBlocks=true;
input bool InpRequireFVG=false;
input bool InpRequireSweep=false;
input bool InpUseStructuralSL=true;
input double InpATRMultiplier=2.0;
input double InpGoldMinSL=10.0;
input double InpGoldMaxSL=18.0;
input int InpMaxSpread=32;
input double InpMaxSpreadToRisk=0.10;
input bool InpDrawZones=true;
input group "V15 - Exit experiment"
input double InpRiskReward=2.2;
input bool InpUsePartials=false;
input double InpPartialAtR=1.0;
input double InpPartialPercent=50.0; // Percentage of INITIAL volume; one partial stage.
input int InpBELockPoints=10;
input bool InpUseCandleTrailing=false;
input int InpCandleTrailAfterBars=4;
input int InpCandleTrailBars=2;
input bool InpRunner=false; // No initial TP; trail 1R behind price after 3R.
input group "V15 - Clock / news"
input int InpServerUTCOffsetMinutes=9999; // Mandatory; 9999 blocks entries, management continues.
input bool InpUseSessionFilter=true;
input bool InpUseNewsFilter=true;
input int InpNewsWindowMinutes=15;
input string InpNewsFile="aurum_news.csv"; // Server timestamps CSV: time,currency,importance.

CTrade trade;
int hMA=INVALID_HANDLE,hHTF=INVALID_HANDLE,hRSI=INVALID_HANDLE,hADX=INVALID_HANDLE,hATR=INVALID_HANDLE;
int owner_file=INVALID_HANDLE;
string prefix,status="Starting";
datetime last_bar=0;
MqlRates bars[];
double ema=0,htf=0,rsi=0,adx=0,atr=0,range_high=0,range_low=0;
bool ready=false,busy=false;
struct Zone { double top,bottom; datetime born; bool bull,breaker,fvg; };
Zone zones[];
double swing_high=0,swing_low=0;
bool high_broken=false,low_broken=false,sweep_buy=false,sweep_sell=false;
struct NewsItem { datetime time; string currency; };
NewsItem news[];
datetime news_from=0,news_to=0;

uint TextHash(string s) { uint h=2166136261; for(int i=0;i<StringLen(s);i++) h=(h^(uint)StringGetCharacter(s,i))*16777619; return h; }
string Key(string suffix) { return prefix+suffix; }
string PKey(ulong id,string field) { return Key("p"+(string)id+"."+field); }
double PV(ulong id,string field) { return GlobalVariableGet(PKey(id,field)); }
void Put(ulong id,string field,double v) { GlobalVariableSet(PKey(id,field),v); }
bool Owned(long magic) { return magic==InpMagicNumber || (InpManageManualTrades && magic==0) || (InpManageLegacyMagic && magic==777999); }
int AccountLock() { return FileOpen(Key("admission.lock"),FILE_BIN|FILE_READ|FILE_WRITE); }
bool SelectId(ulong id) {
   for(int i=PositionsTotal()-1;i>=0;i--) { ulong t=PositionGetTicket(i); if(t>0 && (ulong)PositionGetInteger(POSITION_IDENTIFIER)==id) return true; }
   return false;
}
void Audit(string action,ulong id,string detail) {
   PrintFormat("[AURUM15] %s position=%I64u %s",action,id,detail);
   int f=FileOpen(Key("events."+(string)TextHash(_Symbol)+".csv"),FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI,',',CP_UTF8);
   if(f==INVALID_HANDLE) { Print("Audit file write failed: ",GetLastError());return; }
   if(FileSize(f)==0) FileWrite(f,"server_time","account","symbol","magic","build","experiment","position_id","action","detail");
   FileSeek(f,0,SEEK_END);
   FileWrite(f,TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),(string)AccountInfoInteger(ACCOUNT_LOGIN),_Symbol,InpMagicNumber,"15.00",InpExperimentId,(string)id,action,detail);
   FileFlush(f); FileClose(f);
}
bool Accepted(bool call,string action,ulong id) {
   uint ret=trade.ResultRetcode();
   bool ok=call && (ret==TRADE_RETCODE_DONE || ret==TRADE_RETCODE_DONE_PARTIAL || ret==TRADE_RETCODE_NO_CHANGES);
   Audit(action,id,StringFormat("ret=%u order=%I64u deal=%I64u volume=%.8f price=%.8f %s",ret,trade.ResultOrder(),trade.ResultDeal(),trade.ResultVolume(),trade.ResultPrice(),trade.ResultRetcodeDescription()));
   return ok;
}
double TickRound(double value,bool up) {
   double tick=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE);
   if(tick<=0) return 0;
   return NormalizeDouble((up?MathCeil(value/tick-1e-9):MathFloor(value/tick+1e-9))*tick,_Digits);
}
bool Loss(string symbol,ENUM_ORDER_TYPE side,double volume,double entry,double sl,double &loss) {
   loss=0; double result=0;
   if(entry<=0 || sl<=0 || volume<=0 || !OrderCalcProfit(side,symbol,volume,entry,sl,result) || !MathIsValidNumber(result)) return false;
   loss=MathMax(0,-result); return true;
}

// Recover immutable entry data from original order/deals, never from the current ATR or moved SL.
bool EnsurePosition(ulong ticket) {
   if(!PositionSelectByTicket(ticket)) return false;
   ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(GlobalVariableCheck(PKey(id,"ready"))) return PV(id,"ready")==1;
   if(!HistorySelectByPosition(id)) return false;
   double volume=0,weighted=0,sl0=0; ulong order=0; bool exited=false;
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i); long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_IN && HistoryDealGetInteger(d,DEAL_TYPE)<=DEAL_TYPE_SELL) {
         ulong o=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
         if(order!=0 && order!=o) { Audit("UNTRACKED_ADDON",id,"Multiple entry orders; manual reconciliation required"); return false; }
         order=o; double v=HistoryDealGetDouble(d,DEAL_VOLUME);
         volume+=v; weighted+=v*HistoryDealGetDouble(d,DEAL_PRICE);
      } else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) exited=true;
   }
   if(order==0 || volume<=0 || !HistoryOrderGetDouble(order,ORDER_SL,sl0) || sl0<=0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   double en=weighted/volume;
   bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
   if((buy && sl0>=en) || (!buy && sl0<=en)) return false;
   double money=0;
   if(!Loss(_Symbol,buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,volume,en,sl0,money) || money<=0) return false;
   Put(id,"entry",en); Put(id,"sl0",sl0); Put(id,"r0",MathAbs(en-sl0)); Put(id,"v0",volume); Put(id,"risk0",money);
   // Existing exits have unknown origin: never blindly repeat an historical partial.
   Put(id,"partial",exited?2:0); Put(id,"partial_r",InpUsePartials?InpPartialAtR:0);
   Put(id,"pct",InpPartialPercent); Put(id,"runner",InpRunner?1:0);
   Put(id,"rr",InpRiskReward); Put(id,"lock",InpBELockPoints);
   Put(id,"candle",InpUseCandleTrailing?InpCandleTrailAfterBars:0); Put(id,"trailbars",InpCandleTrailBars);
   Put(id,"ready",1); GlobalVariablesFlush();
   Audit("R0_CAPTURED",id,StringFormat("entry=%.8f sl0=%.8f r0=%.8f volume=%.8f risk=%.8f",en,sl0,MathAbs(en-sl0),volume,money));
   return true;
}

// Account-wide history: count unique entry orders and only FULLY closed positions, including other EAs.
bool AccountStats(datetime day,int &entries,int &losses,double &flows) {
   entries=0; losses=0; flows=0;
   if(!HistorySelect(0,TimeCurrent())) return false;
   ulong orders[],ids[]; double net[],volumes[]; bool has_entry[]; long closed_at[];
   datetime origin=(datetime)GlobalVariableGet(Key("origin"));
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i); long type=HistoryDealGetInteger(d,DEAL_TYPE);
      datetime at=(datetime)HistoryDealGetInteger(d,DEAL_TIME);
      double pnl=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_COMMISSION)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_FEE);
      if(type==DEAL_TYPE_BALANCE || type==DEAL_TYPE_CREDIT || type==DEAL_TYPE_BONUS) { if(at>origin) flows+=pnl; continue; }
      if(type!=DEAL_TYPE_BUY && type!=DEAL_TYPE_SELL) continue;
      long entry=HistoryDealGetInteger(d,DEAL_ENTRY);
      if(entry==DEAL_ENTRY_INOUT) return false; // Hedge-only contract; don't guess reversals.
      ulong id=(ulong)HistoryDealGetInteger(d,DEAL_POSITION_ID);
      int k=-1; for(int j=0;j<ArraySize(ids);j++) if(ids[j]==id) { k=j; break; }
      if(k<0) { k=ArraySize(ids); ArrayResize(ids,k+1); ArrayResize(net,k+1); ArrayResize(closed_at,k+1); ArrayResize(volumes,k+1); ArrayResize(has_entry,k+1); ids[k]=id; net[k]=0; volumes[k]=0; has_entry[k]=false; closed_at[k]=0; }
      net[k]+=pnl;
      double dv=HistoryDealGetDouble(d,DEAL_VOLUME);
      if(entry==DEAL_ENTRY_IN) {has_entry[k]=true;volumes[k]+=dv;}
      else if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) volumes[k]-=dv;
      if(entry==DEAL_ENTRY_OUT || entry==DEAL_ENTRY_OUT_BY) closed_at[k]=HistoryDealGetInteger(d,DEAL_TIME_MSC);
      if(entry==DEAL_ENTRY_IN && at>=day) {
         ulong order=(ulong)HistoryDealGetInteger(d,DEAL_ORDER); bool seen=false;
         for(int j=0;j<ArraySize(orders);j++) if(orders[j]==order) seen=true;
         if(!seen) { int n=ArraySize(orders); ArrayResize(orders,n+1); orders[n]=order; entries++; }
      }
   }
   // Select latest completed positions first. Ties are deterministic by position id.
   for(int i=0;i<ArraySize(ids);i++) {
      int best=-1;
      for(int j=0;j<ArraySize(ids);j++) if(closed_at[j]>0 && (best<0 || closed_at[j]>closed_at[best] || (closed_at[j]==closed_at[best] && ids[j]>ids[best]))) best=j;
      if(best<0) break;
      long at=closed_at[best]; closed_at[best]=0;
      if(at<(long)day*1000) break;
      if(SelectId(ids[best])) continue;
      if(!has_entry[best] || MathAbs(volumes[best])>1e-7) return false;
      if(net[best]<-0.005) losses++;
      else if(net[best]>0.005) break; // Genuine BE does not reset a loss streak.
   }
   return true;
}
bool Guard() {
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity<=0) { status="Invalid equity"; return false; }
   MqlDateTime dt; TimeToStruct(TimeCurrent(),dt); dt.hour=0;dt.min=0;dt.sec=0; datetime day=StructToTime(dt);
   if(!GlobalVariableCheck(Key("origin"))) {
      bool real=AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL && !MQLInfoInteger(MQL_TESTER);
      if(real && (InpInitialDayEquity<=0 || InpInitialPeakEquity<=0)) {status="Verified initial day/peak equity required for real account";return false;}
      GlobalVariableSet(Key("origin"),(double)TimeCurrent()); GlobalVariableSet(Key("peak"),InpInitialPeakEquity>0?InpInitialPeakEquity:equity);
      GlobalVariableSet(Key("day"),(double)day);GlobalVariableSet(Key("base"),InpInitialDayEquity>0?InpInitialDayEquity:equity);
      Audit("ACCOUNT_BASELINE",0,"First observed equity; no retrospective midnight equity assumed");
   }
   int entries=0,losses=0; double flows=0;
   if(!AccountStats(day,entries,losses,flows)) { status="History unavailable / unsupported reversal";return false; }
   double adjusted=equity-flows;
   if((datetime)GlobalVariableGet(Key("day"))!=day) {
      GlobalVariableSet(Key("day"),(double)day);GlobalVariableSet(Key("base"),adjusted);GlobalVariableSet(Key("daily_lock"),0);
   }
   double peak=MathMax(adjusted,GlobalVariableGet(Key("peak")));GlobalVariableSet(Key("peak"),peak);
   double base=GlobalVariableGet(Key("base"));
   if(adjusted<=base-MathAbs(base)*InpMaxDailyLoss/100) GlobalVariableSet(Key("daily_lock"),1);
   if(adjusted<=peak-MathAbs(peak)*InpMaxTotalDrawdown/100) GlobalVariableSet(Key("total_lock"),1);
   if(losses>=InpMaxConsecutiveLosses) GlobalVariableSet(Key("daily_lock"),1);
   GlobalVariablesFlush();
   if(GlobalVariableGet(Key("total_lock"))>0 || GlobalVariableGet(Key("daily_lock"))>0) { status="Account risk/streak lock";return false; }
   if(GlobalVariableGet(Key("execution_lock"))>0) {status="Uncertain execution: reconcile account before unlocking";return false;}
   if(entries>=InpMaxDailyTrades) { status="Daily entry limit";return false; }
   status="Risk checks OK"; return true;
}
bool PortfolioRisk(double &risk) {
   risk=0;
   if(OrdersTotal()>0) { status="Pending orders: reserve unknown";return false; }
   for(int i=0;i<PositionsTotal();i++) {
      ulong t=PositionGetTicket(i); if(t==0) return false;
      string sym=PositionGetString(POSITION_SYMBOL);
      double sl=PositionGetDouble(POSITION_SL),v=PositionGetDouble(POSITION_VOLUME),en=PositionGetDouble(POSITION_PRICE_OPEN),loss=0;
      if(!Loss(sym,PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY?ORDER_TYPE_BUY:ORDER_TYPE_SELL,v,en,sl,loss)) return false;
      risk+=loss+InpCostReservePerLot*v;
      if(sym==_Symbol) { status="Position already open on symbol";return false; }
   }
   return true;
}

bool Buffer(int h,int start,int count,double &values[]) { ArraySetAsSeries(values,true); return CopyBuffer(h,0,start,count,values)==count; }
bool Refresh() {
   double b[]; ready=false;
   if(BarsCalculated(hMA)<InpEMAPeriod+3 || BarsCalculated(hHTF)<InpEMAPeriod+3) return false;
   if(!Buffer(hMA,1,1,b)) return false; ema=b[0];
   if(!Buffer(hHTF,1,1,b)) return false; htf=b[0];
   if(!Buffer(hRSI,1,1,b)) return false; rsi=b[0];
   if(!Buffer(hADX,1,1,b)) return false; adx=b[0];
   if(!Buffer(hATR,1,1,b)) return false; atr=b[0];
   ArraySetAsSeries(bars,true);
   if(CopyRates(_Symbol,_Period,0,InpZoneMaxAgeBars+2*InpSwingLength+5,bars)<InpZoneMaxAgeBars+2*InpSwingLength+5) return false;
   MqlRates h1[]; if(CopyRates(_Symbol,PERIOD_H1,1,20,h1)!=20) return false;
   range_high=h1[0].high;range_low=h1[0].low;
   for(int i=1;i<20;i++) { range_high=MathMax(range_high,h1[i].high);range_low=MathMin(range_low,h1[i].low); }
   ready=ema>0 && htf>0 && atr>0 && range_high>range_low;
   return ready;
}
void AddZone(double top,double bottom,datetime born,bool bull,bool fvg) {
   for(int i=0;i<ArraySize(zones);i++) if(zones[i].born==born && zones[i].fvg==fvg && zones[i].bull==bull) return;
   int n=ArraySize(zones);
   if(n>=40) { for(int i=1;i<n;i++) zones[i-1]=zones[i]; n--; ArrayResize(zones,n); }
   ArrayResize(zones,n+1); zones[n].top=top;zones[n].bottom=bottom;zones[n].born=born;zones[n].bull=bull;zones[n].breaker=false;zones[n].fvg=fvg;
}
void RemoveZone(int i) { int n=ArraySize(zones);for(int j=i+1;j<n;j++) zones[j-1]=zones[j];ArrayResize(zones,n-1); }
void StructureAt(int s) {
   int pivot=s+InpSwingLength;
   if(pivot+InpSwingLength>=ArraySize(bars)) return;
   bool sh=true,sl=true;
   for(int j=1;j<=InpSwingLength;j++) {
      if(bars[pivot-j].high>=bars[pivot].high || bars[pivot+j].high>=bars[pivot].high) sh=false;
      if(bars[pivot-j].low<=bars[pivot].low || bars[pivot+j].low<=bars[pivot].low) sl=false;
   }
   if(sh) { swing_high=bars[pivot].high;high_broken=false; }
   if(sl) { swing_low=bars[pivot].low;low_broken=false; }
   sweep_buy=swing_low>0 && bars[s].low<swing_low && bars[s].close>=swing_low;
   sweep_sell=swing_high>0 && bars[s].high>swing_high && bars[s].close<=swing_high;
   for(int i=ArraySize(zones)-1;i>=0;i--) {
      int age=iBarShift(_Symbol,_Period,zones[i].born)-s;
      bool crossed=zones[i].bull?bars[s].close<zones[i].bottom:bars[s].close>zones[i].top;
      bool filled=zones[i].fvg && (zones[i].bull?bars[s].low<=zones[i].bottom:bars[s].high>=zones[i].top);
      if(age>InpZoneMaxAgeBars || filled || (crossed && zones[i].breaker)) { RemoveZone(i);continue; }
      if(crossed && !zones[i].fvg) { zones[i].breaker=true; zones[i].bull=!zones[i].bull; }
   }
   if(swing_high>0 && !high_broken && bars[s].close>swing_high) {
      high_broken=true;
      for(int k=s+1;k<=s+30 && k<ArraySize(bars);k++) if(bars[k].close<bars[k].open) { AddZone(bars[k].high,bars[k].low,bars[k].time,true,false);break; }
   }
   if(swing_low>0 && !low_broken && bars[s].close<swing_low) {
      low_broken=true;
      for(int k=s+1;k<=s+30 && k<ArraySize(bars);k++) if(bars[k].close>bars[k].open) { AddZone(bars[k].high,bars[k].low,bars[k].time,false,false);break; }
   }
   if(bars[s].low>bars[s+2].high) AddZone(bars[s].low,bars[s+2].high,bars[s+1].time,true,true);
   if(bars[s].high<bars[s+2].low) AddZone(bars[s+2].low,bars[s].high,bars[s+1].time,false,true);
}
void RebuildStructure() {
   ArrayResize(zones,0);swing_high=0;swing_low=0;high_broken=false;low_broken=false;
   // Bounded causal replay on EVERY signal bar: identical state after restart.
   for(int i=InpZoneMaxAgeBars;i>=1;i--) StructureAt(i);
}
bool ZoneSignal(bool buy,double &edge) {
   bool ob=false,fvg=false; edge=0;
   for(int i=ArraySize(zones)-1;i>=0;i--) {
      if(zones[i].bull!=buy || bars[1].low>zones[i].top || bars[1].high<zones[i].bottom) continue;
      if(zones[i].fvg) { fvg=true;continue; }
      if((zones[i].breaker && !InpUseBreakerBlocks) || (!zones[i].breaker && !InpUseOrderBlocks)) continue;
      if(!ob) edge=buy?zones[i].bottom:zones[i].top;
      ob=true;
   }
   return ob && (!InpRequireFVG || fvg) && (!InpRequireSweep || (buy?sweep_buy:sweep_sell));
}
bool Signal(bool buy,double &edge) {
   double c=bars[1].close,eq=(range_high+range_low)/2,span=bars[1].high-bars[1].low;
   if(span<=0 || adx<InpADXThreshold || span>atr*2.8) return false;
   bool trend=buy?c>ema:c<ema;
   if(InpUseMTFFilter) trend=trend && (buy?c>htf:c<htf);
   double wick=buy?MathMin(bars[1].open,c)-bars[1].low:bars[1].high-MathMax(bars[1].open,c);
   bool pa=(buy?c>bars[1].open:c<bars[1].open) || wick/span>=0.30;
   return trend && pa && (buy?c<eq:c>eq) && (buy?rsi<InpRSIOversold:rsi>InpRSIOverbought) && ZoneSignal(buy,edge);
}

bool LoadNews() {
   ArrayResize(news,0);news_from=0;news_to=0;
   int f=FileOpen(InpNewsFile,FILE_CSV|FILE_READ|FILE_ANSI,',',CP_UTF8);
   if(f==INVALID_HANDLE) return false;
   // First row declares coverage: coverage,server_from,server_to.
   string tag=FileReadString(f); news_from=StringToTime(FileReadString(f));news_to=StringToTime(FileReadString(f));
   if(tag!="coverage" || news_from<=0 || news_to<=news_from) { FileClose(f);return false; }
   while(!FileIsEnding(f)) {
      string raw=FileReadString(f);if(raw=="") break;
      datetime t=StringToTime(raw); string currency=FileReadString(f);int importance=(int)StringToInteger(FileReadString(f));
      if(t<=0 || StringLen(currency)!=3) { FileClose(f);news_to=0;return false; }
      if(importance>=3) { int n=ArraySize(news);ArrayResize(news,n+1);news[n].time=t;news[n].currency=currency; }
   }
   FileClose(f);return true;
}
bool Session() {
   if(InpServerUTCOffsetMinutes==9999) { status="Set verified server UTC offset";return false; }
   datetime cdmx=TimeCurrent()-InpServerUTCOffsetMinutes*60-6*3600;MqlDateTime t;TimeToStruct(cdmx,t);
   if(t.day_of_week==0 || t.day_of_week==6) {status="Weekend";return false;}
   MqlDateTime srv;TimeToStruct(TimeCurrent(),srv);
   if(srv.hour*60+srv.min>=1435 || srv.hour*60+srv.min<=15) {status="Broker rollover";return false;}
   if(InpUseSessionFilter && !AurumSessionMinute(t.hour*60+t.min)) {status="Outside configured CDMX windows";return false;}
   if(InpUseNewsFilter) {
      if(TimeCurrent()-InpNewsWindowMinutes*60<news_from || TimeCurrent()+InpNewsWindowMinutes*60>news_to) {status="News coverage missing/expired";return false;}
      string base=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_BASE),quote=SymbolInfoString(_Symbol,SYMBOL_CURRENCY_PROFIT);
      for(int i=0;i<ArraySize(news);i++) if((news[i].currency==base || news[i].currency==quote) && MathAbs((double)(TimeCurrent()-news[i].time))<=InpNewsWindowMinutes*60) {status="High impact news window";return false;}
   }
   return true;
}

void Enter(bool buy,double edge) {
   double portfolio=0;
   if(!Guard() || !PortfolioRisk(portfolio) || !Session()) return;
   if(!MQLInfoInteger(MQL_TESTER) && AccountInfoInteger(ACCOUNT_TRADE_MODE)==ACCOUNT_TRADE_MODE_REAL && !InpAllowLiveTrading) {status="Demo validation build: live entries disabled";return;}
   MqlTick tick;if(!SymbolInfoTick(_Symbol,tick) || tick.ask<=tick.bid || tick.bid<=0) return;
   if((tick.ask-tick.bid)/_Point>InpMaxSpread) {status="Spread limit";return;}
   double en=buy?tick.ask:tick.bid;
   double distance=atr*InpATRMultiplier;
   string upper=_Symbol;StringToUpper(upper);bool gold=StringFind(upper,"GOLD")>=0 || StringFind(upper,"XAU")>=0;
   if(gold) distance=MathMax(distance,InpGoldMinSL);
   double sl=InpUseStructuralSL?(buy?edge-(tick.ask-tick.bid)-2*_Point:edge+(tick.ask-tick.bid)+2*_Point):(buy?en-distance:en+distance);
   double min_dist=(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL)+1)*_Point;
   sl=TickRound(buy?MathMin(sl,tick.bid-min_dist):MathMax(sl,tick.ask+min_dist),!buy);
   distance=buy?en-sl:sl-en;
   if(sl<=0 || distance<=0 || (gold && distance>InpGoldMaxSL) || (tick.ask-tick.bid)/distance>InpMaxSpreadToRisk) {status="SL/cost invalid; setup skipped";return;}
   double tp=InpRunner?0:TickRound(buy?en+distance*InpRiskReward:en-distance*InpRiskReward,buy);
   if(tp>0 && (buy?tp-tick.bid:tick.ask-tp)<min_dist) return;
   double loss=0;
   // Reserve permitted adverse fill displacement plus explicit per-lot costs.
   double worst_en=buy?en+InpDeviationPoints*_Point:en-InpDeviationPoints*_Point;
   if(!Loss(_Symbol,buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,1,worst_en,sl,loss)) return;
   loss+=InpCostReservePerLot;
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double budget=MathMin(equity*InpRiskPercent/100,equity*InpMaxPortfolioRiskPercent/100-portfolio);
   double v=AurumRiskVolume(budget,loss,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
   double margin=0;
   if(v<=0 || !OrderCalcMargin(buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,_Symbol,v,en,margin) || margin>AccountInfoDouble(ACCOUNT_MARGIN_FREE)) {status="Lot minimum / risk / margin: entry skipped";return;}
   trade.SetTypeFillingBySymbol(_Symbol);
   // Persist one intent per symbol/bar. No automatic resend after timeout/uncertain outcome.
   string intent=Key("intent."+(string)TextHash(_Symbol));
   if(GlobalVariableGet(intent)==(double)last_bar) return;
   GlobalVariableSet(intent,(double)last_bar); GlobalVariablesFlush();
   bool ok=buy?trade.Buy(v,_Symbol,en,sl,tp,"Aurum15"):trade.Sell(v,_Symbol,en,sl,tp,"Aurum15");
   Accepted(ok,"ENTRY",0);
   // An uncertain request locks further account entries pending reconciliation.
   if(trade.ResultRetcode()==TRADE_RETCODE_TIMEOUT || trade.ResultRetcode()==TRADE_RETCODE_CONNECTION || trade.ResultRetcode()==TRADE_RETCODE_PLACED) GlobalVariableSet(Key("execution_lock"),1);
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL)!=_Symbol || PositionGetInteger(POSITION_MAGIC)!=InpMagicNumber) continue;
      double actual=0;
      if(PositionGetDouble(POSITION_SL)<=0 || !Loss(_Symbol,buy?ORDER_TYPE_BUY:ORDER_TYPE_SELL,PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL),actual) || actual+InpCostReservePerLot*PositionGetDouble(POSITION_VOLUME)>budget+0.01) {
         ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER); Put(id,"emergency",1);GlobalVariableSet(Key("execution_lock"),1);GlobalVariablesFlush();Accepted(trade.PositionClose(ticket),"RISK_BREACH_CLOSE",id);
      } else EnsurePosition(ticket);
   }
}

void Manage() {
   for(int i=PositionsTotal()-1;i>=0;i--) {
      ulong ticket=PositionGetTicket(i);
      if(ticket==0 || PositionGetString(POSITION_SYMBOL)!=_Symbol || !Owned(PositionGetInteger(POSITION_MAGIC))) continue;
      ulong id=(ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(PV(id,"emergency")>0 || (InpCloseManagedOnDrawdown && (GlobalVariableGet(Key("daily_lock"))>0 || GlobalVariableGet(Key("total_lock"))>0))) {
         if(TimeCurrent()-(datetime)PV(id,"close_attempt")>=5) {Put(id,"close_attempt",(double)TimeCurrent());Accepted(trade.PositionClose(ticket),"GUARD_CLOSE",id);}
         continue;
      }
      if(!EnsurePosition(ticket) || !PositionSelectByTicket(ticket)) {status="Untracked position: retain broker SL, reconcile history";continue;}
      double en=PV(id,"entry"),r0=PV(id,"r0"),sl=PositionGetDouble(POSITION_SL),tp=PositionGetDouble(POSITION_TP),v=PositionGetDouble(POSITION_VOLUME);
      bool buy=PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY;
      MqlTick q;if(!SymbolInfoTick(_Symbol,q) || r0<=0) continue;
      double px=buy?q.bid:q.ask;double rr=(buy?px-en:en-px)/r0;
      double trigger=PV(id,"partial_r"),target=sl;
      if(trigger>0 && rr>=trigger) {
         double be=buy?en+PV(id,"lock")*_Point:en-PV(id,"lock")*_Point;
         target=buy?MathMax(target,be):(target==0?be:MathMin(target,be));
         if(PV(id,"partial")==1 && PV(id,"v0")-v>=PV(id,"v0")*PV(id,"pct")/100-1e-8) Put(id,"partial",2);
         if(PV(id,"partial")==0) {
            double part=AurumPartialVolume(PV(id,"v0"),v,PV(id,"pct")/100,SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MIN),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_MAX),SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP));
            if(part<=0) {Put(id,"partial",3);GlobalVariablesFlush();Audit("PARTIAL_NOT_APPLICABLE",id,"Volume step/minimum or prior reduction");}
            else {
               Put(id,"partial",1); GlobalVariablesFlush(); // Durable intent BEFORE request; never double-close on restart.
               bool ok=Accepted(trade.PositionClosePartial(ticket,part),"PARTIAL",id);
               if(!PositionSelectByTicket(ticket)) continue;
               double after=PositionGetDouble(POSITION_VOLUME);
               if(ok && after<v-1e-9) {Put(id,"partial",2);GlobalVariablesFlush();}
               else {status="Partial uncertain/rejected; inspect events before retry";Audit("PARTIAL_RECONCILE",id,"Intent retained; no blind retry");}
            }
         }
      }
      if(PV(id,"runner")>0 && rr>=3) {
         double run=buy?px-r0:px+r0;target=buy?MathMax(target,run):(target==0?run:MathMin(target,run));
      }
      if(PV(id,"candle")>0 && rr>=1 && iBarShift(_Symbol,_Period,(datetime)PositionGetInteger(POSITION_TIME))>=(int)PV(id,"candle")) {
         int n=(int)PV(id,"trailbars");double low[],high[];
         if(CopyLow(_Symbol,_Period,1,n,low)==n && CopyHigh(_Symbol,_Period,1,n,high)==n) {
            double trail=buy?low[ArrayMinimum(low)]-2*_Point:high[ArrayMaximum(high)]+2*_Point;
            if((buy && trail>en) || (!buy && trail<en)) target=buy?MathMax(target,trail):(target==0?trail:MathMin(target,trail));
         }
      }
      target=TickRound(target,!buy);
      double min_dist=(MathMax(SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(_Symbol,SYMBOL_TRADE_FREEZE_LEVEL))+1)*_Point;
      bool improves=target>0 && (buy?target>sl+_Point:(sl==0 || target<sl-_Point));
      if(improves && (buy?q.bid-target:target-q.ask)>=min_dist) Accepted(trade.PositionModify(ticket,target,tp),"SL_MOVE",id);
      // TP=0 remains zero for a runner; no generic auto-TP replacement.
   }
}
void Draw() {
   Comment("Aurum V15 | ",InpExperimentId,"\n",status,"\nClosed H1 EMA: ",DoubleToString(ema,_Digits)," | RSI: ",DoubleToString(rsi,1)," | ADX: ",DoubleToString(adx,1),"\nAccount risk ",InpRiskPercent,"% / open ",InpMaxPortfolioRiskPercent,"% | Research build");
   if(!InpDrawZones) return;
   ObjectsDeleteAll(0,"aurum15_zone_");
   for(int i=0;i<ArraySize(zones);i++) {
      string name="aurum15_zone_"+(string)i;
      if(ObjectCreate(0,name,OBJ_RECTANGLE,0,zones[i].born,zones[i].top,TimeCurrent()+PeriodSeconds(_Period)*5,zones[i].bottom)) {
         ObjectSetInteger(0,name,OBJPROP_COLOR,zones[i].breaker?clrBlue:(zones[i].bull?clrSeaGreen:clrIndianRed));
         ObjectSetInteger(0,name,OBJPROP_FILL,true);ObjectSetInteger(0,name,OBJPROP_BACK,true);
      }
   }
}
int OnInit() {
   if(_Period!=PERIOD_M15) {Print("V15 validation profile requires M15");return INIT_PARAMETERS_INCORRECT;}
   if(InpEMAPeriod<2 || InpMaxSpread<1 || InpBELockPoints<0 || InpGoldMinSL<0 || InpInitialDayEquity<0 || InpInitialPeakEquity<0 || InpRSIOversold<=0 || InpRSIOversold>=50 || InpRSIOverbought<=50 || InpRSIOverbought>=100 || InpADXThreshold<0 || InpADXThreshold>100 || (!InpUseOrderBlocks && !InpUseBreakerBlocks)) return INIT_PARAMETERS_INCORRECT;
   if(InpMagicNumber<=0 || InpRiskPercent<=0 || InpMaxPortfolioRiskPercent<InpRiskPercent || InpMaxDailyLoss<=0 || InpMaxTotalDrawdown<=0 || InpMaxDailyTrades<1 || InpMaxConsecutiveLosses<1 || InpSwingLength<2 || InpSwingLength>20 || InpZoneMaxAgeBars<40 || InpZoneMaxAgeBars>1000 || InpRiskReward<=0 || InpPartialAtR<=0 || InpPartialPercent<=0 || InpPartialPercent>=100 || InpDeviationPoints<0 || InpCostReservePerLot<0 || InpCandleTrailBars<1 || InpCandleTrailAfterBars<1 || InpMaxSpreadToRisk<=0 || InpATRMultiplier<=0 || InpGoldMaxSL<InpGoldMinSL || InpNewsWindowMinutes<0 || (InpServerUTCOffsetMinutes!=9999 && MathAbs(InpServerUTCOffsetMinutes)>840)) return INIT_PARAMETERS_INCORRECT;
   if(AccountInfoInteger(ACCOUNT_MARGIN_MODE)!=ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {Print("Aurum15 requires hedging; netting unsupported and blocked");return INIT_FAILED;}
   prefix="A15."+(string)TextHash(AccountInfoString(ACCOUNT_SERVER))+"."+(string)AccountInfoInteger(ACCOUNT_LOGIN)+".";
   owner_file=FileOpen(Key("owner."+(string)TextHash(_Symbol)),FILE_READ|FILE_WRITE|FILE_BIN);
   if(owner_file==INVALID_HANDLE) {Print("Another Aurum15 owns this account/symbol");return INIT_FAILED;}
   string policy=StringFormat("%.8f/%.8f/%.8f/%d/%d",InpMaxPortfolioRiskPercent,InpMaxDailyLoss,InpMaxTotalDrawdown,InpMaxDailyTrades,InpMaxConsecutiveLosses);
   int lock=AccountLock();if(lock==INVALID_HANDLE) return INIT_FAILED;
   uint policy_hash=TextHash(policy);
   if(GlobalVariableCheck(Key("policy")) && GlobalVariableGet(Key("policy"))!=(double)policy_hash) {FileClose(lock);Print("Account risk policy mismatch; reconcile before resetting persistent policy");return INIT_FAILED;}
   GlobalVariableSet(Key("policy"),(double)policy_hash);GlobalVariablesFlush();FileClose(lock);
   trade.SetExpertMagicNumber(InpMagicNumber);trade.SetDeviationInPoints(InpDeviationPoints);trade.SetAsyncMode(false);
   hMA=iMA(_Symbol,PERIOD_H1,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);hHTF=iMA(_Symbol,PERIOD_H4,InpEMAPeriod,0,MODE_EMA,PRICE_CLOSE);
   hRSI=iRSI(_Symbol,_Period,14,PRICE_CLOSE);hADX=iADX(_Symbol,_Period,14);hATR=iATR(_Symbol,_Period,14);
   if(hMA==INVALID_HANDLE || hHTF==INVALID_HANDLE || hRSI==INVALID_HANDLE || hADX==INVALID_HANDLE || hATR==INVALID_HANDLE) return INIT_FAILED;
   LoadNews();last_bar=iTime(_Symbol,_Period,0);EventSetTimer(1);
   Audit("INIT",0,StringFormat("offset=%d risk=%.3f totalrisk=%.3f partial=%s trigger=%.2f runner=%s",InpServerUTCOffsetMinutes,InpRiskPercent,InpMaxPortfolioRiskPercent,InpUsePartials?"true":"false",InpPartialAtR,InpRunner?"true":"false"));
   return INIT_SUCCEEDED;
}
void OnDeinit(const int reason) {
   EventKillTimer();if(owner_file!=INVALID_HANDLE) FileClose(owner_file);
   IndicatorRelease(hMA);IndicatorRelease(hHTF);IndicatorRelease(hRSI);IndicatorRelease(hADX);IndicatorRelease(hATR);
   ObjectsDeleteAll(0,"aurum15_zone_");Comment("");GlobalVariablesFlush();
}
void OnTick() {
   if(busy) return;busy=true;
   int lock=AccountLock();
   if(lock!=INVALID_HANDLE) {
      bool allowed=Guard();Manage();
      datetime bar=iTime(_Symbol,_Period,0);
      if(bar>0 && bar!=last_bar) {
         last_bar=bar;
         if(Refresh()) {
            RebuildStructure();double edge=0;
            if(allowed && GlobalVariableGet(Key("execution_lock"))==0) {
               if(Signal(true,edge)) Enter(true,edge);
               else if(Signal(false,edge)) Enter(false,edge);
            }
            Draw();
         } else status="Waiting for complete synchronized history";
      }
      FileClose(lock);
   }
   busy=false;
}
void OnTimer() {
   if(busy) return;busy=true;int lock=AccountLock();
   if(lock!=INVALID_HANDLE) {Guard();Manage();FileClose(lock);}
   static datetime last_news=0;if(TimeCurrent()-last_news>=60) {LoadNews();last_news=TimeCurrent();}
   busy=false;
}
void OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result) {
   // No recursive trade requests from this callback. Management is serialized by account lock.
   if(trans.type==TRADE_TRANSACTION_DEAL_ADD && trans.symbol==_Symbol && HistoryDealSelect(trans.deal)) Audit("DEAL_EVENT",(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID),StringFormat("deal=%I64u order=%I64u",trans.deal,trans.order));
}
#endif
