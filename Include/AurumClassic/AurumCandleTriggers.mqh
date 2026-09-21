//+------------------------------------------------------------------+
//|                                         AurumCandleTriggers.mqh |
//|                                  Copyright 2026, Aurum Capital   |
//|      Detector de Patrones de Velas Japonesas (Libro Opwens)      |
//|      Hammer, Shooting Star, Engulfing, Tweezers, Stars, Soldiers |
//+------------------------------------------------------------------+
#ifndef AURUM_CANDLE_TRIGGERS_MQH
#define AURUM_CANDLE_TRIGGERS_MQH

#property copyright "Aurum Capital"
#property strict

// --- Enumeración de Tipos de Señales de Velas
enum ENUM_CANDLE_PATTERN
{
   CANDLE_NONE = 0,
   CANDLE_HAMMER,               // Martillo (Alcista)
   CANDLE_INVERTED_HAMMER,      // Martillo Invertido (Alcista)
   CANDLE_BULLISH_ENGULFING,    // Envolvente Alcista
   CANDLE_TWEEZER_BOTTOM,       // Pinzas de Suelo (Alcista)
   CANDLE_MORNING_STAR,         // Estrella de la Mañana (Alcista)
   CANDLE_THREE_WHITE_SOLDIERS, // Tres Soldados Blancos (Alcista)
   CANDLE_THREE_INSIDE_UP,      // Three Inside Up (Alcista)
   
   CANDLE_HANGING_MAN,          // Hombre Colgado (Bajista)
   CANDLE_SHOOTING_STAR,        // Estrella Fugaz (Bajista)
   CANDLE_BEARISH_ENGULFING,    // Envolvente Bajista
   CANDLE_TWEEZER_TOP,          // Pinzas de Techo (Bajista)
   CANDLE_EVENING_STAR,         // Estrella del Atardecer (Bajista)
   CANDLE_THREE_BLACK_ROWS,     // Tres Cuervos Negros (Bajista)
   CANDLE_THREE_INSIDE_DOWN     // Three Inside Down (Bajista)
};

class CAurumCandleTriggers
{
private:
   double m_point;
   int    m_digits;

public:
   CAurumCandleTriggers()
   {
      m_point  = _Point;
      m_digits = _Digits;
   }

   void Init(string sym)
   {
      m_point  = SymbolInfoDouble(sym, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   }

   //+---------------------------------------------------------------+
   //| Medidas Anatómicas de una Vela                                 |
   //+---------------------------------------------------------------+
   inline double BodySize(const MqlRates &r) const
   {
      return MathAbs(r.close - r.open);
   }

   inline double CandleRange(const MqlRates &r) const
   {
      return (r.high - r.low);
   }

   inline double UpperShadow(const MqlRates &r) const
   {
      double topBody = MathMax(r.open, r.close);
      return (r.high - topBody);
   }

   inline double LowerShadow(const MqlRates &r) const
   {
      double botBody = MathMin(r.open, r.close);
      return (botBody - r.low);
   }

   inline bool IsBullish(const MqlRates &r) const
   {
      return (r.close > r.open);
   }

   inline bool IsBearish(const MqlRates &r) const
   {
      return (r.close < r.open);
   }

   //+---------------------------------------------------------------+
   //| 1. Martillo (Hammer) - Giro Alcista (Opwens p. 14)            |
   //| Mecha inferior >= 2x cuerpo, sombra superior mínima           |
   //+---------------------------------------------------------------+
   bool IsHammer(const MqlRates &rates[], int idx) const
   {
      MqlRates r = rates[idx];
      double rng = CandleRange(r);
      if(rng < 5 * m_point) return false;

      double body = BodySize(r);
      double lower = LowerShadow(r);
      double upper = UpperShadow(r);

      return (lower >= (2.0 * body) && lower >= (0.55 * rng) && upper <= (0.15 * rng));
   }

   //+---------------------------------------------------------------+
   //| 2. Estrella Fugaz (Shooting Star) - Giro Bajista (Opwens p.15)|
   //| Mecha superior >= 2x cuerpo, sombra inferior mínima           |
   //+---------------------------------------------------------------+
   bool IsShootingStar(const MqlRates &rates[], int idx) const
   {
      MqlRates r = rates[idx];
      double rng = CandleRange(r);
      if(rng < 5 * m_point) return false;

      double body = BodySize(r);
      double upper = UpperShadow(r);
      double lower = LowerShadow(r);

      return (upper >= (2.0 * body) && upper >= (0.55 * rng) && lower <= (0.15 * rng));
   }

   //+---------------------------------------------------------------+
   //| 3. Martillo Invertido (Inverted Hammer) - Giro Alcista (p.15)  |
   //+---------------------------------------------------------------+
   bool IsInvertedHammer(const MqlRates &rates[], int idx) const
   {
      return IsShootingStar(rates, idx);
   }

   //+---------------------------------------------------------------+
   //| 4. Hombre Colgado (Hanging Man) - Giro Bajista (Opwens p.14)  |
   //+---------------------------------------------------------------+
   bool IsHangingMan(const MqlRates &rates[], int idx) const
   {
      return IsHammer(rates, idx);
   }

   //+---------------------------------------------------------------+
   //| 5. Vela Envolvente Alcista (Bullish Engulfing - Opwens p. 16) |
   //+---------------------------------------------------------------+
   bool IsBullishEngulfing(const MqlRates &rates[], int idx) const
   {
      MqlRates curr = rates[idx];     // Barra más reciente cerrada (Bar 1)
      MqlRates prev = rates[idx + 1]; // Barra previa (Bar 2)

      if(!IsBearish(prev) || !IsBullish(curr)) return false;

      bool bodyEngulfs = (curr.close >= prev.open && curr.open <= prev.close);
      bool sizeSignificant = BodySize(curr) >= (BodySize(prev) * 1.1);

      return (bodyEngulfs && sizeSignificant);
   }

   //+---------------------------------------------------------------+
   //| 6. Vela Envolvente Bajista (Bearish Engulfing - Opwens p. 16) |
   //+---------------------------------------------------------------+
   bool IsBearishEngulfing(const MqlRates &rates[], int idx) const
   {
      MqlRates curr = rates[idx];
      MqlRates prev = rates[idx + 1];

      if(!IsBullish(prev) || !IsBearish(curr)) return false;

      bool bodyEngulfs = (curr.close <= prev.open && curr.open >= prev.close);
      bool sizeSignificant = BodySize(curr) >= (BodySize(prev) * 1.1);

      return (bodyEngulfs && sizeSignificant);
   }

   //+---------------------------------------------------------------+
   //| 7. Pinzas de Suelo (Tweezer Bottoms - Opwens p. 17)           |
   //+---------------------------------------------------------------+
   bool IsTweezerBottom(const MqlRates &rates[], int idx, double tolerancePips = 2.0) const
   {
      MqlRates curr = rates[idx];
      MqlRates prev = rates[idx + 1];

      double tol = tolerancePips * 10 * m_point;
      bool sameLow = MathAbs(curr.low - prev.low) <= tol;
      bool rejection = (LowerShadow(curr) >= BodySize(curr) * 0.8 && LowerShadow(prev) >= BodySize(prev) * 0.8);

      return (sameLow && rejection && IsBullish(curr));
   }

   //+---------------------------------------------------------------+
   //| 8. Pinzas de Techo (Tweezer Tops - Opwens p. 17)              |
   //+---------------------------------------------------------------+
   bool IsTweezerTop(const MqlRates &rates[], int idx, double tolerancePips = 2.0) const
   {
      MqlRates curr = rates[idx];
      MqlRates prev = rates[idx + 1];

      double tol = tolerancePips * 10 * m_point;
      bool sameHigh = MathAbs(curr.high - prev.high) <= tol;
      bool rejection = (UpperShadow(curr) >= BodySize(curr) * 0.8 && UpperShadow(prev) >= BodySize(prev) * 0.8);

      return (sameHigh && rejection && IsBearish(curr));
   }

   //+---------------------------------------------------------------+
   //| 9. Estrella de la Mañana (Morning Star - Opwens p. 18)        |
   //+---------------------------------------------------------------+
   bool IsMorningStar(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];     // Barra alcista fuerte
      MqlRates c2 = rates[idx + 1]; // Vela pequeña / indecisión
      MqlRates c1 = rates[idx + 2]; // Vela bajista previa

      if(!IsBearish(c1) || !IsBullish(c3)) return false;

      double body1 = BodySize(c1);
      double body2 = BodySize(c2);
      double body3 = BodySize(c3);

      if(body2 > (body1 * 0.45)) return false;

      double midpoint1 = (c1.open + c1.close) * 0.5;
      return (c3.close > midpoint1 && body3 >= (body1 * 0.6));
   }

   //+---------------------------------------------------------------+
   //| 10. Estrella del Atardecer (Evening Star - Opwens p. 18)      |
   //+---------------------------------------------------------------+
   bool IsEveningStar(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];     // Barra bajista fuerte
      MqlRates c2 = rates[idx + 1]; // Vela pequeña
      MqlRates c1 = rates[idx + 2]; // Vela alcista previa

      if(!IsBullish(c1) || !IsBearish(c3)) return false;

      double body1 = BodySize(c1);
      double body2 = BodySize(c2);
      double body3 = BodySize(c3);

      if(body2 > (body1 * 0.45)) return false;

      double midpoint1 = (c1.open + c1.close) * 0.5;
      return (c3.close < midpoint1 && body3 >= (body1 * 0.6));
   }

   //+---------------------------------------------------------------+
   //| 11. Tres Soldados Blancos (Three White Soldiers - Opwens p.19)|
   //+---------------------------------------------------------------+
   bool IsThreeWhiteSoldiers(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];
      MqlRates c2 = rates[idx + 1];
      MqlRates c1 = rates[idx + 2];

      if(!IsBullish(c1) || !IsBullish(c2) || !IsBullish(c3)) return false;

      bool progressiveCloses = (c2.close > c1.close && c3.close > c2.close);
      bool healthyBodies = (BodySize(c1) > 5 * m_point && BodySize(c2) > 5 * m_point && BodySize(c3) > 5 * m_point);

      return (progressiveCloses && healthyBodies);
   }

   //+---------------------------------------------------------------+
   //| 12. Tres Cuervos Negros (Three Black Crows - Opwens p. 19)    |
   //+---------------------------------------------------------------+
   bool IsThreeBlackCrows(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];
      MqlRates c2 = rates[idx + 1];
      MqlRates c1 = rates[idx + 2];

      if(!IsBearish(c1) || !IsBearish(c2) || !IsBearish(c3)) return false;

      bool progressiveCloses = (c2.close < c1.close && c3.close < c2.close);
      bool healthyBodies = (BodySize(c1) > 5 * m_point && BodySize(c2) > 5 * m_point && BodySize(c3) > 5 * m_point);

      return (progressiveCloses && healthyBodies);
   }

   //+---------------------------------------------------------------+
   //| 13. Three Inside Up (Opwens p. 20)                            |
   //+---------------------------------------------------------------+
   bool IsThreeInsideUp(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];
      MqlRates c2 = rates[idx + 1];
      MqlRates c1 = rates[idx + 2];

      if(!IsBearish(c1) || !IsBullish(c2) || !IsBullish(c3)) return false;
      bool harami = (c2.open >= c1.close && c2.close <= c1.open);
      bool confirm = (c3.close > c1.high);

      return (harami && confirm);
   }

   //+---------------------------------------------------------------+
   //| 14. Three Inside Down (Opwens p. 20)                          |
   //+---------------------------------------------------------------+
   bool IsThreeInsideDown(const MqlRates &rates[], int idx) const
   {
      MqlRates c3 = rates[idx];
      MqlRates c2 = rates[idx + 1];
      MqlRates c1 = rates[idx + 2];

      if(!IsBullish(c1) || !IsBearish(c2) || !IsBearish(c3)) return false;
      bool harami = (c2.open <= c1.close && c2.close >= c1.open);
      bool confirm = (c3.close < c1.low);

      return (harami && confirm);
   }

   //+---------------------------------------------------------------+
   //| Evaluador Global de Gatillo Candlestick en barra cerrada      |
   //+---------------------------------------------------------------+
   ENUM_CANDLE_PATTERN ScanBar(const MqlRates &rates[], int idx, bool lookForBullish) const
   {
      if(lookForBullish)
      {
         if(IsHammer(rates, idx)) return CANDLE_HAMMER;
         if(IsBullishEngulfing(rates, idx)) return CANDLE_BULLISH_ENGULFING;
         if(IsTweezerBottom(rates, idx)) return CANDLE_TWEEZER_BOTTOM;
         if(IsMorningStar(rates, idx)) return CANDLE_MORNING_STAR;
         if(IsThreeWhiteSoldiers(rates, idx)) return CANDLE_THREE_WHITE_SOLDIERS;
         if(IsThreeInsideUp(rates, idx)) return CANDLE_THREE_INSIDE_UP;
         if(IsInvertedHammer(rates, idx)) return CANDLE_INVERTED_HAMMER;
      }
      else
      {
         if(IsShootingStar(rates, idx)) return CANDLE_SHOOTING_STAR;
         if(IsBearishEngulfing(rates, idx)) return CANDLE_BEARISH_ENGULFING;
         if(IsTweezerTop(rates, idx)) return CANDLE_TWEEZER_TOP;
         if(IsEveningStar(rates, idx)) return CANDLE_EVENING_STAR;
         if(IsThreeBlackCrows(rates, idx)) return CANDLE_THREE_BLACK_ROWS;
         if(IsThreeInsideDown(rates, idx)) return CANDLE_THREE_INSIDE_DOWN;
         if(IsHangingMan(rates, idx)) return CANDLE_HANGING_MAN;
      }
      return CANDLE_NONE;
   }

   //+---------------------------------------------------------------+
   //| Nombre Legible del Patrón                                     |
   //+---------------------------------------------------------------+
   string GetPatternName(ENUM_CANDLE_PATTERN pat) const
   {
      switch(pat)
      {
         case CANDLE_HAMMER:               return "Hammer (Martillo)";
         case CANDLE_INVERTED_HAMMER:      return "Inverted Hammer";
         case CANDLE_BULLISH_ENGULFING:    return "Bullish Engulfing (Envolvente Alcista)";
         case CANDLE_TWEEZER_BOTTOM:       return "Tweezer Bottom (Pinzas de Suelo)";
         case CANDLE_MORNING_STAR:         return "Morning Star (Estrella Matutina)";
         case CANDLE_THREE_WHITE_SOLDIERS: return "Three White Soldiers (3 Soldados)";
         case CANDLE_THREE_INSIDE_UP:      return "Three Inside Up";
         case CANDLE_HANGING_MAN:          return "Hanging Man (Hombre Colgado)";
         case CANDLE_SHOOTING_STAR:        return "Shooting Star (Estrella Fugaz)";
         case CANDLE_BEARISH_ENGULFING:    return "Bearish Engulfing (Envolvente Bajista)";
         case CANDLE_TWEEZER_TOP:          return "Tweezer Top (Pinzas de Techo)";
         case CANDLE_EVENING_STAR:         return "Evening Star (Estrella Vespertina)";
         case CANDLE_THREE_BLACK_ROWS:     return "Three Black Crows (3 Cuervos)";
         case CANDLE_THREE_INSIDE_DOWN:    return "Three Inside Down";
         default:                          return "Ninguno";
      }
   }
};

#endif // AURUM_CANDLE_TRIGGERS_MQH
