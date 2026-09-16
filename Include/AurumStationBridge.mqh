//+------------------------------------------------------------------+
//|                                           AurumStationBridge.mqh |
//|                                  Copyright 2026, Aurum Capital   |
//|                         Telemetría en Vivo a Aurum Invest Station |
//+------------------------------------------------------------------+
#ifndef AURUM_STATION_BRIDGE_MQH
#define AURUM_STATION_BRIDGE_MQH

// Inputs configurables de integración
input group "Aurum Invest Station - Telemetría"
input bool   InpStationSyncEnabled = false;                                // Habilitar sincronización con Station
input string InpStationWebhookUrl  = "https://auruminvest.mx/api/webhooks/mt5"; // URL del Webhook
input string InpStationApiKey      = "";                                   // API Key de Aurum Station

class CAurumStationBridge
{
private:
   bool   m_enabled;
   string m_url;
   string m_api_key;

public:
   CAurumStationBridge() : m_enabled(false), m_url(""), m_api_key("") {}

   void Init(bool enabled, string url, string api_key)
   {
      m_enabled = enabled;
      m_url     = url;
      m_api_key = api_key;
   }

   // Enviar evento de Apertura de Posición
   bool SendOrderOpen(ulong ticket,
                      int magic,
                      string symbol,
                      string type,
                      double price,
                      double sl,
                      double tp,
                      double lot,
                      double risk_pct,
                      string setup)
   {
      if(!m_enabled || m_url == "" || m_api_key == "") return false;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

      string json = StringFormat(
         "{\"ticket\":%I64u,\"magicNumber\":%d,\"action\":\"OPEN\",\"symbol\":\"%s\",\"type\":\"%s\","
         "\"price\":%.5f,\"sl\":%.5f,\"tp\":%.5f,\"lotSize\":%.2f,\"riskPercent\":%.2f,"
         "\"setup\":\"%s\",\"accountBalance\":%.2f,\"accountEquity\":%.2f}",
         ticket, magic, symbol, type, price, sl, tp, lot, risk_pct, setup, balance, equity
      );

      return PostWebhook(json);
   }

   // Enviar evento de Cierre de Posición
   bool SendOrderClose(ulong ticket,
                       int magic,
                       string symbol,
                       string type,
                       double close_price,
                       double profit,
                       double commission,
                       double swap,
                       double lot,
                       string setup,
                       string comment = "")
   {
      if(!m_enabled || m_url == "" || m_api_key == "") return false;

      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double equity  = AccountInfoDouble(ACCOUNT_EQUITY);

      string json = StringFormat(
         "{\"ticket\":%I64u,\"magicNumber\":%d,\"action\":\"CLOSE\",\"symbol\":\"%s\",\"type\":\"%s\","
         "\"price\":%.5f,\"profit\":%.2f,\"commission\":%.2f,\"swap\":%.2f,\"lotSize\":%.2f,"
         "\"setup\":\"%s\",\"accountBalance\":%.2f,\"accountEquity\":%.2f,\"comment\":\"%s\"}",
         ticket, magic, symbol, type, close_price, profit, commission, swap, lot, setup, balance, equity, comment
      );

      return PostWebhook(json);
   }

   // Enviar Snapshot diario / Fin de sesión
   bool SendDailySnapshot(double balance, double equity, double daily_pnl, int total_trades)
   {
      if(!m_enabled || m_url == "" || m_api_key == "") return false;

      string json = StringFormat(
         "{\"action\":\"SNAPSHOT\",\"balance\":%.2f,\"equity\":%.2f,\"dailyPnL\":%.2f,\"totalTrades\":%d}",
         balance, equity, daily_pnl, total_trades
      );

      return PostWebhook(json);
   }

private:
   bool PostWebhook(string json)
   {
      string headers = "Content-Type: application/json\r\nx-api-key: " + m_api_key + "\r\n";
      char post_data[];
      char result[];
      string result_headers;

      int len = StringToCharArray(json, post_data, 0, WHOLE_ARRAY, CP_UTF8);
      if(len > 0 && post_data[len - 1] == 0) ArrayResize(post_data, len - 1);

      ResetLastError();
      int res = WebRequest("POST", m_url, headers, 3000, post_data, result, result_headers);

      if(res == 200 || res == 201)
      {
         PrintFormat("📡 [STATION BRIDGE] Telemetría enviada con éxito (%d bytes)", ArraySize(post_data));
         return true;
      }
      else
      {
         int err = GetLastError();
         PrintFormat("⚠️ [STATION BRIDGE] Error HTTP %d (MQL5 Err: %d). Verifica URL permitida en MT5.", res, err);
         return false;
      }
   }
};

#endif // AURUM_STATION_BRIDGE_MQH
