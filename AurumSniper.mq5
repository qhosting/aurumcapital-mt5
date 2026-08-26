//+------------------------------------------------------------------+
//|                                           AurumSniper_V12.mq5   |
//|                    Copyright 2026, Aurum Capital                 |
//|   V12.99 - M5 Fast Scalper (TP1 0.6R / TP2 1.5R / TP3 3.0R)      |
//+------------------------------------------------------------------+
// CHANGELOG V12.99:
//  [V12.99] OPTIMIZACION M5/M1 FAST SCALPER & MULTI-FASE DINAMICA:
//          - InpStep1_TriggerR = 0.6R: Disparo rápido de Break-Even y Toma Parcial (50%) en el primer impulso M5.
//          - InpStep2_TriggerR = 1.5R / InpStep2_LockR = 0.8R: Captura de liquidez estructural realista en M5.
//          - InpStep3_TriggerR = 3.0R / InpStep3_LockR = 1.8R: Modo Runner / Cierre total en extensiones fuertes.
//  [V12.98] FILTRO DE SESIONES DE ALTA LIQUIDEZ CDMX (KILLZONES LONDRES + NY):
//          - InpUseHighLiquiditySession: Activo (true) por defecto (01:00 AM a 12:00 PM CDMX).
//          - Bloquea operaciones en sesión asiática nocturna y domingos noche en Forex/Oro/Índices.
//          - InpSessionFilterForexOnly: Mantiene Cripto (BTC/ETH) 24/7 libre en cualquier sesión.
//  [V12.97] CIERRE TOTAL EN TP3 (TAKE PROFIT 3 EXIT):
//          - InpCloseOnTP3: Cierra el 100% de la posición restante al tocar el nivel TP3 (+3.0R).
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "12.99"
#property strict

#include <Trade\Trade.mqh>

// ==================== INPUTS ====================
input group "=== GESTION DE RIESGO AVANZADA (V12.99) ==="
input double   InpLotSize                 = 0.01;
input bool     InpUseAutoRiskPercent      = true;
input double   InpRiskPercent             = 1.0; // Arriesga exactamente el 1.0% del capital
input double   InpMaxAllowedRiskPercent   = 5.0; // [V12.99] Riesgo Máximo Permitido por Trade (% del capital)
input bool     InpStrictRiskProtection    = false;// [V12.99] Bloquear trade si el lote mínimo excede el Riesgo Máximo
input double   InpMaxDailyLoss            = 3.0;
input bool     InpAutoDailyReset          = true;

input group "=== AUTO-TUNING POR ACTIVO (V12.99) ==="
input bool     InpAutoGoldSettings        = true;
input double   InpGoldMinSL               = 6.0;  // [V12.99] SL Mínimo para Oro ($6.00 = 600 pts en M5 Scalp)
input bool     InpAutoForexSettings       = true;
input bool     InpAutoCryptoSettings      = true;
input bool     InpAutoIndexSettings       = true;

input group "=== FILTROS DE ENTRADA Y PORTAFOLIO (V12.95) ==="
input bool     InpUseDiscountPremiumFilter = true; // Exigir Descuento en Compras y Premium en Ventas
input double   InpEquilibriumPercent       = 50.0; // Nivel de Equilibrio (50% = Mitad de rango H1)
input bool     InpBlockCorrelatedUSDRisk   = true; // [V12.95] Bloquear riesgo duplicado USD si trade previo tiene riesgo (>0R)
input bool     InpSmartCooldown            = true; // Cooldown inteligente (1 vela si el trade previo cerró en Profit/BE)
input bool     InpAllowRiskFreeAddon       = true; // Permitir 2da entrada si la posición previa ya está en BE/Ganancia

input group "=== ESTRATEGIA SNIPER (V9 Engine) ==="
input int      InpMaxSpread          = 32;
input int      InpDistanciaPuntos    = 150;
input int      InpEMAPeriod          = 200;
input int      InpRSIOverbought      = 60;
input int      InpRSIOversold        = 42;
input int      InpADXThreshold       = 15;

input group "=== GESTION DE SALIDA ESCALONADA POR FASES (V12.99 M5) ==="
input double   InpATRMultiplier      = 2.0;
input bool     InpUsePartials        = true;
input double   InpRiskReward         = 3.0; // Ratio Riesgo:Beneficio Inicial (1:3)
input int      InpBE_Trigger         = 150;
input int      InpBE_LockPips        = 10;
input bool     InpManageManualTrades = true;
input bool     InpBlockAutoWhenManualOpen = false; // Bloquear auto si hay manual (false = bot opera independiente)
input bool     InpAutoSetManualSLTP  = true;

input bool     InpUseStepTrailing    = true; // [V12.99] Habilitar Fases (BE 0.6R -> +0.8R -> TP3 3.0R)
input double   InpStep1_TriggerR     = 0.6;  // [V12.99] Fase 1: Activar Break-Even protegido (+0.6R M5 Fast Scalp)
input double   InpStep2_TriggerR     = 1.5;  // [V12.99] Fase 2: Al tocar (+1.5R), asegurar (+0.8R)
input double   InpStep2_LockR        = 0.8;  // [V12.99] Fase 2: Ganancia bloqueada (+0.8R)
input double   InpStep3_TriggerR     = 3.0;  // [V12.99] Fase 3: Nivel de TP3 (+3.0R)
input double   InpStep3_LockR        = 1.8;  // [V12.99] Fase 3: Ganancia bloqueada (+1.8R si corre)
input bool     InpCloseOnTP3         = true; // [V12.97] Cerrar 100% de la posición en TP3 (+3.0R)
input bool     InpStepRunnerAbove3R  = false;// [V12.9] Runner infinito sobre 3R (solo si InpCloseOnTP3 = false)

input bool     InpUseTrailingStop    = false; // Trailing Stop continuo clásico (false si se usan Fases)
input bool     InpUseATRTrailing     = true;
input double   InpTrailingATRMult    = 1.5;
input int      InpTrailingStep       = 20;
input int      InpMaxDailyTrades     = 16;
input bool     InpUseLiquidityTraps  = true;

input group "=== FILTROS DE SEGURIDAD Y SESION (V12.98) ==="
input int      InpCooldownBars             = 2;
input bool     InpUseHighLiquiditySession  = true; // [V12.98] Operar solo en Sesiones de Alta Liquidez (Londres + NY)
input int      InpSessionStartHourCDMX     = 1;    // Hora Inicio CDMX (01:00 AM - Apertura Londres)
input int      InpSessionEndHourCDMX       = 12;   // Hora Cierre CDMX (12:00 PM - Fin Golden Overlap)
input bool     InpSessionFilterForexOnly   = true; // Aplicar a Forex, Metales e Índices (Cripto 24/7 libre)
input bool     InpUseFridayFilter          = true; // [V12.96] Filtro Especial de Viernes (Horario CDMX)
input int      InpFridayStartHourCDMX      = 1;    // Hora Inicio Viernes CDMX (01:00 AM)
input int      InpFridayEndHourCDMX        = 11;   // Hora Límite Viernes CDMX (11:00 AM)
input bool     InpFridayFilterForexOnly    = true; // Aplicar solo a Forex, Metales e Índices
input bool     InpUseSessionFilter         = false;// Filtro horario de broker personalizado
input int      InpStartHour                = 0;
input int      InpEndHour                  = 24;
input bool     InpUseATRBreakEven          = true;
input double   InpBE_ATR_Mult              = 0.8;  // [V12.9] 0.8x ATR para asegurar BE equilibrado

input group "=== FILTRO MULTITEMPORALIDAD (MTF) ==="
input bool            InpUseMTFFilter      = true;
input ENUM_TIMEFRAMES InpHTFTimeframe      = PERIOD_H4;
input bool            InpUseEMAInclinacion = true;

// ==================== GLOBALES ====================
CTrade trade;
int hMA, hMA_HTF, hRSI, hADX, hATR;
double   g_start_equity   = 0;
datetime g_last_reset_day = 0;
int      g_daily_trades   = 0;
datetime g_last_bar_time  = 0;
const int MAGIC_NUMBER    = 777999;
double   g_last_trade_profit = 0; // Ganancia/Pérdida del último trade cerrado
int      g_consecutive_losses = 0; // Contador de pérdidas consecutivas

double g_lot_size;
int    g_max_spread;
int    g_distancia_puntos;
int    g_be_trigger;
int    g_adx_threshold;
double g_atr_multiplier;
int    g_rsi_overbought;
int    g_rsi_oversold;
bool   g_gold_mode_active = false;
double g_momentum_spike_multiplier;
double g_risk_reward;
double g_min_sl_price = 0; // SL minimo en precio (0 = solo ATR). Para ORO = $15.00

// [OPT #3] Cache de Indicadores
double g_ma_h1_cache      = 0;
double g_ma_htf_cache     = 0;
double g_ma_htf_p2_cache  = 0;
double g_rsi_cache        = 0;
double g_adx_cache        = 0;
double g_atr_cache        = 0;
double g_atr_0_cache      = 0;

// [V12.7] Cache de rango H1 (evita llamadas repetitivas a iHighest/iLowest)
double g_h1_high_cache    = 0;
double g_h1_low_cache     = 0;

// [FIX #2]
ulong g_partial_closed_tickets[];

// [OPT #4]
datetime g_last_trade_close = 0;

//+------------------------------------------------------------------+
// [V12.99] Helper de Normalización de Volumen y Microlotes
double NormalizeLotVolume(double lot) {
   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(min_vol <= 0) min_vol = 0.01;
   if(max_vol <= 0) max_vol = 100.0;
   if(step_vol <= 0) step_vol = 0.01;

   int lot_digits = 2;
   if(step_vol >= 1.0) lot_digits = 0;
   else if(step_vol >= 0.1) lot_digits = 1;
   else if(step_vol >= 0.01) lot_digits = 2;
   else lot_digits = 3;

   double normalized = MathFloor((lot - min_vol) / step_vol + 0.000001) * step_vol + min_vol;
   normalized = MathMax(min_vol, MathMin(max_vol, normalized));
   return NormalizeDouble(normalized, lot_digits);
}

//+------------------------------------------------------------------+
void AutoTuneAssets() {
   g_lot_size = InpLotSize; g_max_spread = InpMaxSpread;
   g_distancia_puntos = InpDistanciaPuntos; g_be_trigger = InpBE_Trigger;
   g_adx_threshold = InpADXThreshold; g_atr_multiplier = InpATRMultiplier;
   g_rsi_overbought = InpRSIOverbought; g_rsi_oversold = InpRSIOversold;
   g_gold_mode_active = false; g_momentum_spike_multiplier = 3.0; g_risk_reward = InpRiskReward;
   g_min_sl_price = 0; // Default: sin minimo para Forex
   if(InpAutoGoldSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"XAU") >= 0 || StringFind(symbol,"GOLD") >= 0) {
         g_gold_mode_active = true;
         g_lot_size = (!InpUseAutoRiskPercent && InpLotSize > 0.01) ? InpLotSize : 0.01;
         g_max_spread = 75; g_distancia_puntos = 600; g_be_trigger = 600; // [V12.9] BE Trigger equilibrado en puntos
         g_adx_threshold = 20; g_atr_multiplier = 2.0; g_risk_reward = 3.0;
         g_rsi_oversold = 38; g_rsi_overbought = 62;
         g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = (InpGoldMinSL > 0) ? InpGoldMinSL : 6.0; // [V12.99] SL optimizado $6.00 (600 pts) en M5
         PrintFormat("AURUM GOLD MODE V12.99 ACTIVE: ATR x2.0, R:R 1:3, Multi-Phase Trailing (BE 0.6R), SL min $%.2f", g_min_sl_price);
      }
   }
   if(InpAutoForexSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"EURUSD") >= 0) {
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
      }
   }
   if(InpAutoCryptoSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"BTC") >= 0 || StringFind(symbol,"BITCOIN") >= 0) {
         g_max_spread = 6000; g_distancia_puntos = 3000; g_be_trigger = 2500;
         g_adx_threshold = 15; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 100.0; // Minimo $100 USD en BTC
         Print("AURUM CRYPTO V12.97 ACTIVE: BTC (Spread Max: 6000, Dist: 3000, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: $100)");
      } else if(StringFind(symbol,"ETH") >= 0 || StringFind(symbol,"ETHEREUM") >= 0) {
         g_max_spread = 3000; g_distancia_puntos = 1500; g_be_trigger = 1200;
         g_adx_threshold = 15; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 10.0; // Minimo $10 USD en ETH
         Print("AURUM CRYPTO V12.97 ACTIVE: ETH (Spread Max: 3000, Dist: 1500, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: $10)");
      }
   }
   if(InpAutoIndexSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"US30") >= 0 || StringFind(symbol,"DJI") >= 0 || StringFind(symbol,"WS30") >= 0 || StringFind(symbol,"WALLSTREET") >= 0) {
         g_max_spread = 1000; g_distancia_puntos = 800; g_be_trigger = 600;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 50.0; // Minimo 50 pts en US30
         Print("AURUM INDEX V12.97 ACTIVE: US30 (Spread Max: 1000, Dist: 800, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: 50pts)");
      } else if(StringFind(symbol,"NAS100") >= 0 || StringFind(symbol,"USTEC") >= 0 || StringFind(symbol,"NDX") >= 0 || StringFind(symbol,"NQ") >= 0) {
         g_max_spread = 800; g_distancia_puntos = 600; g_be_trigger = 500;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 30.0; // Minimo 30 pts en NAS100
         Print("AURUM INDEX V12.97 ACTIVE: NAS100 (Spread Max: 800, Dist: 600, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: 30pts)");
      } else if(StringFind(symbol,"US500") >= 0 || StringFind(symbol,"SPX") >= 0 || StringFind(symbol,"ES") >= 0) {
         g_max_spread = 500; g_distancia_puntos = 400; g_be_trigger = 300;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 5.0; // Minimo 5 pts en US500
         Print("AURUM INDEX V12.97 ACTIVE: US500 (Spread Max: 500, Dist: 400, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: 5pts)");
      } else if(StringFind(symbol,"GER") >= 0 || StringFind(symbol,"DAX") >= 0) {
         g_max_spread = 800; g_distancia_puntos = 600; g_be_trigger = 500;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 25.0; // Minimo 25 pts en DAX
         Print("AURUM INDEX V12.97 ACTIVE: DAX/GER40 (Spread Max: 800, Dist: 600, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: 25pts)");
      }
   }
   g_lot_size = NormalizeLotVolume(g_lot_size);
}

// [FIX #7]
void RecoverDailyTradeCount() {
   g_daily_trades = 0;
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   if(today_start == 0) return;
   if(!HistorySelect(today_start, TimeCurrent())) return;
   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++) {
      ulong tk = HistoryDealGetTicket(i);
      if(tk <= 0) continue;
      if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
      if(HistoryDealGetInteger(tk, DEAL_MAGIC) != MAGIC_NUMBER) continue;
      if(HistoryDealGetInteger(tk, DEAL_ENTRY) == DEAL_ENTRY_IN) g_daily_trades++;
   }
   if(g_daily_trades > 0) Print("[RECOVERY V12.3] Trades del dia: ", g_daily_trades);
}

// [OPT #3]
void UpdateATRCache() {
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(hATR, 0, 0, 2, b) > 0) { g_atr_cache = b[1]; g_atr_0_cache = b[0]; }
}
void UpdateIndicatorCache() {
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(hMA,     0, 0, 1, b) > 0) g_ma_h1_cache = b[0];
   if(CopyBuffer(hMA_HTF, 0, 0, 3, b) > 0) { g_ma_htf_cache = b[0]; g_ma_htf_p2_cache = b[2]; }
   if(CopyBuffer(hRSI,    0, 0, 2, b) > 0) g_rsi_cache = b[1];
   if(CopyBuffer(hADX,    0, 0, 2, b) > 0) g_adx_cache = b[1];
   UpdateATRCache();
   // [V12.7] Cache de rango H1
   g_h1_high_cache = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   g_h1_low_cache  = iLow(_Symbol,  PERIOD_H1, iLowest(_Symbol,  PERIOD_H1, MODE_LOW,  20, 1));
}

// [FIX #2]
bool IsPartialAlreadyClosed(ulong ticket) {
   int sz = ArraySize(g_partial_closed_tickets);
   for(int i = 0; i < sz; i++) if(g_partial_closed_tickets[i] == ticket) return true;
   return false;
}
void MarkPartialClosed(ulong ticket) {
   int sz = ArraySize(g_partial_closed_tickets);
   ArrayResize(g_partial_closed_tickets, sz + 1);
   g_partial_closed_tickets[sz] = ticket;
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   AutoTuneAssets();
   g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
   g_last_bar_time = iTime(_Symbol, _Period, 0);
   hMA     = iMA(_Symbol, PERIOD_H1,       InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hMA_HTF = iMA(_Symbol, InpHTFTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   hADX    = iADX(_Symbol, _Period, 14);
   hATR    = iATR(_Symbol, _Period, 14);
   if(hMA == INVALID_HANDLE || hMA_HTF == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE || hATR == INVALID_HANDLE)
      return(INIT_FAILED);
   UpdateIndicatorCache();
   RecoverDailyTradeCount();
   datetime today_start = iTime(_Symbol, PERIOD_D1, 0);
   if(today_start > 0 && HistorySelect(today_start, TimeCurrent())) {
      int total = HistoryDealsTotal();
      for(int i = total - 1; i >= 0; i--) {
         ulong tk = HistoryDealGetTicket(i);
         if(tk <= 0) continue;
         if(HistoryDealGetString(tk, DEAL_SYMBOL) != _Symbol) continue;
         long et = HistoryDealGetInteger(tk, DEAL_ENTRY);
         if(et == DEAL_ENTRY_OUT || et == DEAL_ENTRY_INOUT) {
            datetime t = (datetime)HistoryDealGetInteger(tk, DEAL_TIME);
            if(t > g_last_trade_close) {
               g_last_trade_close = t;
               g_last_trade_profit = HistoryDealGetDouble(tk, DEAL_PROFIT);
            }
         }
      }
   }
   long sym_trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(sym_trade_mode == SYMBOL_TRADE_MODE_DISABLED)
      Print("[ALERTA] Simbolo deshabilitado, usa sufijo micro.");
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) Print("[ALERTA] Algo Trading DESACTIVADO en MT5.");
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) Print("[ALERTA] Trading no permitido en propiedades EA.");
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) || !AccountInfoInteger(ACCOUNT_TRADE_EXPERT))
      Print("[ALERTA] Trading automatico deshabilitado por broker.");
   if(_Period >= PERIOD_H1)
      Print("[AVISO TEMPORALIDAD] AurumSniper cargado en ", EnumToString(_Period), ". Para operaciones Sniper de alta precision se recomienda M1 o M5.");
   
   // [V12.99] Diagnóstico de Capital, Contrato y Riesgo por Trade
   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double cur_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double sample_sl_dist = (g_min_sl_price > 0) ? g_min_sl_price : (100 * _Point);
   double one_lot_loss = GetOneLotLoss(sample_sl_dist);
   double calc_loss_min_lot = one_lot_loss * min_vol;
   double risk_pct_min_lot = (cur_eq > 0) ? (calc_loss_min_lot / cur_eq) * 100.0 : 0.0;
   
   bool is_micro_account = (contract <= 10.0 || StringFind(_Symbol, "micro") >= 0 || StringFind(_Symbol, "m") == StringLen(_Symbol)-1);
   string acct_type_str = is_micro_account ? "MICRO" : "ESTANDAR";

   PrintFormat("[DIAGNOSTICO V12.99] Simbolo: %s (%s) | Contrato: %.0f | Lote Min: %.2f | Riesgo SL ($%.2f): $%.2f (%.1f%%) | Balance: $%.2f",
               _Symbol, acct_type_str, contract, min_vol, sample_sl_dist, calc_loss_min_lot, risk_pct_min_lot, cur_eq);
   if(cur_eq > 0 && risk_pct_min_lot > InpMaxAllowedRiskPercent) {
      PrintFormat("[ADVERTENCIA CAPITAL] En cuenta %s, el lote minimo (%.2f) arriesga $%.2f (%.1f%% del capital > Max %.1f%%). Para reducir riesgo a <$1 usar cuenta Micro (%smicro) o pares Forex.",
                  acct_type_str, min_vol, calc_loss_min_lot, risk_pct_min_lot, InpMaxAllowedRiskPercent, _Symbol);
   }

   EventSetTimer(1);
   Print("AURUM V12.99 ULTIMATE Loaded.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(hMA); IndicatorRelease(hMA_HTF);
   IndicatorRelease(hRSI); IndicatorRelease(hADX); IndicatorRelease(hATR);
   EventKillTimer();
   ObjectsDeleteAll(0, "lbl_");
   ObjectsDeleteAll(0, "tp_lvl_");
}

// [OPT #4 & V12.6]
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;
   if(trans.symbol != _Symbol) return;
   if(HistoryDealSelect(trans.deal)) {
      long et = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
      if(et == DEAL_ENTRY_OUT || et == DEAL_ENTRY_INOUT) {
          datetime ct = (datetime)HistoryDealGetInteger(trans.deal, DEAL_TIME);
          if(ct > g_last_trade_close) {
             g_last_trade_close = ct;
             g_last_trade_profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);
             // [V12.7] Tracking de pérdidas consecutivas
             if(g_last_trade_profit < -0.01)
                g_consecutive_losses++;
             else
                g_consecutive_losses = 0;
             // [V12.7] Log de resultado del trade
             double deal_price = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
             double deal_vol   = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
             string deal_sym   = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
             string result_tag = (g_last_trade_profit >= 0) ? "GANANCIA" : "PERDIDA";
             Print("[CIERRE ",result_tag,"] ",deal_sym," Vol:",DoubleToString(deal_vol,2),
                   " @ ",DoubleToString(deal_price,_Digits),
                   " P&L: $",DoubleToString(g_last_trade_profit,2),
                   " Losses seguidos: ",g_consecutive_losses);
          }
      }
   }
}

//+------------------------------------------------------------------+
// [V12.99] Obtener Pérdida Monetaria de 1.0 Lote a la distancia de SL
double GetOneLotLoss(double sl_dist_price) {
   if(sl_dist_price <= 0) return 0.0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double one_lot_loss = 0.0;
   if(OrderCalcProfit(ORDER_TYPE_BUY, _Symbol, 1.0, ask, ask - sl_dist_price, one_lot_loss)) {
      one_lot_loss = MathAbs(one_lot_loss);
   }
   if(one_lot_loss <= 0) {
      double contract  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
      if(contract <= 0) contract = 100.0;
      double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
      double tick_val  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
      if(tick_size > 0 && tick_val > 0) {
         one_lot_loss = (sl_dist_price / tick_size) * tick_val;
      } else {
         one_lot_loss = sl_dist_price * contract;
      }
   }
   return one_lot_loss;
}

//+------------------------------------------------------------------+
// [V12.99] Cálculo de Lotaje y Gestión de Riesgo por Trade con Microlotes
double CalculateLotSize(double sl_dist_price, double &actual_risk_usd, double &actual_risk_pct) {
   actual_risk_usd = 0.0;
   actual_risk_pct = 0.0;
   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(min_vol <= 0) min_vol = 0.01;

   if(!InpUseAutoRiskPercent) {
      double chosen_lot = NormalizeLotVolume(g_lot_size);
      double one_loss = GetOneLotLoss(sl_dist_price);
      actual_risk_usd = one_loss * chosen_lot;
      double eq = AccountInfoDouble(ACCOUNT_EQUITY);
      actual_risk_pct = (eq > 0) ? (actual_risk_usd / eq) * 100.0 : 0.0;
      return chosen_lot;
   }

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0 || sl_dist_price <= 0) return min_vol;

   // [V12.7] Reducir riesgo tras pérdidas consecutivas (anti-cascade)
   double effective_risk = InpRiskPercent;
   if(g_consecutive_losses >= 2) effective_risk *= 0.5;  // 50% del riesgo tras 2 losses
   if(g_consecutive_losses >= 3) effective_risk *= 0.5;  // 25% del riesgo tras 3+ losses
   double risk_amount = equity * (effective_risk / 100.0);

   double one_lot_loss = GetOneLotLoss(sl_dist_price);
   if(one_lot_loss <= 0) return min_vol;

   double min_lot_loss = one_lot_loss * min_vol;
   double min_lot_risk_pct = (min_lot_loss / equity) * 100.0;

   // Si la protección estricta está habilitada y el lote mínimo supera el riesgo máximo permitido:
   if(InpStrictRiskProtection && min_lot_risk_pct > InpMaxAllowedRiskPercent) {
      PrintFormat("[BLOQUEO RIESGO V12.99] Lote min %.2f en %s arriesga $%.2f (%.1f%% > Max %.1f%%). Trade cancelado por seguridad de capital ($%.2f).",
                  min_vol, _Symbol, min_lot_loss, min_lot_risk_pct, InpMaxAllowedRiskPercent, equity);
      return 0.0;
   }

   double raw_lot  = risk_amount / one_lot_loss;
   double final_lot = NormalizeLotVolume(raw_lot);
   actual_risk_usd = one_lot_loss * final_lot;
   actual_risk_pct = (actual_risk_usd / equity) * 100.0;

   // Advertencia educativa si el lote mínimo excede el porcentaje deseado por capital reducido
   if(final_lot == min_vol && min_lot_risk_pct > (effective_risk * 1.5)) {
      static datetime last_risk_warn = 0;
      if(TimeCurrent() - last_risk_warn >= 120) {
         PrintFormat("[AVISO CAPITAL/LOTAJE] %s: Lote min %.2f arriesga $%.2f (%.1f%%). Target: %.1f%% ($%.2f). Para arriesgar menos usa cuenta Micro (%smicro) o pares Forex.",
                     _Symbol, min_vol, actual_risk_usd, actual_risk_pct, effective_risk, risk_amount, _Symbol);
         last_risk_warn = TimeCurrent();
      }
   }

   return final_lot;
}

//+------------------------------------------------------------------+
// [V12.98] Filtro de Horario de Trading con soporte de Killzones CDMX (Londres + NY)
bool IsTradingSession(string &session_reason) {
   session_reason = "";
   MqlDateTime dt_local;
   TimeLocal(dt_local);
   
   bool is_crypto = false;
   string sym = _Symbol; StringToUpper(sym);
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "BITCOIN") >= 0 || StringFind(sym, "ETHEREUM") >= 0) {
      is_crypto = true;
   }

   // [V12.98] Filtro de Sesiones de Alta Liquidez CDMX (Londres + NY: 01:00 a 12:00 CDMX)
   // Bloquea sesión asiática nocturna (20:00 - 00:59) y aperturas dominicales en Forex/Oro/Índices
   if(InpUseHighLiquiditySession && (!is_crypto || !InpSessionFilterForexOnly)) {
      // Bloqueo total en domingos (day 0) para Forex/Metales/Índices (aperturas con spreads erráticos)
      if(dt_local.day_of_week == 0) {
         session_reason = "[Fin de Semana / Domingo Forex Cerrado]";
         return false;
      }
      if(dt_local.hour < InpSessionStartHourCDMX || dt_local.hour >= InpSessionEndHourCDMX) {
         session_reason = StringFormat("[Fuera Killzone CDMX (%02d:00-%02d:00, Actual %02d:%02d)]",
                                       InpSessionStartHourCDMX, InpSessionEndHourCDMX, dt_local.hour, dt_local.min);
         return false;
      }
   }
   
   // [V12.96] Filtro Especial de Viernes en Horario CDMX (01:00 - 11:00 CDMX)
   if(InpUseFridayFilter && dt_local.day_of_week == 5) {
      if(!is_crypto || !InpFridayFilterForexOnly) {
         if(dt_local.hour < InpFridayStartHourCDMX || dt_local.hour >= InpFridayEndHourCDMX) {
            session_reason = StringFormat("[Viernes Cierre CDMX (%02d:00-%02d:00, Actual %02d:%02d)]",
                                          InpFridayStartHourCDMX, InpFridayEndHourCDMX, dt_local.hour, dt_local.min);
            return false;
         }
      }
   }

   if(!InpUseSessionFilter) return true;
   
   MqlDateTime dt; TimeCurrent(dt);
   if(InpStartHour <= InpEndHour) {
      if(dt.hour < InpStartHour || dt.hour >= InpEndHour) {
         session_reason = "[Fuera Sesion Broker]";
         return false;
      }
   } else {
      if(dt.hour < InpStartHour && dt.hour >= InpEndHour) {
         session_reason = "[Fuera Sesion Broker]";
         return false;
      }
   }
   return true;
}

// [OPT #4 & V12.6] Cooldown Inteligente
bool CheckCooldownPass() {
   if(InpCooldownBars <= 0) return true;
   if(g_last_trade_close == 0) return true;
   int wait_bars = InpCooldownBars;
   if(InpSmartCooldown && g_last_trade_profit >= 0) {
      wait_bars = 1; // Si cerro en ganancia/BE, solo espera 1 barra de confirmacion
   }
   return (TimeCurrent() - g_last_trade_close >= wait_bars * PeriodSeconds(_Period));
}

//+------------------------------------------------------------------+
// [V12.9] Filtro de Zona de Descuento (Compras baratas) y Premium (Ventas caras)
bool IsInDiscountPremiumZone(string type) {
   if(!InpUseDiscountPremiumFilter) return true;
   // [V12.7] Usar cache de rango H1
   double h1_high = g_h1_high_cache;
   double h1_low  = g_h1_low_cache;
   double range = h1_high - h1_low;
   if(range <= 0) return true;
   
   double cur_price = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   // [V12.9] Equilibrio dinámico adaptativo con ADX
   double eq_pct = InpEquilibriumPercent; // Base: 50%
   double adx = g_adx_cache;
   if(adx >= 25.0) {
      // En tendencia moderada (ADX>=25): flexibilizar 10%
      if(type == "BUY")  eq_pct = MathMin(eq_pct + 10.0, 60.0);
      if(type == "SELL") eq_pct = MathMax(eq_pct - 10.0, 40.0);
   }
   if(adx >= 35.0) {
      // En tendencia fuerte/parabólica (ADX>=35): flexibilizar 15% para compras/ventas de continuación
      if(type == "BUY")  eq_pct = MathMin(eq_pct + 5.0, 65.0);
      if(type == "SELL") eq_pct = MathMax(eq_pct - 5.0, 35.0);
   }
   double eq_price = h1_low + (range * (eq_pct / 100.0));
   
   if(type == "BUY")  return (cur_price <= eq_price); // Solo comprar en zona Descuento
   if(type == "SELL") return (cur_price >= eq_price); // Solo vender en zona Premium
   return true;
}

//+------------------------------------------------------------------+
void DebugSignalMiss(string direction, bool trend, bool in_zone,
                     double rsi, double adx, bool is_spike,
                     bool has_open_trade, bool good_spread,
                     bool daily_limit, double eff_rsi_oversold,
                     double eff_rsi_overbought, bool cooldown_ok, bool session_ok,
                     bool discount_ok, bool usd_corr_blocked, string conflict_sym,
                     string session_reason) {
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
      if(reason != "") Print("[X-RAY VENTA OMITIDA] ", _Symbol, ": ", reason);
   }
}

//+------------------------------------------------------------------+
//| Main Engine V12.96                                               |
//+------------------------------------------------------------------+
void OnTick() {
   bool new_bar = IsNewBar();
   if(new_bar) UpdateIndicatorCache();
   else        UpdateATRCache();
   CheckAndResetDaily();
   if(CheckDailyDrawdown()) { Comment("\nMAX DRAWDOWN DIARIO ALCANZADO."); return; }
   else Comment("");
   GestionarPosicionesPro();
   if(!new_bar) return;

   double ma_h1     = g_ma_h1_cache;
   double ma_htf    = g_ma_htf_cache;
   double ma_htf_p2 = g_ma_htf_p2_cache;
   double rsi       = g_rsi_cache;
   double adx       = g_adx_cache;
   double atr       = g_atr_cache;
   double cur_price = iClose(_Symbol, _Period, 0);

   bool trend_bull = (cur_price > ma_h1);
   bool trend_bear = (cur_price < ma_h1);

   if(InpUseMTFFilter) {
      bool htf_bull = (cur_price > ma_htf);
      bool htf_bear = (cur_price < ma_htf);
      if(InpUseEMAInclinacion) {
         htf_bull = htf_bull && (ma_htf > ma_htf_p2);
         htf_bear = htf_bear && (ma_htf < ma_htf_p2);
      }
      trend_bull = trend_bull && htf_bull;
      trend_bear = trend_bear && htf_bear;
   }

   bool in_zone_buy  = IsInZone("BUY",  ma_h1, adx, atr);
   bool in_zone_sell = IsInZone("SELL", ma_h1, adx, atr);
   bool is_trap_buy  = InpUseLiquidityTraps ? CheckLiquidityTrap("BUY")  : false;
   bool is_trap_sell = InpUseLiquidityTraps ? CheckLiquidityTrap("SELL") : false;

   bool discount_buy_ok  = IsInDiscountPremiumZone("BUY");
   bool discount_sell_ok = IsInDiscountPremiumZone("SELL");

   bool buy_zone_ok  = (in_zone_buy  || is_trap_buy)  && discount_buy_ok;
   bool sell_zone_ok = (in_zone_sell || is_trap_sell) && discount_sell_ok;

   // [V12.7] RSI Adaptativo: En tendencia fuerte, relajar umbrales progresivamente
   double eff_rsi_oversold   = g_rsi_oversold;    // Base: 38 (Gold)
   double eff_rsi_overbought = g_rsi_overbought;  // Base: 62 (Gold)
   if(adx >= 25.0) {
      // Tendencia moderada: relajar 4 pts (42/58 para Gold)
      eff_rsi_oversold   += 4.0;
      eff_rsi_overbought -= 4.0;
   }
   if(adx >= 35.0) {
      // Tendencia fuerte: relajar 3 pts más (45/55 para Gold)
      eff_rsi_oversold   += 3.0;
      eff_rsi_overbought -= 3.0;
   }

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool has_open_trade      = IsPositionOpenOnSymbol();
   bool good_spread         = CheckSpread();
   bool daily_limit_reached = (g_daily_trades >= InpMaxDailyTrades);
   bool cooldown_ok         = CheckCooldownPass();
   
   string session_reason = "";
   bool session_ok          = IsTradingSession(session_reason);

   // [V12.95] Verificación de Exposición Duplicada al USD en Portafolio
   string conflict_sym_buy = "";
   bool usd_corr_blocked_buy = HasUnprotectedCorrelatedUSDPosition(_Symbol, "BUY", conflict_sym_buy);
   string conflict_sym_sell = "";
   bool usd_corr_blocked_sell = HasUnprotectedCorrelatedUSDPosition(_Symbol, "SELL", conflict_sym_sell);

   if(daily_limit_reached)
      Comment("\nMETA DIARIA ("+IntegerToString(g_daily_trades)+"/"+IntegerToString(InpMaxDailyTrades)+"). HASTA MANANA.");

   bool is_spike_buy  = buy_zone_ok  ? IsMomentumSpike("BUY")  : false;
   bool is_spike_sell = sell_zone_ok ? IsMomentumSpike("SELL") : false;

   DebugSignalMiss("BUY",  trend_bull, buy_zone_ok,  rsi, adx, is_spike_buy,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_buy_ok,
                   usd_corr_blocked_buy, conflict_sym_buy, session_reason);
   DebugSignalMiss("SELL", trend_bear, sell_zone_ok, rsi, adx, is_spike_sell,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_sell_ok,
                   usd_corr_blocked_sell, conflict_sym_sell, session_reason);

   if(has_open_trade || !good_spread || daily_limit_reached || !cooldown_ok || !session_ok) return;

   long sym_trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(sym_trade_mode == SYMBOL_TRADE_MODE_DISABLED) {
      static datetime last_sym_warn = 0;
      if(TimeCurrent() - last_sym_warn >= 300) {
         Print("[SIMBOLO BLOQUEADO] '",_Symbol,"' solo lectura. Usa sufijo micro.");
         last_sym_warn = TimeCurrent();
      }
      return;
   }
   bool algo_allowed = TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                       MQLInfoInteger(MQL_TRADE_ALLOWED) &&
                       AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) &&
                       AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   if(!algo_allowed) {
      static datetime last_warn = 0;
      if(TimeCurrent() - last_warn >= 300) {
         Print("[TRADING BLOQUEADO] Algo Trading desactivado (F7 / MT5).");
         last_warn = TimeCurrent();
      }
      return;
   }

   if(trend_bull && buy_zone_ok && rsi < eff_rsi_oversold && adx > g_adx_threshold && !is_spike_buy && !usd_corr_blocked_buy) {
      // [V12.4] SL = maximo entre ATR dinamico y minimo de activo (evita SL demasiado justos)
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(ask - sl_dist, _Digits);
      double tp = NormalizeDouble(ask + tp_dist, _Digits);
      CheckStops(sl, tp, true);
      double actual_risk_usd = 0, actual_risk_pct = 0;
      double trade_lot = CalculateLotSize(sl_dist, actual_risk_usd, actual_risk_pct);
      if(trade_lot > 0) {
         if(trade.Buy(trade_lot, _Symbol, ask, sl, tp, "Aurum V12 Sniper")) {
            g_daily_trades++;
            PrintFormat("[COMPRA] Lote:%.2f SL:%.2f TP:%.2f | Riesgo: -$%.2f (%.1f%%) | SL_dist:$%.2f (%.0f pts) | ATR:%.2f | R:R 1:%.1f%s",
                        trade_lot, sl, tp, actual_risk_usd, actual_risk_pct, sl_dist, sl_dist/_Point, atr, g_risk_reward,
                        (g_consecutive_losses >= 2 ? " [ANTI-CASCADE]": ""));
         }
      }
   }
   if(trend_bear && sell_zone_ok && rsi > eff_rsi_overbought && adx > g_adx_threshold && !is_spike_sell && !usd_corr_blocked_sell) {
      // [V12.4] SL = maximo entre ATR dinamico y minimo de activo
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(bid + sl_dist, _Digits);
      double tp = NormalizeDouble(bid - tp_dist, _Digits);
      CheckStops(sl, tp, false);
      double actual_risk_usd = 0, actual_risk_pct = 0;
      double trade_lot = CalculateLotSize(sl_dist, actual_risk_usd, actual_risk_pct);
      if(trade_lot > 0) {
         if(trade.Sell(trade_lot, _Symbol, bid, sl, tp, "Aurum V12 Sniper")) {
            g_daily_trades++;
            PrintFormat("[VENTA] Lote:%.2f SL:%.2f TP:%.2f | Riesgo: -$%.2f (%.1f%%) | SL_dist:$%.2f (%.0f pts) | ATR:%.2f | R:R 1:%.1f%s",
                        trade_lot, sl, tp, actual_risk_usd, actual_risk_pct, sl_dist, sl_dist/_Point, atr, g_risk_reward,
                        (g_consecutive_losses >= 2 ? " [ANTI-CASCADE]": ""));
         }
      }
   }
}

void OnTimer() { UpdateDashboard(); }

//+------------------------------------------------------------------+
// [OPT #5] IsInZone recibe atr_val como parametro
bool IsInZone(string type, double ma_ref, double adx_val, double atr_val) {
   double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double h1_low  = iLow(_Symbol,  PERIOD_H1, iLowest(_Symbol,  PERIOD_H1, MODE_LOW,  20, 1));
   double base_dist    = g_distancia_puntos * _Point;
   double adx_mult     = (adx_val >= 30.0) ? 2.0 : 1.0;
   double dynamic_dist = MathMax(base_dist, atr_val * 2.5) * adx_mult;
   double price = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK)
                                  : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(type == "BUY")
      return (MathAbs(price - h1_low) <= dynamic_dist || MathAbs(price - ma_ref) <= dynamic_dist);
   if(type == "SELL")
      return (MathAbs(price - h1_high) <= dynamic_dist || MathAbs(price - ma_ref) <= dynamic_dist);
   return false;
}

//+------------------------------------------------------------------+
// [SMART TRAP] Deteccion de Falsa Ruptura / Barrido de Liquidez
bool CheckLiquidityTrap(string direction) {
   double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double h1_low  = iLow(_Symbol,  PERIOD_H1, iLowest(_Symbol,  PERIOD_H1, MODE_LOW,  20, 1));
   double low1   = iLow(_Symbol,   _Period, 1);
   double high1  = iHigh(_Symbol,  _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   if(direction == "BUY") {
      return (low1 < h1_low && close1 > h1_low);
   }
   if(direction == "SELL") {
      return (high1 > h1_high && close1 < h1_high);
   }
   return false;
}

//+------------------------------------------------------------------+
// [V12.99] Distancia SL/TP para Trades Manuales en Cualquier Activo
double GetManualAssetSLDist(string symbol, double &tp_ratio) {
   tp_ratio = InpRiskReward;
   string sym = symbol; StringToUpper(sym);
   double pt = SymbolInfoDouble(symbol, SYMBOL_POINT);
   if(pt <= 0) pt = 0.0001;

   // Oro / Metales
   if(StringFind(sym, "XAU") >= 0 || StringFind(sym, "GOLD") >= 0) {
      return (InpGoldMinSL > 0) ? InpGoldMinSL : 6.0;
   }
   // Forex
   if(StringFind(sym, "EURUSD") >= 0) return 250 * pt; // 25 pips
   if(StringFind(sym, "USDJPY") >= 0) return 300 * pt; // 30 pips
   if(StringFind(sym, "GBPUSD") >= 0) return 350 * pt; // 35 pips
   // Cripto
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "BITCOIN") >= 0) return 300.0;
   if(StringFind(sym, "ETH") >= 0 || StringFind(sym, "ETHEREUM") >= 0) return 25.0;
   // Indices
   if(StringFind(sym, "US30") >= 0 || StringFind(sym, "WS30") >= 0) return 100.0;
   if(StringFind(sym, "NAS100") >= 0 || StringFind(sym, "USTEC") >= 0) return 50.0;
   
   return 300 * pt;
}

//+------------------------------------------------------------------+
void GestionarPosicionesPro() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_magic != MAGIC_NUMBER && !InpManageManualTrades) continue;
      
      string pos_sym = PositionGetString(POSITION_SYMBOL);
      bool is_current_symbol = (pos_sym == _Symbol);

      // [V12.99] Protección Multidivisa de Trades Manuales:
      // Si el trade manual se abrió en otro activo (ej. USDJPY) mientras el bot está en GOLD
      if(!is_current_symbol) {
         if(pos_magic == MAGIC_NUMBER) continue; // Posiciones automáticas de otro chart las maneja su instancia
         if(InpAutoSetManualSLTP) {
            double pos_sl = PositionGetDouble(POSITION_SL);
            double pos_tp = PositionGetDouble(POSITION_TP);
            if(pos_sl == 0 || pos_tp == 0) {
               double pos_entry = PositionGetDouble(POSITION_PRICE_OPEN);
               long pos_type = PositionGetInteger(POSITION_TYPE);
               int pos_digits = (int)SymbolInfoInteger(pos_sym, SYMBOL_DIGITS);
               double pos_point = SymbolInfoDouble(pos_sym, SYMBOL_POINT);
               double tp_mult = 3.0;
               double sl_dist_manual = GetManualAssetSLDist(pos_sym, tp_mult);
               double tp_dist_manual = sl_dist_manual * tp_mult;

               double new_sl = pos_sl;
               double new_tp = pos_tp;
               if(pos_type == POSITION_TYPE_BUY) {
                  if(new_sl == 0) new_sl = NormalizeDouble(pos_entry - sl_dist_manual, pos_digits);
                  if(new_tp == 0) new_tp = NormalizeDouble(pos_entry + tp_dist_manual, pos_digits);
               } else if(pos_type == POSITION_TYPE_SELL) {
                  if(new_sl == 0) new_sl = NormalizeDouble(pos_entry + sl_dist_manual, pos_digits);
                  if(new_tp == 0) new_tp = NormalizeDouble(pos_entry - tp_dist_manual, pos_digits);
               }
               if(trade.PositionModify(ticket, new_sl, new_tp)) {
                  PrintFormat("[AUTO-SL/TP MULTIDIVISA] Ticket %d %s | SL=%s TP=%s", ticket, pos_sym, DoubleToString(new_sl, pos_digits), DoubleToString(new_tp, pos_digits));
               }
            }
         }
         continue;
      }

      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      double vol       = PositionGetDouble(POSITION_VOLUME);
      long   type      = PositionGetInteger(POSITION_TYPE);
      double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);

      double profit_price = (type == POSITION_TYPE_BUY) ? (cur_price - entry) : (entry - cur_price);
      double profit_puntos = profit_price / _Point;

      // Auto SL/TP si se abrió manual sin ellos en el símbolo actual
      if(InpAutoSetManualSLTP && (sl == 0 || tp == 0)) {
         double atr_val = (hATR != INVALID_HANDLE && g_atr_0_cache > 0) ? g_atr_0_cache : 0;
         double sl_dist = (atr_val > 0) ? (atr_val * g_atr_multiplier) : (g_distancia_puntos * _Point * 2.0);
         if(g_min_sl_price > 0 && sl_dist < g_min_sl_price) sl_dist = g_min_sl_price;
         double tp_dist = sl_dist * g_risk_reward;
         double new_sl = sl; double new_tp = tp;
         if(type == POSITION_TYPE_BUY) {
            if(new_sl == 0) new_sl = NormalizeDouble(entry - sl_dist, _Digits);
            if(new_tp == 0) new_tp = NormalizeDouble(entry + tp_dist, _Digits);
            CheckStops(new_sl, new_tp, true);
         } else if(type == POSITION_TYPE_SELL) {
            if(new_sl == 0) new_sl = NormalizeDouble(entry + sl_dist, _Digits);
            if(new_tp == 0) new_tp = NormalizeDouble(entry - tp_dist, _Digits);
            CheckStops(new_sl, new_tp, false);
         }
         if(ticket > 0 && PositionSelectByTicket(ticket)) {
            if(trade.PositionModify(ticket, new_sl, new_tp)) {
               sl = new_sl; tp = new_tp;
               Print("[AUTO-SL/TP Ticket ",ticket,"] SL=",DoubleToString(new_sl,_Digits)," TP=",DoubleToString(new_tp,_Digits));
            }
         }
      }

      // Distancia base 1R para cálculos
      double atr_val_now = (hATR != INVALID_HANDLE && g_atr_0_cache > 0) ? g_atr_0_cache : 0;
      double r_dist = (atr_val_now > 0) ? (atr_val_now * g_atr_multiplier) : (g_distancia_puntos * _Point * 2.0);
      if(g_min_sl_price > 0 && r_dist < g_min_sl_price) r_dist = g_min_sl_price;
      double profit_R = (r_dist > 0) ? (profit_price / r_dist) : 0;

      double lock_dist = InpBE_LockPips * _Point;
      double effective_be_trigger = (double)g_be_trigger;
      if(InpUseATRBreakEven && atr_val_now > 0) {
         double atr_be_pts = (atr_val_now * InpBE_ATR_Mult) / _Point;
         effective_be_trigger = MathMax(atr_be_pts, (double)InpBE_LockPips * 2.0);
      }

      // ================================================================
      // NUEVA GESTIÓN ESCALONADA POR FASES (V12.5)
      // ================================================================
      if(InpUseStepTrailing) {
         double target_sl = 0;
         string phase_name = "";

         // FASE 3: TP3 Alcanzado (Cierre Total o Runner)
         if(profit_R >= InpStep3_TriggerR) {
            // [V12.97] Si InpCloseOnTP3 está activo, cerrar 100% de la posición en TP3
            if(InpCloseOnTP3) {
               if(ticket > 0 && PositionSelectByTicket(ticket)) {
                  if(trade.PositionClose(ticket)) {
                     Print("[CIERRE TOTAL TP3] Ticket ",ticket," ",_Symbol," Profit: ",DoubleToString(profit_R,2),"R alcanzado. Posición 100% cerrada con éxito.");
                     continue;
                  }
               }
            }
            double locked_dist = InpStep3_LockR * r_dist;
            if(type == POSITION_TYPE_BUY) {
               target_sl = entry + locked_dist;
               if(InpStepRunnerAbove3R) {
                  double runner_sl = cur_price - r_dist; // 1R de holgura
                  if(runner_sl > target_sl) target_sl = runner_sl;
               }
            } else {
               target_sl = entry - locked_dist;
               if(InpStepRunnerAbove3R) {
                  double runner_sl = cur_price + r_dist; // 1R de holgura
                  if(runner_sl < target_sl) target_sl = runner_sl;
               }
            }
            phase_name = "FASE 3 (3R+ -> SL a +2R / Runner)";
         }
         // FASE 2: 2R Alcanzado (Bloquea +1R firme)
         else if(profit_R >= InpStep2_TriggerR) {
            double locked_dist = InpStep2_LockR * r_dist;
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + locked_dist) : (entry - locked_dist);
            phase_name = "FASE 2 (2R -> SL a +1R Asegurado)";
         }
         // FASE 1: Trigger BE Alcanzado (SL a Break-Even + lock pips)
         else if(profit_R >= InpStep1_TriggerR) {
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + lock_dist) : (entry - lock_dist);
            phase_name = StringFormat("FASE 1 (%.1fR/BE -> SL a Entrada Protegida)", InpStep1_TriggerR);

            // Cierre parcial en Fase 1 si está habilitado
            if(InpUsePartials && pos_magic == MAGIC_NUMBER && !IsPartialAlreadyClosed(ticket)) {
               double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
               double half_vol = NormalizeDouble(vol / 2.0, 2);
               double partial  = (step_vol > 0) ? MathFloor(half_vol / step_vol) * step_vol : half_vol;
               if(partial >= min_vol && (vol - partial) >= min_vol) {
                  if(ticket > 0 && PositionSelectByTicket(ticket)) {
                     if(trade.PositionClosePartial(ticket, partial)) {
                        MarkPartialClosed(ticket);
                        Print("[PARCIAL Ticket ",ticket,"] Vol:",DoubleToString(partial,2));
                     }
                  }
               } else {
                  MarkPartialClosed(ticket);
               }
            }
         }

         if(target_sl > 0) {
            target_sl = NormalizeDouble(target_sl, _Digits);
            bool need_modify = false;
            if(type == POSITION_TYPE_BUY  && (sl == 0 || target_sl > sl + (2 * _Point))) need_modify = true;
            if(type == POSITION_TYPE_SELL && (sl == 0 || target_sl < sl - (2 * _Point))) need_modify = true;

            if(need_modify && ticket > 0 && PositionSelectByTicket(ticket)) {
               double modify_tp = tp;
               // Si no cerramos en TP3 y está habilitado el Runner, dejamos correr sin TP
               if(!InpCloseOnTP3 && InpStepRunnerAbove3R && profit_R >= InpStep3_TriggerR && tp > 0) modify_tp = 0;
               // [V12.97] Si InpCloseOnTP3 está activo, asegurar que el TP esté colocado a nivel TP3
               else if(InpCloseOnTP3 && modify_tp == 0) {
                  double tp3_price = (type == POSITION_TYPE_BUY) ? (entry + InpStep3_TriggerR * r_dist) : (entry - InpStep3_TriggerR * r_dist);
                  modify_tp = NormalizeDouble(tp3_price, _Digits);
               }
               // [V12.7] Validar stops antes de modificar (evita "Invalid stops")
               CheckStops(target_sl, modify_tp, (type == POSITION_TYPE_BUY));
               // [V12.7] Verificar que el SL no empeoró tras CheckStops
               if(type == POSITION_TYPE_BUY  && target_sl < sl && sl > 0) { /* skip */ }
               else if(type == POSITION_TYPE_SELL && target_sl > sl && sl > 0) { /* skip */ }
               else if(trade.PositionModify(ticket, target_sl, modify_tp)) {
                  // [V12.7] Throttle: solo logear si SL cambió significativamente (>10 puntos)
                  static double last_logged_sl = 0;
                  static ulong  last_logged_tk = 0;
                  if(ticket != last_logged_tk || MathAbs(target_sl - last_logged_sl) >= 10.0 * _Point) {
                     Print("[",phase_name," Ticket ",ticket,"] SL->",DoubleToString(target_sl,_Digits)," (Profit: ",DoubleToString(profit_R,2),"R)");
                     last_logged_sl = target_sl;
                     last_logged_tk = ticket;
                  }
               }
            }
         }
      }
      // ================================================================
      // GESTIÓN CLÁSICA / CONTINUA (Si InpUseStepTrailing = false)
      // ================================================================
      else {
         if(profit_puntos >= effective_be_trigger) {
            double target_sl = (type == POSITION_TYPE_BUY) ? (entry + lock_dist) : (entry - lock_dist);
            target_sl = NormalizeDouble(target_sl, _Digits);
            bool is_risky = (type == POSITION_TYPE_BUY) ? (sl < target_sl) : (sl == 0 || sl > target_sl);
            if(is_risky) {
               if(InpUsePartials && pos_magic == MAGIC_NUMBER && !IsPartialAlreadyClosed(ticket)) {
                  double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                  double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                  double half_vol = NormalizeDouble(vol / 2.0, 2);
                  double partial  = (step_vol > 0) ? MathFloor(half_vol / step_vol) * step_vol : half_vol;
                  if(partial >= min_vol && (vol - partial) >= min_vol) {
                     if(ticket > 0 && PositionSelectByTicket(ticket)) {
                        if(trade.PositionClosePartial(ticket, partial)) {
                           MarkPartialClosed(ticket);
                           Print("[PARCIAL Ticket ",ticket,"] Vol:",DoubleToString(partial,2));
                        }
                     }
                  } else {
                     MarkPartialClosed(ticket);
                  }
               }
               if(ticket > 0 && PositionSelectByTicket(ticket)) {
                  trade.PositionModify(ticket, target_sl, tp);
                  Print("[COBERTURA BE Ticket ",ticket,"] SL->",DoubleToString(target_sl,_Digits));
               }
            }
         }

         if(InpUseTrailingStop && profit_puntos > (effective_be_trigger + InpTrailingStep)) {
            double trail_dist = (InpUseATRTrailing && atr_val_now > 0) ? (atr_val_now * InpTrailingATRMult) : (effective_be_trigger * _Point);
            if(type == POSITION_TYPE_BUY) {
               double new_sl = NormalizeDouble(cur_price - trail_dist, _Digits);
               if(new_sl > sl + (InpTrailingStep * _Point)) {
                  if(ticket > 0 && PositionSelectByTicket(ticket)) {
                     trade.PositionModify(ticket, new_sl, tp);
                     Print("[TRAILING BUY ",ticket,"] SL->",DoubleToString(new_sl,_Digits));
                  }
               }
            } else if(type == POSITION_TYPE_SELL) {
               double new_sl = NormalizeDouble(cur_price + trail_dist, _Digits);
               if(sl == 0 || new_sl < sl - (InpTrailingStep * _Point)) {
                  if(ticket > 0 && PositionSelectByTicket(ticket)) {
                     trade.PositionModify(ticket, new_sl, tp);
                     Print("[TRAILING SELL ",ticket,"] SL->",DoubleToString(new_sl,_Digits));
                  }
               }
            }
         }
      }
   }
}

void CheckAndResetDaily() {
   if(g_start_equity <= 0) {
      g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      return;
   }
   if(!InpAutoDailyReset) return;
   if(iTime(_Symbol, PERIOD_D1, 0) > g_last_reset_day) {
      g_start_equity   = AccountInfoDouble(ACCOUNT_EQUITY);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      g_daily_trades   = 0;
      g_last_trade_close = 0;
      g_consecutive_losses = 0; // [V12.7] Reset cascading losses
      ArrayResize(g_partial_closed_tickets, 0);
      Print("[NUEVO DIA] Balance, Trades y Parciales Reseteados.");
   }
}

bool CheckDailyDrawdown() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   return ((g_start_equity - equity) >= g_start_equity * (InpMaxDailyLoss / 100.0));
}

bool CheckSpread() { return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= g_max_spread); }

bool IsNewBar() {
   datetime cur_bar = iTime(_Symbol, _Period, 0);
   if(cur_bar == 0) return false;
   if(g_last_bar_time == 0) {
      g_last_bar_time = cur_bar;
      return false; // Primera barra tras arranque/cambio: espera al cierre de la vela
   }
   if(g_last_bar_time == cur_bar) return false;
   g_last_bar_time = cur_bar;
   return true;
}

bool IsMomentumSpike(string direction) {
   double body_avg = 0;
   for(int i = 5; i <= 14; i++)
      body_avg += MathAbs(iClose(_Symbol,_Period,i) - iOpen(_Symbol,_Period,i));
   if(body_avg == 0) return false;
   body_avg /= 10.0;
   double open2 = iOpen(_Symbol,_Period,2); double close2 = iClose(_Symbol,_Period,2);
   double candle_body = MathAbs(close2 - open2);
   double atr_min_threshold = (g_atr_cache > 0) ? (g_atr_cache * 1.2) : 0;
   if(candle_body > body_avg * g_momentum_spike_multiplier && candle_body > atr_min_threshold) {
      if(direction == "BUY"  && close2 < open2) { Print("[ELEFANTE BAJISTA] Compra cancelada."); return true; }
      if(direction == "SELL" && close2 > open2) { Print("[ELEFANTE ALCISTA] Venta cancelada."); return true; }
   }
   return false;
}

double GetBufferVal(int h, int idx) {
   double b[]; ArraySetAsSeries(b, true);
   if(CopyBuffer(h, 0, idx, 1, b) > 0) return b[0];
   return 0;
}

void CheckStops(double &sl, double &tp, bool isBuy) {
   long stops_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   long spread      = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   double min_dist  = (double)(stops_level + spread + 10) * _Point;
   if(min_dist < 20 * _Point) min_dist = 20 * _Point;
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(isBuy) {
      if((price - sl) < min_dist) sl = price - min_dist;
      if((tp - price) < min_dist) tp = price + min_dist;
   } else {
      if((sl - price) < min_dist) sl = price + min_dist;
      if((price - tp) < min_dist) tp = price - min_dist;
   }
   sl = NormalizeDouble(sl, _Digits); tp = NormalizeDouble(tp, _Digits);
}

// [V12.6] Funciones de Dibujo en Gráfico para TP1 (+1R), TP2 (+2R) y TP3 (+3R)
void DrawChartLine(string name, double price_level, color clr, ENUM_LINE_STYLE style, int width, string tooltip) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price_level);
   }
   ObjectSetDouble(0, name, OBJPROP_PRICE, price_level);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

void DrawChartText(string name, datetime t, double price_lvl, string text, color clr) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_TEXT, 0, t, price_lvl);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   }
   ObjectSetInteger(0, name, OBJPROP_TIME, t);
   ObjectSetDouble(0, name, OBJPROP_PRICE, price_lvl);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

void CleanPositionLevels() {
   ObjectsDeleteAll(0, "tp_lvl_");
}

void DrawPositionLevels() {
   ulong active_ticket = 0;
   double entry = 0, sl = 0, tp = 0, cur_price = 0;
   long type = -1;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != MAGIC_NUMBER && !InpManageManualTrades) continue;
      
      active_ticket = ticket;
      entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      sl        = PositionGetDouble(POSITION_SL);
      tp        = PositionGetDouble(POSITION_TP);
      type      = PositionGetInteger(POSITION_TYPE);
      cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      break;
   }
   
   if(active_ticket == 0) {
      CleanPositionLevels();
      return;
   }
   
   double atr_val_now = (hATR != INVALID_HANDLE && g_atr_0_cache > 0) ? g_atr_0_cache : 0;
   double r_dist = (atr_val_now > 0) ? (atr_val_now * g_atr_multiplier) : (g_distancia_puntos * _Point * 2.0);
   if(g_min_sl_price > 0 && r_dist < g_min_sl_price) r_dist = g_min_sl_price;
   
   double profit_price = (type == POSITION_TYPE_BUY) ? (cur_price - entry) : (entry - cur_price);
   double profit_R = (r_dist > 0) ? (profit_price / r_dist) : 0;
   
   double tp1 = (type == POSITION_TYPE_BUY) ? (entry + InpStep1_TriggerR * r_dist) : (entry - InpStep1_TriggerR * r_dist);
   double tp2 = (type == POSITION_TYPE_BUY) ? (entry + InpStep2_TriggerR * r_dist) : (entry - InpStep2_TriggerR * r_dist);
   double tp3 = (type == POSITION_TYPE_BUY) ? (entry + InpStep3_TriggerR * r_dist) : (entry - InpStep3_TriggerR * r_dist);
   
   tp1 = NormalizeDouble(tp1, _Digits);
   tp2 = NormalizeDouble(tp2, _Digits);
   tp3 = NormalizeDouble(tp3, _Digits);
   
   string tp1_tt = StringFormat("TP1 (%.1fR / BE & Parcial): %.2f | %s", InpStep1_TriggerR, tp1, (profit_R >= InpStep1_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp1 - cur_price)/_Point)));
   string tp2_tt = StringFormat("TP2 (%.1fR / Lock +%.1fR): %.2f | %s", InpStep2_TriggerR, InpStep2_LockR, tp2, (profit_R >= InpStep2_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp2 - cur_price)/_Point)));
   string tp3_tt = StringFormat("TP3 (%.1fR / Runner): %.2f | %s", InpStep3_TriggerR, tp3, (profit_R >= InpStep3_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp3 - cur_price)/_Point)));
   
   DrawChartLine("tp_lvl_1", tp1, clrGold, STYLE_DASH, 2, tp1_tt);
   DrawChartLine("tp_lvl_2", tp2, clrDeepSkyBlue, STYLE_DASH, 2, tp2_tt);
   DrawChartLine("tp_lvl_3", tp3, clrLime, STYLE_SOLID, 2, tp3_tt);
   
   datetime bar0_time = iTime(_Symbol, _Period, 0);
   if(bar0_time == 0) bar0_time = TimeCurrent();
   
   DrawChartText("tp_lvl_txt1", bar0_time, tp1, StringFormat("  🎯 TP1 (%.1fR/BE): ", InpStep1_TriggerR) + DoubleToString(tp1, _Digits) + (profit_R >= InpStep1_TriggerR ? " [ALCANZADO ✅]" : ""), clrGold);
   DrawChartText("tp_lvl_txt2", bar0_time, tp2, StringFormat("  🎯 TP2 (%.1fR/+%.1fR): ", InpStep2_TriggerR, InpStep2_LockR) + DoubleToString(tp2, _Digits) + (profit_R >= InpStep2_TriggerR ? " [ALCANZADO ✅]" : ""), clrDeepSkyBlue);
   DrawChartText("tp_lvl_txt3", bar0_time, tp3, StringFormat("  🚀 TP3 (%.1fR/Runner): ", InpStep3_TriggerR) + DoubleToString(tp3, _Digits) + (profit_R >= InpStep3_TriggerR ? " [ALCANZADO ✅]" : ""), clrLime);
}

// [OPT #6] Dashboard usa cache de indicadores
void UpdateDashboard() {
   double price = iClose(_Symbol, _Period, 0);
   double ma = g_ma_h1_cache; double adx = g_adx_cache; double rsi = g_rsi_cache;
   double ma_htf = g_ma_htf_cache; double ma_htf_p2 = g_ma_htf_p2_cache;
   string trend_txt = (price > ma) ? "ALCISTA (Busca BUY)" : "BAJISTA (Busca SELL)";
   color trend_clr = (price > ma) ? clrLime : clrRed;
   int y = 20;
   DrawLabel("lbl_Title", "AURUM SNIPER V12.9 (ULTIMATE)", 20, y, clrGold, 12); y += 22;
   long sym_trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   bool sym_enabled  = (sym_trade_mode != SYMBOL_TRADE_MODE_DISABLED);
   bool algo_allowed = sym_enabled && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                       MQLInfoInteger(MQL_TRADE_ALLOWED) &&
                       AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   string ts = !sym_enabled ? ("Estado: SIMBOLO BLOQUEADO (usar "+_Symbol+"micro)")
             : (algo_allowed ? "Estado: PERMITIDO Y OPERATIVO" : "Estado: DESACTIVADO (Revisar MT5/F7)");
   DrawLabel("lbl_TradeStatus", ts, 20, y, algo_allowed ? clrLime : clrRed, 10); y += 20;
   if(g_gold_mode_active) { DrawLabel("lbl_AssetMode", "MODO ORO: ACTIVO", 20, y, clrOrange, 10); y += 20; }
   else ObjectDelete(0, "lbl_AssetMode");
   
   string trail_mode_txt = InpUseStepTrailing ? "FASES R (BE -> +1R -> +2R -> Runner)" : (InpUseTrailingStop ? "TRAILING CONTINUO" : "SOLO BREAK-EVEN");
   DrawLabel("lbl_TrailMode", "Gestión SL: " + trail_mode_txt, 20, y, InpUseStepTrailing ? clrLime : clrSilver, 10); y += 20;

   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, y, trend_clr, 10); y += 20;
   
   bool disc_ok = (price > ma) ? IsInDiscountPremiumZone("BUY") : IsInDiscountPremiumZone("SELL");
   string disc_txt = (price > ma) ? (disc_ok ? "ZONA DESCUENTO (COMPRA OK)" : "ZONA PREMIUM (CARA - ESPERAR)")
                                  : (disc_ok ? "ZONA PREMIUM (VENTA OK)" : "ZONA DESCUENTO (BARATA - ESPERAR)");
   DrawLabel("lbl_DiscZone", "Rango H1: " + disc_txt, 20, y, disc_ok ? clrLime : clrOrange, 10); y += 20;

   bool htf_bull = (price > ma_htf); bool htf_bear = (price < ma_htf);
   if(InpUseEMAInclinacion) {
      htf_bull = htf_bull && (ma_htf > ma_htf_p2);
      htf_bear = htf_bear && (ma_htf < ma_htf_p2);
   }
   string mtf_txt = !InpUseMTFFilter ? "OFF (Solo H1)" : (htf_bull ? "ALCISTA OK" : (htf_bear ? "BAJISTA OK" : "CONFLICTO"));
   color  mtf_clr = !InpUseMTFFilter ? clrGray : (htf_bull ? clrLime : (htf_bear ? clrRed : clrOrange));
   DrawLabel("lbl_MTF", "Filtro MTF ("+EnumToString(InpHTFTimeframe)+"): "+mtf_txt, 20, y, mtf_clr, 10); y += 20;
   string dd_txt = StringFormat("Drawdown: %.2f%% / Max %.1f%%",
      (g_start_equity - AccountInfoDouble(ACCOUNT_EQUITY)) / g_start_equity * 100.0, InpMaxDailyLoss);
   DrawLabel("lbl_Risk", dd_txt, 20, y, clrWhite, 10); y += 20;
   DrawLabel("lbl_RSI", "RSI: " + DoubleToString(rsi, 2), 20, y, clrWhite, 10); y += 20;
   string adx_txt = "ADX: " + DoubleToString(adx, 2);
   color adx_clr = clrOrange;
   if(adx > g_adx_threshold) { adx_txt += " (ACTIVO)"; adx_clr = clrLime; } else adx_txt += " (DORMIDO)";
   DrawLabel("lbl_ADX", adx_txt, 20, y, adx_clr, 10); y += 20;
   DrawLabel("lbl_Partials","Parciales hoy: "+IntegerToString(ArraySize(g_partial_closed_tickets)),20,y,clrSilver,10); y += 20;

   // [V12.99] Monitoreo de Riesgo Monetario por Lote Mínimo
   double min_vol_dash = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double contract_dash = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double sample_sl_dash = (g_min_sl_price > 0) ? g_min_sl_price : (g_atr_cache > 0 ? g_atr_cache * g_atr_multiplier : 100 * _Point);
   double min_risk_usd = GetOneLotLoss(sample_sl_dash) * min_vol_dash;
   double cur_equity_dash = AccountInfoDouble(ACCOUNT_EQUITY);
   double min_risk_pct = (cur_equity_dash > 0) ? (min_risk_usd / cur_equity_dash) * 100.0 : 0.0;
   bool is_micro_dash = (contract_dash <= 10.0 || StringFind(_Symbol, "micro") >= 0);
   string risk_status_txt = StringFormat("Riesgo Lote Mín (%.2f): $%.2f (%.1f%%) [%s]",
                                         min_vol_dash, min_risk_usd, min_risk_pct,
                                         (is_micro_dash ? "MICRO" : "ESTANDAR"));
   DrawLabel("lbl_LotRisk", risk_status_txt, 20, y, (min_risk_pct > InpMaxAllowedRiskPercent ? clrOrange : clrLime), 10); y += 20;

   if(InpBlockCorrelatedUSDRisk) {
      DrawLabel("lbl_USDCorr", "Filtro USD Corr: PROTEGIDO (Max 1R activo)", 20, y, clrDeepSkyBlue, 10); y += 20;
   } else {
      ObjectDelete(0, "lbl_USDCorr");
   }

   MqlDateTime dt_dash; TimeLocal(dt_dash);
   bool is_crypto_dash = (StringFind(_Symbol, "BTC") >= 0 || StringFind(_Symbol, "ETH") >= 0);
   if(InpUseHighLiquiditySession && (!is_crypto_dash || !InpSessionFilterForexOnly)) {
      bool is_sun = (dt_dash.day_of_week == 0);
      bool in_kz = (!is_sun && dt_dash.hour >= InpSessionStartHourCDMX && dt_dash.hour < InpSessionEndHourCDMX);
      string kz_txt = StringFormat("Killzone CDMX (%02d-%02dh): %s (%02d:%02d)",
                                   InpSessionStartHourCDMX, InpSessionEndHourCDMX,
                                   (is_sun ? "DOMINGO CERRADO" : in_kz ? "ACTIVA (Londres/NY)" : "FUERA DE SESION (Asia)"),
                                   dt_dash.hour, dt_dash.min);
      DrawLabel("lbl_Killzone", kz_txt, 20, y, (in_kz ? clrLime : clrOrange), 10); y += 20;
   } else {
      ObjectDelete(0, "lbl_Killzone");
   }

   if(dt_dash.day_of_week == 5 && InpUseFridayFilter) {
      if(!is_crypto_dash || !InpFridayFilterForexOnly) {
         bool in_fri = (dt_dash.hour >= InpFridayStartHourCDMX && dt_dash.hour < InpFridayEndHourCDMX);
         string fri_txt = StringFormat("Viernes CDMX (%02d-%02dh): %s (%02d:%02d)",
                                       InpFridayStartHourCDMX, InpFridayEndHourCDMX,
                                       (in_fri ? "OPERATIVO" : "CERRADO (Fin de Semana)"),
                                       dt_dash.hour, dt_dash.min);
         DrawLabel("lbl_Friday", fri_txt, 20, y, (in_fri ? clrLime : clrOrange), 10); y += 20;
      } else {
         ObjectDelete(0, "lbl_Friday");
      }
   } else {
      ObjectDelete(0, "lbl_Friday");
   }

   // Dibujar lineas y textos de niveles TP en el gráfico
   DrawPositionLevels();

   // Extraer datos del trade en vivo para el Dashboard
   ulong act_ticket = 0; double pos_entry = 0, pos_cur = 0; long pos_type = -1;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong tk = PositionGetTicket(i);
      if(tk > 0 && PositionSelectByTicket(tk) && PositionGetString(POSITION_SYMBOL) == _Symbol) {
         long mg = PositionGetInteger(POSITION_MAGIC);
         if(mg == MAGIC_NUMBER || InpManageManualTrades) {
            act_ticket = tk;
            pos_entry = PositionGetDouble(POSITION_PRICE_OPEN);
            pos_cur   = PositionGetDouble(POSITION_PRICE_CURRENT);
            pos_type  = PositionGetInteger(POSITION_TYPE);
            break;
         }
      }
   }

   if(act_ticket > 0) {
      double atr_val_now = (hATR != INVALID_HANDLE && g_atr_0_cache > 0) ? g_atr_0_cache : 0;
      double r_dist = (atr_val_now > 0) ? (atr_val_now * g_atr_multiplier) : (g_distancia_puntos * _Point * 2.0);
      if(g_min_sl_price > 0 && r_dist < g_min_sl_price) r_dist = g_min_sl_price;
      
      double profit_price = (pos_type == POSITION_TYPE_BUY) ? (pos_cur - pos_entry) : (pos_entry - pos_cur);
      double profit_R = (r_dist > 0) ? (profit_price / r_dist) : 0;
      
      double tp1 = (pos_type == POSITION_TYPE_BUY) ? (pos_entry + InpStep1_TriggerR * r_dist) : (pos_entry - InpStep1_TriggerR * r_dist);
      double tp2 = (pos_type == POSITION_TYPE_BUY) ? (pos_entry + InpStep2_TriggerR * r_dist) : (pos_entry - InpStep2_TriggerR * r_dist);
      double tp3 = (pos_type == POSITION_TYPE_BUY) ? (pos_entry + InpStep3_TriggerR * r_dist) : (pos_entry - InpStep3_TriggerR * r_dist);
      
      DrawLabel("lbl_TradeHeader", "=== TRADE EN VIVO (" + (pos_type == POSITION_TYPE_BUY ? "BUY" : "SELL") + ") ===", 20, y, clrGold, 10); y += 18;
      
      color prof_clr = (profit_R >= 0) ? clrLime : clrRed;
      DrawLabel("lbl_TradeProfitR", StringFormat("Progreso: %.2f R (Puntos: %+.0f)", profit_R, profit_price / _Point), 20, y, prof_clr, 10); y += 18;
      
      string s_tp1 = (profit_R >= InpStep1_TriggerR) ? StringFormat("TP1 (%.1fR): ALCANZADO ✅ (BE/Parcial)", InpStep1_TriggerR) : StringFormat("TP1 (%.1fR): %.2f (Faltan %.1f pts)", InpStep1_TriggerR, tp1, MathAbs(tp1 - pos_cur)/_Point);
      DrawLabel("lbl_DashTP1", s_tp1, 20, y, (profit_R >= InpStep1_TriggerR ? clrLime : clrGold), 9); y += 16;
      
      string s_tp2 = (profit_R >= InpStep2_TriggerR) ? StringFormat("TP2 (%.1fR): ALCANZADO ✅ (SL en +%.1fR)", InpStep2_TriggerR, InpStep2_LockR) : StringFormat("TP2 (%.1fR): %.2f (Faltan %.1f pts)", InpStep2_TriggerR, tp2, MathAbs(tp2 - pos_cur)/_Point);
      DrawLabel("lbl_DashTP2", s_tp2, 20, y, (profit_R >= InpStep2_TriggerR ? clrLime : clrDeepSkyBlue), 9); y += 16;
      
      string s_tp3 = (profit_R >= InpStep3_TriggerR) ? StringFormat("TP3 (%.1fR): ALCANZADO ✅ (%s)", InpStep3_TriggerR, (InpCloseOnTP3 ? "CIERRE TOTAL" : "RUNNER Activo")) : StringFormat("TP3 (%.1fR): %.2f (Faltan %.1f pts)", InpStep3_TriggerR, tp3, MathAbs(tp3 - pos_cur)/_Point);
      DrawLabel("lbl_DashTP3", s_tp3, 20, y, (profit_R >= InpStep3_TriggerR ? clrLime : clrWhite), 9); y += 16;
   } else {
      ObjectDelete(0, "lbl_TradeHeader");
      ObjectDelete(0, "lbl_TradeProfitR");
      ObjectDelete(0, "lbl_DashTP1");
      ObjectDelete(0, "lbl_DashTP2");
      ObjectDelete(0, "lbl_DashTP3");
   }

   ChartRedraw();
}

void DrawLabel(string name, string text, int x, int y, color clr, int fontsize) {
   if(ObjectFind(0, name) < 0) {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   }
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
}

// [FIX #1 & V12.6] Permite re-entrada si la posición abierta previa ya tiene SL en Ganancia/BE
bool IsPositionOpenOnSymbol() {
   int count = 0;
   bool has_unprotected = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != MAGIC_NUMBER && (!InpManageManualTrades || !InpBlockAutoWhenManualOpen)) continue;
      
      count++;
      double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl = PositionGetDouble(POSITION_SL);
      long type = PositionGetInteger(POSITION_TYPE);
      
      if(type == POSITION_TYPE_BUY) {
         if(sl == 0 || sl < (open_price - 2 * _Point)) has_unprotected = true;
      } else if(type == POSITION_TYPE_SELL) {
         if(sl == 0 || sl > (open_price + 2 * _Point)) has_unprotected = true;
      }
   }
   
   if(count == 0) return false;
   if(InpAllowRiskFreeAddon && count < 2 && !has_unprotected) {
      // Posición previa con riesgo 0 (SL en BE/Ganancia asegurada). Permite 1 re-entrada en zona óptima
      return false;
   }
   return true;
}

//+------------------------------------------------------------------+
// [V12.95] Clasificador de Exposición Direccional al USD
// Retorna: +1 = Comprar USD (Long USD), -1 = Vender USD (Short USD), 0 = No correlacionado directo
int GetUSDDirection(string symbol, string order_type) {
   string sym = symbol;
   StringToUpper(sym);
   bool is_buy = (order_type == "BUY");
   
   // Pares XXX/USD (EURUSD, GBPUSD, AUDUSD, NZDUSD, XAUUSD, GOLD)
   if(StringFind(sym, "EURUSD") >= 0 || 
      StringFind(sym, "GBPUSD") >= 0 || 
      StringFind(sym, "AUDUSD") >= 0 || 
      StringFind(sym, "NZDUSD") >= 0 ||
      StringFind(sym, "XAUUSD") >= 0 ||
      StringFind(sym, "GOLD")   >= 0) {
      return is_buy ? -1 : +1; // BUY XXX/USD = Short USD (-1) | SELL XXX/USD = Long USD (+1)
   }
   
   // Pares USD/XXX (USDJPY, USDCAD, USDCHF)
   if(StringFind(sym, "USDJPY") >= 0 || 
      StringFind(sym, "USDCAD") >= 0 || 
      StringFind(sym, "USDCHF") >= 0) {
      return is_buy ? +1 : -1; // BUY USD/XXX = Long USD (+1) | SELL USD/XXX = Short USD (-1)
   }
   
   return 0; // Otros activos no indexados directamente a paridad USD
}

//+------------------------------------------------------------------+
// [V12.95] Filtro de Correlación Portfolio USD: Evita doble exposición al USD sin BE previo
bool HasUnprotectedCorrelatedUSDPosition(string symbol, string new_order_type, string &conflict_sym) {
   conflict_sym = "";
   if(!InpBlockCorrelatedUSDRisk) return false;
   int new_usd_dir = GetUSDDirection(symbol, new_order_type);
   if(new_usd_dir == 0) return false;
   
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      
      long magic = PositionGetInteger(POSITION_MAGIC);
      if(magic != MAGIC_NUMBER && (!InpManageManualTrades || !InpBlockAutoWhenManualOpen)) continue;
      
      string pos_sym = PositionGetString(POSITION_SYMBOL);
      if(pos_sym == symbol) continue; // Mismo símbolo ya lo gestiona IsPositionOpenOnSymbol
      
      long pos_type = PositionGetInteger(POSITION_TYPE);
      string pos_type_str = (pos_type == POSITION_TYPE_BUY) ? "BUY" : "SELL";
      int pos_usd_dir = GetUSDDirection(pos_sym, pos_type_str);
      
      // Ambas posiciones tienen la misma dirección neta en USD (ej. ambas Venden USD o ambas Compran USD)
      if(pos_usd_dir != 0 && pos_usd_dir == new_usd_dir) {
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double pt = SymbolInfoDouble(pos_sym, SYMBOL_POINT);
         if(pt <= 0) pt = 0.0001;
         
         bool is_unprotected = false;
         if(pos_type == POSITION_TYPE_BUY) {
            if(sl == 0 || sl < (open_price - 2 * pt)) is_unprotected = true;
         } else if(pos_type == POSITION_TYPE_SELL) {
            if(sl == 0 || sl > (open_price + 2 * pt)) is_unprotected = true;
         }
         
         if(is_unprotected) {
            conflict_sym = pos_sym;
            return true; // Bloquea la 2da entrada hasta que la 1ra asegure BE / Profit
         }
      }
   }
   return false;
}
