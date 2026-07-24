//+------------------------------------------------------------------+
//|                                           AurumSniper_V11.mq5   |
//|                    Copyright 2026, Aurum Capital                 |
//|           FUSION: V9 Sniper Logic + V1.05 Capital Management     |
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "11.00"
#property strict

#include <Trade\Trade.mqh>

// ==================== INPUTS ====================
input group "=== GESTION DE RIESGO AVANZADA (V1.05) ==="
input double   InpLotSize       = 0.02;     // Lote Base
input double   InpMaxDailyLoss  = 3.0;      // % Max Perdida Diaria Shield
input bool     InpAutoDailyReset= true;     // Resetear contador cada dia

input group "=== ESTRATEGIA SNIPER (V9 Engine) ==="
input int      InpMaxSpread     = 25;       // Spread maximo (M1 Scalping)
input int      InpDistanciaPuntos = 100;    // Distancia a Zona H1
input int      InpEMAPeriod     = 200;      // Tendencia H1
input int      InpRSIOverbought = 70;       // RSI SobreVenta (>70 Venta)
input int      InpRSIOversold   = 30;       // RSI Sobrecompra (<30 compra)
input int      InpADXThreshold  = 20;       // Volatilidad Minima

input group "=== GESTION DE SALIDA PRO ==="
input double   InpATRMultiplier = 2.0;      // Multiplicador SL (ATR)
input bool     InpUsePartials   = true;     // Cerrar 50% al 1:1
input int      InpRiskReward    = 2;        // Ratio riesgo/beneficio
input int      InpBE_Trigger    = 100;      // Puntos para BreakEven
input int      InpMaxDailyTrades= 16;       // Max Operaciones Diarias
input bool     InpUseTrailingStop = true;   // Usar Trailing Stop (Recorrer Ganancias)
input int      InpTrailingStart   = 150;    // Puntos para iniciar Trailing (despues del BE)
input int      InpTrailingStep    = 50;     // Puntos de paso para mover SL

input group "=== OPTIMIZACION DE ACTIVOS ==="
input bool     InpAutoGoldSettings = true;  // Auto-Ajustar parámetros para ORO (XAUUSD)
input bool     InpAutoForexSettings = true; // Auto-Ajustar EURUSD, USDJPY y GBPUSD

// ==================== GLOBALES ====================
CTrade trade;
int hMA, hRSI, hADX, hATR;
double g_start_equity = 0;
datetime g_last_reset_day = 0;
int g_daily_trades = 0; // Contador de trades hoy
const int MAGIC_NUMBER = 777999;

// Parámetros Dinámicos (Auto-ajustables en OnInit)
double g_lot_size;
int g_max_spread;
int g_distancia_puntos;
int g_be_trigger;
int g_adx_threshold;
double g_atr_multiplier;
int g_rsi_overbought;
int g_rsi_oversold;
bool g_gold_mode_active = false;
double g_momentum_spike_multiplier;
double g_risk_reward;

// Módulo de Auto-Detección y Configuración para ORO
void AutoTuneAssets() {
   g_lot_size = InpLotSize;
   g_max_spread = InpMaxSpread;
   g_distancia_puntos = InpDistanciaPuntos;
   g_be_trigger = InpBE_Trigger;
   g_adx_threshold = InpADXThreshold;
   g_atr_multiplier = InpATRMultiplier;
   g_rsi_overbought = InpRSIOverbought;
   g_rsi_oversold = InpRSIOversold;
   g_gold_mode_active = false;
   g_momentum_spike_multiplier = 3.0; // Default
   g_risk_reward = InpRiskReward;     // Default

   if(InpAutoGoldSettings) {
      string symbol = _Symbol;
      StringToUpper(symbol);
      if(StringFind(symbol, "XAU") >= 0 || StringFind(symbol, "GOLD") >= 0) {
         g_gold_mode_active = true;
         g_lot_size = 0.01;            // Reducir riesgo para cuenta pequeña ($200 equidad)
         g_max_spread = 60;            // Permitir operar con spreads normales de Oro (hasta 6.0 pips / 60 ptos)
         g_distancia_puntos = 400;     // Dar margen de búsqueda de zona H1/EMA en Oro (400 puntos / $4.00)
         g_be_trigger = 350;           // Mover SL a BE tras $3.50 de ganancia
         g_adx_threshold = 25;         // Exigir mayor fuerza direccional (ADX > 25)
         g_atr_multiplier = 2.5;       // SL más amplio (2.5x ATR) por alta volatilidad
         g_rsi_oversold = 35;          // RSI de compra en retroceso más sensible
         g_rsi_overbought = 65;        // RSI de venta en retroceso más sensible
         Print("🦅 [AURUM GOLD MODE] Símbolo de Oro detectado. Ajustes optimizados cargados.");
      }
   }

   if(InpAutoForexSettings) {
      string symbol = _Symbol;
      StringToUpper(symbol);
      if(StringFind(symbol, "EURUSD") >= 0) {
         g_distancia_puntos = 100;     // Pegado a la EMA
         g_rsi_oversold = 45;          // Compra en rebote temprano
         g_rsi_overbought = 80;        // Venta
         g_atr_multiplier = 2.5;       // SL más amplio para dar respiro
         g_risk_reward = 1.5;          // Ratio Beneficio ajustado
         g_momentum_spike_multiplier = 4.5; // Relajar filtro vela elefante
         Print("🦅 [AURUM FOREX MODE] Símbolo EURUSD detectado. Ajustes optimizados cargados.");
      }
      else if(StringFind(symbol, "USDJPY") >= 0) {
         g_distancia_puntos = 300;     // Tendencia más amplia
         g_rsi_oversold = 40;          // Compra
         g_rsi_overbought = 60;        // Venta
         g_be_trigger = 150;           // BreakEven a 150 puntos para evitar salidas prematuras por ruido
         g_atr_multiplier = 2.5;       // SL más amplio
         g_risk_reward = 1.5;          // TP más realista para asegurar ganancias
         g_momentum_spike_multiplier = 4.0; // Relajar un poco vela elefante
         Print("🦅 [AURUM FOREX MODE] Símbolo USDJPY detectado. Ajustes optimizados cargados.");
      }
      else if(StringFind(symbol, "GBPUSD") >= 0) {
         g_distancia_puntos = 150;     // Un poco más de margen por volatilidad de la Libra
         g_rsi_oversold = 42;          // Compra
         g_rsi_overbought = 78;        // Venta
         g_be_trigger = 200;           // Holgura para BreakEven (antes 100) para aguantar retrocesos
         g_atr_multiplier = 2.5;       // SL más amplio
         g_risk_reward = 1.5;          // TP más realista
         g_momentum_spike_multiplier = 4.5; // Relajar vela elefante
         Print("🦅 [AURUM FOREX MODE] Símbolo GBPUSD detectado. Ajustes optimizados cargados.");
      }
   }

   // --- PROTECCIÓN DE VOLUMEN ---
   // Asegurar que el lotaje nunca sea menor al mínimo permitido por el bróker para este símbolo
   double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   if(g_lot_size < min_vol) {
      Print("⚠️ [VOLUMEN CORREGIDO] Lotaje ", DoubleToString(g_lot_size, 2), " es menor al mínimo. Ajustado a: ", DoubleToString(min_vol, 2));
      g_lot_size = min_vol;
   }
}

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   
   // Cargar auto-configuración de activos
   AutoTuneAssets();
   
   // Inicializar Gestión de Saldo (V1.05)
   g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);

   // Inicializar Indicadores Sniper (V9 - H1 Tendencia)
   hMA  = iMA(_Symbol, PERIOD_H1, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
   hADX = iADX(_Symbol, _Period, 14);
   hATR = iATR(_Symbol, _Period, 14); // Volatilidad para SL Dinamico
   
   if(hMA==INVALID_HANDLE || hRSI==INVALID_HANDLE || hADX==INVALID_HANDLE) return(INIT_FAILED);
   
   EventSetTimer(1); // Dashboard Timer
   Print("🦅 AURUM V11 ULTIMATE: Sniper Engine + Equity Guard Loaded.");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   IndicatorRelease(hMA); IndicatorRelease(hRSI); IndicatorRelease(hADX);
   EventKillTimer();
   ObjectsDeleteAll(0, "lbl_");
}

//+------------------------------------------------------------------+
//| X-RAY DEBUG MODE                                                 |
//+------------------------------------------------------------------+
void DebugSignalMiss(string direction, bool trend, bool in_zone, double rsi, double adx, bool is_spike, bool has_open_trade, bool good_spread, bool daily_limit) {
    if(!in_zone) return; // Solo nos importa si el precio llegó a la zona
    
    double open1 = iOpen(_Symbol, _Period, 1);
    double close1 = iClose(_Symbol, _Period, 1);
    long current_spread = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);
    
    if(direction == "BUY" && close1 > open1) {
        string reason = "";
        if(!trend) reason += "[Precio < EMA] ";
        if(rsi >= g_rsi_oversold) reason += "[RSI=" + DoubleToString(rsi, 1) + " (Req < " + DoubleToString(g_rsi_oversold, 1) + ")] ";
        if(adx <= g_adx_threshold) reason += "[ADX=" + DoubleToString(adx, 1) + " (Req > " + DoubleToString(g_adx_threshold, 1) + ")] ";
        if(is_spike) reason += "[Bloqueo Vela Elefante] ";
        if(!good_spread) reason += "[Spread alto: " + IntegerToString(current_spread) + " ptos] ";
        if(daily_limit) reason += "[Meta Diaria alcanzada] ";
        if(has_open_trade) reason += "[Trade abierto] ";
        
        if(reason != "") Print("🔍 [X-RAY COMPRA OMITIDA] ", _Symbol, ": ", reason);
    }
    
    if(direction == "SELL" && close1 < open1) {
        string reason = "";
        if(!trend) reason += "[Precio > EMA] ";
        if(rsi <= g_rsi_overbought) reason += "[RSI=" + DoubleToString(rsi, 1) + " (Req > " + DoubleToString(g_rsi_overbought, 1) + ")] ";
        if(adx <= g_adx_threshold) reason += "[ADX=" + DoubleToString(adx, 1) + " (Req > " + DoubleToString(g_adx_threshold, 1) + ")] ";
        if(is_spike) reason += "[Bloqueo Vela Elefante] ";
        if(!good_spread) reason += "[Spread alto: " + IntegerToString(current_spread) + " ptos] ";
        if(daily_limit) reason += "[Meta Diaria alcanzada] ";
        if(has_open_trade) reason += "[Trade abierto] ";
        
        if(reason != "") Print("🔍 [X-RAY VENTA OMITIDA] ", _Symbol, ": ", reason);
    }
}

//+------------------------------------------------------------------+
//| Main Engine                                                      |
//+------------------------------------------------------------------+
void OnTick() {
   // 1. Modulo de Gestion de Cuenta (V1.05)
   CheckAndResetDaily();
   if(CheckDailyDrawdown()) {
      Comment("\n⛔ MAX DRAWDOWN DIARIO ALCANZADO. TRADING DETENIDO.");
      return; 
   } else {
      Comment(""); // Limpiar mensaje si estamos operativos
   }
   
   // 2. Gestion de Posiciones (Cierres Parciales V1.05)
   GestionarPosicionesPro();
   
   if(!IsNewBar()) return; // 3. Logica de Entrada Sniper (V9)
   
   double ma_h1 = GetBufferVal(hMA, 0);
   double rsi   = GetBufferVal(hRSI, 1); // Vela cerrada
   double adx   = GetBufferVal(hADX, 1);
   double close = iClose(_Symbol, _Period, 1);
   double current_price = iClose(_Symbol, _Period, 0);

   bool trend_bull = (current_price > ma_h1); 
   bool trend_bear = (current_price < ma_h1);
   bool in_zone_buy = IsInZone("BUY", ma_h1);
   bool in_zone_sell= IsInZone("SELL", ma_h1);
   
   double atr = GetBufferVal(hATR, 1);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Evaluaciones de restricciones globales
   bool has_open_trade = IsPositionOpenOnSymbol();
   bool good_spread = CheckSpread();
   bool daily_limit_reached = (g_daily_trades >= InpMaxDailyTrades);
   
   if(daily_limit_reached) {
       Comment("\n😴 META DIARIA ALCANZADA (" + IntegerToString(g_daily_trades) + "/" + IntegerToString(InpMaxDailyTrades) + "). HASTA MAÑANA.");
   }
   
   bool is_spike_buy = false;
   bool is_spike_sell = false;
   
   // Solo calcular elefante si estamos en zona (ahorrar recursos)
   if(in_zone_buy) is_spike_buy = IsMomentumSpike("BUY");
   if(in_zone_sell) is_spike_sell = IsMomentumSpike("SELL");
   
   // --- MODO X-RAY (DEBUG) ---
   DebugSignalMiss("BUY", trend_bull, in_zone_buy, rsi, adx, is_spike_buy, has_open_trade, good_spread, daily_limit_reached);
   DebugSignalMiss("SELL", trend_bear, in_zone_sell, rsi, adx, is_spike_sell, has_open_trade, good_spread, daily_limit_reached);
   
   // Si no se puede operar por reglas globales, salir
   if(has_open_trade || !good_spread || daily_limit_reached) return;

   // COMPRA: Tendencia Alcista + Zona H1 + RSI Sobreventado + ADX
    if(trend_bull && in_zone_buy && rsi < g_rsi_oversold && adx > g_adx_threshold && !is_spike_buy) {
        double sl_dist = atr * g_atr_multiplier; // SL dinamico por volatilidad
        double tp_dist = sl_dist * g_risk_reward;
        
        double sl_price = ask - sl_dist;
        double sl = NormalizeDouble(sl_price - (ask - bid), _Digits);
        
        double tp_price = ask + tp_dist;
        double tp = NormalizeDouble(tp_price - (ask - bid), _Digits);
        
        // Validar distancia minima del broker
        CheckStops(sl, tp, true); 
        
        if(trade.Buy(g_lot_size, _Symbol, ask, sl, tp, "Aurum V11 Sniper")) {
            g_daily_trades++; // Sumar contador
        }
    }

    // VENTA: Tendencia Bajista + Zona H1 + RSI Sobrecomprado + ADX
    if(trend_bear && in_zone_sell && rsi > g_rsi_overbought && adx > g_adx_threshold && !is_spike_sell) {
        double sl_dist = atr * g_atr_multiplier;
        double tp_dist = sl_dist * g_risk_reward;
        
        double sl_price = bid + sl_dist;
        double sl = NormalizeDouble(sl_price + (ask - bid), _Digits);
        
        double tp_price = bid - tp_dist;
        double tp = NormalizeDouble(tp_price + (ask - bid), _Digits);
        
        CheckStops(sl, tp, false);
        
        if(trade.Sell(g_lot_size, _Symbol, bid, sl, tp, "Aurum V11 Sniper")) {
            g_daily_trades++; // Sumar contador
        }
    }
}

void OnTimer() {
   UpdateDashboard();
}

//+------------------------------------------------------------------+
//| HELPERS: LOGICA V1.05 + VISUALES                                 |
//+------------------------------------------------------------------+

// Modulo de Soportes V9 + V11 (Dinámico: Zona Fija + EMA Pullback)
bool IsInZone(string type, double ma_ref) {
   double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double h1_low  = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20, 1));
   double dist = g_distancia_puntos * _Point;
   
   double price = (type == "BUY") ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(type == "BUY") {
       bool near_floor = MathAbs(price - h1_low) <= dist;
       bool near_ema   = MathAbs(price - ma_ref) <= dist; // Pullback a la media
       return (near_floor || near_ema);
   }
   if(type == "SELL") {
       bool near_ceil = MathAbs(price - h1_high) <= dist;
       bool near_ema  = MathAbs(price - ma_ref) <= dist; // Pullback a la media
       return (near_ceil || near_ema);
   }
   return false;
}

// Modulo Gestion Avanzada V1.05 (Adaptado)
void GestionarPosicionesPro() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(!PositionSelectByTicket(ticket)) continue;
      if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      long type    = PositionGetInteger(POSITION_TYPE);
      double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      // Calcula los puntos matemáticamente según la dirección de la operación
      double profit_puntos = 0;
      if (type == POSITION_TYPE_BUY) profit_puntos = (cur_price - entry) / _Point;
      if (type == POSITION_TYPE_SELL) profit_puntos = (entry - cur_price) / _Point;
      
      // 1. BreakEven y Cierre Parcial Protegido
      if(profit_puntos >= g_be_trigger) {
          // Si el SL aun está en riesgo (no breakeven), lo protegemos
          bool is_risky = (type==POSITION_TYPE_BUY) ? (sl < entry) : (sl > entry);
          if(is_risky) {
             if(InpUsePartials) {
                 double min_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
                 double step_vol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
                 
                 double half_vol = NormalizeDouble(vol / 2.0, 2);
                 double partial = MathFloor(half_vol / step_vol) * step_vol;
                 
                 if (partial >= min_vol && (vol - partial) >= min_vol) {
                     trade.PositionClosePartial(ticket, partial);
                     Print("🛡️ SHIELD: Parcial Cerrado (Vol: ", DoubleToString(partial, 2), ").");
                 }
             }
             double new_sl = entry; // Mueve SL a Entrada (BreakEven estricto)
             trade.PositionModify(ticket, new_sl, tp);
             Print("🛡️ SHIELD ACTIVADO: BreakEven establecido.");
          }
      }
      
      // 2. Trailing Stop Loss (Recorrer Ganancias)
      if(InpUseTrailingStop && profit_puntos >= InpTrailingStart) {
          double step_points = InpTrailingStep * _Point;
          double min_stop_level = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
          double new_sl = sl;
          bool modify_needed = false;
          
          if(type == POSITION_TYPE_BUY) {
              // El SL propuesto es el precio actual menos la distancia del trailing
              double proposed_sl = NormalizeDouble(cur_price - (InpTrailingStart * _Point), _Digits);
              
              // Solo actualizamos si el nuevo SL asegura MÁS ganancias y respeta el step
              if(proposed_sl > sl + step_points) {
                  // Asegurar que respeta la distancia mínima del broker
                  if(cur_price - proposed_sl >= min_stop_level) {
                      new_sl = proposed_sl;
                      modify_needed = true;
                  }
              }
          } else if(type == POSITION_TYPE_SELL) {
              double proposed_sl = NormalizeDouble(cur_price + (InpTrailingStart * _Point), _Digits);
              
              // Cuidado al vender: el SL debe ser menor para asegurar ganancias. 
              // Si sl == 0 (no tenia) o el nuevo SL es mejor (mas bajo), actualizamos
              if(sl == 0 || proposed_sl < sl - step_points) {
                  if(proposed_sl - cur_price >= min_stop_level) {
                      new_sl = proposed_sl;
                      modify_needed = true;
                  }
              }
          }
          
          if(modify_needed) {
              if(trade.PositionModify(ticket, new_sl, tp)) {
                  Print("🏃 TRAILING STOP: SL movido a ", DoubleToString(new_sl, _Digits), " para proteger ganancias.");
              }
          }
      }
   }
}

// Modulo Seguridad V1.05
void CheckAndResetDaily() {
   // Inicializacion de Seguridad (Si el bot arranca con 0)
   if(g_start_equity <= 0) {
      g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      return;
   }

   if(!InpAutoDailyReset) return;
   
   if(iTime(_Symbol, PERIOD_D1, 0) > g_last_reset_day) {
      g_start_equity = AccountInfoDouble(ACCOUNT_EQUITY);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      g_daily_trades = 0; // Resetear contador de trades
      Print("🔄 NUEVO DIA: Balance y Trades Reseteados.");
   }
}

bool CheckDailyDrawdown() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drop = g_start_equity - equity;
   return (drop >= g_start_equity * (InpMaxDailyLoss/100.0));
}

bool CheckSpread() {
   return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= g_max_spread);
}

bool IsNewBar() {
   static datetime last_bar;
   if(last_bar == iTime(_Symbol, _Period, 0)) return false;
   last_bar = iTime(_Symbol, _Period, 0);
   return true;
}

// Filtro de Inercia Direccional (Solo bloquea si el spike va en CONTRA de nuestro trade)
// Para igualar a TradingView, evaluamos la vela "k=2" (la vela anterior a la señal).
bool IsMomentumSpike(string direction) {
   double body_avg = 0;
   for(int i=5; i<=14; i++) { // Desfasado en 1 para promediar las anteriores a k=2
      body_avg += MathAbs(iClose(_Symbol,_Period,i) - iOpen(_Symbol,_Period,i));
   }
   if(body_avg == 0) return false;
   body_avg /= 10.0;
   
   // En TradingView, la alerta de spike evalúa la vela ANTERIOR a la señal (body[1]).
   // Dado que MT5 evalúa en el OPEN de la vela posterior a la señal (la entrada),
   // la señal fue en k=1, por tanto, la vela anterior a la señal es k=2.
   double open2 = iOpen(_Symbol,_Period,2);
   double close2 = iClose(_Symbol,_Period,2);
   double candle_body = MathAbs(close2 - open2);
   
   if (candle_body > body_avg * g_momentum_spike_multiplier) {
       // Es un spike. Bloqueamos solo si va EN CONTRA del trade.
       if (direction == "BUY" && close2 < open2) {
           Print("⚠️ ALERTA: Vela 'Elefante' BAJISTA detectada. Compra cancelada por inercia en contra.");
           return true; 
       }
       if (direction == "SELL" && close2 > open2) {
           Print("⚠️ ALERTA: Vela 'Elefante' ALCISTA detectada. Venta cancelada por inercia en contra.");
           return true; 
       }
   }
   
   return false;
}

double GetBufferVal(int h, int idx) {
   double b[]; 
   ArraySetAsSeries(b, true);
   if(CopyBuffer(h, 0, idx, 1, b)>0) return b[0]; 
   return 0; 
}

// Validar Stops Minimos del Broker
void CheckStops(double &sl, double &tp, bool isBuy) {
   double min_dist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   double price = isBuy ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Si el SL esta muy pegado (< StopsLevel), ajustarlo
   if(MathAbs(price - sl) < min_dist) {
       sl = isBuy ? price - min_dist -_Point : price + min_dist + _Point;
   }
}

// GUI Visual
void UpdateDashboard() {
   double ma = GetBufferVal(hMA, 0);
   double price = iClose(_Symbol, _Period, 0);
   string trend_txt = (price > ma) ? "ALCISTA (Busca BUY)" : "BAJISTA (Busca SELL)";
   color trend_clr = (price > ma) ? clrLime : clrRed;
   
   int y_offset = 20;
   DrawLabel("lbl_Title", "🦅 AURUM SNIPER V11 (ULTIMATE)", 20, y_offset, clrGold, 12);
   y_offset += 25;
   
   if(g_gold_mode_active) {
      DrawLabel("lbl_AssetMode", "MODO ORO: ACTIVO 🦅", 20, y_offset, clrOrange, 10);
      y_offset += 20;
   } else {
      ObjectDelete(0, "lbl_AssetMode");
   }
   
   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, y_offset, trend_clr, 10);
   y_offset += 20;
   
   string dd_txt = StringFormat("Drawdown Diario: %.2f %% / Max %.1f %%", 
      (g_start_equity - AccountInfoDouble(ACCOUNT_EQUITY))/g_start_equity*100, InpMaxDailyLoss);
   DrawLabel("lbl_Risk", dd_txt, 20, y_offset, clrWhite, 10);
   y_offset += 20;
   
   DrawLabel("lbl_RSI", "RSI: " + DoubleToString(GetBufferVal(hRSI,0), 2), 20, y_offset, clrWhite, 10);
   y_offset += 20;

   // --- ADX Display ---
   double adx = GetBufferVal(hADX, 0);
   string adx_txt = "ADX: " + DoubleToString(adx, 2);
   color adx_clr = clrGray;
   
   if(adx > g_adx_threshold) {
      adx_txt += " (✅ ACTIVO)";
      adx_clr = clrLime;
   } else {
      adx_txt += " (💤 DORMIDO)";
      adx_clr = clrOrange; // Advertencia
   }
   DrawLabel("lbl_ADX", adx_txt, 20, y_offset, adx_clr, 10);
   
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

// Helper Multidivisa
bool IsPositionOpenOnSymbol() {
   for(int i=PositionsTotal()-1; i>=0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket)) {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == MAGIC_NUMBER) {
            return true;
         }
      }
   }
   return false;
}
