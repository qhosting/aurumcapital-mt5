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
input int      InpDistanciaPuntos = 100;    // Distancia a Zona H1 (Ampliada)
input int      InpEMAPeriod     = 200;      // Tendencia H1
input int      InpRSIOverbought = 70;       // Venta (Mas sensible)
input int      InpRSIOversold   = 30;       // Compra (Mas sensible)
input int      InpADXThreshold  = 20;       // Volatilidad Minima

input group "=== GESTION DE SALIDA PRO ==="
input bool     InpUsePartials   = true;     // Cerrar 50% al 1:1
input int      InpRiskReward    = 2;        // Ratio riesgo/beneficio
input int      InpBE_Trigger    = 100;      // Puntos para BreakEven
input int      InpMaxDailyTrades= 3;        // Max Operaciones Diarias

// ==================== GLOBALES ====================
CTrade trade;
int hMA, hRSI, hADX, hATR;
double g_start_balance = 0;
datetime g_last_reset_day = 0;
int g_daily_trades = 0; // Contador de trades hoy
const int MAGIC_NUMBER = 777999;

//+------------------------------------------------------------------+
//| Initialization                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   trade.SetExpertMagicNumber(MAGIC_NUMBER);
   
   // Inicializar Gestión de Saldo (V1.05)
   g_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
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
   if(trend_bull && in_zone_buy && rsi < InpRSIOversold && adx > InpADXThreshold) {
       double sl_dist = atr * 1.5; // SL dinamico por volatilidad
       double tp_dist = sl_dist * InpRiskReward;
       
       double sl = NormalizeDouble(ask - sl_dist, _Digits);
       double tp = NormalizeDouble(ask + tp_dist, _Digits);
       
       // Validar distancia minima del broker
       CheckStops(sl, tp, true); 
       
       if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "Aurum V11 Sniper")) {
           g_daily_trades++; // Sumar contador
       }
   }

   // VENTA: Tendencia Bajista + Zona H1 + RSI Sobrecomprado + ADX
   if(trend_bear && in_zone_sell && rsi > InpRSIOverbought && adx > InpADXThreshold) {
       double sl_dist = atr * 1.5;
       double tp_dist = sl_dist * InpRiskReward;
       
       double sl = NormalizeDouble(bid + sl_dist, _Digits);
       double tp = NormalizeDouble(bid - tp_dist, _Digits);
       
       CheckStops(sl, tp, false);
       
       if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "Aurum V11 Sniper")) {
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
   double dist = InpDistanciaPuntos * _Point;
   
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

      double entry = PositionGetDouble(POSITION_PRICE_OPEN);
      double sl    = PositionGetDouble(POSITION_SL);
      double tp    = PositionGetDouble(POSITION_TP);
      double vol   = PositionGetDouble(POSITION_VOLUME);
      long type    = PositionGetInteger(POSITION_TYPE);
      double cur_price = PositionGetDouble(POSITION_PRICE_CURRENT);
      
      double profit_puntos = MathAbs(cur_price - entry) / _Point;
      
      // 1. Cierre Parcial al 1:1 (Protege ganancias rápido)
      if(InpUsePartials && vol >= 0.02 && profit_puntos >= InpBE_Trigger) {
          // Si el SL aun está en riesgo (no breakeven), ejecutamos parcial
          bool is_risky = (type==POSITION_TYPE_BUY) ? (sl < entry) : (sl > entry);
          if(is_risky) {
             trade.PositionClosePartial(ticket, vol/2.0); // Cierra mitad
             double new_sl = entry; // Mueve SL a Entrada (BreakEven estricto)
             trade.PositionModify(ticket, new_sl, tp);
             Print("🛡️ SHIELD ACTIVADO: Parcial Cerrado + BreakEven.");
          }
      }
   }
}

// Modulo Seguridad V1.05
void CheckAndResetDaily() {
   // Inicializacion de Seguridad (Si el bot arranca con 0)
   if(g_start_balance <= 0) {
      g_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      return;
   }

   if(!InpAutoDailyReset) return;
   
   if(iTime(_Symbol, PERIOD_D1, 0) > g_last_reset_day) {
      g_start_balance = AccountInfoDouble(ACCOUNT_BALANCE);
      g_last_reset_day = iTime(_Symbol, PERIOD_D1, 0);
      g_daily_trades = 0; // Resetear contador de trades
      Print("🔄 NUEVO DIA: Balance y Trades Reseteados.");
   }
}

bool CheckDailyDrawdown() {
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double drop = g_start_balance - equity;
   return (drop >= g_start_balance * (InpMaxDailyLoss/100.0));
}

bool CheckSpread() {
   return (SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpread);
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
   
   DrawLabel("lbl_Title", "🦅 AURUM SNIPER V11 (ULTIMATE)", 20, 20, clrGold, 12);
   DrawLabel("lbl_Trend", "Tendencia H1: " + trend_txt, 20, 45, trend_clr, 10);
   
   string dd_txt = StringFormat("Drawdown Diario: %.2f %% / Max %.1f %%", 
      (g_start_balance - AccountInfoDouble(ACCOUNT_EQUITY))/g_start_balance*100, InpMaxDailyLoss);
   DrawLabel("lbl_Risk", dd_txt, 20, 65, clrWhite, 10);
   DrawLabel("lbl_RSI", "RSI: " + DoubleToString(GetBufferVal(hRSI,0), 2), 20, 85, clrWhite, 10);

   // --- ADX Display ---
   double adx = GetBufferVal(hADX, 0);
   string adx_txt = "ADX: " + DoubleToString(adx, 2);
   color adx_clr = clrGray;
   
   if(adx > InpADXThreshold) {
      adx_txt += " (✅ ACTIVO)";
      adx_clr = clrLime;
   } else {
      adx_txt += " (💤 DORMIDO)";
      adx_clr = clrOrange; // Advertencia
   }
   DrawLabel("lbl_ADX", adx_txt, 20, 105, adx_clr, 10);
   
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
