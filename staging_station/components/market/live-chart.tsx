"use client"

import { useEffect, useRef, useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Button } from "@/components/ui/button"
import { Badge } from "@/components/ui/badge"
import { TrendingUp, Maximize2, RefreshCw } from "lucide-react"

declare global {
  interface Window {
    TradingView: any
  }
}

interface LiveChartProps {
  initialSymbol?: string
  defaultSymbol?: string
}

const SUPPORTED_SYMBOLS = [
  { id: "OANDA:XAUUSD", label: "ORO (XAU/USD)", category: "METALS" },
  { id: "FX:EURUSD", label: "EUR/USD", category: "FOREX" },
  { id: "FX:USDJPY", label: "USD/JPY", category: "FOREX" },
  { id: "FX:GBPUSD", label: "GBP/USD", category: "FOREX" },
  { id: "BINANCE:BTCUSDT", label: "BITCOIN (BTC/USDT)", category: "CRYPTO" }
]

export function LiveChart({ initialSymbol, defaultSymbol = "OANDA:XAUUSD" }: LiveChartProps) {
  const containerRef = useRef<HTMLDivElement>(null)
  const [currentSymbol, setCurrentSymbol] = useState<string>(initialSymbol || defaultSymbol)
  const [interval, setInterval] = useState<string>("15")
  const [isScriptLoaded, setIsScriptLoaded] = useState<boolean>(false)

  // Cargar el script oficial de TradingView Widget de forma segura
  useEffect(() => {
    const existingScript = document.getElementById("tradingview-widget-script")
    if (!existingScript) {
      const script = document.createElement("script")
      script.id = "tradingview-widget-script"
      script.src = "https://s3.tradingview.com/tv.js"
      script.async = true
      script.onload = () => setIsScriptLoaded(true)
      document.head.appendChild(script)
    } else {
      setIsScriptLoaded(true)
    }
  }, [])

  // Inicializar o actualizar el widget cuando cambia el símbolo o el intervalo
  useEffect(() => {
    if (!isScriptLoaded || !containerRef.current || !window.TradingView) return

    containerRef.current.innerHTML = ""
    const chartId = `tv_chart_${Math.random().toString(36).substring(7)}`
    const chartDiv = document.createElement("div")
    chartDiv.id = chartId
    chartDiv.className = "w-full h-full"
    containerRef.current.appendChild(chartDiv)

    new window.TradingView.widget({
      autosize: true,
      symbol: currentSymbol,
      interval: interval,
      timezone: "Etc/UTC",
      theme: "dark",
      style: "1", // Velas japonesas
      locale: "es",
      enable_publishing: false,
      hide_side_toolbar: false,
      allow_symbol_change: true,
      container_id: chartId,
      backgroundColor: "#0A192F",
      gridColor: "rgba(255, 255, 255, 0.05)",
      toolbar_bg: "#12233A",
      studies: [
        "MASimple@tv-basicstudies", // Media móvil de referencia
        "RSI@tv-basicstudies"
      ]
    })
  }, [isScriptLoaded, currentSymbol, interval])

  return (
    <Card className="bg-[#12233A] border-gray-700 shadow-2xl overflow-hidden flex flex-col h-full min-h-[580px]">
      <CardHeader className="p-4 border-b border-gray-800 flex flex-row items-center justify-between shrink-0">
        <div className="flex items-center gap-3">
          <div className="p-2 rounded-lg bg-[#0A192F] border border-gray-800">
            <TrendingUp className="h-5 w-5 text-[#D4AF37]" />
          </div>
          <div>
            <div className="flex items-center gap-2">
              <CardTitle className="text-base text-white font-bold">Terminal de Mercado en Vivo</CardTitle>
              <Badge className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px]">
                DATOS EN TIEMPO REAL
              </Badge>
            </div>
            <CardDescription className="text-xs text-gray-400">
              Velas institucionales, soporte multi-temporal y herramientas de análisis técnico
            </CardDescription>
          </div>
        </div>

        {/* Selector de Activos */}
        <div className="flex flex-wrap items-center gap-2">
          {SUPPORTED_SYMBOLS.map((sym) => {
            const isSelected = sym.id === currentSymbol
            return (
              <Button
                key={sym.id}
                size="sm"
                variant={isSelected ? "default" : "outline"}
                onClick={() => setCurrentSymbol(sym.id)}
                className={`text-xs h-8 px-3 font-semibold transition-all ${
                  isSelected
                    ? "bg-[#D4AF37] text-[#0A192F] hover:bg-[#c49f27]"
                    : "border-gray-700 text-gray-300 hover:text-white hover:bg-[#1A2E46]"
                }`}
              >
                {sym.label}
              </Button>
            )
          })}
        </div>
      </CardHeader>

      {/* Contenedor del Gráfico Embebido */}
      <CardContent className="p-0 flex-1 relative bg-[#0A192F] w-full min-h-[500px]">
        <div ref={containerRef} className="w-full h-full min-h-[500px]" />
      </CardContent>
    </Card>
  )
}
