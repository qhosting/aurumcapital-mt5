//+------------------------------------------------------------------+
//|                                           AurumHistorySync.mq5   |
//|                                  Copyright 2026, Aurum Capital   |
//|                 Sincronizador de Historial de Cuenta a Aurum AIS |
//+------------------------------------------------------------------+
#property copyright   "Copyright 2026, Aurum Capital"
#property link        "https://auruminvest.mx"
#property version     "1.00"
#property description "Exporta y sincroniza todo el historial de operaciones de la cuenta actual hacia Aurum Invest Station (AIS)"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Parámetros de Entrada                                            |
//+------------------------------------------------------------------+
input group "=== Configuración de Aurum Invest Station ==="
input string InpApiKey            = "aurum-v15-c41b9551";                                // API Key de AIS
input string InpApiUrl            = "https://auruminvest.mx/api/webhooks/mt5/sync-history"; // URL del Endpoint de Sincronización
input string InpCustomAccountName = "";                                                  // Nombre Personalizado (Opcional, ej: 'XM Real Micro')

input group "=== Filtros de Historial ==="
input int    InpDaysBack          = 0;                                                   // Días de historial a sincronizar (0 = Completo)
input int    InpBatchSize         = 40;                                                  // Lote de trades por paquete HTTP

//+------------------------------------------------------------------+
//| Enviar Lote de Trades a AIS vía WebRequest                      |
//+------------------------------------------------------------------+
bool SendBatch(const string &accountJson, const string &tradesJsonArray, int tradesCount)
{
   string fullJson = "{\"account\":" + accountJson + ",\"trades\":[" + tradesJsonArray + "]}";

   string headers = "Content-Type: application/json\r\nx-api-key: " + InpApiKey + "\r\n";
   char post_data[];
   char result[];
   string result_headers;

   int len = StringToCharArray(fullJson, post_data, 0, WHOLE_ARRAY, CP_UTF8);
   if(len > 0 && post_data[len - 1] == 0) ArrayResize(post_data, len - 1);

   ResetLastError();
   int res = WebRequest("POST", InpApiUrl, headers, 15000, post_data, result, result_headers);

   if(res == 200 || res == 201)
   {
      PrintFormat("✅ [SYNC AIS] Lote de %d trades sincronizado exitosamente (Respuesta: HTTP %d)", tradesCount, res);
      return true;
   }
   else
   {
      int err = GetLastError();
      string respStr = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      PrintFormat("❌ [SYNC AIS] Error al enviar lote: HTTP %d | MQL5 Err: %d | Respuesta: %s", res, err, respStr);
      if(res == -1)
      {
         Print("⚠️ Asegúrate de agregar la URL 'https://auruminvest.mx' en MT5: Herramientas > Opciones > Asesores Expertos > Permitir WebRequest");
      }
      return false;
   }
}

//+------------------------------------------------------------------+
//| Script program start function                                    |
//+------------------------------------------------------------------+
void OnStart()
{
   if(InpApiKey == "")
   {
      Alert("❌ Por favor especifica tu InpApiKey de Aurum Invest Station.");
      return;
   }

   // 1. Datos de la cuenta activa
   long   accLogin = AccountInfoInteger(ACCOUNT_LOGIN);
   string broker   = AccountInfoString(ACCOUNT_COMPANY);
   string server   = AccountInfoString(ACCOUNT_SERVER);
   string currency = AccountInfoString(ACCOUNT_CURRENCY);
   double balance  = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity   = AccountInfoDouble(ACCOUNT_EQUITY);
   
   string accType = (AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL) ? "REAL" :
                    ((AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO) ? "DEMO" : "CONTEST");
   
   string accName = (InpCustomAccountName != "") ? InpCustomAccountName : (broker + " #" + IntegerToString(accLogin));

   PrintFormat("🚀 [SYNC AIS] Iniciando sincronización para cuenta: %s (Login: %I64d, Tipo: %s, Balance: %.2f)",
               accName, accLogin, accType, balance);

   // JSON de la cuenta
   string accountJson = StringFormat(
      "{\"accountNumber\":\"%I64d\",\"name\":\"%s\",\"type\":\"%s\",\"broker\":\"%s\","
      "\"server\":\"%s\",\"currency\":\"%s\",\"balance\":%.2f,\"equity\":%.2f}",
      accLogin, accName, accType, broker, server, currency, balance, equity
   );

   // 2. Seleccionar Rango Histórico
   datetime fromDate = 0;
   if(InpDaysBack > 0)
   {
      fromDate = TimeCurrent() - (datetime)(InpDaysBack * 86400);
   }

   if(!HistorySelect(fromDate, TimeCurrent()))
   {
      Alert("❌ Error al seleccionar el historial de la cuenta MT5.");
      return;
   }

   int totalDeals = HistoryDealsTotal();
   PrintFormat("📋 Total deals en historial seleccionado: %d", totalDeals);

   string tradesBuffer = "";
   int currentBatchCount = 0;
   int totalSyncedTrades = 0;
   int failedBatches = 0;

   // 3. Recorrer deals de salida (posiciones cerradas)
   for(int i = 0; i < totalDeals; i++)
   {
      ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0) continue;

      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);
      // Solo nos interesan los deals de salida
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      ulong  positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
      string symbol     = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
      if(symbol == "") continue;

      long   closeDealType = HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      double volume        = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
      double exitPrice     = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
      double profit        = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
      double commission    = HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      double swap          = HistoryDealGetDouble(dealTicket, DEAL_SWAP);
      long   closeTime     = HistoryDealGetInteger(dealTicket, DEAL_TIME);
      long   magic         = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
      string comment       = HistoryDealGetString(dealTicket, DEAL_COMMENT);

      // Buscar deal de entrada para obtener precio y hora de apertura
      double entryPrice = exitPrice;
      long   openTime   = closeTime;
      string tradeType  = (closeDealType == DEAL_TYPE_SELL) ? "BUY" : "SELL";
      double sl         = 0.0;
      double tp         = 0.0;

      // Buscar el deal IN para esta posición
      for(int j = 0; j < totalDeals; j++)
      {
         ulong inTicket = HistoryDealGetTicket(j);
         if(HistoryDealGetInteger(inTicket, DEAL_POSITION_ID) == positionId &&
            HistoryDealGetInteger(inTicket, DEAL_ENTRY) == DEAL_ENTRY_IN)
         {
            entryPrice = HistoryDealGetDouble(inTicket, DEAL_PRICE);
            openTime   = HistoryDealGetInteger(inTicket, DEAL_TIME);
            long inType = HistoryDealGetInteger(inTicket, DEAL_TYPE);
            tradeType  = (inType == DEAL_TYPE_BUY) ? "BUY" : "SELL";
            break;
         }
      }

      // Si existe la orden en el historial, intentar leer SL y TP originales
      if(HistoryOrderSelect(positionId))
      {
         sl = HistoryOrderGetDouble(positionId, ORDER_SL);
         tp = HistoryOrderGetDouble(positionId, ORDER_TP);
      }

      // Calcular R-Múltiplo si había SL
      string rMultipleStr = "null";
      if(sl > 0.0 && entryPrice > 0.0)
      {
         double riskDist = MathAbs(entryPrice - sl);
         if(riskDist > 0.0)
         {
            double rewardDist = (tradeType == "BUY") ? (exitPrice - entryPrice) : (entryPrice - exitPrice);
            double rMult = rewardDist / riskDist;
            rMultipleStr = DoubleToString(rMult, 2);
         }
      }

      // Crear objeto JSON para el trade
      string tradeJson = StringFormat(
         "{\"ticket\":%I64u,\"magicNumber\":%d,\"symbol\":\"%s\",\"type\":\"%s\","
         "\"entryPrice\":%.5f,\"exitPrice\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"lotSize\":%.2f,"
         "\"profit\":%.2f,\"commission\":%.2f,\"swap\":%.2f,\"rMultiple\":%s,\"status\":\"CLOSED\","
         "\"setup\":\"HISTORICO_MT5\",\"isCompliant\":true,\"openTime\":%I64d,\"closeTime\":%I64d}",
         positionId, magic, symbol, tradeType,
         entryPrice, exitPrice, sl, tp, volume,
         profit, commission, swap, rMultipleStr, openTime, closeTime
      );

      if(currentBatchCount > 0) tradesBuffer += ",";
      tradesBuffer += tradeJson;
      currentBatchCount++;

      // Si alcanzamos el tamaño del lote, enviar
      if(currentBatchCount >= InpBatchSize)
      {
         Comment(StringFormat("Sincronizando lote... (%d trades procesados)", totalSyncedTrades + currentBatchCount));
         if(SendBatch(accountJson, tradesBuffer, currentBatchCount))
         {
            totalSyncedTrades += currentBatchCount;
         }
         else
         {
            failedBatches++;
         }
         tradesBuffer = "";
         currentBatchCount = 0;
         Sleep(150); // Breve pausa para no saturar la red
      }
   }

   // Enviar remanente
   if(currentBatchCount > 0)
   {
      Comment(StringFormat("Sincronizando último lote... (%d trades)", currentBatchCount));
      if(SendBatch(accountJson, tradesBuffer, currentBatchCount))
      {
         totalSyncedTrades += currentBatchCount;
      }
      else
      {
         failedBatches++;
      }
   }

   Comment(""); // Limpiar comentario del gráfico

   string msg = StringFormat(
      "✅ Sincronización Finalizada.\n"
      "Cuenta: %s (#%I64d)\n"
      "Trades subidos a AIS: %d\n"
      "Lotes fallidos: %d",
      accName, accLogin, totalSyncedTrades, failedBatches
   );

   Print(msg);
   Alert(msg);
}
//+------------------------------------------------------------------+
