//+------------------------------------------------------------------+
//|                                           AurumClassicRisk.mqh   |
//|                                  Copyright 2026, Aurum Capital   |
//|      Gestión de Riesgo Institucional y Ejecución (Forex Blueprint)|
//|      Cálculo de Lote % Exacto, Órdenes Pendientes, Breakeven y SL|
//+------------------------------------------------------------------+
#ifndef AURUM_CLASSIC_RISK_MQH
#define AURUM_CLASSIC_RISK_MQH

#property copyright "Aurum Capital"
#property strict

#include <Trade\Trade.mqh>

class CAurumClassicRisk
{
private:
   CTrade   m_trade;
   string   m_symbol;
   int      m_magic;
   double   m_point;
   int      m_digits;

   // Circuit breaker diario
   double   m_startDayEquity;
   datetime m_lastResetDay;
   int      m_consecutiveLosses;

public:
   CAurumClassicRisk() : m_symbol(_Symbol), m_magic(888111), m_startDayEquity(0.0), m_consecutiveLosses(0), m_lastResetDay(0)
   {
      m_point  = _Point;
      m_digits = _Digits;
   }

   void Init(string sym, int magic)
   {
      m_symbol = sym;
      m_magic  = magic;
      m_trade.SetExpertMagicNumber(magic);
      m_point  = SymbolInfoDouble(sym, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_trade.SetDeviationInPoints(15);
      m_trade.SetTypeFillingBySymbol(sym);

      CheckDailyReset();
   }

   //+---------------------------------------------------------------+
   //| Reinicio y Monitoreo del Capital Diario (Daily Risk Guard)    |
   //+---------------------------------------------------------------+
   void CheckDailyReset()
   {
      MqlDateTime dt;
      TimeCurrent(dt);
      datetime today = StringToTime(StringFormat("%04d.%02d.%02d 00:00", dt.year, dt.mon, dt.day));

      if(today != m_lastResetDay)
      {
         m_startDayEquity    = AccountInfoDouble(ACCOUNT_EQUITY);
         m_lastResetDay      = today;
         m_consecutiveLosses = 0;
         PrintFormat("[AurumRisk] Nuevo día detectado (%s). Equity base fijada en: $%.2f", 
                     TimeToString(today, TIME_DATE), m_startDayEquity);
      }
   }

   //+---------------------------------------------------------------+
   //| Verificar si se ha superado el Límite de Pérdida Diaria       |
   //+---------------------------------------------------------------+
   bool IsDailyRiskBreached(double maxDailyLossPct, double maxDailyLossUSD, int maxConsecLosses)
   {
      CheckDailyReset();
      double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
      double currentLossUSD = m_startDayEquity - currentEquity;

      // Pérdida por monto fijo USD
      if(maxDailyLossUSD > 0 && currentLossUSD >= maxDailyLossUSD)
      {
         PrintFormat("[AurumRisk] BLOQUEADO: Pérdida diaria en USD ($%.2f) superó el límite ($%.2f)", currentLossUSD, maxDailyLossUSD);
         return true;
      }

      // Pérdida por porcentaje del capital
      if(maxDailyLossPct > 0 && m_startDayEquity > 0)
      {
         double lossPct = (currentLossUSD / m_startDayEquity) * 100.0;
         if(lossPct >= maxDailyLossPct)
         {
            PrintFormat("[AurumRisk] BLOQUEADO: Pérdida diaria (%.2f%%) superó el límite de %.2f%%", lossPct, maxDailyLossPct);
            return true;
         }
      }

      // Disyuntor por pérdidas consecutivas
      if(maxConsecLosses > 0 && m_consecutiveLosses >= maxConsecLosses)
      {
         PrintFormat("[AurumRisk] BLOQUEADO: Racha de %d pérdidas consecutivas.", m_consecutiveLosses);
         return true;
      }

      return false;
   }

   //+---------------------------------------------------------------+
   //| Registrar resultado de posición cerrada para racha de pérdidas |
   //+---------------------------------------------------------------+
   void RecordTradeResult(double profit)
   {
      if(profit < 0.0)
         m_consecutiveLosses++;
      else if(profit > 0.0)
         m_consecutiveLosses = 0;
   }

   //+---------------------------------------------------------------+
   //| Cálculo Dinámico de Lotaje por Porcentaje de Riesgo (1% Rule) |
   //+---------------------------------------------------------------+
   double CalculateLotSize(double riskPercent, double entryPrice, double slPrice, double maxAllowedLot = 10.0)
   {
      if(entryPrice <= 0.0 || slPrice <= 0.0) return 0.01;

      double slDistance = MathAbs(entryPrice - slPrice);
      if(slDistance <= 0.0) return 0.01;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double riskMoney = balance * (riskPercent / 100.0);

      double tickSize  = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_SIZE);
      double tickValue = SymbolInfoDouble(m_symbol, SYMBOL_TRADE_TICK_VALUE);
      double minLot    = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MIN);
      double maxLot    = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_MAX);
      double lotStep   = SymbolInfoDouble(m_symbol, SYMBOL_VOLUME_STEP);

      if(tickSize <= 0.0 || tickValue <= 0.0) return minLot;

      // Cantidad de ticks en la distancia de Stop Loss
      double slTicks = slDistance / tickSize;
      double riskPerLot = slTicks * tickValue;

      if(riskPerLot <= 0.0) return minLot;

      double rawLot = riskMoney / riskPerLot;

      // Normalizar al step del broker
      double steps = MathFloor(rawLot / lotStep);
      double calcLot = steps * lotStep;

      // Acotar entre mínimos y máximos
      calcLot = MathMax(minLot, MathMin(calcLot, maxLot));
      calcLot = MathMin(calcLot, maxAllowedLot);

      return NormalizeDouble(calcLot, 2);
   }

   //+---------------------------------------------------------------+
   //| Obtener Spread Máximo Adaptado según el Tipo de Activo        |
   //+---------------------------------------------------------------+
   int GetAdaptiveMaxSpread(int userMaxSpread)
   {
      string sym = m_symbol;
      StringToUpper(sym);

      int effective = userMaxSpread;

      // Oro y metales preciosos (XM GOLD / GOLDmicro / XAUUSD)
      if(StringFind(sym, "GOLD") >= 0 || StringFind(sym, "XAU") >= 0)
      {
         if(effective < 75) effective = 75; // Spread normal en Oro es 40-60 pts
      }
      // Criptomonedas (BTCUSD, ETHUSD)
      else if(StringFind(sym, "BTC") >= 0)
      {
         if(effective < 6000) effective = 6000;
      }
      else if(StringFind(sym, "ETH") >= 0)
      {
         if(effective < 3000) effective = 3000;
      }
      // Índices (US30, NAS100, GER40)
      else if(StringFind(sym, "US30") >= 0 || StringFind(sym, "DJ") >= 0)
      {
         if(effective < 1200) effective = 1200;
      }
      else if(StringFind(sym, "NAS") >= 0 || StringFind(sym, "USTEC") >= 0)
      {
         if(effective < 900) effective = 900;
      }
      else if(StringFind(sym, "GER") >= 0 || StringFind(sym, "DAX") >= 0)
      {
         if(effective < 900) effective = 900;
      }

      return effective;
   }

   //+---------------------------------------------------------------+
   //| Validación Pre-Flight de Mercado (Spread, Modo Trading)       |
   //+---------------------------------------------------------------+
   bool CheckPreFlight(int maxSpreadPoints, bool logWarning = false)
   {
      int effectiveMaxSpread = GetAdaptiveMaxSpread(maxSpreadPoints);
      long spread = SymbolInfoInteger(m_symbol, SYMBOL_SPREAD);

      if(spread > effectiveMaxSpread)
      {
         if(logWarning)
         {
            PrintFormat("[AurumRisk] Pre-Flight Fallido: Spread actual (%d) > Máximo permitido (%d) para %s", 
                        spread, effectiveMaxSpread, m_symbol);
         }
         return false;
      }

      long tradeMode = SymbolInfoInteger(m_symbol, SYMBOL_TRADE_MODE);
      if(tradeMode != SYMBOL_TRADE_MODE_FULL)
      {
         if(logWarning)
            PrintFormat("[AurumRisk] Pre-Flight Fallido: Modo de trading restringido (%d)", tradeMode);
         return false;
      }

      return true;
   }

   //+---------------------------------------------------------------+
   //| Disparar Orden a Mercado (Market Execution con Gatillo Vela)  |
   //+---------------------------------------------------------------+
   ulong OpenMarketOrder(ENUM_ORDER_TYPE orderType, double lot, double sl, double tp, string comment = "AurumClassic")
   {
      double price = (orderType == ORDER_TYPE_BUY) ? SymbolInfoDouble(m_symbol, SYMBOL_ASK) : SymbolInfoDouble(m_symbol, SYMBOL_BID);

      if(!m_trade.PositionOpen(m_symbol, orderType, lot, price, sl, tp, comment))
      {
         PrintFormat("[AurumRisk] Error abriendo orden a mercado: %s (code: %d)", 
                     m_trade.ResultRetcodeDescription(), m_trade.ResultRetcode());
         return 0;
      }

      PrintFormat("[AurumRisk] Posición abierta con éxito! Ticket: %d, Lote: %.2f, SL: %.5f, TP: %.5f", 
                  m_trade.ResultOrder(), lot, sl, tp);
      return m_trade.ResultOrder();
   }

   //+---------------------------------------------------------------+
   //| Colocar Orden Pendiente (Buy/Sell Stop para Breakout,         |
   //|                          Buy/Sell Limit para Pullback)        |
   //+---------------------------------------------------------------+
   ulong PlacePendingOrder(ENUM_ORDER_TYPE orderType, double lot, double entryPrice, double sl, double tp, string comment = "AurumPending")
   {
      entryPrice = NormalizeDouble(entryPrice, m_digits);
      sl         = NormalizeDouble(sl, m_digits);
      tp         = NormalizeDouble(tp, m_digits);

      if(!m_trade.OrderOpen(m_symbol, orderType, lot, 0.0, entryPrice, sl, tp, ORDER_TIME_GTC, 0, comment))
      {
         PrintFormat("[AurumRisk] Error colocando orden pendiente: %s (code: %d)", 
                     m_trade.ResultRetcodeDescription(), m_trade.ResultRetcode());
         return 0;
      }

      PrintFormat("[AurumRisk] Orden Pendiente colocada! Tipo: %s, Precio: %.5f, SL: %.5f, TP: %.5f", 
                  EnumToString(orderType), entryPrice, sl, tp);
      return m_trade.ResultOrder();
   }

   //+---------------------------------------------------------------+
   //| Gestión de Breakeven y Trailing Stop a 1R                     |
   //+---------------------------------------------------------------+
   void ManagePositions(double beLockPips = 2.0)
   {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
      {
         ulong ticket = PositionGetTicket(i);
         if(ticket <= 0) continue;

         if(PositionGetString(POSITION_SYMBOL) != m_symbol || PositionGetInteger(POSITION_MAGIC) != m_magic)
            continue;

         double openPrice   = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentSL   = PositionGetDouble(POSITION_SL);
         double currentTP   = PositionGetDouble(POSITION_TP);
         double currentPrice= PositionGetDouble(POSITION_PRICE_CURRENT);
         long   posType     = PositionGetInteger(POSITION_TYPE);

         double initialRisk = MathAbs(openPrice - currentSL);
         if(initialRisk <= 0.0) continue;

         double beLockDist = beLockPips * 10 * m_point;

         // Para posiciones de Compra: Si avanza >= 1R, mover SL a Breakeven + lock
         if(posType == POSITION_TYPE_BUY)
         {
            double gain = currentPrice - openPrice;
            if(gain >= initialRisk) // Ya alcanzó al menos 1R de beneficio
            {
               double newSL = openPrice + beLockDist;
               if(currentSL < newSL)
               {
                  m_trade.PositionModify(ticket, NormalizeDouble(newSL, m_digits), currentTP);
                  PrintFormat("[AurumRisk] Breakeven activado para BUY #%d. SL movido a %.5f", ticket, newSL);
               }
            }
         }
         // Para posiciones de Venta
         else if(posType == POSITION_TYPE_SELL)
         {
            double gain = openPrice - currentPrice;
            if(gain >= initialRisk)
            {
               double newSL = openPrice - beLockDist;
               if(currentSL == 0.0 || currentSL > newSL)
               {
                  m_trade.PositionModify(ticket, NormalizeDouble(newSL, m_digits), currentTP);
                  PrintFormat("[AurumRisk] Breakeven activado para SELL #%d. SL movido a %.5f", ticket, newSL);
               }
            }
         }
      }
   }
};

#endif // AURUM_CLASSIC_RISK_MQH
