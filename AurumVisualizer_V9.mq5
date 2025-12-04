//+------------------------------------------------------------------+
//|                                          AurumVisualizer_V9.mq5 |
//|                               Copyright 2025, Aurum Capital     |
//+------------------------------------------------------------------+
#property copyright "Aurum Capital"
#property version   "9.00"
#property indicator_chart_window
#property indicator_buffers 2
#property indicator_plots   2

#property indicator_label1  "Buy Signal"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrLime
#property indicator_width1  2

#property indicator_label2  "Sell Signal"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrRed
#property indicator_width2  2

//--- INPUTS
input group "Estrategia M5"
input int    InpDistanciaPuntos = 50;
input int    InpADXThreshold    = 20;
input int    InpEMAPeriod   = 200;
input int    InpRSIPeriod   = 14;
input double InpRSIOverbought = 75.0;
input double InpRSIOversold   = 25.0;

//--- BUFFERS
double BuyBuffer[];
double SellBuffer[];

//--- HANDLES
int hMA, hRSI, hADX;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
  {
   SetIndexBuffer(0, BuyBuffer, INDICATOR_DATA);
   SetIndexBuffer(1, SellBuffer, INDICATOR_DATA);

   PlotIndexSetInteger(0, PLOT_ARROW, 233); // Up Arrow
   PlotIndexSetInteger(1, PLOT_ARROW, 234); // Down Arrow

   hMA = iMA(_Symbol, PERIOD_M15, InpEMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   hRSI = iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
   hADX = iADX(_Symbol, PERIOD_M15, 14);

   if(hMA == INVALID_HANDLE || hRSI == INVALID_HANDLE || hADX == INVALID_HANDLE)
      return(INIT_FAILED);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Helper: Check for Candle Pattern                                |
//+------------------------------------------------------------------+
string GetPatternName(string type, int shift, const double &open[], const double &high[], const double &low[], const double &close[])
  {
   double b_open  = open[shift];
   double b_close = close[shift];
   double b_high  = high[shift];
   double b_low   = low[shift];

   double body  = MathAbs(b_close - b_open);
   double range = b_high - b_low;
   if(range == 0) return "";

   double upper_wick = b_high - MathMax(b_open, b_close);
   double lower_wick = MathMin(b_open, b_close) - b_low;

   if(type == "BUY")
     {
      // Hammer
      if((lower_wick >= 2 * body) && (MathMin(b_open, b_close) >= b_low + (0.7 * range)))
         return "Hammer";

      // Bullish Engulfing
      double prev_open  = open[shift + 1];
      double prev_close = close[shift + 1];
      if((prev_close < prev_open) && (b_close > b_open) &&
         (b_close > prev_open) && (b_open < prev_close))
         return "Bullish Engulfing";
     }

   if(type == "SELL")
     {
      // Shooting Star
      if((upper_wick >= 2 * body) && (MathMax(b_open, b_close) <= b_low + (0.3 * range)))
         return "Shooting Star";

      // Bearish Engulfing
      double prev_open  = open[shift + 1];
      double prev_close = close[shift + 1];
      if((prev_close > prev_open) && (b_close < b_open) &&
         (b_close < prev_open) && (b_open > prev_close))
         return "Bearish Engulfing";
     }

   return "";
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
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(BuyBuffer, true);
   ArraySetAsSeries(SellBuffer, true);

   int limit = rates_total - prev_calculated;
   if(limit > rates_total - 1000) limit = rates_total - 1000;
   if(prev_calculated == 0) limit = rates_total - 1000;

   for(int i=limit; i>=0; i--)
     {
      BuyBuffer[i] = EMPTY_VALUE;
      SellBuffer[i] = EMPTY_VALUE;

      string pat_buy = GetPatternName("BUY", i, open, high, low, close);
      string pat_sell = GetPatternName("SELL", i, open, high, low, close);

      if(pat_buy == "" && pat_sell == "") continue;

      datetime bar_time = time[i];

      double rsi_vals[1];
      if(CopyBuffer(hRSI, 0, i, 1, rsi_vals) <= 0) continue;
      double rsi = rsi_vals[0];

      int i_m15 = iBarShift(_Symbol, PERIOD_M15, bar_time);
      if(i_m15 < 0) continue;

      double adx_vals[1];
      if(CopyBuffer(hADX, 0, i_m15, 1, adx_vals) <= 0) continue;
      double adx = adx_vals[0];

      double ma_vals[1];
      if(CopyBuffer(hMA, 0, i_m15, 1, ma_vals) <= 0) continue;
      double ma = ma_vals[0];

      double close_m15 = iClose(_Symbol, PERIOD_M15, i_m15);
      bool trend_bullish = close_m15 > ma;
      bool trend_bearish = close_m15 < ma;

      int i_h1 = iBarShift(_Symbol, PERIOD_H1, bar_time);
      double h1_high = iHigh(_Symbol, PERIOD_H1, iHighest(_Symbol, PERIOD_H1, MODE_HIGH, 20, i_h1 + 1));
      double h1_low  = iLow(_Symbol, PERIOD_H1, iLowest(_Symbol, PERIOD_H1, MODE_LOW, 20, i_h1 + 1));
      double dist = InpDistanciaPuntos * SymbolInfoDouble(_Symbol, SYMBOL_POINT);

      bool in_buy_zone  = MathAbs(close[i] - h1_low) <= dist;
      bool in_sell_zone = MathAbs(close[i] - h1_high) <= dist;

      if(pat_buy != "" && trend_bullish && in_buy_zone && rsi < InpRSIOversold && adx > InpADXThreshold)
        {
         BuyBuffer[i] = low[i] - 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        }
      else if(pat_sell != "" && trend_bearish && in_sell_zone && rsi > InpRSIOverbought && adx > InpADXThreshold)
        {
         SellBuffer[i] = high[i] + 10 * SymbolInfoDouble(_Symbol, SYMBOL_POINT);
        }
     }

   string comment = "Aurum Visualizer V9\n";
   comment += "RSI: " + DoubleToString(iRSI(_Symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE, 0), 2) + "\n";

   string curr_pat_buy = GetPatternName("BUY", 0, open, high, low, close);
   string curr_pat_sell = GetPatternName("SELL", 0, open, high, low, close);

   string pat_status = "ESPERANDO";
   if(curr_pat_buy != "") pat_status = "BUY: " + curr_pat_buy;
   else if(curr_pat_sell != "") pat_status = "SELL: " + curr_pat_sell;

   comment += "Patrón Vela: " + pat_status;

   Comment(comment);

   return(rates_total);
  }
