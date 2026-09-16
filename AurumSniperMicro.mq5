//+------------------------------------------------------------------+
//|                                         AurumSniperMicro.mq5     |
//|                    Copyright 2026, Aurum Capital                 |
//|      Edición Especial Micro (XM / Forex / Oro / Índices / Cripto)|
//|   V15.00 - Institutional Risk, Reconciliation & Pre-Flight Validation  |
//+------------------------------------------------------------------+
#property description "AurumSniper Institutional V15: Risk Guard, Order Reconciliation & Pre-Flight Validation Engine"
// CHANGELOG V15.20:
//  [V15.20] KILLZONE FOREX OBLIGATORIA, MUTEX USD ANTI-RACE CONDITION & PISO SL REALISTA:
//          - InpUseHighLiquiditySession = true: Forex opera estrictamente en Londres y NY (01:15 a 12:00 CDMX). Erradica pérdidas nocturnas en Asia.
//          - Mutex Inter-Chart ("AURUM_USD_DISPATCH_TIME"): Evita que EURUSD y GBPUSD disparen órdenes en el mismo milisegundo.
//          - Piso Mínimo de SL en Forex adaptado a M15: EURUSD (14 pips), GBPUSD (16 pips), USDJPY (15 pips) evitando barridos por ruido nocturno de 7 pips.
// CHANGELOG V15.10:
//  [V15.10] FILTROS DE ALINEACION SMC & PROTECCION DE POI OPUESTO:
//          - InpStrictSMCAlign: Bloquea ventas si la estructura SMC local está en Bullish CHoCH/BOS, y compras en Bearish CHoCH/BOS.
//          - InpBlockOpposingPOI: Bloquea disparos si el precio está testeando simultáneamente un POI opuesto activo (ej: no vender sobre Bull Breaker/OB).
//          - IsSMCStructureAligned() & HasOpposingSMCZone() integrados en evaluación OnTick() y DebugSignalMiss().
//          - Dashboard enriquecido con indicador de permiso de estructura SMC en vivo.
// CHANGELOG V13.50:
//  [V13.50] OPTIMIZACION DE SALIDAS REALISTAS & FILTRO ANTI-NOTICIAS:
//          - InpRiskReward = 1.8: Target global adaptado a la expansión natural intradía del Oro (+1.8R).
//          - InpStep1_TriggerR = 0.8R / InpPartialPercent = 60.0%: 60% parcial al primer impulso y SL a BE protegido.
//          - InpStep2_TriggerR = 1.8R: Cierre del 40% restante en +1.8R ($25 a $32 USD de ganancia limpia).
//          - InpGoldMaxSL = 18.0: Techo máximo de Stop Loss ($18.00) que evita SL inflados por noticias.
//          - InpMaxAllowedATR = 15.0: Filtro Anti-Noticias que pausa compras/ventas si el ATR supera $15.00 USD.
//  [V13.40] CONFIRMACION DE ACCION DEL PRECIO Y ABSORCION:
//          - CheckPriceActionConfirmation(): Exige vela de giro o mecha de absorción en soporte/resistencia antes de disparar.
//          - CheckMicroTrigger(): Filtro estricto en M1 que previene compras prematuras mientras la vela sigue cayendo.
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "15.20"
#property strict

#include <Trade\Trade.mqh>
#include "Include\AurumStationBridge.mqh"

CAurumStationBridge g_station_bridge;

// ==================== INPUTS ====================
input group "=== GESTIÓN DE RIESGO INSTITUCIONAL & PROTECCIÓN DIARIA (V15) ==="
input int      InpMagicNumber             = 777998; // Magic Number de identificación
input double   InpLotSize                 = 0.1;   // Lote base para operativa estándar
input bool     InpUseAutoRiskPercent      = true;
input double   InpRiskPercent             = 1.0;    // Arriesga exactamente el 1.0% del capital
input double   InpMaxAllowedRiskPercent   = 5.0;    // Riesgo Máximo Permitido por Trade (% del capital)
input bool     InpStrictRiskProtection    = false;  // Bloquear trade si el lote mínimo excede el Riesgo Máximo
input bool     InpUseDailyRiskGuard       = true;   // [V15] Activar Guardia de Riesgo Diario (Hard Stop de Pérdida)
input double   InpMaxDailyLossUSD         = 20.0;  // [V15] Límite Monetario Máximo de Pérdida Diaria ($ USD)
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
input bool     InpLogValidationEvents     = true;   // [V15] Registrar diagnósticos en log detallado

input group "=== AUTO-TUNING POR ACTIVO (V13.50) ==="
input bool     InpAutoGoldSettings        = true;
input double   InpGoldMinSL               = 10.0; // [V13.50] SL Mínimo para Oro ($10.00 = 1000 pts en M15)
input double   InpGoldMaxSL               = 18.0; // [V13.50] SL Máximo para Oro ($18.00 = 1800 pts en M15)
input double   InpMaxAllowedATR           = 15.0; // [V13.50] Filtro Anti-Noticias: Bloquear si ATR > $15.00
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

input group "=== GESTION DE SALIDA ESCALONADA POR FASES (V13.70 M15) ==="
input double   InpATRMultiplier      = 2.0;
input bool     InpUsePartials        = true;
input double   InpPartialPercent     = 40.0;// [V13.70] Porcentaje de Cierre Parcial en Fase 1 (40% del volumen)
input double   InpRiskReward         = 2.2; // [V13.70] Ratio Riesgo:Beneficio Realista Intradía (1:2.2)
input int      InpBE_Trigger         = 150;
input int      InpBE_LockPips        = 10;
input bool     InpManageManualTrades = true;
input bool     InpBlockAutoWhenManualOpen = false; // Bloquear auto si hay manual (false = bot opera independiente)
input bool     InpAutoSetManualSLTP  = true;
input bool     InpAllowRangeTrading       = true;  // [V13.70] Permitir compras/ventas en Soporte/Resistencia durante consolidación

input bool     InpUseStepTrailing    = true; // [V13.70] Habilitar Fases (BE 1.3R -> TP 2.2R -> Runner 3.0R)
input bool     InpUseMicroLock05R    = true; // [V15.0] Micro-Lock Temprano a +0.5R (Asegura parcial y BE en scalps)
input double   InpMicroLock05Trigger = 0.5;  // [V15.0] Nivel R para Micro-Lock (0.5R)
input double   InpMicroLock05Pct     = 50.0; // [V15.0] Porcentaje de cierre parcial en Micro-Lock (50% del lote)
input int      InpMicroLockLockPips  = 10;   // [V15.0] Pips de ganancia asegurada en SL tras Micro-Lock (+1 pip)
input double   InpStep1_TriggerR     = 1.0;  // [V15.0] Fase 1: Break-Even protegido y 50% Parcial (+1.0R)
input double   InpStep1_5_TriggerR   = 1.0;  // [V15.0] Fase 1.5: Asegurar Ganancia (+1.0R)
input double   InpStep1_5_LockR      = 0.4;  // [V15.0] Fase 1.5: Ganancia asegurada (+0.4R)
input double   InpStep2_TriggerR     = 1.8;  // [V15.0] Fase 2: TP Principal (+1.8R)
input double   InpStep2_LockR        = 1.0;  // [V15.0] Fase 2: Ganancia bloqueada (+1.0R)
input double   InpStep3_TriggerR     = 2.2;  // [V15.0] Fase 3: Nivel Runner Extendido (+2.2R)
input double   InpStep3_LockR        = 1.8;  // [V15.0] Fase 3: Ganancia bloqueada (+1.8R)
input bool     InpCloseOnTP3         = true; // [V15.0] Cerrar 100% de la posición en TP2/TP3
input bool     InpStepRunnerAbove3R  = false;// [V12.9] Runner infinito sobre 3.0R (solo si InpCloseOnTP3 = false)
input bool     InpUseCandleTrailing  = true; // [V14.1] Candle-Trailing Stop tras N velas en profit
input int      InpCandleTrailAfterBars = 4;  // [V14.1] Activar Candle-Trail tras N velas en ganancia (optimizado: 4 velas)
input int      InpCandleTrailBars    = 2;    // [V14.1] Ceñir SL a High/Low de las últimas N velas cerradas

input bool     InpUseTrailingStop    = false; // Trailing Stop continuo clásico (false si se usan Fases)
input bool     InpUseATRTrailing     = true;
input double   InpTrailingATRMult    = 1.5;
input int      InpTrailingStep       = 20;
input int      InpMaxDailyTrades     = 16;
input bool     InpUseLiquidityTraps  = true;

input group "=== FILTROS DE SEGURIDAD Y SESION (V13.00) ==="
input int      InpCooldownBars             = 2;
input bool     InpUseHighLiquiditySession  = true; // [V15.20] Operar solo en Sesiones de Alta Liquidez (true = Londres y NY 01:15 a 12:00 CDMX)
input int      InpSessionStartHourCDMX     = 1;    // Hora Inicio CDMX (01:00 AM)
input int      InpSessionStartMinCDMX      = 15;   // Minuto Inicio CDMX (01:15 AM - Evita Rollover de Broker)
input int      InpSessionEndHourCDMX       = 12;   // Hora Cierre CDMX (12:00 PM - Fin Golden Overlap)
input bool     InpSessionFilterForexOnly   = true; // Aplicar a Forex, Metales e Índices (Cripto 24/7 libre)
input bool     InpSessionFilterMetals      = false;// [V14.2] Aplicar Killzone a Metales/Oro (false = Oro opera 24h salvo rollover)
input bool     InpCryptoAvoidWeekendChop   = true; // [V13.80] Bloquear Domingo en Cripto (Evita trampas de baja liquidez y bull traps de fin de semana)
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

input group "=== MICRO-GATILLO MULTITEMPORAL (V13.10) ==="
input bool            InpUseMicroTrigger       = true;       // [V13.10] Confirmación de Giro en Temporalidad Menor (M1)
input ENUM_TIMEFRAMES InpMicroTriggerTimeframe = PERIOD_M1;  // [V13.10] Temporalidad del Gatillo Sniper (M1)
input int             InpMicroTriggerEMA       = 9;          // [V13.10] Periodo EMA Rápida Micro-Gatillo

// ==================== GLOBALES ====================
CTrade trade;
int hMA, hMA_HTF, hMA_Micro = INVALID_HANDLE, hRSI, hADX, hATR;
double   g_start_equity   = 0;
datetime g_last_reset_day = 0;
int      g_daily_trades   = 0;
datetime g_last_bar_time  = 0;
const int MAGIC_NUMBER    = 777998;
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
string   g_last_validation_fail_reason   = "";

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
double g_min_sl_price = 0; // SL minimo en precio (0 = solo ATR). Para ORO = $10.00
double g_max_sl_price = 0; // [V13.50] SL maximo en precio. Para ORO = $18.00
double g_microlock_trigger_r = 0.5;
double g_microlock_pct       = 50.0;
double g_step1_trigger_r   = 0.8;
double g_step1_5_trigger_r = 1.0;
double g_step1_5_lock_r    = 0.4;
double g_step2_trigger_r   = 1.8;
double g_step2_lock_r      = 1.0;
double g_step3_trigger_r   = 2.2;
double g_step3_lock_r      = 1.5;
double g_partial_percent   = 60.0;

// [OPT #3] Cache de Indicadores
double g_ma_h1_cache      = 0;
double g_ma_h1_p2_cache   = 0;
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
   g_microlock_trigger_r = InpMicroLock05Trigger;
   g_microlock_pct       = InpMicroLock05Pct;
   g_step1_trigger_r   = InpStep1_TriggerR;
   g_step1_5_trigger_r = InpStep1_5_TriggerR;
   g_step1_5_lock_r    = InpStep1_5_LockR;
   g_step2_trigger_r   = InpStep2_TriggerR;
   g_step2_lock_r      = InpStep2_LockR;
   g_step3_trigger_r   = InpStep3_TriggerR;
   g_step3_lock_r      = InpStep3_LockR;
   g_partial_percent   = InpPartialPercent;

   if(InpAutoGoldSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"XAU") >= 0 || StringFind(symbol,"GOLD") >= 0 || StringFind(symbol,"MGC") >= 0) {
         g_gold_mode_active = true;
         g_lot_size = (!InpUseAutoRiskPercent && InpLotSize > 0.01) ? InpLotSize : 0.01;
         g_max_spread = 75;
         g_distancia_puntos = (_Period >= PERIOD_M15) ? 900 : 700; // [V13.50] Adaptativo M15/M5
         g_be_trigger = (_Period >= PERIOD_M15) ? 900 : 700;
         g_adx_threshold = 20; g_atr_multiplier = 2.0; g_risk_reward = InpRiskReward; // [V13.70] Ratio positivo (1:2.2)
         g_microlock_trigger_r = InpMicroLock05Trigger; // [V14.3] Micro-Lock 0.5R
         g_microlock_pct       = InpMicroLock05Pct;
         g_step1_trigger_r   = InpStep1_TriggerR; // [V13.70] +1.3R para dar holgura al impulso
         g_step1_5_trigger_r = InpStep1_5_TriggerR;
         g_step1_5_lock_r    = InpStep1_5_LockR;
         g_step2_trigger_r   = InpStep2_TriggerR; // [V13.70] +2.2R
         g_step2_lock_r      = InpStep2_LockR;    // [V13.70] +1.2R
         g_step3_trigger_r   = InpStep3_TriggerR; // [V13.70] +3.0R
         g_step3_lock_r      = InpStep3_LockR;    // [V13.70] +2.0R
         g_partial_percent   = InpPartialPercent; // [V13.70] 40.0%
         g_rsi_oversold = 42; g_rsi_overbought = 58;
         g_momentum_spike_multiplier = 4.5;
         g_min_sl_price = MathMax(InpGoldMinSL, (_Period >= PERIOD_M15 ? 10.0 : 8.0)); // [V13.50]
         g_max_sl_price = (InpGoldMaxSL > 0) ? InpGoldMaxSL : (_Period >= PERIOD_M15 ? 18.0 : 15.0); // [V13.50]
         PrintFormat("AURUM GOLD & MICRO-GOLD MODE V14.3 ACTIVE (%s): ATR x2.0, R:R 1:%.1f, Micro-Lock (%.1fR -> %.0f%% BE), Fases (BE %.1fR -> TP %.1fR), SL [$%.2f - $%.2f], Parcial %.0f%%",
                     EnumToString(_Period), g_risk_reward, g_microlock_trigger_r, g_microlock_pct, g_step1_trigger_r, g_step2_trigger_r, g_min_sl_price, g_max_sl_price, g_partial_percent);
      }
   }
   if(InpAutoForexSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"EURUSD") >= 0) {
         g_distancia_puntos = 250; g_rsi_oversold = 42; g_rsi_overbought = 58;
         g_adx_threshold = 18; g_be_trigger = 120; g_atr_multiplier = 2.2;
         g_risk_reward = InpRiskReward; g_momentum_spike_multiplier = 4.5;
         g_max_spread = 22; // [V15.30] Spread maximo 2.2 pips en Forex
         g_min_sl_price = (_Period >= PERIOD_M15 ? 150 : 100) * _Point; // [V15.30] Min 15.0 pips de holgura en M15 (evita barridos de 7 pips)
         g_max_sl_price = 250 * _Point; // [V15.30] Techo maximo de 25.0 pips
         PrintFormat("AURUM FOREX V15.30 EURUSD: Spread max %d pts, SL [%.1f - %.1f] pips, BE %d pts, R:R 1:%.1f",
                     g_max_spread, g_min_sl_price/_Point/10.0, g_max_sl_price/_Point/10.0, g_be_trigger, g_risk_reward);
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
      }
   }
   if(InpAutoCryptoSettings) {
      string symbol = _Symbol; StringToUpper(symbol);
      if(StringFind(symbol,"BTC") >= 0 || StringFind(symbol,"BITCOIN") >= 0) {
         g_max_spread = 6000; g_distancia_puntos = 3000; g_be_trigger = 3500;
         g_adx_threshold = 18; g_atr_multiplier = 2.8; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 500.0; // [V13.80] Minimo $500 USD de SL en BTC para holgura de ruido M15
         Print("AURUM CRYPTO V13.80 ACTIVE: BTC (Spread Max: 6000, Dist: 3000, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: $500, ATR Mult: 2.8)");
      } else if(StringFind(symbol,"ETH") >= 0 || StringFind(symbol,"ETHEREUM") >= 0) {
         g_max_spread = 3000; g_distancia_puntos = 1500; g_be_trigger = 1800;
         g_adx_threshold = 18; g_atr_multiplier = 2.8; g_risk_reward = InpRiskReward;
         g_rsi_oversold = 40; g_rsi_overbought = 60;
         g_momentum_spike_multiplier = 4.0;
         g_min_sl_price = 40.0; // [V13.80] Minimo $40 USD de SL en ETH
         Print("AURUM CRYPTO V13.80 ACTIVE: ETH (Spread Max: 3000, Dist: 1500, RR 1:", DoubleToString(g_risk_reward,1), ", SL min: $40, ATR Mult: 2.8)");
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
   if(CopyBuffer(hMA,     0, 0, 3, b) > 0) { g_ma_h1_cache = b[0]; g_ma_h1_p2_cache = b[2]; }
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

//+------------------------------------------------------------------+
//| === INSTITUTIONAL SMART MONEY CONCEPTS (SMC) & ORDER BLOCKS ===   |
//| Based on SMC.txt (LuxAlgo Pro) & OB.txt (VEGA OB / Breakers)      |
//+------------------------------------------------------------------+
input group "=== INSTITUTIONAL SMART MONEY CONCEPTS (V15.0) ==="
input bool     InpUseSMCStructures         = true;  // Activar Motor SMC (BOS, CHoCH, OB, Breakers)
input int      InpSwingLength              = 5;     // Longitud de Swing High/Low (VEGA OB)
input bool     InpUseOrderBlocks           = true;  // Confluencia en Order Blocks (OB)
input bool     InpUseBreakerBlocks         = true;  // Confluencia en Breaker Blocks (Inversion de Polaridad)
input bool     InpUseChopControl           = true;  // [V15] Chop Control: Eliminar Breakers atravesados en falso (OB.txt)
input bool     InpUseFVGFilter             = true;  // Confluencia en Fair Value Gaps (FVG)
input bool     InpUseLiquiditySweeps       = true;  // Cazas de Liquidez (Equal Highs/Lows Sweeps)
input bool     InpDrawSMCVisuals           = true;  // Dibujar Zonas SMC en el grafico de MT5
input int      InpMaxSMCBoxes              = 8;     // Maximo de Cajas SMC simultaneas en grafico
input color    InpBullOBColor              = C'20,60,50'; // Color Bullish OB / FVG
input color    InpBearOBColor              = C'70,25,35'; // Color Bearish OB / FVG
input color    InpBreakerColor             = C'25,45,75'; // Color Breaker Block
input bool     InpStrictSMCAlign           = true;  // [V15.10] Alinear Disparo con Estructura SMC (Anti-CHoCH Contrario)
input bool     InpBlockOpposingPOI         = true;  // [V15.10] Bloquear Disparo si Hay POI Opuesto Activo

// Estructuras de Datos Institucionales
struct SOrderBlock {
   double   top;
   double   bottom;
   datetime time;
   int      bar_index;
   bool     is_bullish;
   bool     is_breaker;
   bool     was_originally_bullish;
   bool     is_mitigated;
   string   box_name;
};

struct SFairValueGap {
   double   top;
   double   bottom;
   datetime time;
   bool     is_bullish;
   bool     is_mitigated;
   string   box_name;
};

// Variables Globales del Motor SMC
SOrderBlock    g_order_blocks[20];
int            g_total_obs = 0;
SFairValueGap  g_fvgs[20];
int            g_total_fvgs = 0;

double         g_last_swing_high = 0;
double         g_last_swing_low  = 0;
datetime       g_last_swing_high_time = 0;
datetime       g_last_swing_low_time  = 0;
int            g_last_swing_high_bar  = 0;
int            g_last_swing_low_bar   = 0;
bool           g_swing_high_breached  = false;
bool           g_swing_low_breached   = false;
int            g_market_structure_trend = 0; // 1 = Bullish, -1 = Bearish

bool           g_smc_liquidity_sweep_buy  = false;
bool           g_smc_liquidity_sweep_sell = false;

//+------------------------------------------------------------------+
//| Deteccion de Swing High (Pivots)                                 |
//+------------------------------------------------------------------+
bool IsSwingHighBar(int bar, int length) {
   double target = iHigh(_Symbol, _Period, bar);
   for(int i = 1; i <= length; i++) {
      if(iHigh(_Symbol, _Period, bar + i) >= target) return false;
      if(iHigh(_Symbol, _Period, bar - i) >= target) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Deteccion de Swing Low (Pivots)                                  |
//+------------------------------------------------------------------+
bool IsSwingLowBar(int bar, int length) {
   double target = iLow(_Symbol, _Period, bar);
   for(int i = 1; i <= length; i++) {
      if(iLow(_Symbol, _Period, bar + i) <= target) return false;
      if(iLow(_Symbol, _Period, bar - i) <= target) return false;
   }
   return true;
}

//+------------------------------------------------------------------+
//| Limpieza de Objetos Graficos SMC                                 |
//+------------------------------------------------------------------+
void CleanSMCVisuals() {
   ObjectsDeleteAll(0, "smc_ob_");
   ObjectsDeleteAll(0, "smc_brk_");
   ObjectsDeleteAll(0, "smc_fvg_");
   ObjectsDeleteAll(0, "smc_swp_");
}

//+------------------------------------------------------------------+
//| Dibujar Rectangulo SMC en el Grafico                             |
//+------------------------------------------------------------------+
void DrawSMCBox(string name, datetime t1, double p1, datetime t2, double p2, color clr, string tip) {
   if(!InpDrawSMCVisuals) return;
   ObjectDelete(0, name);
   if(ObjectCreate(0, name, OBJ_RECTANGLE, 0, t1, p1, t2, p2)) {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_FILL, true);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, name, OBJPROP_TOOLTIP, tip);
   }
}

//+------------------------------------------------------------------+
//| Actualizacion Integral del Motor SMC (BOS, CHoCH, OB, Breakers)  |
//+------------------------------------------------------------------+
void UpdateSMCStructures() {
   if(!InpUseSMCStructures) return;
   
   int scan_bars = 60;
   int length = MathMax(InpSwingLength, 3);
   
   // 1. Detectar Pivots Recientes
   for(int i = length + 1; i <= scan_bars; i++) {
      if(IsSwingHighBar(i, length)) {
         double sh = iHigh(_Symbol, _Period, i);
         datetime st = iTime(_Symbol, _Period, i);
         if(st > g_last_swing_high_time) {
            g_last_swing_high = sh;
            g_last_swing_high_time = st;
            g_last_swing_high_bar = i;
            g_swing_high_breached = false;
         }
         break;
      }
   }
   for(int i = length + 1; i <= scan_bars; i++) {
      if(IsSwingLowBar(i, length)) {
         double sl = iLow(_Symbol, _Period, i);
         datetime st = iTime(_Symbol, _Period, i);
         if(st > g_last_swing_low_time) {
            g_last_swing_low = sl;
            g_last_swing_low_time = st;
            g_last_swing_low_bar = i;
            g_swing_low_breached = false;
         }
         break;
      }
   }
   
   double close1 = iClose(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol, _Period, 1);
   double low1   = iLow(_Symbol, _Period, 1);
   
   // 2. Ruptura de Estructura (BOS vs CHoCH) y Registro de Order Blocks (OB.txt)
   if(g_last_swing_high > 0 && !g_swing_high_breached && close1 > g_last_swing_high) {
      g_swing_high_breached = true;
      int prev_trend = g_market_structure_trend;
      g_market_structure_trend = 1; // Bullish
      
      // Buscar la ultima vela bajista antes de la ruptura (Bullish OB)
      for(int k = 1; k <= 30; k++) {
         double op_k = iOpen(_Symbol, _Period, k);
         double cl_k = iClose(_Symbol, _Period, k);
         if(cl_k < op_k) { // Ultima vela bajista
            if(g_total_obs < 20) {
               g_order_blocks[g_total_obs].top = iHigh(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].bottom = iLow(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].time = iTime(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].bar_index = k;
               g_order_blocks[g_total_obs].is_bullish = true;
               g_order_blocks[g_total_obs].is_breaker = false;
               g_order_blocks[g_total_obs].was_originally_bullish = true;
               g_order_blocks[g_total_obs].is_mitigated = false;
               g_order_blocks[g_total_obs].box_name = "smc_ob_" + IntegerToString(g_total_obs);
               g_total_obs++;
            }
            break;
         }
      }
   }
   
   if(g_last_swing_low > 0 && !g_swing_low_breached && close1 < g_last_swing_low) {
      g_swing_low_breached = true;
      int prev_trend = g_market_structure_trend;
      g_market_structure_trend = -1; // Bearish
      
      // Buscar la ultima vela alcista antes de la ruptura (Bearish OB)
      for(int k = 1; k <= 30; k++) {
         double op_k = iOpen(_Symbol, _Period, k);
         double cl_k = iClose(_Symbol, _Period, k);
         if(cl_k > op_k) { // Ultima vela alcista
            if(g_total_obs < 20) {
               g_order_blocks[g_total_obs].top = iHigh(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].bottom = iLow(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].time = iTime(_Symbol, _Period, k);
               g_order_blocks[g_total_obs].bar_index = k;
               g_order_blocks[g_total_obs].is_bullish = false;
               g_order_blocks[g_total_obs].is_breaker = false;
               g_order_blocks[g_total_obs].was_originally_bullish = false;
               g_order_blocks[g_total_obs].is_mitigated = false;
               g_order_blocks[g_total_obs].box_name = "smc_ob_" + IntegerToString(g_total_obs);
               g_total_obs++;
            }
            break;
         }
      }
   }
   
   // 3. Breaker Blocks (Inversion de Polaridad - Motor OB.txt) & Mitigacion
   datetime now_t = TimeCurrent() + PeriodSeconds() * 15;
   for(int b = 0; b < g_total_obs; b++) {
      if(!g_order_blocks[b].is_breaker) {
         // Si un Bullish OB es perforado a la baja con cierre -> muta a Bearish Breaker
         if(g_order_blocks[b].is_bullish && close1 < g_order_blocks[b].bottom) {
            g_order_blocks[b].is_breaker = true;
            g_order_blocks[b].is_bullish = false; // Ahora actua como resistencia bajista
            g_order_blocks[b].box_name = "smc_brk_" + IntegerToString(b);
         }
         // Si un Bearish OB es perforado al alza con cierre -> muta a Bullish Breaker
         else if(!g_order_blocks[b].is_bullish && close1 > g_order_blocks[b].top) {
            g_order_blocks[b].is_breaker = true;
            g_order_blocks[b].is_bullish = true; // Ahora actua como soporte alcista
            g_order_blocks[b].box_name = "smc_brk_" + IntegerToString(b);
         }
      }
      else if(InpUseChopControl && g_order_blocks[b].is_breaker) {
         // Chop Control de OB.txt (lineas 195-209): si el precio vuelve a atravesar el breaker, se mitiga/elimina
         if(g_order_blocks[b].was_originally_bullish && close1 > g_order_blocks[b].top) {
            g_order_blocks[b].is_mitigated = true;
         }
         else if(!g_order_blocks[b].was_originally_bullish && close1 < g_order_blocks[b].bottom) {
            g_order_blocks[b].is_mitigated = true;
         }
      }
   }
   
   // 4. Deteccion de Fair Value Gaps (FVG de 3 velas - Motor SMC.txt)
   double h3 = iHigh(_Symbol, _Period, 3);
   double l1 = iLow(_Symbol,  _Period, 1);
   double l3 = iLow(_Symbol,  _Period, 3);
   double h1 = iHigh(_Symbol, _Period, 1);
   
   // Bullish FVG: low de vela 1 > high de vela 3
   if(l1 > h3) {
      if(g_total_fvgs < 20) {
         g_fvgs[g_total_fvgs].top = l1;
         g_fvgs[g_total_fvgs].bottom = h3;
         g_fvgs[g_total_fvgs].time = iTime(_Symbol, _Period, 2);
         g_fvgs[g_total_fvgs].is_bullish = true;
         g_fvgs[g_total_fvgs].is_mitigated = false;
         g_fvgs[g_total_fvgs].box_name = "smc_fvg_" + IntegerToString(g_total_fvgs);
         g_total_fvgs++;
      }
   }
   // Bearish FVG: high de vela 1 < low de vela 3
   if(h1 < l3) {
      if(g_total_fvgs < 20) {
         g_fvgs[g_total_fvgs].top = l3;
         g_fvgs[g_total_fvgs].bottom = h1;
         g_fvgs[g_total_fvgs].time = iTime(_Symbol, _Period, 2);
         g_fvgs[g_total_fvgs].is_bullish = false;
         g_fvgs[g_total_fvgs].is_mitigated = false;
         g_fvgs[g_total_fvgs].box_name = "smc_fvg_" + IntegerToString(g_total_fvgs);
         g_total_fvgs++;
      }
   }
   
   // 5. Cazas de Liquidez (Equal Highs / Equal Lows Sweeps - SMC.txt)
   g_smc_liquidity_sweep_buy = false;
   g_smc_liquidity_sweep_sell = false;
   if(InpUseLiquiditySweeps && g_last_swing_low > 0 && g_last_swing_high > 0) {
      double atr = g_atr_cache > 0 ? g_atr_cache : 10 * _Point;
      // Barrido de Bajos (Sweep EQL): vela 1 perforo el swing low pero cerro por encima
      if(low1 < g_last_swing_low && close1 >= g_last_swing_low) {
         g_smc_liquidity_sweep_buy = true;
      }
      // Barrido de Altos (Sweep EQH): vela 1 perforo el swing high pero cerro por debajo
      if(high1 > g_last_swing_high && close1 <= g_last_swing_high) {
         g_smc_liquidity_sweep_sell = true;
      }
   }
   
   // Mitigacion de FVGs por accion del precio
   for(int f = 0; f < g_total_fvgs; f++) {
      if(!g_fvgs[f].is_mitigated) {
         if(g_fvgs[f].is_bullish && low1 <= g_fvgs[f].bottom) g_fvgs[f].is_mitigated = true;
         else if(!g_fvgs[f].is_bullish && high1 >= g_fvgs[f].top) g_fvgs[f].is_mitigated = true;
      }
   }

   // 6. Renderizar Cajas Graficas Limpias en MT5 (Limpiar antes de redibujar)
   if(InpDrawSMCVisuals) {
      CleanSMCVisuals();
      int drawn = 0;
      for(int b = g_total_obs - 1; b >= 0 && drawn < InpMaxSMCBoxes; b--) {
         if(g_order_blocks[b].is_mitigated) continue;
         color clr = g_order_blocks[b].is_breaker ? InpBreakerColor :
                     (g_order_blocks[b].is_bullish ? InpBullOBColor : InpBearOBColor);
         string tip = StringFormat("[%s] %s | Top:%.5f Bot:%.5f",
                                   (g_order_blocks[b].is_breaker ? "BREAKER" : "ORDERBLOCK"),
                                   (g_order_blocks[b].is_bullish ? "BULL" : "BEAR"),
                                   g_order_blocks[b].top, g_order_blocks[b].bottom);
         DrawSMCBox(g_order_blocks[b].box_name, g_order_blocks[b].time, g_order_blocks[b].top,
                    now_t, g_order_blocks[b].bottom, clr, tip);
         drawn++;
      }
   }
}

//+------------------------------------------------------------------+
//| Verificacion de Confluencia en Zona Institucional SMC            |
//+------------------------------------------------------------------+
bool IsInSMCInstitutionalZone(string direction, double cur_price, bool &has_ob, bool &has_breaker, bool &has_fvg) {
   has_ob = false;
   has_breaker = false;
   has_fvg = false;
   if(!InpUseSMCStructures) return true; // Si el motor esta apagado, permitir paso libre
   
   double tolerance = 3.0 * _Point;
   
   // Evaluar Order Blocks y Breakers
   for(int b = g_total_obs - 1; b >= 0; b--) {
      double top = g_order_blocks[b].top + tolerance;
      double bot = g_order_blocks[b].bottom - tolerance;
      
      if(direction == "BUY" && g_order_blocks[b].is_bullish) {
         if(cur_price >= bot && cur_price <= top) {
            if(g_order_blocks[b].is_breaker) has_breaker = true;
            else                             has_ob = true;
            break;
         }
      }
      else if(direction == "SELL" && !g_order_blocks[b].is_bullish) {
         if(cur_price >= bot && cur_price <= top) {
            if(g_order_blocks[b].is_breaker) has_breaker = true;
            else                             has_ob = true;
            break;
         }
      }
   }
   
   // Evaluar Fair Value Gaps
   for(int f = g_total_fvgs - 1; f >= 0; f--) {
      double top = g_fvgs[f].top + tolerance;
      double bot = g_fvgs[f].bottom - tolerance;
      if(direction == "BUY" && g_fvgs[f].is_bullish && cur_price >= bot && cur_price <= top) {
         has_fvg = true;
         break;
      }
      else if(direction == "SELL" && !g_fvgs[f].is_bullish && cur_price >= bot && cur_price <= top) {
         has_fvg = true;
         break;
      }
   }
   
   // Si el usuario exige OB, Breaker o FVG
   bool ob_valid = (!InpUseOrderBlocks || has_ob || has_breaker);
   bool fvg_valid = (!InpUseFVGFilter || has_fvg);
   
   bool sweep_valid = (direction == "BUY") ? g_smc_liquidity_sweep_buy : g_smc_liquidity_sweep_sell;
   return (has_ob || has_breaker || has_fvg || sweep_valid);
}

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
                  // Ya se produjo un cierre parcial en esta posición
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

int OnInit() {
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_station_bridge.Init(InpStationSyncEnabled, InpStationWebhookUrl, InpStationApiKey);
   AutoTuneAssets();
   g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
   g_last_bar_time = iTime(_Symbol, _Period, 0);
   hMA     = iMA(_Symbol, PERIOD_H1,       InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hMA_HTF = iMA(_Symbol, InpHTFTimeframe, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRSI    = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   hADX    = iADX(_Symbol, _Period, 14);
   hATR    = iATR(_Symbol, _Period, 14);
   if(InpUseMicroTrigger) {
      hMA_Micro = iMA(_Symbol, InpMicroTriggerTimeframe, InpMicroTriggerEMA, 0, MODE_EMA, PRICE_CLOSE);
   }
   if(hMA == INVALID_HANDLE || hMA_HTF == INVALID_HANDLE ||
      hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE || hATR == INVALID_HANDLE ||
      (InpUseMicroTrigger && hMA_Micro == INVALID_HANDLE))
      return(INIT_FAILED);
   UpdateIndicatorCache();
   UpdateSMCStructures();
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
   
   // [V13.10] Diagnóstico de Capital, Contrato y Riesgo por Trade
   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double contract = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
   double cur_eq = AccountInfoDouble(ACCOUNT_EQUITY);
   double sample_sl_dist = (g_min_sl_price > 0) ? g_min_sl_price : (100 * _Point);
   double one_lot_loss = GetOneLotLoss(sample_sl_dist);
   double calc_loss_min_lot = one_lot_loss * min_vol;
   double risk_pct_min_lot = (cur_eq > 0) ? (calc_loss_min_lot / cur_eq) * 100.0 : 0.0;
   
   bool is_micro_account = (contract <= 10.0 || StringFind(_Symbol, "micro") >= 0 || StringFind(_Symbol, "m") == StringLen(_Symbol)-1 || StringFind(_Symbol, "MGC") >= 0);
   string acct_type_str = is_micro_account ? "MICRO" : "ESTANDAR";

   PrintFormat("[DIAGNOSTICO V13.50] Simbolo: %s (%s) | Contrato: %.0f | Lote Min: %.2f | Riesgo SL ($%.2f): $%.2f (%.1f%%) | Balance: $%.2f | Micro-Gatillo: %s (%s)",
               _Symbol, acct_type_str, contract, min_vol, sample_sl_dist, calc_loss_min_lot, risk_pct_min_lot, cur_eq,
               (InpUseMicroTrigger ? "ON" : "OFF"), EnumToString(InpMicroTriggerTimeframe));
   if(cur_eq > 0 && risk_pct_min_lot > InpMaxAllowedRiskPercent) {
      PrintFormat("[ADVERTENCIA CAPITAL] En cuenta %s, el lote minimo (%.2f) arriesga $%.2f (%.1f%% del capital > Max %.1f%%). Para reducir riesgo a <$1 usar cuenta Micro (%smicro) o pares Forex.",
                  acct_type_str, min_vol, calc_loss_min_lot, risk_pct_min_lot, InpMaxAllowedRiskPercent, _Symbol);
   }

   // [V15 INITIALIZATION & RECONCILIATION]
   UpdateDailyRiskMetrics();
   if(InpAutoReconcileOnInit) {
      ReconcileOpenPositions();
   }
   string preflight_err = "";
   bool preflight_ok = ValidateEnvironmentV15(preflight_err);
   PrintFormat("[V15 PRE-FLIGHT STATUS] %s %s", g_preflight_status_txt, (preflight_ok ? "✅" : ("⚠️ Razón: " + preflight_err)));

   EventSetTimer(1);
   Print("AURUM SNIPER INSTITUTIONAL V15 PRO Loaded.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(hMA); IndicatorRelease(hMA_HTF);
   IndicatorRelease(hRSI); IndicatorRelease(hADX); IndicatorRelease(hATR);
   if(hMA_Micro != INVALID_HANDLE) IndicatorRelease(hMA_Micro);
   EventKillTimer();
   CleanSMCVisuals();
   ObjectsDeleteAll(0, "lbl_");
   ObjectsDeleteAll(0, "tp_lvl_");
}

// [OPT #4 & V12.6]
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD || trans.type == TRADE_TRANSACTION_POSITION) {
      GestionarPosicionesPro();
   }
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
             double deal_comm = HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
              double deal_swap = HistoryDealGetDouble(trans.deal, DEAL_SWAP);
              ulong deal_order = (ulong)HistoryDealGetInteger(trans.deal, DEAL_ORDER);
              g_station_bridge.SendOrderClose(deal_order, InpMagicNumber, deal_sym, (g_last_trade_profit >= 0 ? "WIN" : "LOSS"), deal_price, g_last_trade_profit, deal_comm, deal_swap, deal_vol, "V15 Exit", result_tag);
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
// [V13.00] Filtro de Horario de Trading con soporte de Killzones CDMX y Rollover Guard
bool IsTradingSession(string &session_reason) {
   session_reason = "";
   
   // [V13.00] Protección contra Mercado Cerrado o Trading Deshabilitado por el Broker
   long trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(trade_mode == SYMBOL_TRADE_MODE_DISABLED || trade_mode == SYMBOL_TRADE_MODE_CLOSEONLY) {
      session_reason = "[Mercado Cerrado/Solo Cierre por Broker]";
      return false;
   }

   MqlDateTime dt_local;
   TimeLocal(dt_local);
   
   bool is_crypto = false;
   string sym = _Symbol; StringToUpper(sym);
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "ETH") >= 0 || StringFind(sym, "BITCOIN") >= 0 || StringFind(sym, "ETHEREUM") >= 0) {
      is_crypto = true;
   }
   bool is_metal = (StringFind(sym, "GOLD") >= 0 || StringFind(sym, "XAU") >= 0 || StringFind(sym, "SILVER") >= 0 || StringFind(sym, "XAG") >= 0);

   int current_min_of_day = dt_local.hour * 60 + dt_local.min;

   // [V13.80] Filtro de Fin de Semana para Criptomonedas (Evita bull/bear traps en Domingo)
   if(is_crypto && InpCryptoAvoidWeekendChop && dt_local.day_of_week == 0) {
      session_reason = "[Domingo Cripto: Evitando Trampas de Fin de Semana]";
      return false;
   }

   // [V14.2] Protección Permanente contra Rollover y Fines de Semana (Forex y Metales 24h)
   if(!is_crypto) {
      // Bloqueo total de Domingo para Forex y Metales (Mercado cerrado / apertura con spreads erráticos)
      if(dt_local.day_of_week == 0) {
         session_reason = "[Fin de Semana / Domingo Forex y Metales Cerrado]";
         return false;
      }
      MqlDateTime dt_srv;
      TimeCurrent(dt_srv);
      int srv_min = dt_srv.hour * 60 + dt_srv.min;
      // Ventana de Rollover del Servidor del Broker (23:55 a 00:05)
      if(srv_min >= 1435 || srv_min <= 5) {
         session_reason = StringFormat("[Rollover Broker Activo (%02d:%02d Servidor - Evitando Spreads Anómalos)]", dt_srv.hour, dt_srv.min);
         return false;
      }
   }

   // [V15.30] Filtro de Sesiones de Alta Liquidez CDMX (Londres + NY: 01:15 a 12:00 CDMX)
   // Obligatorio para Forex (EURUSD, GBPUSD, USDJPY) para erradicar perdidas nocturnas en Asia (20:00 - 01:14)
   bool is_forex = (!is_crypto && !is_metal);
   bool apply_killzone = InpUseHighLiquiditySession || is_forex;
   if(is_crypto && InpSessionFilterForexOnly) apply_killzone = false;
   if(is_metal && !InpSessionFilterMetals)    apply_killzone = false;

   if(apply_killzone) {
      int start_min = InpSessionStartHourCDMX * 60 + InpSessionStartMinCDMX;
      int end_min   = InpSessionEndHourCDMX * 60;
      if(current_min_of_day < start_min || current_min_of_day >= end_min) {
         session_reason = StringFormat("[Fuera Killzone CDMX (%02d:%02d-%02d:00, Actual %02d:%02d)]",
                                       InpSessionStartHourCDMX, InpSessionStartMinCDMX, InpSessionEndHourCDMX, dt_local.hour, dt_local.min);
         return false;
      }
   }
   
   // [V13.00] Filtro Especial de Viernes en Horario CDMX (01:15 - 11:00 CDMX)
   if(InpUseFridayFilter && dt_local.day_of_week == 5) {
      if(!is_crypto || !InpFridayFilterForexOnly) {
         int fri_start_min = InpFridayStartHourCDMX * 60 + InpSessionStartMinCDMX;
         int fri_end_min   = InpFridayEndHourCDMX * 60;
         if(current_min_of_day < fri_start_min || current_min_of_day >= fri_end_min) {
            session_reason = StringFormat("[Viernes Cierre CDMX (%02d:%02d-%02d:00, Actual %02d:%02d)]",
                                          InpFridayStartHourCDMX, InpSessionStartMinCDMX, InpFridayEndHourCDMX, dt_local.hour, dt_local.min);
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

// [OPT #4 & V13.70] Cooldown Inteligente con Anti-Cascade
bool CheckCooldownPass() {
   if(InpCooldownBars <= 0) return true;
   if(g_last_trade_close == 0) return true;
   int wait_bars = InpCooldownBars;
   if(InpSmartCooldown && g_last_trade_profit >= 0) {
      wait_bars = 1; // Si cerro en ganancia/BE, solo espera 1 barra de confirmacion
   } else if(g_last_trade_profit < -0.01) {
      // [V13.70] Cooldown estricto tras pérdida: mínimo 15 minutos (900 seg) para evitar ráfagas
      wait_bars = MathMax(InpCooldownBars, 2);
      if(TimeCurrent() - g_last_trade_close < 900) return false;
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
   // [V13.70] Equilibrio dinámico adaptativo con ADX (Permite compras de continuación)
   double eq_pct = InpEquilibriumPercent; // Base: 50%
   double adx = g_adx_cache;
   if(adx >= 25.0) {
      // En tendencia moderada (ADX>=25): flexibilizar 12%
      if(type == "BUY")  eq_pct = MathMin(eq_pct + 12.0, 62.0);
      if(type == "SELL") eq_pct = MathMax(eq_pct - 12.0, 38.0);
   }
   if(adx >= 35.0) {
      // En tendencia fuerte/parabólica (ADX>=35): permitir hasta 70% para compras y 30% para ventas
      if(type == "BUY")  eq_pct = MathMin(eq_pct + 8.0, 70.0);
      if(type == "SELL") eq_pct = MathMax(eq_pct - 8.0, 30.0);
   }
   double eq_price = h1_low + (range * (eq_pct / 100.0));
   
   if(type == "BUY")  return (cur_price <= eq_price); // Solo comprar en zona Descuento
   if(type == "SELL") return (cur_price >= eq_price); // Solo vender en zona Premium
   return true;
}

//+------------------------------------------------------------------+
// [V13.80] Confirmación de Acción del Precio (Vela de Giro y Absorción)
bool CheckPriceActionConfirmation(string direction, string &pa_reason) {
   pa_reason = "";
   double open1  = iOpen(_Symbol,  _Period, 1);
   double close1 = iClose(_Symbol, _Period, 1);
   double high1  = iHigh(_Symbol,  _Period, 1);
   double low1   = iLow(_Symbol,   _Period, 1);
   double total_range = high1 - low1;
   if(total_range <= 0) return true;

   bool is_crypto = (StringFind(_Symbol, "BTC") >= 0 || StringFind(_Symbol, "ETH") >= 0 || StringFind(_Symbol, "BITCOIN") >= 0);

   if(direction == "BUY") {
      double lower_wick = MathMin(open1, close1) - low1;
      double wick_ratio = lower_wick / total_range;
      bool is_green_reversal = (close1 > open1);
      // [V13.80] En Cripto, exigir que la vela verde cierre en la mitad superior del rango para validar demanda real
      if(is_crypto) {
         is_green_reversal = (close1 > open1) && (close1 >= (high1 + low1) * 0.5);
      }
      bool is_absorption_pinbar = (wick_ratio >= 0.30); // 30% o más de mecha inferior compradora
      
      if(!is_green_reversal && !is_absorption_pinbar) {
         pa_reason = "[Esperando Giro: Vela 1 aún cayendo sin rechazo]";
         return false;
      }
      return true;
   }
   else if(direction == "SELL") {
      double upper_wick = high1 - MathMax(open1, close1);
      double wick_ratio = upper_wick / total_range;
      bool is_red_reversal = (close1 < open1);
      // [V13.80] En Cripto, exigir que la vela roja cierre en la mitad inferior del rango para validar oferta real
      if(is_crypto) {
         is_red_reversal = (close1 < open1) && (close1 <= (high1 + low1) * 0.5);
      }
      bool is_absorption_pinbar = (wick_ratio >= 0.30); // 30% o más de mecha superior vendedora

      if(!is_red_reversal && !is_absorption_pinbar) {
         pa_reason = "[Esperando Giro: Vela 1 aún subiendo sin rechazo]";
         return false;
      }
      return true;
   }
   return true;
}

//+------------------------------------------------------------------+
// [V13.40] Confirmación de Micro-Gatillo Estricto en M1
bool CheckMicroTrigger(string direction, string &micro_reason) {
   micro_reason = "";
   if(!InpUseMicroTrigger) return true;
   if(_Period <= InpMicroTriggerTimeframe) return true;

   double micro_c1 = iClose(_Symbol, InpMicroTriggerTimeframe, 1);
   double micro_o1 = iOpen(_Symbol,  InpMicroTriggerTimeframe, 1);
   double micro_h1 = iHigh(_Symbol,  InpMicroTriggerTimeframe, 1);
   double micro_l1 = iLow(_Symbol,   InpMicroTriggerTimeframe, 1);
   double micro_range = micro_h1 - micro_l1;

   double ma_buf[];
   ArraySetAsSeries(ma_buf, true);
   double ma_val = 0;
   if(hMA_Micro != INVALID_HANDLE && CopyBuffer(hMA_Micro, 0, 1, 1, ma_buf) > 0) {
      ma_val = ma_buf[0];
   }

   if(direction == "BUY") {
      bool bull_close     = (micro_c1 > micro_o1);
      bool above_ma       = (ma_val > 0) ? (micro_c1 >= ma_val) : true;
      double lower_wick   = (micro_range > 0) ? ((MathMin(micro_o1, micro_c1) - micro_l1) / micro_range) : 0;
      bool rejection_wick = (lower_wick >= 0.35);

      // Exige giro real: (Vela verde Y sobre EMA) O (Fuerte mecha de absorción en soporte)
      if(!((bull_close && above_ma) || rejection_wick)) {
         micro_reason = "[Micro-Gatillo M1 Aún Cayendo sin Giro Confirmado]";
         return false;
      }
      return true;
   }
   else if(direction == "SELL") {
      bool bear_close     = (micro_c1 < micro_o1);
      bool below_ma       = (ma_val > 0) ? (micro_c1 <= ma_val) : true;
      double upper_wick   = (micro_range > 0) ? ((micro_h1 - MathMax(micro_o1, micro_c1)) / micro_range) : 0;
      bool rejection_wick = (upper_wick >= 0.35);

      // Exige giro real: (Vela roja Y bajo EMA) O (Fuerte mecha de rechazo en resistencia)
      if(!((bear_close && below_ma) || rejection_wick)) {
         micro_reason = "[Micro-Gatillo M1 Aún Subiendo sin Giro Confirmado]";
         return false;
      }
      return true;
   }
   return true;
}

//+------------------------------------------------------------------+
void DebugSignalMiss(string direction, bool trend, bool in_zone,
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
}

//+------------------------------------------------------------------+
//| Main Engine V13.10                                               |
//+------------------------------------------------------------------+
void OnTick() {
   bool new_bar = IsNewBar();
   if(new_bar) { UpdateIndicatorCache(); UpdateSMCStructures(); }
   else        UpdateATRCache();
   CheckAndResetDaily();
   
   // [V15 RISK GUARD & RECONCILIATION ON TICK]
   UpdateDailyRiskMetrics();
   ReconcileOpenPositions();
   
   if(g_daily_killswitch_active || CheckDailyDrawdown()) {
      Comment(StringFormat("\n⚠️ [V15 RISK GUARD] MAX DRAWDOWN / LIMITE DIARIO ALCANZADO (P&L Hoy: $%.2f). Operaciones pausadas.", g_daily_closed_pnl + g_daily_floating_pnl));
      GestionarPosicionesPro();
      return;
   } else if(g_consecutive_cooldown_until > TimeCurrent()) {
      Comment(StringFormat("\n⏳ [V15 DISYUNTOR] Enfriamiento tras %d pérdidas consecutivas. Pausa activa hasta %s.", g_consecutive_losses, TimeToString(g_consecutive_cooldown_until, TIME_MINUTES)));
   } else {
      Comment("");
   }
   
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

   if(InpUseEMAInclinacion) {
      trend_bull = trend_bull && (ma_h1 > g_ma_h1_p2_cache);
      trend_bear = trend_bear && (ma_h1 < g_ma_h1_p2_cache);
   }

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

   // [V13.70] Modo Rebote en Rango (Lateral S/R Mean Reversion)
   // Si el mercado no tiene tendencia direccional clara pero está en rango con baja volatilidad (ADX < 25)
   bool range_bull = false;
   bool range_bear = false;
   if(!trend_bull && !trend_bear && InpAllowRangeTrading && adx < 25.0) {
      range_bull = true; // Permite compra si está en zona de Descuento extrema + mecha de absorción M1
      range_bear = true; // Permite venta si está en zona Premium extrema + mecha de rechazo M1
   }

   bool in_zone_buy  = IsInZone("BUY",  ma_h1, adx, atr);
   bool in_zone_sell = IsInZone("SELL", ma_h1, adx, atr);
   bool is_trap_buy  = InpUseLiquidityTraps ? CheckLiquidityTrap("BUY")  : false;
   bool is_trap_sell = InpUseLiquidityTraps ? CheckLiquidityTrap("SELL") : false;

   bool discount_buy_ok  = IsInDiscountPremiumZone("BUY");
   bool discount_sell_ok = IsInDiscountPremiumZone("SELL");

   bool buy_zone_ok  = (in_zone_buy  || is_trap_buy)  && discount_buy_ok;
   bool sell_zone_ok = (in_zone_sell || is_trap_sell) && discount_sell_ok;

   // [V13.70] RSI Adaptativo en Pullback de Tendencia:
   // En tendencia alcista fuerte, el pullback suele soportarse en RSI 45 - 52 (no en < 38).
   // Relajamos progresivamente para no rechazar compras de tendencia sanas.
   double eff_rsi_oversold   = trend_bull ? 48.0 : g_rsi_oversold;
   double eff_rsi_overbought = trend_bear ? 52.0 : g_rsi_overbought;
   if(adx >= 25.0) {
      if(trend_bull) eff_rsi_oversold   += 4.0; // Hasta 52.0 en tendencia moderada
      if(trend_bear) eff_rsi_overbought -= 4.0; // Hasta 48.0 en tendencia moderada
   }
   if(adx >= 35.0) {
      if(trend_bull) eff_rsi_oversold   += 3.0; // Hasta 55.0 en tendencia fuerte
      if(trend_bear) eff_rsi_overbought -= 3.0; // Hasta 45.0 en tendencia fuerte
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

   // [V13.10] Verificación de Micro-Gatillo M1
   string micro_reason_buy = "";
   bool micro_buy_ok = CheckMicroTrigger("BUY", micro_reason_buy);
   string micro_reason_sell = "";
   bool micro_sell_ok = CheckMicroTrigger("SELL", micro_reason_sell);

   // [V13.40] Verificación de Acción del Precio (Giro / Absorción en M15)
   string pa_reason_buy = "";
   bool pa_buy_ok = CheckPriceActionConfirmation("BUY", pa_reason_buy);
   string pa_reason_sell = "";
   bool pa_sell_ok = CheckPriceActionConfirmation("SELL", pa_reason_sell);

   if(daily_limit_reached)
      Comment("\nMETA DIARIA ("+IntegerToString(g_daily_trades)+"/"+IntegerToString(InpMaxDailyTrades)+"). HASTA MANANA.");

   bool is_spike_buy  = buy_zone_ok  ? IsMomentumSpike("BUY")  : false;
   bool is_spike_sell = sell_zone_ok ? IsMomentumSpike("SELL") : false;

   bool smc_struct_buy_ok  = IsSMCStructureAligned("BUY");
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
                   pa_sell_ok, pa_reason_sell, smc_struct_sell_ok, opposing_poi_sell);

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

   // [V13.70] Filtro Anti-Noticias por Volatilidad Extrema Multi-Activo (ATR y Vela Anómala)
   bool is_news_volatility = (g_gold_mode_active && InpMaxAllowedATR > 0 && atr > InpMaxAllowedATR);
   if(!is_news_volatility && atr > 0) {
      double bar1_range = iHigh(_Symbol, _Period, 1) - iLow(_Symbol, _Period, 1);
      if(bar1_range > atr * 2.8) is_news_volatility = true; // Vela de impacto macro anómala
   }

   bool has_ob_buy = false, has_brk_buy = false, has_fvg_buy = false;
   bool smc_buy_ok = IsInSMCInstitutionalZone("BUY", ask, has_ob_buy, has_brk_buy, has_fvg_buy);
   bool can_buy = (trend_bull || (range_bull && (is_trap_buy || g_smc_liquidity_sweep_buy))) && buy_zone_ok && (!InpUseSMCStructures || smc_buy_ok || g_smc_liquidity_sweep_buy) && smc_struct_buy_ok && !opposing_poi_buy && (rsi < eff_rsi_oversold) && (adx > g_adx_threshold) && !is_spike_buy && !usd_corr_blocked_buy && micro_buy_ok && pa_buy_ok && !is_news_volatility;
   string preflight_buy_fail = "";
   bool v15_buy_ready = ValidateEnvironmentV15(preflight_buy_fail);

   if(can_buy && v15_buy_ready) {
      // [V15] SL acotado entre mínimo ($10) y techo máximo ($18) para ratios óptimos
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      if(g_max_sl_price > 0 && sl_dist > g_max_sl_price) sl_dist = g_max_sl_price;
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(ask - sl_dist, _Digits);
      double tp = NormalizeDouble(ask + tp_dist, _Digits);
      CheckStops(sl, tp, true);
      double actual_risk_usd = 0, actual_risk_pct = 0;
      double trade_lot = CalculateLotSize(sl_dist, actual_risk_usd, actual_risk_pct);
      if(trade_lot > 0) {
         int usd_dir_buy = GetUSDDirection(_Symbol, "BUY");
         if(usd_dir_buy != 0) GlobalVariableSet("AURUM_USD_DISPATCH_TIME", (double)TimeCurrent());
         if(trade.Buy(trade_lot, _Symbol, ask, sl, tp, "Aurum V15 Sniper")) {
            ulong t_ticket = trade.ResultOrder();
            g_station_bridge.SendOrderOpen(t_ticket, InpMagicNumber, _Symbol, "BUY", ask, sl, tp, trade_lot, actual_risk_pct, "Aurum V15 Sniper");
            g_daily_trades++;
            PrintFormat("[COMPRA%s] Lote:%.2f SL:%.2f TP:%.2f | Riesgo: -$%.2f (%.1f%%) | SL_dist:%.1f pips (%.0f pts) | ATR:%.1f pips | R:R 1:%.1f%s%s",
                        (trend_bull ? "" : " RANGO"), trade_lot, sl, tp, actual_risk_usd, actual_risk_pct, sl_dist, sl_dist/_Point, atr, g_risk_reward,
                        (InpUseMicroTrigger ? " [M1-TRIGGER OK]" : ""),
                        (g_consecutive_losses >= 2 ? " [ANTI-CASCADE]": ""));
         }
      }
   }
   bool has_ob_sell = false, has_brk_sell = false, has_fvg_sell = false;
   bool smc_sell_ok = IsInSMCInstitutionalZone("SELL", bid, has_ob_sell, has_brk_sell, has_fvg_sell);
   bool can_sell = (trend_bear || (range_bear && (is_trap_sell || g_smc_liquidity_sweep_sell))) && sell_zone_ok && (!InpUseSMCStructures || smc_sell_ok || g_smc_liquidity_sweep_sell) && smc_struct_sell_ok && !opposing_poi_sell && (rsi > eff_rsi_overbought) && (adx > g_adx_threshold) && !is_spike_sell && !usd_corr_blocked_sell && micro_sell_ok && pa_sell_ok && !is_news_volatility;
   string preflight_sell_fail = "";
   bool v15_sell_ready = ValidateEnvironmentV15(preflight_sell_fail);

   if(can_sell && v15_sell_ready) {
      // [V15] SL acotado entre mínimo ($10) y techo máximo ($18)
      double sl_dist = MathMax(atr * g_atr_multiplier, g_min_sl_price);
      if(g_max_sl_price > 0 && sl_dist > g_max_sl_price) sl_dist = g_max_sl_price;
      double tp_dist = sl_dist * g_risk_reward;
      double sl = NormalizeDouble(bid + sl_dist, _Digits);
      double tp = NormalizeDouble(bid - tp_dist, _Digits);
      CheckStops(sl, tp, false);
      double actual_risk_usd = 0, actual_risk_pct = 0;
      double trade_lot = CalculateLotSize(sl_dist, actual_risk_usd, actual_risk_pct);
      if(trade_lot > 0) {
         int usd_dir_sell = GetUSDDirection(_Symbol, "SELL");
         if(usd_dir_sell != 0) GlobalVariableSet("AURUM_USD_DISPATCH_TIME", (double)TimeCurrent());
         if(trade.Sell(trade_lot, _Symbol, bid, sl, tp, "Aurum V15 Sniper")) {
            g_daily_trades++;
            PrintFormat("[VENTA%s] Lote:%.2f SL:%.2f TP:%.2f | Riesgo: -$%.2f (%.1f%%) | SL_dist:%.1f pips (%.0f pts) | ATR:%.1f pips | R:R 1:%.1f%s%s",
                        (trend_bear ? "" : " RANGO"), trade_lot, sl, tp, actual_risk_usd, actual_risk_pct, sl_dist, sl_dist/_Point, atr, g_risk_reward,
                        (InpUseMicroTrigger ? " [M1-TRIGGER OK]" : ""),
                        (g_consecutive_losses >= 2 ? " [ANTI-CASCADE]": ""));
         }
      }
   }
}

void OnTimer() {
   GestionarPosicionesPro();
   UpdateDashboard();
 }

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
   if(StringFind(sym, "BTC") >= 0 || StringFind(sym, "BITCOIN") >= 0) return 500.0;
   if(StringFind(sym, "ETH") >= 0 || StringFind(sym, "ETHEREUM") >= 0) return 40.0;
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

      // [V13.70] Aislamiento Estricto por Símbolo:
      // Cada instancia de EA gestiona ÚNICAMENTE las posiciones de su propio gráfico (_Symbol).
      // Evita colisiones de SL/TP y que un chart de Forex sobreescriba el SL del Oro.
      if(!is_current_symbol) continue;

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
         if(profit_R >= g_step3_trigger_r) {
            // [V12.97] Si InpCloseOnTP3 está activo, cerrar 100% de la posición en TP3
            if(InpCloseOnTP3) {
               if(ticket > 0 && PositionSelectByTicket(ticket)) {
                  if(trade.PositionClose(ticket)) {
                     Print("[CIERRE TOTAL TP3] Ticket ",ticket," ",_Symbol," Profit: ",DoubleToString(profit_R,2),"R alcanzado. Posición 100% cerrada con éxito.");
                     continue;
                  }
               }
            }
            double locked_dist = g_step3_lock_r * r_dist;
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
            phase_name = StringFormat("FASE 3 (%.1fR+ -> SL a +%.1fR / Runner)", g_step3_trigger_r, g_step3_lock_r);
         }
         // FASE 2: 1.8R Alcanzado (Bloquea +1.0R firme)
         else if(profit_R >= g_step2_trigger_r) {
            double locked_dist = g_step2_lock_r * r_dist;
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + locked_dist) : (entry - locked_dist);
            phase_name = StringFormat("FASE 2 (%.1fR -> SL a +%.1fR Asegurado)", g_step2_trigger_r, g_step2_lock_r);
         }
         // FASE 1.5: +1.0R Alcanzado (Bloquea +0.4R en verde, evita escape del trade)
         else if(profit_R >= g_step1_5_trigger_r) {
            double locked_dist = g_step1_5_lock_r * r_dist;
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + locked_dist) : (entry - locked_dist);
            phase_name = StringFormat("FASE 1.5 (%.1fR -> SL a +%.1fR Asegurado)", g_step1_5_trigger_r, g_step1_5_lock_r);
         }
         // FASE 1: Trigger BE Alcanzado (SL a Break-Even + lock pips)
         else if(profit_R >= g_step1_trigger_r) {
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + lock_dist) : (entry - lock_dist);
            phase_name = StringFormat("FASE 1 (%.1fR/BE -> SL a Entrada Protegida)", g_step1_trigger_r);

            // Cierre parcial en Fase 1 si está habilitado (ahora también en trades manuales gestionados)
            if(InpUsePartials && (pos_magic == MAGIC_NUMBER || InpManageManualTrades) && !IsPartialAlreadyClosed(ticket)) {
               double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
               double pct_mult = (g_partial_percent > 0 && g_partial_percent <= 90.0) ? (g_partial_percent / 100.0) : 0.50;
               double calc_vol = NormalizeDouble(vol * pct_mult, 2);
               double partial  = (step_vol > 0) ? MathFloor(calc_vol / step_vol) * step_vol : calc_vol;
               if(partial >= min_vol && (vol - partial) >= min_vol) {
                  if(ticket > 0 && PositionSelectByTicket(ticket)) {
                     if(trade.PositionClosePartial(ticket, partial)) {
                        MarkPartialClosed(ticket);
                        PrintFormat("[PARCIAL Ticket %d] Vol:%.2f (%.0f%%) cerrado a +%.1fR. Restante: %.2f lote",
                                    ticket, partial, pct_mult * 100.0, g_step1_trigger_r, vol - partial);
                     }
                  }
               } else {
                  MarkPartialClosed(ticket);
               }
            }
         }
         // [V14.3] FASE 0.5R: Micro-Lock Temprano (+0.5R ~ $3.5-$4 USD) - Cierre 50% y SL a BE protegido
         else if(InpUseMicroLock05R && profit_R >= g_microlock_trigger_r) {
            double lock_05_dist = InpMicroLockLockPips * _Point;
            target_sl = (type == POSITION_TYPE_BUY) ? (entry + lock_05_dist) : (entry - lock_05_dist);
            phase_name = StringFormat("FASE 0.5R (Micro-Lock %.1fR/BE -> SL Protegido y Parcial %.0f%%)", g_microlock_trigger_r, g_microlock_pct);

            // Cierre parcial temprano si aún no se ha tomado parcial
            if(InpUsePartials && (pos_magic == MAGIC_NUMBER || InpManageManualTrades) && !IsPartialAlreadyClosed(ticket)) {
               double min_vol  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
               double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
               double pct_mult = (g_microlock_pct > 0 && g_microlock_pct <= 90.0) ? (g_microlock_pct / 100.0) : 0.50;
               double calc_vol = NormalizeDouble(vol * pct_mult, 2);
               double partial  = (step_vol > 0) ? MathFloor(calc_vol / step_vol) * step_vol : calc_vol;
               if(partial >= min_vol && (vol - partial) >= min_vol) {
                  if(ticket > 0 && PositionSelectByTicket(ticket)) {
                     if(trade.PositionClosePartial(ticket, partial)) {
                        MarkPartialClosed(ticket);
                        PrintFormat("[PARCIAL MICRO-LOCK Ticket %d] Vol:%.2f (%.0f%%) cerrado a +%.2fR. Restante: %.2f lote",
                                    ticket, partial, pct_mult * 100.0, profit_R, vol - partial);
                     }
                  }
               } else {
                  MarkPartialClosed(ticket);
               }
            }
         }

         // [V14.1] Candle-Trailing Stop: Si el trade lleva >= InpCandleTrailAfterBars en curso y ya alcanzó al menos Fase 0.5R / Fase 1
         if(InpUseCandleTrailing && (profit_R >= g_step1_trigger_r || (InpUseMicroLock05R && profit_R >= g_microlock_trigger_r)) && target_sl > 0) {
            datetime open_time = (datetime)PositionGetInteger(POSITION_TIME);
            int bars_held = iBarShift(_Symbol, _Period, open_time);
            if(bars_held >= InpCandleTrailAfterBars) {
               int bars_to_check = MathMax(InpCandleTrailBars, 1);
               if(type == POSITION_TYPE_BUY) {
                  int lowest_bar = iLowest(_Symbol, _Period, MODE_LOW, bars_to_check, 1);
                  if(lowest_bar > 0) {
                     double candle_sl = NormalizeDouble(iLow(_Symbol, _Period, lowest_bar) - (5 * _Point), _Digits);
                     double min_allowed_sl = entry + lock_dist;
                     if(candle_sl > target_sl && candle_sl >= min_allowed_sl) {
                        target_sl = candle_sl;
                        phase_name = StringFormat("CANDLE-TRAIL (%d barras) SL->%.2f", bars_held, target_sl);
                     }
                  }
               } else if(type == POSITION_TYPE_SELL) {
                  int highest_bar = iHighest(_Symbol, _Period, MODE_HIGH, bars_to_check, 1);
                  if(highest_bar > 0) {
                     double candle_sl = NormalizeDouble(iHigh(_Symbol, _Period, highest_bar) + (5 * _Point), _Digits);
                     double max_allowed_sl = entry - lock_dist;
                     if(candle_sl < target_sl && candle_sl <= max_allowed_sl) {
                        target_sl = candle_sl;
                        phase_name = StringFormat("CANDLE-TRAIL (%d barras) SL->%.2f", bars_held, target_sl);
                     }
                  }
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
               if(InpUsePartials && (pos_magic == MAGIC_NUMBER || InpManageManualTrades) && !IsPartialAlreadyClosed(ticket)) {
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
   
   double tp05 = (type == POSITION_TYPE_BUY) ? (entry + InpMicroLock05Trigger * r_dist) : (entry - InpMicroLock05Trigger * r_dist);
   double tp1  = (type == POSITION_TYPE_BUY) ? (entry + InpStep1_TriggerR * r_dist) : (entry - InpStep1_TriggerR * r_dist);
   double tp2  = (type == POSITION_TYPE_BUY) ? (entry + InpStep2_TriggerR * r_dist) : (entry - InpStep2_TriggerR * r_dist);
   double tp3  = (type == POSITION_TYPE_BUY) ? (entry + InpStep3_TriggerR * r_dist) : (entry - InpStep3_TriggerR * r_dist);
   
   tp05 = NormalizeDouble(tp05, _Digits);
   tp1  = NormalizeDouble(tp1, _Digits);
   tp2  = NormalizeDouble(tp2, _Digits);
   tp3  = NormalizeDouble(tp3, _Digits);
   
   if(InpUseMicroLock05R) {
      string tp05_tt = StringFormat("Micro-Lock (%.1fR / Parcial %.0f%% & BE): %.2f | %s", InpMicroLock05Trigger, InpMicroLock05Pct, tp05, (profit_R >= InpMicroLock05Trigger ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp05 - cur_price)/_Point)));
      DrawChartLine("tp_lvl_05", tp05, clrOrange, STYLE_DOT, 1, tp05_tt);
   } else {
      ObjectDelete(0, "tp_lvl_05");
      ObjectDelete(0, "tp_lvl_txt05");
   }

   string tp1_tt = StringFormat("TP1 (%.1fR / BE & Parcial): %.2f | %s", InpStep1_TriggerR, tp1, (profit_R >= InpStep1_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp1 - cur_price)/_Point)));
   string tp2_tt = StringFormat("TP2 (%.1fR / Lock +%.1fR): %.2f | %s", InpStep2_TriggerR, InpStep2_LockR, tp2, (profit_R >= InpStep2_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp2 - cur_price)/_Point)));
   string tp3_tt = StringFormat("TP3 (%.1fR / Runner): %.2f | %s", InpStep3_TriggerR, tp3, (profit_R >= InpStep3_TriggerR ? "ALCANZADO" : StringFormat("Faltan %.1f pts", MathAbs(tp3 - cur_price)/_Point)));
   
   DrawChartLine("tp_lvl_1", tp1, clrGold, STYLE_DASH, 2, tp1_tt);
   DrawChartLine("tp_lvl_2", tp2, clrDeepSkyBlue, STYLE_DASH, 2, tp2_tt);
   DrawChartLine("tp_lvl_3", tp3, clrLime, STYLE_SOLID, 2, tp3_tt);
   
   datetime bar0_time = iTime(_Symbol, _Period, 0);
   if(bar0_time == 0) bar0_time = TimeCurrent();
   
   if(InpUseMicroLock05R) {
      DrawChartText("tp_lvl_txt05", bar0_time, tp05, StringFormat("  🔒 Micro-Lock (%.1fR/BE): ", InpMicroLock05Trigger) + DoubleToString(tp05, _Digits) + (profit_R >= InpMicroLock05Trigger ? " [ALCANZADO ✅]" : ""), clrOrange);
   }
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
   DrawLabel("lbl_Title", "AURUM SNIPER INSTITUTIONAL V15 (PRO)", 20, y, clrGold, 12); y += 22;
   
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

   DrawLabel("lbl_V15_Health", "Validación: " + g_preflight_status_txt, 20, y, g_preflight_status_clr, 10); y += 20;
   long sym_trade_mode = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   bool sym_enabled  = (sym_trade_mode != SYMBOL_TRADE_MODE_DISABLED);
   bool algo_allowed = sym_enabled && TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) &&
                       MQLInfoInteger(MQL_TRADE_ALLOWED) &&
                       AccountInfoInteger(ACCOUNT_TRADE_ALLOWED) && AccountInfoInteger(ACCOUNT_TRADE_EXPERT);
   string ts = !sym_enabled ? ("Estado: SIMBOLO BLOQUEADO (usar "+_Symbol+"micro)")
             : (algo_allowed ? "Estado: PERMITIDO Y OPERATIVO" : "Estado: DESACTIVADO (Revisar MT5/F7)");
   DrawLabel("lbl_TradeStatus", ts, 20, y, algo_allowed ? clrLime : clrRed, 10); y += 20;
   if(g_gold_mode_active) { DrawLabel("lbl_AssetMode", "MODO ORO / MICRO-ORO: ACTIVO", 20, y, clrOrange, 10); y += 20; }
   else ObjectDelete(0, "lbl_AssetMode");
   
   string trail_mode_txt = InpUseStepTrailing ? StringFormat("FASES R (BE %.1fR -> +%.1fR -> TP3 %.1fR)", InpStep1_TriggerR, InpStep2_LockR, InpStep3_TriggerR) : (InpUseTrailingStop ? "TRAILING CONTINUO" : "SOLO BREAK-EVEN");
   DrawLabel("lbl_TrailMode", "Gestión SL: " + trail_mode_txt, 20, y, InpUseStepTrailing ? clrLime : clrSilver, 10); y += 20;

   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, y, trend_clr, 10); y += 20;

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
   }
   
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

   if(InpUseMicroTrigger) {
      DrawLabel("lbl_MicroTrigger", "Micro-Gatillo ("+EnumToString(InpMicroTriggerTimeframe)+"): ACTIVO (EMA "+IntegerToString(InpMicroTriggerEMA)+")", 20, y, clrDeepSkyBlue, 10); y += 20;
   } else {
      ObjectDelete(0, "lbl_MicroTrigger");
   }
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
   bool is_metal_dash  = (StringFind(_Symbol, "GOLD") >= 0 || StringFind(_Symbol, "XAU") >= 0 || StringFind(_Symbol, "SILVER") >= 0 || StringFind(_Symbol, "XAG") >= 0);
   int cur_min_dash = dt_dash.hour * 60 + dt_dash.min;

   bool apply_kz_dash = InpUseHighLiquiditySession;
   if(is_crypto_dash && InpSessionFilterForexOnly) apply_kz_dash = false;
   if(is_metal_dash && !InpSessionFilterMetals)    apply_kz_dash = false;

   if(apply_kz_dash) {
      bool is_sun = (dt_dash.day_of_week == 0);
      int start_min_dash = InpSessionStartHourCDMX * 60 + InpSessionStartMinCDMX;
      int end_min_dash   = InpSessionEndHourCDMX * 60;
      bool in_kz = (!is_sun && cur_min_dash >= start_min_dash && cur_min_dash < end_min_dash);
      string kz_txt = StringFormat("Killzone CDMX (%02d:%02d-%02d:00): %s (%02d:%02d)",
                                   InpSessionStartHourCDMX, InpSessionStartMinCDMX, InpSessionEndHourCDMX,
                                   (is_sun ? "DOMINGO CERRADO" : in_kz ? "ACTIVA (Londres/NY)" : "FUERA DE SESION (Asia)"),
                                   dt_dash.hour, dt_dash.min);
      DrawLabel("lbl_Killzone", kz_txt, 20, y, (in_kz ? clrLime : clrOrange), 10); y += 20;
   } else {
      MqlDateTime dt_srv_dash; TimeCurrent(dt_srv_dash);
      int srv_min_dash = dt_srv_dash.hour * 60 + dt_srv_dash.min;
      bool in_rollover = (!is_crypto_dash && (srv_min_dash >= 1435 || srv_min_dash <= 5));
      string kz_txt = in_rollover ? "Horario: PAUSA POR ROLLOVER DEL BROKER" : "Horario: 24 Horas Activo (Protección Rollover ON)";
      DrawLabel("lbl_Killzone", kz_txt, 20, y, (in_rollover ? clrOrange : clrLime), 10); y += 20;
   }

   if(dt_dash.day_of_week == 5 && InpUseFridayFilter) {
      if(!is_crypto_dash || !InpFridayFilterForexOnly) {
         int fri_start_dash = InpFridayStartHourCDMX * 60 + InpSessionStartMinCDMX;
         int fri_end_dash   = InpFridayEndHourCDMX * 60;
         bool in_fri = (cur_min_dash >= fri_start_dash && cur_min_dash < fri_end_dash);
         string fri_txt = StringFormat("Viernes CDMX (%02d:%02d-%02d:00): %s (%02d:%02d)",
                                       InpFridayStartHourCDMX, InpSessionStartMinCDMX, InpFridayEndHourCDMX,
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

   // [V15.20 Anti-Race Condition] Si otra divisa USD disparó hace menos de 15 segundos, bloquear disparo concurrente
   if(GlobalVariableCheck("AURUM_USD_DISPATCH_TIME")) {
      datetime last_disp = (datetime)GlobalVariableGet("AURUM_USD_DISPATCH_TIME");
      if(TimeCurrent() - last_disp < 15) {
         conflict_sym = "MUTEX_USD_CONCURRENTE";
         return true;
      }
   }
   
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
