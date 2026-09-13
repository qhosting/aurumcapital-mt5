import re
import sys

def update_to_v15(filepath, is_micro=False):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # 1. Update Header and Version
    content = content.replace(
        '#property version   "13.50"',
        '#property version   "15.00"'
    )
    content = content.replace(
        'V13.50 - Institutional Gold Scalper (Capped SL $18 & TP 1.8R)',
        'V15.00 - Institutional Risk, Reconciliation & Pre-Flight Validation'
    )
    content = content.replace(
        '#property description "AurumSniper Micro Edition V13.50 optimizado para cuentas Micro MT5"',
        '#property description "AurumSniper Institutional V15: Risk Guard, Order Reconciliation & Pre-Flight Validation Engine"'
    )

    # 2. Add V15 Inputs
    # Regex replace for the risk group
    risk_pattern = re.compile(
        r'input group "=== GESTION DE RIESGO AVANZADA \(MICRO EDITION V13\.50\) ===".*?'
        r'input bool\s+InpAutoDailyReset\s*=\s*true;',
        re.DOTALL
    )

    magic = 777998 if is_micro else 777999
    lot = 0.1 if is_micro else 0.01
    loss_usd = 20.0 if is_micro else 150.0

    new_risk_group = f"""input group "=== GESTIÓN DE RIESGO INSTITUCIONAL & PROTECCIÓN DIARIA (V15) ==="
input int      InpMagicNumber             = {magic}; // Magic Number de identificación
input double   InpLotSize                 = {lot};   // Lote base para operativa
input bool     InpUseAutoRiskPercent      = true;
input double   InpRiskPercent             = 1.0;    // Arriesga exactamente el 1.0% del capital
input double   InpMaxAllowedRiskPercent   = 5.0;    // Riesgo Máximo Permitido por Trade (% del capital)
input bool     InpStrictRiskProtection    = false;  // Bloquear trade si el lote mínimo excede el Riesgo Máximo
input bool     InpUseDailyRiskGuard       = true;   // [V15] Activar Guardia de Riesgo Diario (Hard Stop de Pérdida)
input double   InpMaxDailyLossUSD         = {loss_usd:.1f};  // [V15] Límite Monetario Máximo de Pérdida Diaria ($ USD)
input double   InpMaxDailyLoss            = 3.0;    // [V15] Límite Porcentual Máximo de Pérdida Diaria (% del balance)
input int      InpMaxConsecutiveLosses    = 3;      // [V15] Disyuntor: Pausar tras N pérdidas consecutivas seguidas
input int      InpLossCooldownHours       = 2;      // [V15] Horas de enfriamiento forzoso tras activar disyuntor
input double   InpMinFreeMarginPct        = 25.0;   // [V15] Margen libre mínimo requerido para operar (% del equity)
input bool     InpAutoDailyReset          = true;

input group "=== MOTOR DE RECONCILIACIÓN Y AUDITORÍA DE ÓRDENES (V15) ==="
input bool     InpAutoReconcileOnInit     = true;   // [V15] Reconciliar posiciones, SL/TP y parciales al iniciar EA
input bool     InpEnforceSLTPOnReconcile  = true;   // [V15] Inyectar SL/TP técnico inmediato a posiciones huérfanas
input bool     InpSyncPhasesOnReconcile   = true;   // [V15] Sincronizar Fases y Parciales con historial de deals
input bool     InpAutoPurgeOrphanGraphics = true;   // [V15] Limpiar líneas y textos de tickets cerrados en broker

input group "=== FLUJO DE VALIDACIÓN PRE-FLIGHT (V15) ==="
input bool     InpStrictPreFlightCheck    = true;   // [V15] Validar entorno, modo de trading, spread y stops antes de disparar
input bool     InpLogValidationEvents     = true;   // [V15] Registrar diagnósticos en log detallado;"""

    content, n = risk_pattern.subn(new_risk_group, content)
    if n == 0:
        print(f"[ERROR] No se pudo encontrar el grupo de riesgo en {filepath}")
        return

    # 3. Add V15 Global Variables
    old_globals_marker = "const int MAGIC_NUMBER    = " + str(magic) + ";\ndouble   g_last_trade_profit = 0; // Ganancia/Pérdida del último trade cerrado\nint      g_consecutive_losses = 0; // Contador de pérdidas consecutivas"
    # Or regex
    globals_pattern = re.compile(
        r'const int MAGIC_NUMBER\s*=\s*\d+;\s*\n'
        r'double\s+g_last_trade_profit\s*=\s*0;\s*//[^\n]*\n'
        r'int\s+g_consecutive_losses\s*=\s*0;\s*//[^\n]*'
    )
    new_globals = f"""const int MAGIC_NUMBER    = {magic};
double   g_last_trade_profit = 0; // Ganancia/Pérdida del último trade cerrado
int      g_consecutive_losses = 0; // Contador de pérdidas consecutivas

// [V15 GLOBALS] Risk Guard, Reconciliation & Pre-Flight Validation
bool     g_daily_killswitch_active       = false;
datetime g_consecutive_cooldown_until    = 0;
double   g_daily_closed_pnl              = 0.0;
double   g_daily_floating_pnl            = 0.0;
int      g_reconciled_positions_count    = 0;
string   g_preflight_status_txt          = "PRE-FLIGHT: INICIANDO...";
color    g_preflight_status_clr          = clrGold;
string   g_last_validation_fail_reason   = "";"""

    content, n_g = globals_pattern.subn(new_globals, content)
    if n_g == 0:
        print(f"[ERROR] No se pudieron reemplazar las variables globales en {filepath}")
        return

    # 4. Insert V15 Core Functions
    v15_functions = """
//+------------------------------------------------------------------+
//| [V15] MOTOR DE GESTIÓN DE RIESGO DIARIO INSTITUCIONAL           |
//+------------------------------------------------------------------+
void UpdateDailyRiskMetrics() {
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   if(today_start == 0) today_start = TimeCurrent() - (TimeCurrent() % 86400);
   
   // 1. Calcular P&L cerrado del día para el símbolo / magic
   double closed_today = 0.0;
   if(HistorySelect(today_start, TimeCurrent())) {
      int deals_tot = HistoryDealsTotal();
      for(int i = 0; i < deals_tot; i++) {
         ulong dticket = HistoryDealGetTicket(i);
         if(dticket <= 0) continue;
         long entry_type = HistoryDealGetInteger(dticket, DEAL_ENTRY);
         if(entry_type == DEAL_ENTRY_OUT || entry_type == DEAL_ENTRY_INOUT) {
            string sym = HistoryDealGetString(dticket, DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(dticket, DEAL_MAGIC);
            if(sym == _Symbol && (magic == MAGIC_NUMBER || InpManageManualTrades)) {
               closed_today += HistoryDealGetDouble(dticket, DEAL_PROFIT);
               closed_today += HistoryDealGetDouble(dticket, DEAL_SWAP);
               closed_today += HistoryDealGetDouble(dticket, DEAL_COMMISSION);
            }
         }
      }
   }
   g_daily_closed_pnl = NormalizeDouble(closed_today, 2);

   // 2. Calcular P&L flotante actual
   double floating_today = 0.0;
   for(int p = PositionsTotal() - 1; p >= 0; p--) {
      ulong pticket = PositionGetTicket(p);
      if(pticket <= 0 || !PositionSelectByTicket(pticket)) continue;
      string psym = PositionGetString(POSITION_SYMBOL);
      long pmagic = PositionGetInteger(POSITION_MAGIC);
      if(psym == _Symbol && (pmagic == MAGIC_NUMBER || InpManageManualTrades)) {
         floating_today += PositionGetDouble(POSITION_PROFIT);
         floating_today += PositionGetDouble(POSITION_SWAP);
      }
   }
   g_daily_floating_pnl = NormalizeDouble(floating_today, 2);

   // 3. Evaluar Límite de Pérdida Diaria (USD y %)
   double total_daily_pnl = g_daily_closed_pnl + g_daily_floating_pnl;
   bool hit_usd_limit = (InpUseDailyRiskGuard && InpMaxDailyLossUSD > 0 && total_daily_pnl <= -InpMaxDailyLossUSD);
   
   double cur_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   bool hit_pct_limit = false;
   if(g_start_equity > 0 && cur_eq > 0) {
      double dd_pct = (g_start_equity - cur_eq) / g_start_equity * 100.0;
      if(dd_pct >= InpMaxDailyLoss) hit_pct_limit = true;
   }

   if(hit_usd_limit || hit_pct_limit) {
      if(!g_daily_killswitch_active) {
         g_daily_killswitch_active = true;
         PrintFormat("[ALERTA V15 RISK GUARD] KILLSWITCH ACTIVADO: P&L Hoy=$%.2f (Límite USD: -$%.2f | Límite %%: %.1f%%). Nuevas entradas bloqueadas hoy.",
                     total_daily_pnl, InpMaxDailyLossUSD, InpMaxDailyLoss);
      }
   }

   // 4. Evaluar Disyuntor de Pérdidas Consecutivas
   if(InpMaxConsecutiveLosses > 0 && g_consecutive_losses >= InpMaxConsecutiveLosses) {
      if(g_consecutive_cooldown_until <= TimeCurrent()) {
         g_consecutive_cooldown_until = TimeCurrent() + (InpLossCooldownHours * 3600);
         PrintFormat("[ALERTA V15 DISYUNTOR] %d pérdidas consecutivas alcanzadas. Cooldown activo por %d horas hasta: %s",
                     g_consecutive_losses, InpLossCooldownHours, TimeToString(g_consecutive_cooldown_until, TIME_DATE|TIME_MINUTES));
      }
   }
}

//+------------------------------------------------------------------+
//| [V15] MOTOR DE RECONCILIACIÓN Y SINCRONIZACIÓN DE POSICIONES     |
//+------------------------------------------------------------------+
void ReconcileOpenPositions() {
   int active_count = 0;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      
      string pos_sym = PositionGetString(POSITION_SYMBOL);
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_sym != _Symbol) continue;
      if(pos_magic != MAGIC_NUMBER && !InpManageManualTrades) continue;
      
      active_count++;
      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      long   type      = PositionGetInteger(POSITION_TYPE);
      
      // 1. Auto-Reparación de Posición Huérfana (sin SL o sin TP)
      if(InpEnforceSLTPOnReconcile && (sl == 0 || tp == 0)) {
         double atr_val = (hATR != INVALID_HANDLE && g_atr_0_cache > 0) ? g_atr_0_cache : 0;
         double sl_dist = (atr_val > 0) ? (atr_val * g_atr_multiplier) : (g_distancia_puntos * _Point * 2.0);
         if(g_min_sl_price > 0 && sl_dist < g_min_sl_price) sl_dist = g_min_sl_price;
         if(g_max_sl_price > 0 && sl_dist > g_max_sl_price) sl_dist = g_max_sl_price;
         double tp_dist = sl_dist * g_risk_reward;
         
         double new_sl = sl; 
         double new_tp = tp;
         if(type == POSITION_TYPE_BUY) {
            if(new_sl == 0) new_sl = NormalizeDouble(entry - sl_dist, _Digits);
            if(new_tp == 0) new_tp = NormalizeDouble(entry + tp_dist, _Digits);
            CheckStops(new_sl, new_tp, true);
         } else if(type == POSITION_TYPE_SELL) {
            if(new_sl == 0) new_sl = NormalizeDouble(entry + sl_dist, _Digits);
            if(new_tp == 0) new_tp = NormalizeDouble(entry - tp_dist, _Digits);
            CheckStops(new_sl, new_tp, false);
         }
         
         if(trade.PositionModify(ticket, new_sl, new_tp)) {
            PrintFormat("[V15 RECONCILIACIÓN] Posición huérfana reparada Ticket #%I64u | SL=%.2f TP=%.2f", ticket, new_sl, new_tp);
         }
      }

      // 2. Sincronización de Parciales previas consultando Deals de la Posición
      if(InpSyncPhasesOnReconcile && !IsPartialAlreadyClosed(ticket)) {
         if(HistorySelectByPosition(ticket)) {
            int deals_tot = HistoryDealsTotal();
            for(int d = 0; d < deals_tot; d++) {
               ulong dtick = HistoryDealGetTicket(d);
               if(dtick <= 0) continue;
               long dentry = HistoryDealGetInteger(dtick, DEAL_ENTRY);
               if(dentry == DEAL_ENTRY_OUT) {
                  MarkPartialClosed(ticket);
                  PrintFormat("[V15 RECONCILIACIÓN] Sincronizado cierre parcial previo detectado en ticket #%I64u", ticket);
                  break;
               }
            }
         }
      }
   }
   
   g_reconciled_positions_count = active_count;
   
   // 3. Purgar gráficos huérfanos si ya no hay posiciones vivas en este gráfico
   if(InpAutoPurgeOrphanGraphics && active_count == 0) {
      ObjectDelete(0, "tp_lvl_05");
      ObjectDelete(0, "tp_lvl_txt05");
      ObjectDelete(0, "tp_lvl_1");
      ObjectDelete(0, "tp_lvl_txt1");
      ObjectDelete(0, "tp_lvl_2");
      ObjectDelete(0, "tp_lvl_txt2");
      ObjectDelete(0, "tp_lvl_3");
      ObjectDelete(0, "tp_lvl_txt3");
   }
}

//+------------------------------------------------------------------+
//| [V15] FLUJO DE VALIDACIÓN Y DIAGNÓSTICO PRE-FLIGHT               |
//+------------------------------------------------------------------+
bool ValidateEnvironmentV15(string &fail_reason) {
   fail_reason = "";

   // 1. AlgoTrading en MT5 Global
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
      fail_reason = "Algo Trading global DESACTIVADO en MT5 (botón superior)";
      g_preflight_status_txt = "FAIL: ALGO TRADING OFF";
      g_preflight_status_clr = clrRed;
      return false;
   }

   // 2. Permisos de trading del EA específico
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
      fail_reason = "Trading no permitido en propiedades del EA (F7 -> Permitir Trading Algorítmico)";
      g_preflight_status_txt = "FAIL: EA TRADE PERMISSION OFF";
      g_preflight_status_clr = clrRed;
      return false;
   }

   // 3. Permisos de cuenta y broker
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT)) {
      fail_reason = "Trading automático deshabilitado por el broker en esta cuenta";
      g_preflight_status_txt = "FAIL: BROKER TRADE BLOCKED";
      g_preflight_status_clr = clrRed;
      return false;
   }

   // 4. Modo de Trading del Símbolo
   long sym_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(sym_mode != SYMBOL_TRADE_MODE_FULL) {
      fail_reason = StringFormat("Símbolo %s no tiene modo de trading completo (Modo: %d)", _Symbol, sym_mode);
      g_preflight_status_txt = "FAIL: SYMBOL TRADE MODE RESTRICTED";
      g_preflight_status_clr = clrRed;
      return false;
   }

   // 5. Verificación de Margen Libre
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double free_margin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   if(eq > 0) {
      double free_margin_pct = (free_margin / eq) * 100.0;
      if(free_margin_pct < InpMinFreeMarginPct) {
         fail_reason = StringFormat("Margen libre insuficiente: %.1f%% (Mínimo requerido: %.1f%%)", free_margin_pct, InpMinFreeMarginPct);
         g_preflight_status_txt = "FAIL: MARGIN INSUFFICIENT";
         g_preflight_status_clr = clrOrange;
         return false;
      }
   }

   // 6. Verificación de Spread
   int cur_spread = (int)SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(cur_spread > g_max_spread) {
      fail_reason = StringFormat("Spread actual excesivo: %d pts > Máximo permitido: %d pts", cur_spread, g_max_spread);
      g_preflight_status_txt = "FAIL: SPREAD SPIKE";
      g_preflight_status_clr = clrOrange;
      return false;
   }

   // 7. Guardia de Riesgo Diario
   if(g_daily_killswitch_active) {
      fail_reason = StringFormat("Killswitch diario activo: P&L Hoy=$%.2f excede límites de riesgo", g_daily_closed_pnl + g_daily_floating_pnl);
      g_preflight_status_txt = "FAIL: DAILY RISK LIMIT HIT";
      g_preflight_status_clr = clrRed;
      return false;
   }

   // 8. Disyuntor de Pérdidas Consecutivas
   if(g_consecutive_cooldown_until > TimeCurrent()) {
      fail_reason = StringFormat("Enfriamiento por disyuntor activo hasta %s (%d min restantes)",
                                 TimeToString(g_consecutive_cooldown_until, TIME_MINUTES),
                                 (int)((g_consecutive_cooldown_until - TimeCurrent()) / 60));
      g_preflight_status_txt = "PAUSE: LOSS COOLDOWN";
      g_preflight_status_clr = clrOrange;
      return false;
   }

   g_preflight_status_txt = "PRE-FLIGHT: PASS (100% OPERATIVO)";
   g_preflight_status_clr = clrLime;
   return true;
}
"""

    content = content.replace("int OnInit() {", v15_functions + "\nint OnInit() {")

    # 5. Update OnInit()
    old_oninit_code = """   EventSetTimer(1);
   Print("AURUM SNIPER MICRO V13.50 ULTIMATE PRO Loaded.");
   return(INIT_SUCCEEDED);"""

    new_oninit_code = """   // [V15 INITIALIZATION & RECONCILIATION]
   UpdateDailyRiskMetrics();
   if(InpAutoReconcileOnInit) {
      ReconcileOpenPositions();
   }
   string preflight_err = "";
   bool preflight_ok = ValidateEnvironmentV15(preflight_err);
   PrintFormat("[V15 PRE-FLIGHT STATUS] %s %s", g_preflight_status_txt, (preflight_ok ? "✅" : ("⚠️ Razón: " + preflight_err)));

   EventSetTimer(1);
   Print("AURUM SNIPER INSTITUTIONAL V15 PRO Loaded.");
   return(INIT_SUCCEEDED);"""

    content = content.replace(old_oninit_code, new_oninit_code)

    # 6. Update OnTick()
    old_ontick_head = """void OnTick() {
   bool new_bar = IsNewBar();
   if(new_bar) { UpdateIndicatorCache(); UpdateSMCStructures(); }
   else        UpdateATRCache();
   CheckAndResetDaily();
   if(CheckDailyDrawdown()) { Comment("\\nMAX DRAWDOWN DIARIO ALCANZADO."); return; }
   else Comment("");
   GestionarPosicionesPro();"""

    new_ontick_head = """void OnTick() {
   bool new_bar = IsNewBar();
   if(new_bar) { UpdateIndicatorCache(); UpdateSMCStructures(); }
   else        UpdateATRCache();
   CheckAndResetDaily();
   
   // [V15 RISK GUARD & RECONCILIATION ON TICK]
   UpdateDailyRiskMetrics();
   ReconcileOpenPositions();
   
   if(g_daily_killswitch_active || CheckDailyDrawdown()) {
      Comment(StringFormat("\\n⚠️ [V15 RISK GUARD] MAX DRAWDOWN / LIMITE DIARIO ALCANZADO (P&L Hoy: $%.2f). Operaciones pausadas.", g_daily_closed_pnl + g_daily_floating_pnl));
      GestionarPosicionesPro();
      return;
   } else if(g_consecutive_cooldown_until > TimeCurrent()) {
      Comment(StringFormat("\\n⏳ [V15 DISYUNTOR] Enfriamiento tras %d pérdidas consecutivas. Pausa activa hasta %s.", g_consecutive_losses, TimeToString(g_consecutive_cooldown_until, TIME_MINUTES)));
   } else {
      Comment("");
   }
   
   GestionarPosicionesPro();"""

    content = content.replace(old_ontick_head, new_ontick_head)

    # 7. Update Can_buy and Can_sell
    old_buy_exec = """   if(can_buy) {
      // [V13.50] SL acotado entre mínimo ($10) y techo máximo ($18) para ratios óptimos
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);"""

    new_buy_exec = """   string preflight_buy_fail = "";
   bool v15_buy_ready = ValidateEnvironmentV15(preflight_buy_fail);

   if(can_buy && v15_buy_ready) {
      // [V15] SL acotado entre mínimo ($10) y techo máximo ($18) para ratios óptimos
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);"""

    content = content.replace(old_buy_exec, new_buy_exec)

    old_sell_exec = """   if(can_sell) {
      // [V13.50] SL acotado entre mínimo ($10) y techo máximo ($18)
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);"""

    new_sell_exec = """   string preflight_sell_fail = "";
   bool v15_sell_ready = ValidateEnvironmentV15(preflight_sell_fail);

   if(can_sell && v15_sell_ready) {
      // [V15] SL acotado entre mínimo ($10) y techo máximo ($18)
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);"""

    content = content.replace(old_sell_exec, new_sell_exec)

    # 8. Update Trade comments to V15
    content = content.replace('"Aurum V13 Sniper"', '"Aurum V15 Sniper"')

    # 9. Update Dashboard Header & add V15 labels
    old_dash_title = 'DrawLabel("lbl_Title", "AURUM SNIPER MICRO V13.50 (PRO)", 20, y, clrGold, 12); y += 22;'
    new_dash_title = """DrawLabel("lbl_Title", "AURUM SNIPER INSTITUTIONAL V15 (PRO)", 20, y, clrGold, 12); y += 22;
   
   // [V15 DASHBOARD METRICS]
   string pnl_today_txt = StringFormat("P&L Hoy: %s$%.2f (Flotante: %s$%.2f) | Límite: -$%.2f",
                                       (g_daily_closed_pnl >= 0 ? "+" : ""), g_daily_closed_pnl,
                                       (g_daily_floating_pnl >= 0 ? "+" : ""), g_daily_floating_pnl,
                                       InpMaxDailyLossUSD);
   color pnl_today_clr = (g_daily_closed_pnl + g_daily_floating_pnl >= 0) ? clrLime : (g_daily_killswitch_active ? clrRed : clrOrange);
   DrawLabel("lbl_V15_Risk", "Riesgo Diario: " + pnl_today_txt, 20, y, pnl_today_clr, 10); y += 20;

   string rec_txt = StringFormat("Reconciliación: %d Pos. Sincronizadas | Parciales: %d | Disyuntor: %d/%d Losses",
                                 g_reconciled_positions_count, ArraySize(g_partial_closed_tickets),
                                 g_consecutive_losses, InpMaxConsecutiveLosses);
   DrawLabel("lbl_V15_Reconcile", rec_txt, 20, y, (g_consecutive_losses >= InpMaxConsecutiveLosses ? clrOrange : clrSilver), 10); y += 20;

   DrawLabel("lbl_V15_Health", "Validación: " + g_preflight_status_txt, 20, y, g_preflight_status_clr, 10); y += 20;"""

    content = content.replace(old_dash_title, new_dash_title)

    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

    print(f"[OK] {filepath} actualizado con éxito a V15.")

if __name__ == '__main__':
    update_to_v15('AurumSniper.mq5', is_micro=False)
    update_to_v15('AurumSniperMicro.mq5', is_micro=True)
