//+------------------------------------------------------------------+
//|                                            AurumSniper_V9.mq5   |
//|                                  Copyright 2025, Aurum Capital  |
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "9.00" // V9 Price Action Filter Edition
#property strict
#include <Trade\Trade.mqh>

//--- INPUTS
input group "Configuracion General"
input bool   InpEnableAutoTrade = true;
input bool   InpGuardianManual  = true;

input group "Estrategia M5 (Smart Filter)"
input int    InpDistanciaPuntos = 50;
input int    InpADXThreshold    = 20;
input int    InpEMAPeriod   = 200;
input int    InpRSIPeriod   = 14;
input double InpRSIOverbought = 75.0;
input double InpRSIOversold   = 25.0;

input group "Riesgo (Wide Stops)"
input double InpLotSize     = 0.01;
input int    InpATRPeriod   = 14;
input double InpSL_Multiplier = 2.0;
input double InpRiskReward    = 1.5;

input group "Gestion (Profit Locker)"
input int    InpBE_Trigger    = 80;
input int    InpBE_Offset     = 10;
input int    InpTrail_Dist    = 150;
input int    InpTrail_Step    = 50;

input group "News Guard"
input bool   InpUseNewsFilter = true;
input int    InpMinsBefore    = 60;
input int    InpMinsAfter     = 30;

//--- CONSTANTES
const string WEBHOOK_URL = "https://n8n.qhosting.net/webhook/aurum-trading-alerts";
const int    MAGIC_NUMBER = 9999;

//--- GLOBALES
CTrade trade;
int hMA, hRSI, hATR, hADX;
datetime last_alert_time = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   trade.SetExpertMagicNumber(MAGIC_NUMBER);

   hMA = iMA(_Symbol, PERIOD_M15, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   hATR = iATR(_Symbol, PERIOD_M5, InpATRPeriod);
   hADX = iADX(_Symbol, PERIOD_M15, 14);

   if(hMA == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE || hADX == INVALID_HANDLE)
     {
      Print("Error creating indicators");
      return(INIT_FAILED);
     }

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(hMA);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);
   IndicatorRelease(hADX);
  }

//+------------------------------------------------------------------+
//| Helper: Check for Candle Pattern and Return Name                |
//+------------------------------------------------------------------+
string GetPatternName(string type, int shift)
  {
   double open  = iOpen(_Symbol, PERIOD_M5, shift);
   double close = iClose(_Symbol, PERIOD_M5, shift);
   double high  = iHigh(_Symbol, PERIOD_M5, shift);
   double low   = iLow(_Symbol, PERIOD_M5, shift);

   double body  = MathAbs(close - open);
   double range = high - low;
   if(range == 0) return "";

   double upper_wick = high - MathMax(open, close);
   double lower_wick = MathMin(open, close) - low;

   // --- BUY PATTERNS ---
   if(type == "BUY")
     {
      // 1. Hammer: Lower wick >= 2x Body. Body in upper 30%.
      if((lower_wick >= 2 * body) && (MathMin(open, close) >= low + (0.7 * range)))
         return "Hammer";

      // 2. Bullish Engulfing
      double prev_open  = iOpen(_Symbol, PERIOD_M5, shift + 1);
      double prev_close = iClose(_Symbol, PERIOD_M5, shift + 1);

      if((prev_close < prev_open) && (close > open) &&
         (close > prev_open) && (open < prev_close))
         return "Bullish Engulfing";
     }

   // --- SELL PATTERNS ---
   if(type == "SELL")
     {
      // 1. Shooting Star: Upper wick >= 2x Body. Body in lower 30%.
      if((upper_wick >= 2 * body) && (MathMax(open, close) <= low + (0.3 * range)))
         return "Shooting Star";

      // 2. Bearish Engulfing
      double prev_open  = iOpen(_Symbol, PERIOD_M5, shift + 1);
      double prev_close = iClose(_Symbol, PERIOD_M5, shift + 1);

      if((prev_close > prev_open) && (close < open) &&
         (close < prev_open) && (open > prev_close))
         return "Bearish Engulfing";
     }

   return "";
  }

//+------------------------------------------------------------------+
//| Helper: News Guard (HayNoticia)                                  |
//+------------------------------------------------------------------+
bool HayNoticia()
  {
   if(!InpUseNewsFilter) return false;

   MqlCalendarValue values[];
   datetime start = TimeCurrent() - (InpMinsBefore * 60);
   datetime end   = TimeCurrent() + (InpMinsAfter * 60);

   string base = StringSubstr(_Symbol, 0, 3);
   string quote = StringSubstr(_Symbol, 3, 3);

   if(CalendarValueHistory(values, start, end, NULL, NULL))
     {
      for(int i=0; i<ArraySize(values); i++)
        {
         long event_id = values[i].event_id;
         MqlCalendarEvent event;
         if(CalendarEventById(event_id, event))
           {
             if(event.importance >= 3) // High Impact
               {
                if(event.currency == base || event.currency == quote)
                  {
                   return true;
                  }
               }
           }
        }
     }
   return false;
  }

//+------------------------------------------------------------------+
//| Helper: Profit Locker (GestionarPosiciones)                      |
//+------------------------------------------------------------------+
void GestionarPosiciones()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(InpGuardianManual && PositionGetInteger(POSITION_MAGIC) == 0) continue;
         if(PositionGetInteger(POSITION_MAGIC) != MAGIC_NUMBER && PositionGetInteger(POSITION_MAGIC) != 0) continue;

         double sl = PositionGetDouble(POSITION_SL);
         double tp = PositionGetDouble(POSITION_TP);
         double price = PositionGetDouble(POSITION_PRICE_CURRENT);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         long type = PositionGetInteger(POSITION_TYPE);
         double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

         double profit_points = 0;

         if(type == POSITION_TYPE_BUY)
           {
            profit_points = (price - open_price) / point;

            if(profit_points >= InpBE_Trigger && (sl < open_price + InpBE_Offset * point))
              {
               trade.PositionModify(ticket, open_price + InpBE_Offset * point, tp);
              }

            if(profit_points >= InpTrail_Dist)
              {
               double new_sl = price - InpTrail_Step * point;
               if(new_sl > sl)
                 {
                  trade.PositionModify(ticket, new_sl, tp);
                 }
              }
           }
         else if(type == POSITION_TYPE_SELL)
           {
            profit_points = (open_price - price) / point;

            if(profit_points >= InpBE_Trigger && (sl == 0 || sl > open_price - InpBE_Offset * point))
              {
               trade.PositionModify(ticket, open_price - InpBE_Offset * point, tp);
              }

            if(profit_points >= InpTrail_Dist)
              {
               double new_sl = price + InpTrail_Step * point;
               if(sl == 0 || new_sl < sl)
                 {
                  trade.PositionModify(ticket, new_sl, tp);
                 }
              }
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Helper: Connectivity (EnviarWebhook)                             |
//+------------------------------------------------------------------+
void EnviarWebhook(string signal, string razon, double price)
  {
   string headers = "Content-Type: application/json\r\n";
   char data[];
   char result[];
   string result_headers;

   string json = StringFormat("{\"symbol\":\"%s\", \"signal\":\"%s\", \"reason\":\"%s\", \"price\":%.5f, \"time\":\"%s\"}",
                              _Symbol, signal, razon, price, TimeToString(TimeCurrent()));

   StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);

   WebRequest("POST", WEBHOOK_URL, headers, 5000, data, result, result_headers);
  }

//+------------------------------------------------------------------+
//| Helper: Zone Detection (H1 High/Low)                             |
//+------------------------------------------------------------------+
bool IsInZone(string type)
  {
   double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, 1));
   double h1_low  = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20, 1));

   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   double dist = InpDistanciaPuntos * point;

   if(type == "BUY")
     {
      if(MathAbs(ask - h1_low) <= dist) return true;
     }
   else if(type == "SELL")
     {
      if(MathAbs(bid - h1_high) <= dist) return true;
     }

   return false;
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   GestionarPosiciones();

   if(!InpEnableAutoTrade) return;
   if(HayNoticia()) return;

   if(PositionsTotal() > 0) return;

   double rsi[], adx[], ma[];
   ArraySetAsSeries(rsi, true);
   ArraySetAsSeries(adx, true);
   ArraySetAsSeries(ma, true);

   CopyBuffer(hRSI, 0, 0, 2, rsi);
   CopyBuffer(hADX, 0, 0, 2, adx);
   CopyBuffer(hMA, 0, 0, 2, ma);

   double current_rsi = rsi[0];
   double current_adx = adx[0];
   double current_ma  = ma[0];
   double close_m15   = iClose(_Symbol, PERIOD_M15, 0);

   bool trend_bullish = close_m15 > current_ma;
   bool trend_bearish = close_m15 < current_ma;

   // Pattern Check (Shift 1 Priority, then Shift 0)
   string pat_buy_name = GetPatternName("BUY", 1);
   if(pat_buy_name == "") pat_buy_name = GetPatternName("BUY", 0);

   string pat_sell_name = GetPatternName("SELL", 1);
   if(pat_sell_name == "") pat_sell_name = GetPatternName("SELL", 0);

   // --- BUY LOGIC ---
   if(trend_bullish && IsInZone("BUY"))
     {
      if(current_rsi < InpRSIOversold)
        {
         if(current_adx > InpADXThreshold)
           {
            if(pat_buy_name != "")
              {
               double atr_val = 0;
               double atr_buf[]; ArraySetAsSeries(atr_buf, true);
               CopyBuffer(hATR, 0, 0, 1, atr_buf);
               atr_val = atr_buf[0];

               double sl = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - (atr_val * InpSL_Multiplier);
               double tp = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (atr_val * InpSL_Multiplier * InpRiskReward);

               trade.Buy(InpLotSize, _Symbol, 0, sl, tp, "AurumSniper V9");
               EnviarWebhook("BUY", "V9: " + pat_buy_name + " + RSI", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
              }
           }
        }
     }

   // --- SELL LOGIC ---
   if(trend_bearish && IsInZone("SELL"))
     {
      if(current_rsi > InpRSIOverbought)
        {
         if(current_adx > InpADXThreshold)
           {
            if(pat_sell_name != "")
              {
               double atr_val = 0;
               double atr_buf[]; ArraySetAsSeries(atr_buf, true);
               CopyBuffer(hATR, 0, 0, 1, atr_buf);
               atr_val = atr_buf[0];

               double sl = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (atr_val * InpSL_Multiplier);
               double tp = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (atr_val * InpSL_Multiplier * InpRiskReward);

               trade.Sell(InpLotSize, _Symbol, 0, sl, tp, "AurumSniper V9");
               EnviarWebhook("SELL", "V9: " + pat_sell_name + " + RSI", SymbolInfoDouble(_Symbol, SYMBOL_BID));
              }
           }
        }
     }
  }
