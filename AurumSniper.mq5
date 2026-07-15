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
         Print("🦅 [AURUM FOREX MODE] Símbolo EURUSD detectado. Ajustes optimizados cargados.");
      }
      else if(StringFind(symbol, "USDJPY") >= 0) {
         g_distancia_puntos = 300;     // Tendencia más amplia
         g_rsi_oversold = 40;          // Compra
         g_rsi_overbought = 60;        // Venta
         Print("🦅 [AURUM FOREX MODE] Símbolo USDJPY detectado. Ajustes optimizados cargados.");
      }
      else if(StringFind(symbol, "GBPUSD") >= 0) {
         g_distancia_puntos = 150;     // Un poco más de margen por volatilidad de la Libra
         g_rsi_oversold = 42;          // Compra
         g_rsi_overbought = 78;        // Venta
         Print("🦅 [AURUM FOREX MODE] Símbolo GBPUSD detectado. Ajustes optimizados cargados.");
      }
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
   
   if(IsPositionOpenOnSymbol()) return; // Solo esperar si ESTE simbolo tiene trade activo
   if(!CheckSpread()) return;
   
   // 3. Logica de Entrada Sniper (V9)
   if(!IsNewBar()) return;
   
   // Check Max Trades Diarios
   if(g_daily_trades >= InpMaxDailyTrades) {
       Comment("\n😴 META DIARIA ALCANZADA (" + IntegerToString(g_daily_trades) + "/" + IntegerToString(InpMaxDailyTrades) + "). HASTA MAÑANA.");
       return;
   }
   
   // --- FILTRO ANTI-TREN (NUEVO) ---
   // Si la vela anterior fue explosiva (3x el promedio), NO operar reversión
   if(IsMomentumSpike()) {
       Print("⚠️ ALERTA: Vela 'Elefante' detectada. Operación cancelada por inercia fuerte.");
       return;
   }
   
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

   // COMPRA: Tendencia Alcista + Zona H1 + RSI Sobreventado + ADX
    if(trend_bull && in_zone_buy && rsi < g_rsi_oversold && adx > g_adx_threshold) {
        double sl_dist = atr * g_atr_multiplier; // SL dinamico por volatilidad
        double tp_dist = sl_dist * InpRiskReward;
        
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
    if(trend_bear && in_zone_sell && rsi > g_rsi_overbought && adx > g_adx_threshold) {
        double sl_dist = atr * g_atr_multiplier;
        double tp_dist = sl_dist * InpRiskReward;
        
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
             if(InpUsePartials && vol >= 0.02) {
                trade.PositionClosePartial(ticket, vol/2.0); // Cierra mitad
                Print("🛡️ SHIELD: Parcial Cerrado.");
             }
             double new_sl = entry; // Mueve SL a Entrada (BreakEven estricto)
             trade.PositionModify(ticket, new_sl, tp);
             Print("🛡️ SHIELD ACTIVADO: BreakEven establecido.");
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

// Filtro de Inercia (Evita operar contra velas gigantes - Memoria 3 Velas)
bool IsMomentumSpike() {
   double body_avg = 0;
   for(int i=4; i<=13; i++) { // Promedio de 10 velas anteriores al grupo reciente
      body_avg += MathAbs(iClose(_Symbol,_Period,i) - iOpen(_Symbol,_Period,i));
   }
   body_avg /= 10.0;
   
   // Chequear solo la ULTIMA vela cerrada (Agilidad Sniper)
   // Si la vela 1 fue explosiva, esperamos 1 minuto. Si la vela 1 es normal, entramos.
   for(int k=1; k<=1; k++) {
      double candle_body = MathAbs(iClose(_Symbol,_Period,k) - iOpen(_Symbol,_Period,k));
      if (candle_body > body_avg * 3.0) return true; 
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
