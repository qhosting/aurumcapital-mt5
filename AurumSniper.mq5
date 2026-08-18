//+------------------------------------------------------------------+
//|                                           AurumSniper_V12.mq5   |
//|                    Copyright 2026, Aurum Capital                 |
//|         V12.6 - Precisión Sniper: Descuento/Premium & Cooldown   |
//+------------------------------------------------------------------+
// CHANGELOG V12.6:
//  [V12.6] FILTRO DE ZONA DE DESCUENTO / PREMIUM (SMC / Equilibrium):
//          - Compras solo permitidas en la mitad inferior (<= 50% de rango H1).
//          - Ventas solo permitidas en la mitad superior (>= 50% de rango H1).
//          - Evita compras tardías en la cima o ventas en el fondo del swing.
//  [V12.6] COOLDOWN INTELIGENTE:
//          - Si el trade anterior cerró en Ganancia/BE, cooldown se reduce a 1 vela.
//          - Si cerró en Pérdida, mantiene cooldown completo anti-revenge trading.
//  [V12.6] RE-ENTRADA EN POSICIONES PROTEGIDAS (Risk-Free Add-on):
//          - Permite 2da entrada si la posición abierta ya tiene SL en BE / Ganancia.
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "12.60"
#property strict

#include <Trade\Trade.mqh>

// ==================== INPUTS ====================
input group "=== GESTION DE RIESGO AVANZADA (V12.6) ==="
input double   InpLotSize            = 0.01;
input bool     InpUseAutoRiskPercent = true;
input double   InpRiskPercent        = 1.0; // Arriesga exactamente el 1.0% del capital
input double   InpMaxDailyLoss       = 3.0;
input bool     InpAutoDailyReset     = true;

input group "=== AUTO-TUNING POR ACTIVO (V12.6) ==="
input bool     InpAutoGoldSettings   = true;
input bool     InpAutoForexSettings  = true;
input bool     InpAutoCryptoSettings = true;
input bool     InpAutoIndexSettings  = true;

input group "=== FILTROS DE ENTRADA Y PRECISIÓN (V12.6) ==="
input bool     InpUseDiscountPremiumFilter = true; // Exigir Descuento en Compras y Premium en Ventas
input double   InpEquilibriumPercent       = 50.0; // Nivel de Equilibrio (50% = Mitad de rango H1)
input bool     InpSmartCooldown            = true; // Cooldown inteligente (1 vela si el trade previo cerró en Profit/BE)
input bool     InpAllowRiskFreeAddon       = true; // Permitir 2da entrada si la posición previa ya está en BE/Ganancia

input group "=== ESTRATEGIA SNIPER (V9 Engine) ==="
input int      InpMaxSpread          = 32;
input int      InpDistanciaPuntos    = 150;
input int      InpEMAPeriod          = 200;
input int      InpRSIOverbought      = 60;
input int      InpRSIOversold        = 42;
input int      InpADXThreshold       = 15;

input group "=== GESTION DE SALIDA ESCALONADA POR FASES (V12.5) ==="
input double   InpATRMultiplier      = 2.0;
input bool     InpUsePartials        = true;
input double   InpRiskReward         = 3.0; // Ratio Riesgo:Beneficio Inicial (1:3)
input int      InpBE_Trigger         = 100;
input int      InpBE_LockPips        = 10;
input bool     InpManageManualTrades = true;
input bool     InpBlockAutoWhenManualOpen = false; // Bloquear auto si hay manual (false = bot opera independiente)
input bool     InpAutoSetManualSLTP  = true;

input bool     InpUseStepTrailing    = true; // [V12.5] Habilitar Fases (BE -> +1R -> +2R -> Runner)
input double   InpStep1_TriggerR     = 1.0;  // [V12.5] Fase 1: Activar Break-Even al alcanzar (+1R)
input double   InpStep2_TriggerR     = 2.0;  // [V12.5] Fase 2: Al tocar (+2R), bloquear Step2_LockR
input double   InpStep2_LockR        = 1.0;  // [V12.5] Fase 2: Ganancia bloqueada (+1R)
input double   InpStep3_TriggerR     = 3.0;  // [V12.5] Fase 3: Al tocar (+3R), bloquear Step3_LockR
input double   InpStep3_LockR        = 2.0;  // [V12.5] Fase 3: Ganancia bloqueada (+2R)
input bool     InpStepRunnerAbove3R  = true; // [V12.5] Por encima de 3R: Runner con 1R de holgura

input bool     InpUseTrailingStop    = false; // Trailing Stop continuo clásico (false si se usan Fases)
input bool     InpUseATRTrailing     = true;
input double   InpTrailingATRMult    = 1.5;
input int      InpTrailingStep       = 20;
input int      InpMaxDailyTrades     = 16;
input bool     InpUseLiquidityTraps  = true;

input group "=== FILTROS DE SEGURIDAD Y SESION (V12.2) ==="
input int      InpCooldownBars       = 2;
input bool     InpUseSessionFilter   = false; // [V12.4] Default false (evita desfase horario de broker XM)
input int      InpStartHour          = 0;
input int      InpEndHour            = 24;
input bool     InpUseATRBreakEven    = true;
input double   InpBE_ATR_Mult        = 1.0;

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
double   g_last_trade_profit = 0; // [V12.6] Ganancia/Pérdida del último trade cerrado

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
double g_min_sl_price = 0; // [V12.4] SL minimo en precio (0 = solo ATR). Para ORO = $15.00

// [OPT #3] Cache de Indicadores
double g_ma_h1_cache      = 0;
double g_ma_htf_cache     = 0;
double g_ma_htf_p2_cache  = 0;
double g_rsi_cache        = 0;
double g_adx_cache        = 0;
double g_atr_cache        = 0;
double g_atr_0_cache      = 0;

// [FIX #2]
ulong g_partial_closed_tickets[];

// [OPT #4]
datetime g_last_trade_close = 0;

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
         g_max_spread = 75; g_distancia_puntos = 600; g_be_trigger = 500;
         g_adx_threshold = 20; g_atr_multiplier = 2.0; g_risk_reward = 3.0; // [V12.4] 1:3 Base
         g_rsi_oversold = 38; g_rsi_overbought = 62;
         g_momentum_spike_multiplier = 4.5; // [V12.4] Calibrado para M1 en ORO
         g_min_sl_price = 15.0; // [V12.4] SL minimo $15 USD para ORO (evita SL de $8-9 en ATR bajo)
         Print("AURUM GOLD MODE V12.5 ACTIVE: ATR x2.0, R:R 1:3, RSI 38/62, Spike x4.5, SL min $15");
      }
   }
   if(InpAutoForexSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"EURUSD") >= 0) {
         g_distancia_puntos = 250; g_rsi_oversold = 44; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 200; g_atr_multiplier = 2.5;
         g_risk_reward = 2.0; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = 70 * _Point; // Minimo 7.0 pips de SL (evita salidas prematuras por mechas en M5)
         Print("AURUM FOREX V12.5 EURUSD (Spread max: ", g_max_spread, ", SL min: 7.0 pips)");
      } else if(StringFind(symbol,"USDJPY") >= 0) {
         g_distancia_puntos = 550; g_rsi_oversold = 46; g_rsi_overbought = 56;
         g_adx_threshold = 15; g_be_trigger = 250; g_atr_multiplier = 2.0;
         g_risk_reward = 2.0; g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 80 * _Point; // Minimo 8.0 pips de SL
         Print("AURUM FOREX V12.5 USDJPY (Spread max: ", g_max_spread, ", SL min: 8.0 pips)");
      } else if(StringFind(symbol,"GBPUSD") >= 0) {
         g_distancia_puntos = 350; g_rsi_oversold = 45; g_rsi_overbought = 60;
         g_adx_threshold = 15; g_be_trigger = 300; g_atr_multiplier = 2.0;
         g_risk_reward = 2.0; g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = 80 * _Point; // Minimo 8.0 pips de SL
         Print("AURUM FOREX V12.5 GBPUSD (Spread max: ", g_max_spread, ", SL min: 8.0 pips)");
      }
   }
   if(InpAutoCryptoSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"BTC") >= 0 || StringFind(symbol,"BITCOIN") >= 0) {
         g_max_spread = 6000; g_distancia_puntos = 3000; g_be_trigger = 2500;
         g_adx_threshold = 15; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 100.0; // Minimo $100 USD en BTC
         Print("AURUM CRYPTO V12.5 ACTIVE: BTC (Spread Max: 6000, Dist: 3000, RR 1:2.5, SL min: $100)");
      } else if(StringFind(symbol,"ETH") >= 0 || StringFind(symbol,"ETHEREUM") >= 0) {
         g_max_spread = 3000; g_distancia_puntos = 1500; g_be_trigger = 1200;
         g_adx_threshold = 15; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 10.0; // Minimo $10 USD en ETH
         Print("AURUM CRYPTO V12.5 ACTIVE: ETH (Spread Max: 3000, Dist: 1500, RR 1:2.5, SL min: $10)");
      }
   }
   if(InpAutoIndexSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"US30") >= 0 || StringFind(symbol,"DJI") >= 0 || StringFind(symbol,"WS30") >= 0 || StringFind(symbol,"WALLSTREET") >= 0) {
         g_max_spread = 1000; g_distancia_puntos = 800; g_be_trigger = 600;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 50.0; // Minimo 50 pts en US30
         Print("AURUM INDEX V12.5 ACTIVE: US30 (Spread Max: 1000, Dist: 800, RR 1:2.5, SL min: 50pts)");
      } else if(StringFind(symbol,"NAS100") >= 0 || StringFind(symbol,"USTEC") >= 0 || StringFind(symbol,"NDX") >= 0 || StringFind(symbol,"NQ") >= 0) {
         g_max_spread = 800; g_distancia_puntos = 600; g_be_trigger = 500;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 30.0; // Minimo 30 pts en NAS100
         Print("AURUM INDEX V12.5 ACTIVE: NAS100 (Spread Max: 800, Dist: 600, RR 1:2.5, SL min: 30pts)");
      } else if(StringFind(symbol,"US500") >= 0 || StringFind(symbol,"SPX") >= 0 || StringFind(symbol,"ES") >= 0) {
         g_max_spread = 500; g_distancia_puntos = 400; g_be_trigger = 300;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 5.0; // Minimo 5 pts en US500
         Print("AURUM INDEX V12.5 ACTIVE: US500 (Spread Max: 500, Dist: 400, RR 1:2.5, SL min: 5pts)");
      } else if(StringFind(symbol,"GER") >= 0 || StringFind(symbol,"DAX") >= 0) {
         g_max_spread = 800; g_distancia_puntos = 600; g_be_trigger = 500;
         g_adx_threshold = 18; g_atr_multiplier = 2.0; g_risk_reward = 2.5;
         g_rsi_oversold = 42; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 25.0; // Minimo 25 pts en DAX
         Print("AURUM INDEX V12.5 ACTIVE: DAX/GER40 (Spread Max: 800, Dist: 600, RR 1:2.5, SL min: 25pts)");
      }
   }
   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(g_lot_size < min_vol) g_lot_size = min_vol;
   if(g_lot_size > max_vol) g_lot_size = max_vol;
   if(step_vol > 0)
      g_lot_size = MathFloor((g_lot_size - min_vol) / step_vol + 0.000001) * step_vol + min_vol;
   g_lot_size = NormalizeDouble(g_lot_size, 2);
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
   EventSetTimer(1);
   Print("AURUM V12.6 ULTIMATE Loaded.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(hMA); IndicatorRelease(hMA_HTF);
   IndicatorRelease(hRSI); IndicatorRelease(hADX); IndicatorRelease(hATR);
   EventKillTimer();
   ObjectsDeleteAll(0, "lbl_");
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
         }
      }
   }
}

//+------------------------------------------------------------------+
double CalculateLotSize(double sl_dist_price) {
   if(!InpUseAutoRiskPercent) return g_lot_size;
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0) return g_lot_size;
   double risk_amount = equity * (InpRiskPercent / 100.0);
   double tick_size   = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   if(tick_size <= 0 || tick_value <= 0 || sl_dist_price <= 0) return g_lot_size;
   double loss_per_lot = (sl_dist_price / tick_size) * tick_value;
   if(loss_per_lot <= 0) return g_lot_size;
   double raw_lot = risk_amount / loss_per_lot;
   double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(step_vol > 0)
      raw_lot = MathFloor((raw_lot - min_vol) / step_vol + 0.000001) * step_vol + min_vol;
   raw_lot = MathMax(min_vol, MathMin(max_vol, raw_lot));
   return NormalizeDouble(raw_lot, 2);
}

bool IsTradingSession() {
   if(!InpUseSessionFilter) return true;
   MqlDateTime dt; TimeCurrent(dt);
   if(InpStartHour <= InpEndHour) {
      if(dt.hour < InpStartHour || dt.hour >= InpEndHour) return false;
   } else {
      if(dt.hour < InpStartHour && dt.hour >= InpEndHour) return false;
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
// [V12.6] Filtro de Zona de Descuento (Compras baratas) y Premium (Ventas caras)
bool IsInDiscountPremiumZone(string type) {
   if(!InpUseDiscountPremiumFilter) return true;
   double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double h1_low  = iLow(_Symbol,  PERIOD_H1, iLowest(_Symbol,  PERIOD_H1, MODE_LOW,  20, 1));
   double range = h1_high - h1_low;
   if(range <= 0) return true;
   
   double cur_price = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double eq_price  = h1_low + (range * (InpEquilibriumPercent / 100.0));
   
   if(type == "BUY")  return (cur_price <= eq_price); // Solo comprar en la mitad inferior (Descuento)
   if(type == "SELL") return (cur_price >= eq_price); // Solo vender en la mitad superior (Premium)
   return true;
}

//+------------------------------------------------------------------+
void DebugSignalMiss(string direction, bool trend, bool in_zone,
                     double rsi, double adx, bool is_spike,
                     bool has_open_trade, bool good_spread,
                     bool daily_limit, double eff_rsi_oversold,
                     double eff_rsi_overbought, bool cooldown_ok, bool session_ok,
                     bool discount_ok) {
   if(!in_zone && discount_ok) return;
   double open1  = iOpen(_Symbol,  _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   long cur_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
   if(direction == "BUY" && close1 > open1) {
      string reason = "";
      if(!trend)         reason += "[Sin Tendencia] ";
      if(!discount_ok)   reason += "[Zona Cara/Premium] ";
      if(rsi >= eff_rsi_oversold)  reason += "[RSI="+DoubleToString(rsi,1)+"<"+DoubleToString(eff_rsi_oversold,1)+"] ";
      if(adx <= g_adx_threshold)   reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)       reason += "[Vela Elefante] ";
      if(!good_spread)   reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)    reason += "[Meta Diaria] ";
      if(has_open_trade) reason += "[Trade abierto] ";
      if(!cooldown_ok)   reason += "[Cooldown] ";
      if(!session_ok)    reason += "[Fuera Sesion] ";
      if(reason != "") Print("[X-RAY COMPRA OMITIDA] ", _Symbol, ": ", reason);
   }
   if(direction == "SELL" && close1 < open1) {
      string reason = "";
      if(!trend)         reason += "[Sin Tendencia] ";
      if(!discount_ok)   reason += "[Zona Barata/Descuento] ";
      if(rsi <= eff_rsi_overbought) reason += "[RSI="+DoubleToString(rsi,1)+">"+DoubleToString(eff_rsi_overbought,1)+"] ";
      if(adx <= g_adx_threshold)    reason += "[ADX="+DoubleToString(adx,1)+">"+DoubleToString((double)g_adx_threshold,1)+"] ";
      if(is_spike)       reason += "[Vela Elefante] ";
      if(!good_spread)   reason += "[Spread "+IntegerToString((int)cur_spread)+"pts] ";
      if(daily_limit)    reason += "[Meta Diaria] ";
      if(has_open_trade) reason += "[Trade abierto] ";
      if(!cooldown_ok)   reason += "[Cooldown] ";
      if(!session_ok)    reason += "[Fuera Sesion] ";
      if(reason != "") Print("[X-RAY VENTA OMITIDA] ", _Symbol, ": ", reason);
   }
}

//+------------------------------------------------------------------+
//| Main Engine V12.6                                                |
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

   double eff_rsi_oversold   = (adx >= 30.0) ? (g_rsi_oversold   + 5.0) : g_rsi_oversold;
   double eff_rsi_overbought = (adx >= 30.0) ? (g_rsi_overbought - 5.0) : g_rsi_overbought;

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   bool has_open_trade      = IsPositionOpenOnSymbol();
   bool good_spread         = CheckSpread();
   bool daily_limit_reached = (g_daily_trades >= InpMaxDailyTrades);
   bool cooldown_ok         = CheckCooldownPass();
   bool session_ok          = IsTradingSession();

   if(daily_limit_reached)
      Comment("\nMETA DIARIA ("+IntegerToString(g_daily_trades)+"/"+IntegerToString(InpMaxDailyTrades)+"). HASTA MANANA.");

   bool is_spike_buy  = buy_zone_ok  ? IsMomentumSpike("BUY")  : false;
   bool is_spike_sell = sell_zone_ok ? IsMomentumSpike("SELL") : false;

   DebugSignalMiss("BUY",  trend_bull, buy_zone_ok,  rsi, adx, is_spike_buy,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_buy_ok);
   DebugSignalMiss("SELL", trend_bear, sell_zone_ok, rsi, adx, is_spike_sell,
                   has_open_trade, good_spread, daily_limit_reached,
                   eff_rsi_oversold, eff_rsi_overbought, cooldown_ok, session_ok, discount_sell_ok);

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

   if(trend_bull && buy_zone_ok && rsi < eff_rsi_oversold && adx > g_adx_threshold && !is_spike_buy) {
      // [V12.4] SL = maximo entre ATR dinamico y minimo de activo (evita SL demasiado justos)
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(ask - sl_dist, _Digits);
      double tp = NormalizeDouble(ask + tp_dist, _Digits);
      CheckStops(sl, tp, true);
      double trade_lot = CalculateLotSize(sl_dist);
      if(trade.Buy(trade_lot, _Symbol, ask, sl, tp, "Aurum V12 Sniper")) {
         g_daily_trades++;
         Print("[COMPRA] Lote:",DoubleToString(trade_lot,2)," SL:",DoubleToString(sl,_Digits)," TP:",DoubleToString(tp,_Digits)," SL_dist:",DoubleToString(sl_dist,_Digits)," (",DoubleToString(sl_dist/_Point,0)," pts) Risk:",DoubleToString(InpRiskPercent,1),"%");
      }
   }
   if(trend_bear && sell_zone_ok && rsi > eff_rsi_overbought && adx > g_adx_threshold && !is_spike_sell) {
      // [V12.4] SL = maximo entre ATR dinamico y minimo de activo
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(bid + sl_dist, _Digits);
      double tp = NormalizeDouble(bid - tp_dist, _Digits);
      CheckStops(sl, tp, false);
      double trade_lot = CalculateLotSize(sl_dist);
      if(trade.Sell(trade_lot, _Symbol, bid, sl, tp, "Aurum V12 Sniper")) {
         g_daily_trades++;
         Print("[VENTA] Lote:",DoubleToString(trade_lot,2)," SL:",DoubleToString(sl,_Digits)," TP:",DoubleToString(tp,_Digits)," SL_dist:",DoubleToString(sl_dist,_Digits)," (",DoubleToString(sl_dist/_Point,0)," pts) Risk:",DoubleToString(InpRiskPercent,1),"%");
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
void GestionarPosicionesPro() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0 || !PositionSelectByTicket(ticket)) continue;
      long pos_magic = PositionGetInteger(POSITION_MAGIC);
      if(pos_magic != MAGIC_NUMBER && !InpManageManualTrades) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double entry     = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl        = PositionGetDouble(POSITION_SL);
      double tp        = PositionGetDouble(POSITION_TP);
      double vol       = PositionGetDouble(POSITION_VOLUME);
      long   type      = PositionGetInteger(POSITION_TYPE);
      double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);

      double profit_price = (type == POSITION_TYPE_BUY) ? (cur_price - entry) : (entry - cur_price);
      double profit_puntos = profit_price / _Point;

      // Auto SL/TP si se abrió manual sin ellos
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

         // FASE 3: 3R Alcanzado (Bloquea +2R y Runner con 1R holgura)
         if(profit_R >= InpStep3_TriggerR) {
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
         // FASE 1: 1R o Trigger BE Alcanzado (SL a Break-Even + lock pips)
         else if(profit_R >= InpStep1_TriggerR || profit_puntos >= effective_be_trigger) {
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + lock_dist) : (entry - lock_dist);
            phase_name = "FASE 1 (1R/BE -> SL a Entrada Protegida)";

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
               // Si estamos en Runner Fase 3 y supera 3R, expandimos o dejamos correr sin TP rígido
               if(InpStepRunnerAbove3R && profit_R >= InpStep3_TriggerR && tp > 0) modify_tp = 0;
               CheckStops(target_sl, modify_tp, (type == POSITION_TYPE_BUY));
               if(trade.PositionModify(ticket, target_sl, modify_tp)) {
                  Print("[",phase_name," Ticket ",ticket,"] SL->",DoubleToString(target_sl,_Digits)," (Profit: ",DoubleToString(profit_R,2),"R)");
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

// [OPT #6] Dashboard usa cache de indicadores
void UpdateDashboard() {
   double price = iClose(_Symbol, _Period, 0);
   double ma = g_ma_h1_cache; double adx = g_adx_cache; double rsi = g_rsi_cache;
   double ma_htf = g_ma_htf_cache; double ma_htf_p2 = g_ma_htf_p2_cache;
   string trend_txt = (price > ma) ? "ALCISTA (Busca BUY)" : "BAJISTA (Busca SELL)";
   color trend_clr = (price > ma) ? clrLime : clrRed;
   int y = 20;
   DrawLabel("lbl_Title", "AURUM SNIPER V12.6 (ULTIMATE)", 20, y, clrGold, 12); y += 22;
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
   DrawLabel("lbl_Partials","Parciales hoy: "+IntegerToString(ArraySize(g_partial_closed_tickets)),20,y,clrSilver,10);
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
