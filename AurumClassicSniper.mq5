//+------------------------------------------------------------------+
//|                                           AurumClassicSniper.mq5 |
//|                                  Copyright 2026, Aurum Capital   |
//|      Agente Institucional de Trading para MetaTrader 5          |
//|      Basado en Análisis Técnico Clásico, Modelos Cartistas,     |
//|      Gatillos Candlestick (Opwens) y Gestión de Riesgo Blueprint |
//+------------------------------------------------------------------+
#property copyright   "Aurum Capital"
#property link        "https://aurumcapital.io"
#property version     "1.00"
#property description "AurumClassicSniper: Agente Cartista Institucional con Gatillo de Velas Japonesas y Gestión de Riesgo"
#property strict

#include <Trade\Trade.mqh>
#include <AurumClassic\AurumTrendGeometry.mqh>
#include <AurumClassic\AurumCandleTriggers.mqh>
#include <AurumClassic\AurumClassicPatterns.mqh>
#include <AurumClassic\AurumClassicRisk.mqh>

// --- Modos de Ejecución
enum ENUM_EXECUTION_MODE
{
   EXEC_BREAKOUT_PENDING,    // 1. Ruptura con Órdenes Pendientes (Buy Stop / Sell Stop en Neckline)
   EXEC_BREAKOUT_MARKET,     // 2. Ruptura Confirmada al Cierre de Barra
   EXEC_PULLBACK_CANDLE      // 3. Pullback / Throwback con Gatillo Candlestick (Libro Opwens)
};

// ==================== INPUTS ====================
input group "=== GESTIÓN DE CAPITAL & RIESGO (FOREX BLUEPRINT) ==="
input int                  InpMagicNumber          = 888111;   // Magic Number
input double               InpRiskPercent          = 1.0;      // Riesgo Fijo por Operación (% del Balance)
input double               InpMaxAllowedLot        = 5.0;      // Lote Máximo Permitido
input bool                 InpUseDailyGuard        = true;     // Activar Disyuntor de Pérdida Diaria
input double               InpMaxDailyLossPct      = 3.0;      // Límite Máximo de Pérdida Diaria (% del balance)
input double               InpMaxDailyLossUSD      = 150.0;    // Límite Máximo de Pérdida Diaria ($ USD)
input int                  InpMaxConsecLosses      = 3;        // Máximo de pérdidas consecutivas antes de pausar
input int                  InpMaxSpread            = 25;       // Spread Máximo Permitido (Puntos)

input group "=== MODELOS CARTISTAS A OPERAR (MÓDULO 2) ==="
input bool                 InpTradeHCH             = true;     // Operar Hombro-Cabeza-Hombro (Normal e Invertido)
input bool                 InpTradeDoubleTopBottom = true;     // Operar Doble Techo y Doble Suelo
input bool                 InpTradeTriangles       = true;     // Operar Triángulos (Simétrico, Asc, Desc)
input bool                 InpTradeFlags           = true;     // Operar Banderas y Banderines
input int                  InpSwingStrength        = 4;        // Fuerza del Swing Fractal (Barras por lado)

input group "=== MODO DE EJECUCIÓN & GATILLO DE VELAS ==="
input ENUM_EXECUTION_MODE  InpExecutionMode        = EXEC_PULLBACK_CANDLE; // Estrategia de Ejecución
input bool                 InpRequireCandleConfirm = true;     // Exigir Vela Japonesa de Giro en Pullback
input bool                 InpUseTechnicalTargetH  = true;     // Usar Altura Técnica (H) como Take Profit
input double               InpRiskRewardFallback   = 2.0;      // R:R Alternativo si H no aplica
input bool                 InpUseBreakevenAt1R     = true;     // Mover a Breakeven al alcanzar +1R
input double               InpBELockPips           = 2.0;      // Pips protegidos en Breakeven

input group "=== SESIÓN HORARIA INSTITUCIONAL ==="
input bool                 InpUseSessionFilter     = true;     // Filtrar por horario de alta liquidez
input int                  InpStartHour            = 2;        // Hora Inicio (Apertura Londres GMT/Broker)
input int                  InpEndHour              = 17;       // Hora Fin (Cierre NY)

input group "=== PANEL VISUAL HUD ==="
input bool                 InpShowHUD              = true;     // Mostrar Dashboard en Gráfico
input bool                 InpDrawPatternLines     = true;     // Dibujar Líneas de Patrón y Objetivos

// ==================== VARIABLES GLOBALES ====================
CAurumTrendGeometry     ExtGeom;
CAurumCandleTriggers    ExtCandles;
CAurumClassicPatterns   ExtPatterns;
CAurumClassicRisk       ExtRisk;

datetime                ExtLastBarTime = 0;
ClassicChartPattern     ExtActivePattern;
ENUM_CANDLE_PATTERN     ExtLastCandlePattern = CANDLE_NONE;
string                  ExtHUDPrefix = "AurumClassic_";

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("======================================================");
   Print("Iniciando AurumClassicSniper EA - V1.00");
   Print("Estrategia: Análisis Técnico Clásico + Gatillos Opwens + Forex Blueprint");
   Print("======================================================");

   ExtGeom.Init(_Symbol, _Period, InpSwingStrength);
   ExtCandles.Init(_Symbol);
   ExtPatterns.Init(_Symbol, _Period, InpSwingStrength);
   ExtRisk.Init(_Symbol, InpMagicNumber);

   ExtActivePattern.type = PATTERN_NONE;

   if(InpShowHUD)
      CreateHUD();

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   RemoveHUD();
   RemovePatternLines();
   Print("AurumClassicSniper finalizado. Razón: ", reason);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // 1. Gestión continua de posiciones abiertas (Breakeven y Trailing)
   if(InpUseBreakevenAt1R)
      ExtRisk.ManagePositions(InpBELockPips);

   // 2. Control de Nueva Barra (Evaluación estricta al cierre de vela)
   datetime currentBarTime = iTime(_Symbol, _Period, 0);
   if(currentBarTime == ExtLastBarTime)
   {
      return; // Esperar cierre de barra para confirmaciones objetivas
   }
   ExtLastBarTime = currentBarTime;

   // 3. Pre-Flight Checks (Spread y Protección Diaria)
   if(!ExtRisk.CheckPreFlight(InpMaxSpread))
   {
      UpdateHUD("PAUSADO: Spread elevado");
      return;
   }

   if(InpUseDailyGuard && ExtRisk.IsDailyRiskBreached(InpMaxDailyLossPct, InpMaxDailyLossUSD, InpMaxConsecLosses))
   {
      UpdateHUD("DISYUNTOR: Límite de pérdida diaria alcanzado");
      return;
   }

   // 4. Filtro de Sesión Horaria
   if(InpUseSessionFilter)
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      if(dt.hour < InpStartHour || dt.hour >= InpEndHour)
      {
         UpdateHUD("FUERA DE SESIÓN (Esperando Londres/NY)");
         return;
      }
   }

   // 5. Cargar Velas para Análisis
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, 100, rates);
   if(copied < 40) return;

   // 6. Escanear Patrón Cartista en el Gráfico
   ClassicChartPattern detected;
   if(ExtPatterns.ScanCurrentPattern(rates, copied, detected))
   {
      // Validar si el patrón está habilitado por el usuario
      if(IsPatternEnabled(detected.type))
      {
         ExtActivePattern = detected;
         if(InpDrawPatternLines)
            DrawPatternVisuals(detected);
      }
   }

   // 7. Evaluar Ejecución si hay un Patrón Activo
   if(ExtActivePattern.type != PATTERN_NONE)
   {
      EvaluateExecution(rates, copied);
   }

   // 8. Actualizar HUD
   if(InpShowHUD)
      UpdateHUD("Operativo");
}

//+------------------------------------------------------------------+
//| Verificar si el Tipo de Patrón está Habilitado por el Usuario     |
//+------------------------------------------------------------------+
bool IsPatternEnabled(ENUM_CLASSIC_PATTERN type)
{
   if(type == PATTERN_HCH_TOP || type == PATTERN_HCH_BOTTOM)
      return InpTradeHCH;
   if(type == PATTERN_DOUBLE_TOP || type == PATTERN_DOUBLE_BOTTOM || type == PATTERN_TRIPLE_TOP || type == PATTERN_TRIPLE_BOTTOM)
      return InpTradeDoubleTopBottom;
   if(type == PATTERN_TRIANGLE_ASCENDING || type == PATTERN_TRIANGLE_DESCENDING || type == PATTERN_TRIANGLE_SYMMETRIC)
      return InpTradeTriangles;
   if(type == PATTERN_FLAG_BULLISH || type == PATTERN_FLAG_BEARISH || type == PATTERN_PENNANT_BULLISH || type == PATTERN_PENNANT_BEARISH)
      return InpTradeFlags;

   return true;
}

//+------------------------------------------------------------------+
//| Motor de Evaluación y Entrada al Mercado                         |
//+------------------------------------------------------------------+
void EvaluateExecution(const MqlRates &rates[], int totalRates)
{
   // Evitar sobre-operar si ya tenemos posición abierta con este Magic
   if(HasOpenPosition()) return;

   double close1 = rates[1].close;
   double open1  = rates[1].open;
   double high1  = rates[1].high;
   double low1   = rates[1].low;

   double neckPrice = ExtActivePattern.necklinePrice;
   double slPrice   = ExtActivePattern.invalidationSL;
   double tpPrice   = ExtActivePattern.takeProfitTarget;

   // Ajuste de TP si se prefiere R:R fijo en lugar de proyección H
   if(!InpUseTechnicalTargetH)
   {
      double riskDist = MathAbs(neckPrice - slPrice);
      tpPrice = ExtActivePattern.isBullish ? (neckPrice + riskDist * InpRiskRewardFallback) 
                                          : (neckPrice - riskDist * InpRiskRewardFallback);
   }

   // MODO 1: PULLBACK / THROWBACK CON GATILLO CANDLESTICK
   if(InpExecutionMode == EXEC_PULLBACK_CANDLE)
   {
      // En Pullback/Throwback, el precio debe haber testeado la zona de la directriz/neckline
      // Tolerancia adaptativa: En Oro ($3.50 = 35 pips), en Forex (15 pips)
      double maxRetestPips = (StringFind(_Symbol, "GOLD") >= 0 || StringFind(_Symbol, "XAU") >= 0) ? 35.0 : 15.0;
      double pipsFromNeck = MathAbs(rates[1].close - neckPrice) / (_Point * 10);

      // Si está dentro de la zona de retesteo de la línea de cuello
      if(pipsFromNeck <= maxRetestPips)
      {
         // Escanear gatillo de velas del Libro Opwens
         ENUM_CANDLE_PATTERN trigger = ExtCandles.ScanBar(rates, 1, ExtActivePattern.isBullish);
         if(trigger != CANDLE_NONE || !InpRequireCandleConfirm)
         {
            ExtLastCandlePattern = trigger;
            ENUM_ORDER_TYPE oType = ExtActivePattern.isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
            double lot = ExtRisk.CalculateLotSize(InpRiskPercent, close1, slPrice, InpMaxAllowedLot);

            string comment = StringFormat("Aurum_%s", ExtActivePattern.name);
            ulong ticket = ExtRisk.OpenMarketOrder(oType, lot, slPrice, tpPrice, comment);

            if(ticket > 0)
            {
               PrintFormat("DISPARO EJECUTADO! Patrón: %s, Gatillo: %s, Lote: %.2f", 
                           ExtActivePattern.name, ExtCandles.GetPatternName(trigger), lot);
               ExtActivePattern.type = PATTERN_NONE; // Reset tras disparo
               RemovePatternLines();
            }
         }
      }
   }
   // MODO 2: RUPTURA CONFIRMADA A MERCADO (BREAKOUT MARKET)
   else if(InpExecutionMode == EXEC_BREAKOUT_MARKET)
   {
      bool isBreakoutConfirmed = false;
      if(ExtActivePattern.isBullish && close1 > neckPrice && open1 <= neckPrice)
         isBreakoutConfirmed = true;
      else if(!ExtActivePattern.isBullish && close1 < neckPrice && open1 >= neckPrice)
         isBreakoutConfirmed = true;

      if(isBreakoutConfirmed)
      {
         ENUM_ORDER_TYPE oType = ExtActivePattern.isBullish ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
         double lot = ExtRisk.CalculateLotSize(InpRiskPercent, close1, slPrice, InpMaxAllowedLot);

         string comment = StringFormat("Breakout_%s", ExtActivePattern.name);
         ulong ticket = ExtRisk.OpenMarketOrder(oType, lot, slPrice, tpPrice, comment);

         if(ticket > 0)
         {
            ExtActivePattern.type = PATTERN_NONE;
            RemovePatternLines();
         }
      }
   }
   // MODO 3: ÓRDENES PENDIENTES DE RUPTURA (BUY STOP / SELL STOP)
   else if(InpExecutionMode == EXEC_BREAKOUT_PENDING)
   {
      if(!HasPendingOrder())
      {
         ENUM_ORDER_TYPE pendType = ExtActivePattern.isBullish ? ORDER_TYPE_BUY_STOP : ORDER_TYPE_SELL_STOP;
         double lot = ExtRisk.CalculateLotSize(InpRiskPercent, neckPrice, slPrice, InpMaxAllowedLot);

         string comment = StringFormat("Pend_%s", ExtActivePattern.name);
         ExtRisk.PlacePendingOrder(pendType, lot, neckPrice, slPrice, tpPrice, comment);
      }
   }
}

//+------------------------------------------------------------------+
//| Verificar si existen posiciones abiertas con nuestro Magic       |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionGetTicket(i) > 0)
      {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol && PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Verificar si existen órdenes pendientes con nuestro Magic        |
//+------------------------------------------------------------------+
bool HasPendingOrder()
{
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(OrderGetTicket(i) > 0)
      {
         if(OrderGetString(ORDER_SYMBOL) == _Symbol && OrderGetInteger(ORDER_MAGIC) == InpMagicNumber)
            return true;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| DIBUJO DE LÍNEAS EN GRÁFICO (Neckline, Target H, Invalidation SL)|
//+------------------------------------------------------------------+
void DrawPatternVisuals(const ClassicChartPattern &pat)
{
   RemovePatternLines();

   // 1. Línea de Cuello (Neckline)
   string neckName = ExtHUDPrefix + "Neckline";
   ObjectCreate(0, neckName, OBJ_HLINE, 0, 0, pat.necklinePrice);
   ObjectSetInteger(0, neckName, OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, neckName, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, neckName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, neckName, OBJPROP_TEXT, "Neckline (" + pat.name + ")");

   // 2. Línea de Take Profit (Target H)
   string tpName = ExtHUDPrefix + "TargetH";
   ObjectCreate(0, tpName, OBJ_HLINE, 0, 0, pat.takeProfitTarget);
   ObjectSetInteger(0, tpName, OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, tpName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, tpName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, tpName, OBJPROP_TEXT, "Target Proyectado (H)");

   // 3. Línea de Stop Loss (Invalidation)
   string slName = ExtHUDPrefix + "InvalidationSL";
   ObjectCreate(0, slName, OBJ_HLINE, 0, 0, pat.invalidationSL);
   ObjectSetInteger(0, slName, OBJPROP_COLOR, clrCrimson);
   ObjectSetInteger(0, slName, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, slName, OBJPROP_WIDTH, 2);
   ObjectSetString(0, slName, OBJPROP_TEXT, "Invalidación SL");
}

void RemovePatternLines()
{
   ObjectDelete(0, ExtHUDPrefix + "Neckline");
   ObjectDelete(0, ExtHUDPrefix + "TargetH");
   ObjectDelete(0, ExtHUDPrefix + "InvalidationSL");
}

//+------------------------------------------------------------------+
//| CREACIÓN Y GESTIÓN DEL DASHBOARD HUD EN PANTALLA                 |
//+------------------------------------------------------------------+
void CreateHUD()
{
   string bg = ExtHUDPrefix + "BG";
   ObjectCreate(0, bg, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bg, OBJPROP_XDISTANCE, 20);
   ObjectSetInteger(0, bg, OBJPROP_YDISTANCE, 30);
   ObjectSetInteger(0, bg, OBJPROP_XSIZE, 300);
   ObjectSetInteger(0, bg, OBJPROP_YSIZE, 175);
   ObjectSetInteger(0, bg, OBJPROP_BGCOLOR, C'15,23,42'); // Dark Navy Slate
   ObjectSetInteger(0, bg, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bg, OBJPROP_COLOR, C'51,65,85');
   ObjectSetInteger(0, bg, OBJPROP_CORNER, CORNER_LEFT_UPPER);

   CreateHUDLabel(ExtHUDPrefix + "Title", "AURUM CLASSIC SNIPER V1.00", 35, 40, clrGold, 10, true);
   CreateHUDLabel(ExtHUDPrefix + "Sub", "Patrones Clásicos & Gatillos Candlestick", 35, 58, C'148,163,184', 8, false);
   CreateHUDLabel(ExtHUDPrefix + "Status", "Estado: Inicializando...", 35, 80, clrWhite, 9, false);
   CreateHUDLabel(ExtHUDPrefix + "Pat", "Patrón: Buscando figuras...", 35, 100, C'56,189,248', 9, true);
   CreateHUDLabel(ExtHUDPrefix + "Trigger", "Gatillo: Esperando confirmación...", 35, 120, C'203,213,225', 9, false);
   CreateHUDLabel(ExtHUDPrefix + "Risk", "Riesgo: 1.0% | Blueprint Engine", 35, 140, C'74,222,128', 9, false);
   CreateHUDLabel(ExtHUDPrefix + "Pips", "Balance: $0.00 | Drawdown: 0.0%", 35, 160, C'148,163,184', 8, false);
}

void CreateHUDLabel(string name, string text, int x, int y, color clr, int fontSize, bool isBold)
{
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetString(0, name, OBJPROP_FONT, isBold ? "Segoe UI Bold" : "Segoe UI");
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

void UpdateHUD(string statusText)
{
   if(!InpShowHUD) return;

   ObjectSetString(0, ExtHUDPrefix + "Status", OBJPROP_TEXT, "Estado: " + statusText);

   string patStr = (ExtActivePattern.type != PATTERN_NONE) 
      ? StringFormat("Patrón: %s (%s)", ExtActivePattern.name, ExtActivePattern.isBullish ? "BUY" : "SELL")
      : "Patrón: Buscando figuras...";
   ObjectSetString(0, ExtHUDPrefix + "Pat", OBJPROP_TEXT, patStr);

   string trigStr = (ExtLastCandlePattern != CANDLE_NONE)
      ? "Gatillo: " + ExtCandles.GetPatternName(ExtLastCandlePattern)
      : "Gatillo: Monitoreando acción del precio";
   ObjectSetString(0, ExtHUDPrefix + "Trigger", OBJPROP_TEXT, trigStr);

   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity  = AccountInfoDouble(ACCOUNT_EQUITY);
   double dd = (balance > 0) ? ((balance - equity) / balance) * 100.0 : 0.0;
   if(dd < 0) dd = 0;

   ObjectSetString(0, ExtHUDPrefix + "Pips", OBJPROP_TEXT, 
                   StringFormat("Balance: $%.2f | DD: %.1f%%", balance, dd));
}

void RemoveHUD()
{
   ObjectsDeleteAll(0, ExtHUDPrefix);
}
