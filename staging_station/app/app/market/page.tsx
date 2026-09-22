import { Metadata } from "next"
import { LiveChart } from "@/components/market/live-chart"
import { TradeInspector } from "@/components/market/trade-inspector"

export const metadata: Metadata = {
  title: "Mercado en Vivo & Auditor de Trades | Aurum Invest Station",
  description: "Gráficos en tiempo real con TradingView y análisis forense de Take Profit, Stop Loss y R-Múltiplo.",
}

export default function MarketPage() {
  return (
    <div className="container mx-auto px-4 py-8 space-y-8">
      <div className="flex flex-col md:flex-row md:items-center md:justify-between gap-4">
        <div>
          <h1 className="text-2xl font-bold text-white tracking-wide">
            MONITOR DE MERCADO EN VIVO & AUDITORÍA DE TRADES
          </h1>
          <p className="text-gray-400 text-sm">
            Visualización institucional en tiempo real sincronizada con TradingView y simulador de salidas TP/SL/BE.
          </p>
        </div>
      </div>

      <LiveChart initialSymbol="OANDA:XAUUSD" />

      <TradeInspector />
    </div>
  )
}
