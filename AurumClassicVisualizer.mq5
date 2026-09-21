//+------------------------------------------------------------------+
//|                                       AurumClassicVisualizer.mq5 |
//|                                  Copyright 2026, Aurum Capital   |
//|      Indicador Gráfico: Visualizador de Patrones Cartistas y    |
//|      Gatillos Candlestick (Módulo 2 & Libro Opwens)             |
//+------------------------------------------------------------------+
#property copyright   "Aurum Capital"
#property link        "https://aurumcapital.io"
#property version     "1.00"
#property description "AurumClassicVisualizer: Muestra Figuras Cartistas y Gatillos de Velas en Vivo"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Señal Compra Cartista"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLimeGreen
#property indicator_width1  2

#property indicator_label2  "Señal Venta Cartista"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrCrimson
#property indicator_width2  2

#include <AurumClassic\AurumTrendGeometry.mqh>
#include <AurumClassic\AurumCandleTriggers.mqh>
#include <AurumClassic\AurumClassicPatterns.mqh>

// --- INPUTS
input group "=== CONFIGURACIÓN DE ESCANEO ==="
input int  InpSwingStrength = 4;     // Sensibilidad de Swings (Fractales)
input bool InpShowLabels    = true;  // Dibujar Nombres de Patrones sobre las Velas
input bool InpScanCandles   = true;  // Mostrar Señales de Gatillos Candlestick (Opwens)

// --- BUFFERS
double BuyArrowBuffer[];
double SellArrowBuffer[];

// --- OBJETOS
CAurumTrendGeometry     ExtGeom;
CAurumCandleTriggers    ExtCandles;
CAurumClassicPatterns   ExtPatterns;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, BuyArrowBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellArrowBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Flecha Alcista
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Flecha Bajista

   ExtGeom.Init(_Symbol, _Period, InpSwingStrength);
   ExtCandles.Init(_Symbol);
   ExtPatterns.Init(_Symbol, _Period, InpSwingStrength);

   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "AurumVis_");
   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 50) return 0;

   // Inicializar buffers para barras nuevas
   int start = (prev_calculated > 0) ? prev_calculated - 1 : 0;
   for(int i = start; i < rates_total; i++)
   {
      BuyArrowBuffer[i] = EMPTY_VALUE;
      SellArrowBuffer[i] = EMPTY_VALUE;
   }

   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, _Period, 0, MathMin(rates_total, 120), rates);
   if(copied < 40) return rates_total;

   static datetime s_last_pattern_time = 0;
   static ENUM_CLASSIC_PATTERN s_last_pattern_type = PATTERN_NONE;

   // Escaneo del patrón chartista más reciente
   ClassicChartPattern pat;
   if(ExtPatterns.ScanCurrentPattern(rates, copied, pat))
   {
      // Solo dibujar una vez por cada formación única de patrón
      if(pat.formationEnd != s_last_pattern_time || pat.type != s_last_pattern_type)
      {
         s_last_pattern_time = pat.formationEnd;
         s_last_pattern_type = pat.type;

         int targetBar = -1;
         for(int b = rates_total - 1; b >= MathMax(0, rates_total - 40); b--)
         {
            if(time[b] <= pat.formationEnd)
            {
               targetBar = b;
               break;
            }
         }
         if(targetBar < 0) targetBar = rates_total - 2;

         if(pat.isBullish)
         {
            BuyArrowBuffer[targetBar] = low[targetBar] - (10 * _Point);
            if(InpShowLabels)
            {
               string txtName = "AurumVis_Pat_" + IntegerToString(pat.type) + "_" + TimeToString(pat.formationEnd);
               if(ObjectFind(0, txtName) < 0)
               {
                  ObjectCreate(0, txtName, OBJ_TEXT, 0, time[targetBar], low[targetBar] - (25 * _Point));
                  ObjectSetString(0, txtName, OBJPROP_TEXT, pat.name);
                  ObjectSetInteger(0, txtName, OBJPROP_COLOR, clrLimeGreen);
                  ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 8);
               }
            }
         }
         else
         {
            SellArrowBuffer[targetBar] = high[targetBar] + (10 * _Point);
            if(InpShowLabels)
            {
               string txtName = "AurumVis_Pat_" + IntegerToString(pat.type) + "_" + TimeToString(pat.formationEnd);
               if(ObjectFind(0, txtName) < 0)
               {
                  ObjectCreate(0, txtName, OBJ_TEXT, 0, time[targetBar], high[targetBar] + (25 * _Point));
                  ObjectSetString(0, txtName, OBJPROP_TEXT, pat.name);
                  ObjectSetInteger(0, txtName, OBJPROP_COLOR, clrCrimson);
                  ObjectSetInteger(0, txtName, OBJPROP_FONTSIZE, 8);
               }
            }
         }
      }
   }

   return rates_total;
}
