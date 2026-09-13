#property script_show_inputs
#property strict
input datetime InpFrom=D'2020.01.01';
input datetime InpTo=D'2030.01.01';
input string InpOutput="aurum_deals.csv";
void OnStart() {
   if(InpTo<InpFrom || !HistorySelect(InpFrom,InpTo)) { Print("History unavailable");return; }
   int f=FileOpen(InpOutput,FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(f==INVALID_HANDLE) {Print("Cannot write export: ",GetLastError());return;}
   FileWrite(f,"server","account","currency","deal_id","order_id","position_id","time_msc","type","entry","symbol","magic","volume","price","profit","commission","swap","fee","reason","initial_sl");
   for(int i=0;i<HistoryDealsTotal();i++) {
      ulong d=HistoryDealGetTicket(i),o=(ulong)HistoryDealGetInteger(d,DEAL_ORDER);
      double sl=0;if(o>0) HistoryOrderGetDouble(o,ORDER_SL,sl);
      FileWrite(f,AccountInfoString(ACCOUNT_SERVER),(string)AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_CURRENCY),(string)d,(string)o,(string)HistoryDealGetInteger(d,DEAL_POSITION_ID),(string)HistoryDealGetInteger(d,DEAL_TIME_MSC),HistoryDealGetInteger(d,DEAL_TYPE),HistoryDealGetInteger(d,DEAL_ENTRY),HistoryDealGetString(d,DEAL_SYMBOL),HistoryDealGetInteger(d,DEAL_MAGIC),DoubleToString(HistoryDealGetDouble(d,DEAL_VOLUME),8),DoubleToString(HistoryDealGetDouble(d,DEAL_PRICE),8),DoubleToString(HistoryDealGetDouble(d,DEAL_PROFIT),8),DoubleToString(HistoryDealGetDouble(d,DEAL_COMMISSION),8),DoubleToString(HistoryDealGetDouble(d,DEAL_SWAP),8),DoubleToString(HistoryDealGetDouble(d,DEAL_FEE),8),HistoryDealGetInteger(d,DEAL_REASON),DoubleToString(sl,8));
   }
   FileFlush(f);FileClose(f);
   f=FileOpen(InpOutput+".account.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(f!=INVALID_HANDLE) {
      FileWrite(f,"server","account","currency","margin_mode","server_time","balance","credit","equity","floating","export_from","export_to");
      FileWrite(f,AccountInfoString(ACCOUNT_SERVER),(string)AccountInfoInteger(ACCOUNT_LOGIN),AccountInfoString(ACCOUNT_CURRENCY),AccountInfoInteger(ACCOUNT_MARGIN_MODE),TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),AccountInfoDouble(ACCOUNT_BALANCE),AccountInfoDouble(ACCOUNT_CREDIT),AccountInfoDouble(ACCOUNT_EQUITY),AccountInfoDouble(ACCOUNT_PROFIT),TimeToString(InpFrom),TimeToString(InpTo));FileClose(f);
   }
   f=FileOpen(InpOutput+".open.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(f!=INVALID_HANDLE) {
      FileWrite(f,"position_id","ticket","symbol","type","volume","entry","sl","tp");
      for(int i=0;i<PositionsTotal();i++) {ulong t=PositionGetTicket(i);FileWrite(f,(string)PositionGetInteger(POSITION_IDENTIFIER),(string)t,PositionGetString(POSITION_SYMBOL),PositionGetInteger(POSITION_TYPE),PositionGetDouble(POSITION_VOLUME),PositionGetDouble(POSITION_PRICE_OPEN),PositionGetDouble(POSITION_SL),PositionGetDouble(POSITION_TP));} FileClose(f);
   }
   f=FileOpen(InpOutput+".symbols.csv",FILE_WRITE|FILE_CSV|FILE_ANSI,',',CP_UTF8);
   if(f!=INVALID_HANDLE) {
      FileWrite(f,"symbol","contract","tick_size","tick_value","volume_min","volume_step","volume_max","stops","freeze","calc_mode","base","profit_currency");
      for(int i=0;i<SymbolsTotal(true);i++) {string s=SymbolName(i,true);FileWrite(f,s,SymbolInfoDouble(s,SYMBOL_TRADE_CONTRACT_SIZE),SymbolInfoDouble(s,SYMBOL_TRADE_TICK_SIZE),SymbolInfoDouble(s,SYMBOL_TRADE_TICK_VALUE),SymbolInfoDouble(s,SYMBOL_VOLUME_MIN),SymbolInfoDouble(s,SYMBOL_VOLUME_STEP),SymbolInfoDouble(s,SYMBOL_VOLUME_MAX),SymbolInfoInteger(s,SYMBOL_TRADE_STOPS_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_FREEZE_LEVEL),SymbolInfoInteger(s,SYMBOL_TRADE_CALC_MODE),SymbolInfoString(s,SYMBOL_CURRENCY_BASE),SymbolInfoString(s,SYMBOL_CURRENCY_PROFIT));} FileClose(f);
   }
   Print("Export finished in MQL5/Files: ",InpOutput,". Snapshot is CURRENT, not the historical opening balance.");
}
