//+------------------------------------------------------------------+
//|                                        AurumClassicPatterns.mqh  |
//|                                  Copyright 2026, Aurum Capital   |
//|      Detector Cartista de Figuras de Reversión y Continuidad     |
//|      HCH, Doble/Triple Techo-Suelo, Triángulos, Banderas/Banderín|
//+------------------------------------------------------------------+
#ifndef AURUM_CLASSIC_PATTERNS_MQH
#define AURUM_CLASSIC_PATTERNS_MQH

#property copyright "Aurum Capital"
#property strict

#include "AurumTrendGeometry.mqh"
#include "AurumCandleTriggers.mqh"

// --- Tipos de Patrones Cartistas Reconocidos
enum ENUM_CLASSIC_PATTERN
{
   PATTERN_NONE = 0,
   
   // Figuras de Giro / Reversión (Módulo 2, pp. 114-133)
   PATTERN_HCH_TOP,             // Hombro-Cabeza-Hombro (Bajista)
   PATTERN_HCH_BOTTOM,          // Hombro-Cabeza-Hombro Invertido (Alcista)
   PATTERN_DOUBLE_TOP,          // Doble Techo (Bajista)
   PATTERN_DOUBLE_BOTTOM,       // Doble Suelo (Alcista)
   PATTERN_TRIPLE_TOP,          // Triple Techo (Bajista)
   PATTERN_TRIPLE_BOTTOM,       // Triple Suelo (Alcista)
   
   // Figuras de Continuidad (Módulo 2, pp. 134-160)
   PATTERN_TRIANGLE_SYMMETRIC,  // Triángulo Simétrico
   PATTERN_TRIANGLE_ASCENDING,  // Triángulo Ascendente (Alcista)
   PATTERN_TRIANGLE_DESCENDING, // Triángulo Descendente (Bajista)
   PATTERN_FLAG_BULLISH,        // Bandera Alcista (Continuación)
   PATTERN_FLAG_BEARISH,        // Bandera Bajista (Continuación)
   PATTERN_PENNANT_BULLISH,     // Banderín Alcista
   PATTERN_PENNANT_BEARISH,     // Banderín Bajista
   PATTERN_RECTANGLE_RANGE      // Rectángulo de Consolidación
};

// --- Estructura para almacenar la figura detectada
struct ClassicChartPattern
{
   ENUM_CLASSIC_PATTERN type;
   bool                 isBullish;       // true = Compra, false = Venta
   datetime             formationStart;  // Tiempo inicial del patrón
   datetime             formationEnd;    // Tiempo final del patrón
   
   double               necklinePrice;   // Nivel de ruptura / Línea de cuello
   double               invalidationSL;  // Nivel de Stop Loss estructural
   double               targetHeight;    // Altura del patrón (H)
   double               takeProfitTarget;// Objetivo proyectado (Punto de quiebre +- H)
   
   bool                 isBreakout;      // Ruptura ocurrida
   bool                 isRetest;        // Retroceso (Pullback/Throwback) a la directriz
   datetime             breakTime;       // Momento de la ruptura
   string               name;            // Nombre descriptivo
};

//+------------------------------------------------------------------+
//| Clase Motor de Reconocimiento de Patrones Cartistas              |
//+------------------------------------------------------------------+
class CAurumClassicPatterns
{
private:
   string              m_symbol;
   ENUM_TIMEFRAMES     m_timeframe;
   CAurumTrendGeometry m_geom;
   double              m_point;
   int                 m_digits;

public:
   CAurumClassicPatterns() : m_symbol(_Symbol), m_timeframe(_Period)
   {
      m_point = _Point;
      m_digits = _Digits;
   }

   void Init(string sym, ENUM_TIMEFRAMES tf, int swingStrength = 4)
   {
      m_symbol = sym;
      m_timeframe = tf;
      m_point = SymbolInfoDouble(sym, SYMBOL_POINT);
      m_digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      m_geom.Init(sym, tf, swingStrength);
   }

   //+---------------------------------------------------------------+
   //| 1. Detección de Hombro-Cabeza-Hombro (HCH) Superior e Inferior |
   //+---------------------------------------------------------------+
   bool DetectHCH(const SwingPoint &swings[], int swingCount, ClassicChartPattern &pattern)
   {
      pattern.type = PATTERN_NONE;
      if(swingCount < 5) return false;

      // HCH Superior (Bearish): High (H1), Low (L1), High (Head), Low (L2), High (H2)
      // Buscamos 3 picos consecutivos intercalados con 2 valles
      for(int i = 0; i <= swingCount - 5; i++)
      {
         if(swings[i].isHigh && !swings[i+1].isHigh && swings[i+2].isHigh && !swings[i+3].isHigh && swings[i+4].isHigh)
         {
            // swings[i] = Hombro Derecho (H2)
            // swings[i+1] = Valle Derecho (L2)
            // swings[i+2] = Cabeza (Head)
            // swings[i+3] = Valle Izquierdo (L1)
            // swings[i+4] = Hombro Izquierdo (H1)
            double h1 = swings[i+4].price;
            double l1 = swings[i+3].price;
            double head = swings[i+2].price;
            double l2 = swings[i+1].price;
            double h2 = swings[i].price;

            // Regla: Cabeza más alta que ambos hombros
            if(head > h1 && head > h2)
            {
               // Regla: Los hombros deben tener alturas razonablemente proporcionales (desviación < 35%)
               double shoulderDiff = MathAbs(h1 - h2);
               double headHeight = head - MathMin(l1, l2);
               if(headHeight > 0 && (shoulderDiff / headHeight) < 0.35)
               {
                  // Neckline promedio de los valles
                  double neckline = (l1 + l2) * 0.5;
                  double H = head - neckline;

                  pattern.type = PATTERN_HCH_TOP;
                  pattern.isBullish = false;
                  pattern.formationStart = swings[i+4].time;
                  pattern.formationEnd = swings[i].time;
                  pattern.necklinePrice = neckline;
                  pattern.invalidationSL = h2 + (headHeight * 0.1); // SL encima del hombro derecho
                  pattern.targetHeight = H;
                  pattern.takeProfitTarget = neckline - H; // Proyección H hacia abajo
                  pattern.name = "Hombro-Cabeza-Hombro (HCH)";
                  return true;
               }
            }
         }

         // HCH Invertido (Bullish): Low (L1), High (H1), Low (Head), High (H2), Low (L2)
         if(!swings[i].isHigh && swings[i+1].isHigh && !swings[i+2].isHigh && swings[i+3].isHigh && !swings[i+4].isHigh)
         {
            double l1 = swings[i+4].price;
            double h1 = swings[i+3].price;
            double head = swings[i+2].price;
            double h2 = swings[i+1].price;
            double l2 = swings[i].price;

            if(head < l1 && head < l2)
            {
               double shoulderDiff = MathAbs(l1 - l2);
               double headDepth = MathMax(h1, h2) - head;
               if(headDepth > 0 && (shoulderDiff / headDepth) < 0.35)
               {
                  double neckline = (h1 + h2) * 0.5;
                  double H = neckline - head;

                  pattern.type = PATTERN_HCH_BOTTOM;
                  pattern.isBullish = true;
                  pattern.formationStart = swings[i+4].time;
                  pattern.formationEnd = swings[i].time;
                  pattern.necklinePrice = neckline;
                  pattern.invalidationSL = l2 - (headDepth * 0.1); // SL debajo del hombro derecho
                  pattern.targetHeight = H;
                  pattern.takeProfitTarget = neckline + H; // Proyección H hacia arriba
                  pattern.name = "HCH Invertido (Bullish)";
                  return true;
               }
            }
         }
      }
      return false;
   }

   //+---------------------------------------------------------------+
   //| 2. Detección de Doble Techo y Doble Suelo                     |
   //+---------------------------------------------------------------+
   bool DetectDoubleTopBottom(const SwingPoint &swings[], int swingCount, ClassicChartPattern &pattern)
   {
      pattern.type = PATTERN_NONE;
      if(swingCount < 3) return false;

      // Doble Techo (Bearish): High (T2), Low (Valle), High (T1)
      for(int i = 0; i <= swingCount - 3; i++)
      {
         if(swings[i].isHigh && !swings[i+1].isHigh && swings[i+2].isHigh)
         {
            double t2 = swings[i].price;
            double valley = swings[i+1].price;
            double t1 = swings[i+2].price;

            double peakDiff = MathAbs(t1 - t2);
            double height = ((t1 + t2) * 0.5) - valley;

            // Los picos están a nivel muy similar (diferencia < 15% de la altura total)
            if(height > 10 * m_point && (peakDiff / height) < 0.15)
            {
               pattern.type = PATTERN_DOUBLE_TOP;
               pattern.isBullish = false;
               pattern.formationStart = swings[i+2].time;
               pattern.formationEnd = swings[i].time;
               pattern.necklinePrice = valley;
               pattern.invalidationSL = MathMax(t1, t2) + (height * 0.1);
               pattern.targetHeight = height;
               pattern.takeProfitTarget = valley - height; // Proyección de altura H
               pattern.name = "Doble Techo (Double Top)";
               return true;
            }
         }

         // Doble Suelo (Bullish): Low (B2), High (Cresta), Low (B1)
         if(!swings[i].isHigh && swings[i+1].isHigh && !swings[i+2].isHigh)
         {
            double b2 = swings[i].price;
            double peak = swings[i+1].price;
            double b1 = swings[i+2].price;

            double bottomDiff = MathAbs(b1 - b2);
            double height = peak - ((b1 + b2) * 0.5);

            if(height > 10 * m_point && (bottomDiff / height) < 0.15)
            {
               pattern.type = PATTERN_DOUBLE_BOTTOM;
               pattern.isBullish = true;
               pattern.formationStart = swings[i+2].time;
               pattern.formationEnd = swings[i].time;
               pattern.necklinePrice = peak;
               pattern.invalidationSL = MathMin(b1, b2) - (height * 0.1);
               pattern.targetHeight = height;
               pattern.takeProfitTarget = peak + height;
               pattern.name = "Doble Suelo (Double Bottom)";
               return true;
            }
         }
      }
      return false;
   }

   //+---------------------------------------------------------------+
   //| 3. Detección de Triángulos (Simétrico, Ascendente, Descendente)|
   //+---------------------------------------------------------------+
   bool DetectTriangles(const SwingPoint &swings[], int swingCount, ClassicChartPattern &pattern)
   {
      pattern.type = PATTERN_NONE;
      if(swingCount < 4) return false;

      // Necesitamos al menos 2 Swing Highs y 2 Swing Lows recientes
      int hCount = 0, lCount = 0;
      SwingPoint highs[2], lows[2];

      for(int i = 0; i < swingCount && (hCount < 2 || lCount < 2); i++)
      {
         if(swings[i].isHigh && hCount < 2)
         {
            highs[hCount++] = swings[i];
         }
         else if(!swings[i].isHigh && lCount < 2)
         {
            lows[lCount++] = swings[i];
         }
      }

      if(hCount < 2 || lCount < 2) return false;

      // highs[0] es el más reciente, highs[1] el anterior
      // lows[0] es el más reciente, lows[1] el anterior
      double hSlope = (highs[0].price - highs[1].price) / (double)(highs[1].barIndex - highs[0].barIndex);
      double lSlope = (lows[0].price - lows[1].price) / (double)(lows[1].barIndex - lows[0].barIndex);
      double baseHeight = MathAbs(highs[1].price - lows[1].price);

      if(baseHeight < 15 * m_point) return false;

      // Triángulo Ascendente: Resistencia plana (hSlope ~ 0) y mínimos ascendentes (lSlope > 0)
      if(MathAbs(highs[0].price - highs[1].price) <= (baseHeight * 0.12) && lows[0].price > lows[1].price)
      {
         pattern.type = PATTERN_TRIANGLE_ASCENDING;
         pattern.isBullish = true;
         pattern.formationStart = highs[1].time;
         pattern.formationEnd = highs[0].time;
         pattern.necklinePrice = (highs[0].price + highs[1].price) * 0.5;
         pattern.invalidationSL = lows[0].price - (baseHeight * 0.1);
         pattern.targetHeight = baseHeight;
         pattern.takeProfitTarget = pattern.necklinePrice + baseHeight;
         pattern.name = "Triángulo Ascendente";
         return true;
      }

      // Triángulo Descendente: Soporte plano (lSlope ~ 0) y máximos descendentes (hSlope < 0)
      if(MathAbs(lows[0].price - lows[1].price) <= (baseHeight * 0.12) && highs[0].price < highs[1].price)
      {
         pattern.type = PATTERN_TRIANGLE_DESCENDING;
         pattern.isBullish = false;
         pattern.formationStart = lows[1].time;
         pattern.formationEnd = lows[0].time;
         pattern.necklinePrice = (lows[0].price + lows[1].price) * 0.5;
         pattern.invalidationSL = highs[0].price + (baseHeight * 0.1);
         pattern.targetHeight = baseHeight;
         pattern.takeProfitTarget = pattern.necklinePrice - baseHeight;
         pattern.name = "Triángulo Descendente";
         return true;
      }

      // Triángulo Simétrico: Máximos descendentes (hSlope < 0) Y Mínimos ascendentes (lSlope > 0)
      if(highs[0].price < highs[1].price && lows[0].price > lows[1].price)
      {
         pattern.type = PATTERN_TRIANGLE_SYMMETRIC;
         pattern.formationStart = highs[1].time;
         pattern.formationEnd = highs[0].time;
         pattern.targetHeight = baseHeight;
         pattern.name = "Triángulo Simétrico";
         // La dirección dependerá del breakout
         return true;
      }

      return false;
   }

   //+---------------------------------------------------------------+
   //| 4. Detección de Banderas y Banderines (Flags & Pennants)      |
   //| Requiere un Mástil Impulsivo previo + Consolidación Estrecha  |
   //+---------------------------------------------------------------+
   bool DetectFlags(const MqlRates &rates[], int totalBars, const SwingPoint &swings[], int swingCount, ClassicChartPattern &pattern)
   {
      pattern.type = PATTERN_NONE;
      if(swingCount < 4 || totalBars < 40) return false;

      // Comprobar si hubo un mástil fuerte (gran desplazamiento en pocas barras)
      // Comparar swings[2] y swings[3] (mástil) contra la consolidación swings[0] y swings[1]
      double poleHeight = MathAbs(swings[2].price - swings[3].price);
      double flagHeight = MathAbs(swings[0].price - swings[1].price);

      if(poleHeight <= 0.0 || flagHeight <= 0.0) return false;

      // La consolidación de la bandera debe ser compacta: entre 20% y 50% del mástil
      double ratio = flagHeight / poleHeight;
      if(ratio >= 0.15 && ratio <= 0.50)
      {
         bool poleWasBullish = (swings[2].price > swings[3].price && swings[2].isHigh);
         bool poleWasBearish = (swings[2].price < swings[3].price && !swings[2].isHigh);

         if(poleWasBullish) // Bandera alcista: consolidación inclinada a la baja
         {
            pattern.type = PATTERN_FLAG_BULLISH;
            pattern.isBullish = true;
            pattern.formationStart = swings[3].time;
            pattern.formationEnd = swings[0].time;
            pattern.necklinePrice = swings[0].price; // Nivel de salida superior
            pattern.invalidationSL = MathMin(swings[0].price, swings[1].price);
            pattern.targetHeight = poleHeight; // Target = longitud del mástil proyectado
            pattern.takeProfitTarget = pattern.necklinePrice + poleHeight;
            pattern.name = "Bandera Alcista (Bull Flag)";
            return true;
         }
         else if(poleWasBearish) // Bandera bajista
         {
            pattern.type = PATTERN_FLAG_BEARISH;
            pattern.isBullish = false;
            pattern.formationStart = swings[3].time;
            pattern.formationEnd = swings[0].time;
            pattern.necklinePrice = swings[0].price;
            pattern.invalidationSL = MathMax(swings[0].price, swings[1].price);
            pattern.targetHeight = poleHeight;
            pattern.takeProfitTarget = pattern.necklinePrice - poleHeight;
            pattern.name = "Bandera Bajista (Bear Flag)";
            return true;
         }
      }

      return false;
   }

   //+---------------------------------------------------------------+
   //| Escaneo Unificado del Gráfico en Busca del Mejor Patrón       |
   //+---------------------------------------------------------------+
   bool ScanCurrentPattern(const MqlRates &rates[], int totalBars, ClassicChartPattern &pattern)
   {
      SwingPoint swings[];
      int count = m_geom.FindSwingPoints(rates, totalBars, swings, 25);
      if(count < 3) return false;

      // 1. Probar HCH
      if(DetectHCH(swings, count, pattern)) return true;

      // 2. Probar Doble Techo / Doble Suelo
      if(DetectDoubleTopBottom(swings, count, pattern)) return true;

      // 3. Probar Banderas y Banderines
      if(DetectFlags(rates, totalBars, swings, count, pattern)) return true;

      // 4. Probar Triángulos
      if(DetectTriangles(swings, count, pattern)) return true;

      return false;
   }
};

#endif // AURUM_CLASSIC_PATTERNS_MQH
