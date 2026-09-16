import os

def apply_v15_20(filepath):
    print(f"Applying V15.20 upgrades to {filepath}...")
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    content = content.replace("\r\n", "\n")

    # 1. Update Version in property
    content = content.replace(
        '#property version   "15.10"',
        '#property version   "15.20"'
    )

    # 2. Add Changelog comment
    changelog_v15_20 = """// CHANGELOG V15.20:
//  [V15.20] KILLZONE FOREX OBLIGATORIA, MUTEX USD ANTI-RACE CONDITION & PISO SL REALISTA:
//          - InpUseHighLiquiditySession = true: Forex opera estrictamente en Londres y NY (01:15 a 12:00 CDMX). Erradica pérdidas nocturnas en Asia.
//          - Mutex Inter-Chart ("AURUM_USD_DISPATCH_TIME"): Evita que EURUSD y GBPUSD disparen órdenes en el mismo milisegundo.
//          - Piso Mínimo de SL en Forex adaptado a M15: EURUSD (14 pips), GBPUSD (16 pips), USDJPY (15 pips) evitando barridos por ruido nocturno de 7 pips.
"""
    if "CHANGELOG V15.20:" not in content:
        content = content.replace("// CHANGELOG V15.10:", changelog_v15_20 + "// CHANGELOG V15.10:")

    # 3. Enable High Liquidity Session by default
    old_session_input = "input bool     InpUseHighLiquiditySession  = false;// [V14.2] Operar solo en Sesiones de Alta Liquidez (false = 24h continuas salvo rollover)"
    new_session_input = "input bool     InpUseHighLiquiditySession  = true; // [V15.20] Operar solo en Sesiones de Alta Liquidez (true = Londres y NY 01:15 a 12:00 CDMX)"
    assert old_session_input in content, f"old_session_input not found in {filepath}"
    content = content.replace(old_session_input, new_session_input)

    # 4. Update Forex Minimum SL floors for M15 & M5
    old_forex_block = """      if(StringFind(symbol,"EURUSD") >= 0) {
         g_distancia_puntos = 250; g_rsi_oversold = 44; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 150; g_atr_multiplier = 2.5;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = 70 * _Point; // Minimo 7.0 pips de SL (evita salidas prematuras por mechas en M5)
         Print("AURUM FOREX V12.97 EURUSD (Spread max: ", g_max_spread, ", SL min: 7.0 pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      } else if(StringFind(symbol,"USDJPY") >= 0) {
         g_distancia_puntos = 550; g_rsi_oversold = 46; g_rsi_overbought = 56;
         g_adx_threshold = 15; g_be_trigger = 250; g_atr_multiplier = 2.0;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 80 * _Point; // Minimo 8.0 pips de SL
         Print("AURUM FOREX V12.97 USDJPY (Spread max: ", g_max_spread, ", SL min: 8.0 pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      } else if(StringFind(symbol,"GBPUSD") >= 0) {
         g_distancia_puntos = 350; g_rsi_oversold = 45; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 300; g_atr_multiplier = 2.0;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = 80 * _Point; // Minimo 8.0 pips de SL
         Print("AURUM FOREX V12.97 GBPUSD (Spread max: ", g_max_spread, ", SL min: 8.0 pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      }"""

    new_forex_block = """      if(StringFind(symbol,"EURUSD") >= 0) {
         g_distancia_puntos = 250; g_rsi_oversold = 44; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 150; g_atr_multiplier = 2.5;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = (_Period >= PERIOD_M15 ? 140 : 90) * _Point; // [V15.20] Min 14.0 pips en M15 (9.0 en M5)
         Print("AURUM FOREX V15.20 EURUSD (Spread max: ", g_max_spread, ", SL min: ", DoubleToString(g_min_sl_price/_Point/10.0,1), " pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      } else if(StringFind(symbol,"USDJPY") >= 0) {
         g_distancia_puntos = 550; g_rsi_oversold = 46; g_rsi_overbought = 56;
         g_adx_threshold = 15; g_be_trigger = 250; g_atr_multiplier = 2.0;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = (_Period >= PERIOD_M15 ? 150 : 100) * _Point; // [V15.20] Min 15.0 pips en M15 (10.0 en M5)
         Print("AURUM FOREX V15.20 USDJPY (Spread max: ", g_max_spread, ", SL min: ", DoubleToString(g_min_sl_price/_Point/10.0,1), " pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      } else if(StringFind(symbol,"GBPUSD") >= 0) {
         g_distancia_puntos = 350; g_rsi_oversold = 45; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 300; g_atr_multiplier = 2.0;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = (_Period >= PERIOD_M15 ? 160 : 100) * _Point; // [V15.20] Min 16.0 pips en M15 (10.0 en M5)
         Print("AURUM FOREX V15.20 GBPUSD (Spread max: ", g_max_spread, ", SL min: ", DoubleToString(g_min_sl_price/_Point/10.0,1), " pips, R:R 1:", DoubleToString(g_risk_reward,1), ")");
      }"""
    assert old_forex_block in content, f"old_forex_block not found in {filepath}"
    content = content.replace(old_forex_block, new_forex_block)

    # 5. Mutex Inter-Chart in HasUnprotectedCorrelatedUSDPosition
    old_mutex_anchor = """bool HasUnprotectedCorrelatedUSDPosition(string symbol, string new_order_type, string &conflict_sym) {
   conflict_sym = "";
   if(!InpBlockCorrelatedUSDRisk) return false;
   int new_usd_dir = GetUSDDirection(symbol, new_order_type);
   if(new_usd_dir == 0) return false;"""

    new_mutex_anchor = """bool HasUnprotectedCorrelatedUSDPosition(string symbol, string new_order_type, string &conflict_sym) {
   conflict_sym = "";
   if(!InpBlockCorrelatedUSDRisk) return false;
   int new_usd_dir = GetUSDDirection(symbol, new_order_type);
   if(new_usd_dir == 0) return false;

   // [V15.20 Anti-Race Condition] Si otra divisa USD disparó hace menos de 15 segundos, bloquear disparo concurrente
   if(GlobalVariableCheck("AURUM_USD_DISPATCH_TIME")) {
      datetime last_disp = (datetime)GlobalVariableGet("AURUM_USD_DISPATCH_TIME");
      if(TimeCurrent() - last_disp < 15) {
         conflict_sym = "MUTEX_USD_CONCURRENTE";
         return true;
      }
   }"""
    assert old_mutex_anchor in content, f"old_mutex_anchor not found in {filepath}"
    content = content.replace(old_mutex_anchor, new_mutex_anchor)

    # 6. Set Global Mutex upon firing trade.Buy and trade.Sell
    old_buy_exec = 'if(trade.Buy(trade_lot, _Symbol, ask, sl, tp, "Aurum V15 Sniper")) {'
    new_buy_exec = """int usd_dir_buy = GetUSDDirection(_Symbol, "BUY");
         if(usd_dir_buy != 0) GlobalVariableSet("AURUM_USD_DISPATCH_TIME", (double)TimeCurrent());
         if(trade.Buy(trade_lot, _Symbol, ask, sl, tp, "Aurum V15 Sniper")) {"""
    assert old_buy_exec in content, f"old_buy_exec not found in {filepath}"
    content = content.replace(old_buy_exec, new_buy_exec)

    old_sell_exec = 'if(trade.Sell(trade_lot, _Symbol, bid, sl, tp, "Aurum V15 Sniper")) {'
    new_sell_exec = """int usd_dir_sell = GetUSDDirection(_Symbol, "SELL");
         if(usd_dir_sell != 0) GlobalVariableSet("AURUM_USD_DISPATCH_TIME", (double)TimeCurrent());
         if(trade.Sell(trade_lot, _Symbol, bid, sl, tp, "Aurum V15 Sniper")) {"""
    assert old_sell_exec in content, f"old_sell_exec not found in {filepath}"
    content = content.replace(old_sell_exec, new_sell_exec)

    # Convert to CRLF for Windows MT5
    content = content.replace("\n", "\r\n")

    with open(filepath, "wb") as f:
        f.write(content.encode("utf-8"))
    print(f"Successfully applied V15.20 to {filepath} with CRLF!")

if __name__ == "__main__":
    apply_v15_20("AurumSniper.mq5")
    apply_v15_20("AurumSniperMicro.mq5")
