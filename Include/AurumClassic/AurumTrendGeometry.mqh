//+------------------------------------------------------------------+
//|                                           AurumTrendGeometry.mqh |
//|                                  Copyright 2026, Aurum Capital   |
//|      Módulo de Geometría Cartista: Swings, Directrices, Canales, |
//|           Principio Abanico y Retrocesos de Dow / Fibonacci      |
//+------------------------------------------------------------------+
#ifndef AURUM_TREND_GEOMETRY_MQH
#define AURUM_TREND_GEOMETRY_MQH

#property copyright "Aurum Capital"
#property strict

// --- Estructura para representar un punto 2D (Tiempo, Precio, Barra)
struct Point2D
{
   datetime time;
   double   price;
   int      barIndex;
};

// --- Estructura para puntos de giro / fractales (Swings)
struct SwingPoint
{
   datetime time;
   double   price;
   int      barIndex;
   bool     isHigh; // true = Swing High, false = Swing Low
};

// --- Estructura de Línea de Tendencia / Directriz
struct TrendLine
{
   Point2D  p1;
   Point2D  p2;
   double   slope;     // Cambio de precio por barra
   bool     isValid;
   bool     isSupport; // true = Soporte (une mínimos), false = Resistencia (une máximos)

   double GetPriceAtBar(int bar) const
   {
      if(!isValid || p1.barIndex == p2.barIndex) return 0.0;
      return p1.price + slope * (p1.barIndex - bar);
   }

   double GetPriceAtTime(datetime t) const
   {
      if(!isValid || p2.time == p1.time) return 0.0;
      double timeSlope = (p2.price - p1.price) / (double)(p2.time - p1.time);
      return p1.price + timeSlope * (double)(t - p1.time);
   }
};

// --- Estructura del Principio Abanico (Fan Principle - 3 Líneas)
struct FanPrinciple
{
   TrendLine line1;
   TrendLine line2;
   TrendLine line3;
   bool      isBullish;   // Abanico alcista (soportes) o bajista (resistencias)
   bool      isLine1Broken;
   bool      isLine2Broken;
   bool      isLine3Broken; // Si se rompe la 3ª línea, reversión confirmada al 100%
   bool      isReversalConfirmed;
};

// --- Estructura de Canal de Tendencia (Canal Básico + Retorno)
struct TrendChannel
{
   TrendLine baseLine;    // Directriz básica de tendencia
   TrendLine returnLine;  // Línea de retorno paralela
   double    channelWidth;// Anchura vertical del canal
   bool      isBullish;
   bool      isValid;
};

// --- Estructura de Retrocesos de Dow y Fibonacci
struct RetracementLevels
{
   double highPrice;
   double lowPrice;
   double range;
   bool   isUptrend;
   
   // Dow Theory Percentage Retracements (Módulo 2, p.87-88)
   double dow33; // 1/3 (33.3%)
   double dow50; // 1/2 (50.0%)
   double dow66; // 2/3 (66.6%)
   
   // Fibonacci Retracements
   double fibo236; // 23.6%
   double fibo382; // 38.2%
   double fibo500; // 50.0%
   double fibo618; // 61.8% (Golden Ratio)
   double fibo786; // 78.6%
};

//+------------------------------------------------------------------+
//| Clase de Detección Geométrica de Tendencias y Swings              |
//+------------------------------------------------------------------+
class CAurumTrendGeometry
{
private:
   string         m_symbol;
   ENUM_TIMEFRAMES m_timeframe;
   int            m_swingStrength; // Barras a izq y der para validar un swing fractal

public:
   CAurumTrendGeometry() : m_symbol(_Symbol), m_timeframe(_Period), m_swingStrength(4) {}
   ~CAurumTrendGeometry() {}

   void Init(string sym, ENUM_TIMEFRAMES tf, int swingStrength = 4)
   {
      m_symbol = sym;
      m_timeframe = tf;
      m_swingStrength = (swingStrength < 2) ? 2 : swingStrength;
   }

   //+---------------------------------------------------------------+
   //| Detectar Swings Highs y Lows (Fractales Clásicos de Dow)       |
   //+---------------------------------------------------------------+
   int FindSwingPoints(const MqlRates &rates[], int totalBars, SwingPoint &swings[], int maxSwings = 40)
   {
      ArrayResize(swings, 0);
      if(totalBars < (m_swingStrength * 2 + 5)) return 0;

      int count = 0;
      // Recorremos desde las barras más recientes (dejando m_swingStrength para confirmación)
      for(int i = m_swingStrength; i < totalBars - m_swingStrength && count < maxSwings; i++)
      {
         bool isHigh = true;
         bool isLow  = true;
         double currentHigh = rates[i].high;
         double currentLow  = rates[i].low;

         for(int j = 1; j <= m_swingStrength; j++)
         {
            if(rates[i - j].high >= currentHigh || rates[i + j].high > currentHigh)
               isHigh = false;
            if(rates[i - j].low <= currentLow || rates[i + j].low < currentLow)
               isLow = false;
         }

         if(isHigh)
         {
            ArrayResize(swings, count + 1);
            swings[count].time = rates[i].time;
            swings[count].price = currentHigh;
            swings[count].barIndex = i;
            swings[count].isHigh = true;
            count++;
         }
         else if(isLow)
         {
            ArrayResize(swings, count + 1);
            swings[count].time = rates[i].time;
            swings[count].price = currentLow;
            swings[count].barIndex = i;
            swings[count].isHigh = false;
            count++;
         }
      }
      return count;
   }

   //+---------------------------------------------------------------+
   //| Construir Línea de Tendencia a partir de dos puntos            |
   //+---------------------------------------------------------------+
   bool BuildTrendLine(const Point2D &pt1, const Point2D &pt2, bool isSupport, TrendLine &line)
   {
      line.isValid = false;
      if(pt1.barIndex == pt2.barIndex || pt1.time == pt2.time) return false;

      Point2D p1 = pt1;
      Point2D p2 = pt2;

      // Asegurar que p1 sea el punto más antiguo (mayor barIndex en arrays ordenados como series)
      if(p1.barIndex < p2.barIndex)
      {
         Point2D temp = p1;
         p1 = p2;
         p2 = temp;
      }

      line.p1 = p1;
      line.p2 = p2;
      line.slope = (p2.price - p1.price) / (double)(p1.barIndex - p2.barIndex);
      line.isSupport = isSupport;
      line.isValid = true;
      return true;
   }

   //+---------------------------------------------------------------+
   //| Verificar Ruptura Válida de Línea de Tendencia con Cierre      |
   //+---------------------------------------------------------------+
   bool CheckLineBreak(const TrendLine &line, const MqlRates &rates[], int barCheck, bool &brokenUp, bool &brokenDown)
   {
      brokenUp = false;
      brokenDown = false;
      if(!line.isValid) return false;

      double linePrice = line.GetPriceAtBar(barCheck);
      if(linePrice <= 0.0) return false;

      // Ruptura alcista: vela cierra por encima de directriz de resistencia
      if(!line.isSupport && rates[barCheck].close > linePrice)
      {
         brokenUp = true;
         return true;
      }
      // Ruptura bajista: vela cierra por debajo de directriz de soporte
      if(line.isSupport && rates[barCheck].close < linePrice)
      {
         brokenDown = true;
         return true;
      }

      return false;
   }

   //+---------------------------------------------------------------+
   //| Construir Canal de Tendencia Paralelo                          |
   //+---------------------------------------------------------------+
   bool BuildChannel(const TrendLine &baseLine, const SwingPoint &swings[], int swingCount, TrendChannel &channel)
   {
      channel.isValid = false;
      if(!baseLine.isValid || swingCount < 3) return false;

      channel.baseLine = baseLine;
      channel.isBullish = baseLine.isSupport;
      double maxDist = 0.0;
      Point2D extremePoint;
      extremePoint.barIndex = -1;

      // Buscar el swing opuesto más alejado que defina la línea de retorno
      for(int i = 0; i < swingCount; i++)
      {
         if(channel.isBullish && swings[i].isHigh) // en canal alcista buscamos el swing high más alto relativo a la base
         {
            double baseAtBar = baseLine.GetPriceAtBar(swings[i].barIndex);
            double dist = swings[i].price - baseAtBar;
            if(dist > maxDist)
            {
               maxDist = dist;
               extremePoint.barIndex = swings[i].barIndex;
               extremePoint.price = swings[i].price;
               extremePoint.time = swings[i].time;
            }
         }
         else if(!channel.isBullish && !swings[i].isHigh) // en canal bajista buscamos el swing low más bajo relativo a la base
         {
            double baseAtBar = baseLine.GetPriceAtBar(swings[i].barIndex);
            double dist = baseAtBar - swings[i].price;
            if(dist > maxDist)
            {
               maxDist = dist;
               extremePoint.barIndex = swings[i].barIndex;
               extremePoint.price = swings[i].price;
               extremePoint.time = swings[i].time;
            }
         }
      }

      if(maxDist <= 0.0 || extremePoint.barIndex < 0) return false;

      channel.channelWidth = maxDist;
      channel.returnLine = baseLine;
      channel.returnLine.isSupport = !baseLine.isSupport;
      channel.returnLine.p1.price += (channel.isBullish ? maxDist : -maxDist);
      channel.returnLine.p2.price += (channel.isBullish ? maxDist : -maxDist);
      channel.isValid = true;
      return true;
   }

   //+---------------------------------------------------------------+
   //| Calcular Niveles de Retroceso Dow & Fibonacci                  |
   //+---------------------------------------------------------------+
   void CalculateRetracements(double highPrice, double lowPrice, bool isUptrend, RetracementLevels &lvl)
   {
      lvl.highPrice = highPrice;
      lvl.lowPrice  = lowPrice;
      lvl.range     = highPrice - lowPrice;
      lvl.isUptrend = isUptrend;

      if(isUptrend) // Impulso alcista: el retroceso cae desde highPrice
      {
         lvl.dow33   = highPrice - (lvl.range * 0.3333);
         lvl.dow50   = highPrice - (lvl.range * 0.5000);
         lvl.dow66   = highPrice - (lvl.range * 0.6666);

         lvl.fibo236 = highPrice - (lvl.range * 0.236);
         lvl.fibo382 = highPrice - (lvl.range * 0.382);
         lvl.fibo500 = highPrice - (lvl.range * 0.500);
         lvl.fibo618 = highPrice - (lvl.range * 0.618);
         lvl.fibo786 = highPrice - (lvl.range * 0.786);
      }
      else // Impulso bajista: el retroceso sube desde lowPrice
      {
         lvl.dow33   = lowPrice + (lvl.range * 0.3333);
         lvl.dow50   = lowPrice + (lvl.range * 0.5000);
         lvl.dow66   = lowPrice + (lvl.range * 0.6666);

         lvl.fibo236 = lowPrice + (lvl.range * 0.236);
         lvl.fibo382 = lowPrice + (lvl.range * 0.382);
         lvl.fibo500 = lowPrice + (lvl.range * 0.500);
         lvl.fibo618 = lowPrice + (lvl.range * 0.618);
         lvl.fibo786 = lowPrice + (lvl.range * 0.786);
      }
   }
};

#endif // AURUM_TREND_GEOMETRY_MQH
