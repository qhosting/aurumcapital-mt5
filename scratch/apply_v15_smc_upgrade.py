import os

def apply_smc_upgrade(filepath):
    print(f"Upgrading {filepath}...")
    with open(filepath, "r", encoding="utf-8", errors="ignore") as f:
        content = f.read()

    # Normalize to \n for reliable matching
    content = content.replace("\r\n", "\n")

    # 1. Update Version in property
    content = content.replace(
        '#property version   "15.00"',
        '#property version   "15.10"'
    )

    # Add Changelog comment
    changelog_snippet = """// CHANGELOG V15.10:
//  [V15.10] FILTROS DE ALINEACION SMC & PROTECCION DE POI OPUESTO:
//          - InpStrictSMCAlign: Bloquea ventas si la estructura SMC local está en Bullish CHoCH/BOS, y compras en Bearish CHoCH/BOS.
//          - InpBlockOpposingPOI: Bloquea disparos si el precio está testeando simultáneamente un POI opuesto activo (ej: no vender sobre Bull Breaker/OB).
//          - IsSMCStructureAligned() & HasOpposingSMCZone() integrados en evaluación OnTick() y DebugSignalMiss().
//          - Dashboard enriquecido con indicador de permiso de estructura SMC en vivo.
"""
    if "CHANGELOG V15.10:" not in content:
        content = content.replace("// CHANGELOG V13.50:", changelog_snippet + "// CHANGELOG V13.50:")

    # 2. Add Inputs to SMC group
    smc_inputs_target = "input color    InpBreakerColor             = C'25,45,75'; // Color Breaker Block"
    new_smc_inputs = """input color    InpBreakerColor             = C'25,45,75'; // Color Breaker Block
input bool     InpStrictSMCAlign           = true;  // [V15.10] Alinear Disparo con Estructura SMC (Anti-CHoCH Contrario)
input bool     InpBlockOpposingPOI         = true;  // [V15.10] Bloquear Disparo si Hay POI Opuesto Activo"""
    
    assert smc_inputs_target in content, f"smc_inputs_target not found in {filepath}"
    content = content.replace(smc_inputs_target, new_smc_inputs)

    # 3. Add Helper Functions after IsInSMCInstitutionalZone
    smc_helpers = """
//+------------------------------------------------------------------+
//| [V15.10] Verificacion de Alineacion Estricta con Estructura SMC  |
//+------------------------------------------------------------------+
bool IsSMCStructureAligned(string direction) {
   if(!InpUseSMCStructures || !InpStrictSMCAlign) return true;
   // No comprar si la estructura local esta en quiebre bajista (Bearish CHoCH/BOS)
   if(direction == "BUY"  && g_market_structure_trend == -1) return false;
   // No vender si la estructura local esta en quiebre alcista (Bullish CHoCH/BOS)
   if(direction == "SELL" && g_market_structure_trend == 1)  return false;
   return true;
}

//+------------------------------------------------------------------+
//| [V15.10] Verificacion de Conflicto con Zonas Institucionales     |
//+------------------------------------------------------------------+
bool HasOpposingSMCZone(string direction, double cur_price) {
   if(!InpUseSMCStructures || !InpBlockOpposingPOI) return false;
   double tolerance = 3.0 * _Point;
   
   if(direction == "SELL") {
      // Bloquear venta si el precio esta dentro o rebotando en un Bullish OB o Bullish Breaker activo
      for(int b = g_total_obs - 1; b >= 0; b--) {
         if(g_order_blocks[b].is_mitigated) continue;
         if(g_order_blocks[b].is_bullish) {
            double top = g_order_blocks[b].top + tolerance;
            double bot = g_order_blocks[b].bottom - tolerance;
            if(cur_price >= bot && cur_price <= top) return true;
         }
      }
      if(InpUseFVGFilter) {
         for(int f = g_total_fvgs - 1; f >= 0; f--) {
            if(g_fvgs[f].is_mitigated) continue;
            if(g_fvgs[f].is_bullish) {
               double top = g_fvgs[f].top + tolerance;
               double bot = g_fvgs[f].bottom - tolerance;
               if(cur_price >= bot && cur_price <= top) return true;
            }
         }
      }
   }
   else if(direction == "BUY") {
      // Bloquear compra si el precio esta dentro o chocando contra un Bearish OB o Bearish Breaker activo
      for(int b = g_total_obs - 1; b >= 0; b--) {
         if(g_order_blocks[b].is_mitigated) continue;
         if(!g_order_blocks[b].is_bullish) {
            double top = g_order_blocks[b].top + tolerance;
            double bot = g_order_blocks[b].bottom - tolerance;
            if(cur_price >= bot && cur_price <= top) return true;
         }
      }
      if(InpUseFVGFilter) {
         for(int f = g_total_fvgs - 1; f >= 0; f--) {
            if(g_fvgs[f].is_mitigated) continue;
            if(!g_fvgs[f].is_bullish) {
               double top = g_fvgs[f].top + tolerance;
               double bot = g_fvgs[f].bottom - tolerance;
               if(cur_price >= bot && cur_price <= top) return true;
            }
         }
      }
   }
   return false;
}
"""
    anchor_helpers = "   bool sweep_valid = (direction == \"BUY\") ? g_smc_liquidity_sweep_buy : g_smc_liquidity_sweep_sell;\n   return (has_ob || has_breaker || has_fvg || sweep_valid);\n}"
    assert anchor_helpers in content, f"anchor_helpers not found in {filepath}"
    content = content.replace(anchor_helpers, anchor_helpers + "\n" + smc_helpers)

    # 4. Update DebugSignalMiss entire block
    old_debug_block = """void DebugSignalMiss(string direction, bool trend, bool in_zone,
                     double rsi, double adx, bool is_spike,
                     bool has_open_trade, bool good_spread,
                     bool daily_limit, double eff_rsi_oversold,
                     double eff_rsi_overbought, bool cooldown_ok, bool session_ok,
                     bool discount_ok, bool usd_corr_blocked, string conflict_sym,
                     string session_reason, bool micro_ok, string micro_reason,
                     bool pa_ok, string pa_reason) {
   if(!in_zone && discount_ok) return;
   double open1  = iOpen(_Symbol,  _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   long cur_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(direction == "BUY" && close1 > open1) {
      string reason = "";
      if(!trend)             reason += "[Sin Tendencia] ";
      if(!discount_ok)       reason += "[Zona Cara/Premium] ";
      if(rsi >= eff_rsi_oversold)  reason += "[RSI="+DoubleToString(rsi,1)+"<"+DoubleToString(eff_rsi_oversold,1)+"] ";
      if(adx <= g_adx_threshold)   reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)           reason += "[Vela Elefante] ";
      if(!good_spread)       reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)        reason += "[Meta Diaria] ";
      if(has_open_trade)     reason += "[Trade abierto] ";
      if(usd_corr_blocked)   reason += "[Riesgo USD Duplicado con "+conflict_sym+" (Esperando BE)] ";
      if(!cooldown_ok)       reason += "[Cooldown] ";
      if(!session_ok)        reason += (session_reason != "" ? (session_reason + " ") : "[Fuera Sesion] ");
      if(!micro_ok)          reason += (micro_reason != "" ? (micro_reason + " ") : "[Micro-Gatillo Pendiente] ");
      if(!pa_ok)             reason += (pa_reason != "" ? (pa_reason + " ") : "[Esperando Giro PA] ");
      if(reason != "") Print("[X-RAY COMPRA OMITIDA] ", _Symbol, ": ", reason);
   }
   if(direction == "SELL" && close1 < open1) {
      string reason = "";
      if(!trend)             reason += "[Sin Tendencia] ";
      if(!discount_ok)       reason += "[Zona Barata/Descuento] ";
      if(rsi <= eff_rsi_overbought) reason += "[RSI="+DoubleToString(rsi,1)+">"+DoubleToString(eff_rsi_overbought,1)+"] ";
      if(adx <= g_adx_threshold)    reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)           reason += "[Vela Elefante] ";
      if(!good_spread)       reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)        reason += "[Meta Diaria] ";
      if(has_open_trade)     reason += "[Trade abierto] ";
      if(usd_corr_blocked)   reason += "[Riesgo USD Duplicado con "+conflict_sym+" (Esperando BE)] ";
      if(!cooldown_ok)       reason += "[Cooldown] ";
      if(!session_ok)        reason += (session_reason != "" ? (session_reason + " ") : "[Fuera Sesion] ");
      if(!micro_ok)          reason += (micro_reason != "" ? (micro_reason + " ") : "[Micro-Gatillo Pendiente] ");
      if(!pa_ok)             reason += (pa_reason != "" ? (pa_reason + " ") : "[Esperando Giro PA] ");
      if(reason != "") Print("[X-RAY VENTA OMITIDA] ", _Symbol, ": ", reason);
   }
}"""

    new_debug_block = """void DebugSignalMiss(string direction, bool trend, bool in_zone,
                     double rsi, double adx, bool is_spike,
                     bool has_open_trade, bool good_spread,
                     bool daily_limit, double eff_rsi_oversold,
                     double eff_rsi_overbought, bool cooldown_ok, bool session_ok,
                     bool discount_ok, bool usd_corr_blocked, string conflict_sym,
                     string session_reason, bool micro_ok, string micro_reason,
                     bool pa_ok, string pa_reason,
                     bool smc_struct_ok = true, bool opposing_poi = false) {
   if(!in_zone && discount_ok) return;
   double open1  = iOpen(_Symbol,  _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   long cur_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(direction == "BUY" && close1 > open1) {
      string reason = "";
      if(!trend)             reason += "[Sin Tendencia] ";
      if(!discount_ok)       reason += "[Zona Cara/Premium] ";
      if(rsi >= eff_rsi_oversold)  reason += "[RSI="+DoubleToString(rsi,1)+"<"+DoubleToString(eff_rsi_oversold,1)+"] ";
      if(adx <= g_adx_threshold)   reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)           reason += "[Vela Elefante] ";
      if(!good_spread)       reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)        reason += "[Meta Diaria] ";
      if(has_open_trade)     reason += "[Trade abierto] ";
      if(usd_corr_blocked)   reason += "[Riesgo USD Duplicado con "+conflict_sym+" (Esperando BE)] ";
      if(!cooldown_ok)       reason += "[Cooldown] ";
      if(!session_ok)        reason += (session_reason != "" ? (session_reason + " ") : "[Fuera Sesion] ");
      if(!micro_ok)          reason += (micro_reason != "" ? (micro_reason + " ") : "[Micro-Gatillo Pendiente] ");
      if(!pa_ok)             reason += (pa_reason != "" ? (pa_reason + " ") : "[Esperando Giro PA] ");
      if(!smc_struct_ok)     reason += "[Estructura SMC Bajista (CHoCH/BOS)] ";
      if(opposing_poi)       reason += "[Chocando con Resistencia/POI Bajista] ";
      if(reason != "") Print("[X-RAY COMPRA OMITIDA] ", _Symbol, ": ", reason);
   }
   if(direction == "SELL" && close1 < open1) {
      string reason = "";
      if(!trend)             reason += "[Sin Tendencia] ";
      if(!discount_ok)       reason += "[Zona Barata/Descuento] ";
      if(rsi <= eff_rsi_overbought) reason += "[RSI="+DoubleToString(rsi,1)+">"+DoubleToString(eff_rsi_overbought,1)+"] ";
      if(adx <= g_adx_threshold)    reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)           reason += "[Vela Elefante] ";
      if(!good_spread)       reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)        reason += "[Meta Diaria] ";
      if(has_open_trade)     reason += "[Trade abierto] ";
      if(usd_corr_blocked)   reason += "[Riesgo USD Duplicado con "+conflict_sym+" (Esperando BE)] ";
      if(!cooldown_ok)       reason += "[Cooldown] ";
      if(!session_ok)        reason += (session_reason != "" ? (session_reason + " ") : "[Fuera Sesion] ");
      if(!micro_ok)          reason += (micro_reason != "" ? (micro_reason + " ") : "[Micro-Gatillo Pendiente] ");
      if(!pa_ok)             reason += (pa_reason != "" ? (pa_reason + " ") : "[Esperando Giro PA] ");
      if(!smc_struct_ok)     reason += "[Estructura SMC Alcista (CHoCH/BOS)] ";
      if(opposing_poi)       reason += "[Chocando con Soporte/POI Alcista] ";
      if(reason != "") Print("[X-RAY VENTA OMITIDA] ", _Symbol, ": ", reason);
   }
}"""
    assert old_debug_block in content, f"old_debug_block not found in {filepath}"
    content = content.replace(old_debug_block, new_debug_block)

    # 5. Update DebugSignalMiss invocations in OnTick
    old_debug_calls = """   DebugSignalMiss("BUY",  (trend_bull || (range_bull && is_trap_buy)), buy_zone_ok,  rsi, adx, is_spike_buy,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_buy_ok,
                   usd_corr_blocked_buy, conflict_sym_buy, session_reason, micro_buy_ok, micro_reason_buy,
                   pa_buy_ok, pa_reason_buy);
   DebugSignalMiss("SELL", (trend_bear || (range_bear && is_trap_sell)), sell_zone_ok, rsi, adx, is_spike_sell,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_sell_ok,
                   usd_corr_blocked_sell, conflict_sym_sell, session_reason, micro_sell_ok, micro_reason_sell,
                   pa_sell_ok, pa_reason_sell);"""

    new_debug_calls = """   bool smc_struct_buy_ok  = IsSMCStructureAligned("BUY");
   bool opposing_poi_buy   = HasOpposingSMCZone("BUY", ask);
   bool smc_struct_sell_ok = IsSMCStructureAligned("SELL");
   bool opposing_poi_sell  = HasOpposingSMCZone("SELL", bid);

   DebugSignalMiss("BUY",  (trend_bull || (range_bull && is_trap_buy)), buy_zone_ok,  rsi, adx, is_spike_buy,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_buy_ok,
                   usd_corr_blocked_buy, conflict_sym_buy, session_reason, micro_buy_ok, micro_reason_buy,
                   pa_buy_ok, pa_reason_buy, smc_struct_buy_ok, opposing_poi_buy);
   DebugSignalMiss("SELL", (trend_bear || (range_bear && is_trap_sell)), sell_zone_ok, rsi, adx, is_spike_sell,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_sell_ok,
                   usd_corr_blocked_sell, conflict_sym_sell, session_reason, micro_sell_ok, micro_reason_sell,
                   pa_sell_ok, pa_reason_sell, smc_struct_sell_ok, opposing_poi_sell);"""
    assert old_debug_calls in content, f"old_debug_calls not found in {filepath}"
    content = content.replace(old_debug_calls, new_debug_calls)

    # 6. Update can_buy and can_sell conditions
    old_can_buy = """   bool has_ob_buy = false, has_brk_buy = false, has_fvg_buy = false;
   bool smc_buy_ok = IsInSMCInstitutionalZone("BUY", ask, has_ob_buy, has_brk_buy, has_fvg_buy);
   bool can_buy = (trend_bull || (range_bull && (is_trap_buy || g_smc_liquidity_sweep_buy))) && buy_zone_ok && (!InpUseSMCStructures || smc_buy_ok || g_smc_liquidity_sweep_buy) && (rsi < eff_rsi_oversold) && (adx > g_adx_threshold) && !is_spike_buy && !usd_corr_blocked_buy && micro_buy_ok && pa_buy_ok && !is_news_volatility;"""

    new_can_buy = """   bool has_ob_buy = false, has_brk_buy = false, has_fvg_buy = false;
   bool smc_buy_ok = IsInSMCInstitutionalZone("BUY", ask, has_ob_buy, has_brk_buy, has_fvg_buy);
   bool can_buy = (trend_bull || (range_bull && (is_trap_buy || g_smc_liquidity_sweep_buy))) && buy_zone_ok && (!InpUseSMCStructures || smc_buy_ok || g_smc_liquidity_sweep_buy) && smc_struct_buy_ok && !opposing_poi_buy && (rsi < eff_rsi_oversold) && (adx > g_adx_threshold) && !is_spike_buy && !usd_corr_blocked_buy && micro_buy_ok && pa_buy_ok && !is_news_volatility;"""
    assert old_can_buy in content, f"old_can_buy not found in {filepath}"
    content = content.replace(old_can_buy, new_can_buy)

    old_can_sell = """   bool has_ob_sell = false, has_brk_sell = false, has_fvg_sell = false;
   bool smc_sell_ok = IsInSMCInstitutionalZone("SELL", bid, has_ob_sell, has_brk_sell, has_fvg_sell);
   bool can_sell = (trend_bear || (range_bear && (is_trap_sell || g_smc_liquidity_sweep_sell))) && sell_zone_ok && (!InpUseSMCStructures || smc_sell_ok || g_smc_liquidity_sweep_sell) && (rsi > eff_rsi_overbought) && (adx > g_adx_threshold) && !is_spike_sell && !usd_corr_blocked_sell && micro_sell_ok && pa_sell_ok && !is_news_volatility;"""

    new_can_sell = """   bool has_ob_sell = false, has_brk_sell = false, has_fvg_sell = false;
   bool smc_sell_ok = IsInSMCInstitutionalZone("SELL", bid, has_ob_sell, has_brk_sell, has_fvg_sell);
   bool can_sell = (trend_bear || (range_bear && (is_trap_sell || g_smc_liquidity_sweep_sell))) && sell_zone_ok && (!InpUseSMCStructures || smc_sell_ok || g_smc_liquidity_sweep_sell) && smc_struct_sell_ok && !opposing_poi_sell && (rsi > eff_rsi_overbought) && (adx > g_adx_threshold) && !is_spike_sell && !usd_corr_blocked_sell && micro_sell_ok && pa_sell_ok && !is_news_volatility;"""
    assert old_can_sell in content, f"old_can_sell not found in {filepath}"
    content = content.replace(old_can_sell, new_can_sell)

    # 7. Update Dashboard
    old_dash_trend = """   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, y, trend_clr, 10); y += 20;"""
    new_dash_trend = """   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, y, trend_clr, 10); y += 20;

   if(InpUseSMCStructures) {
      string smc_str_txt = (g_market_structure_trend == 1) ? "BULLISH (CHoCH/BOS) [Solo BUY]"
                         : (g_market_structure_trend == -1) ? "BEARISH (CHoCH/BOS) [Solo SELL]"
                         : "NEUTRO / EN RANGO";
      color smc_str_clr = (g_market_structure_trend == 1) ? clrLime
                        : (g_market_structure_trend == -1) ? clrRed
                        : clrSilver;
      DrawLabel("lbl_SMC_Structure", "Estructura SMC: " + smc_str_txt, 20, y, smc_str_clr, 10); y += 20;
   } else {
      ObjectDelete(0, "lbl_SMC_Structure");
   }"""
    assert old_dash_trend in content, f"old_dash_trend not found in {filepath}"
    content = content.replace(old_dash_trend, new_dash_trend)

    # Convert to CRLF for Windows MT5
    content = content.replace("\n", "\r\n")

    with open(filepath, "wb") as f:
        f.write(content.encode("utf-8"))
    print(f"Successfully upgraded {filepath} to V15.10 with CRLF!")

if __name__ == "__main__":
    apply_smc_upgrade("AurumSniper.mq5")
    apply_smc_upgrade("AurumSniperMicro.mq5")
