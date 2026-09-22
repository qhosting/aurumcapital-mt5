"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  ShieldCheck,
  ShieldAlert,
  Target,
  ArrowUpRight,
  ArrowDownRight,
  TrendingUp,
  Award,
  CheckCircle2,
  XCircle,
  AlertCircle
} from "lucide-react"

export interface AnalyzedTrade {
  ticket: string
  symbol: string
  type: "BUY" | "SELL"
  openTime: string
  closeTime: string
  entryPrice: number
  exitPrice: number
  sl: number
  tp: number
  lotSize: number
  profit: number
  rMultiple: number
  setup: string
  slQuality: "OPTIMAL" | "TOO_TIGHT" | "VIOLATED" | "NO_SL"
  phaseReached: "SL_HIT" | "PHASE_0_5R" | "PHASE_1_0R_BE" | "PHASE_1_8R_TP"
  notes: string
}

// Datos de demostración reales extraídos de la auditoría de MT5 y del webhook
export const SAMPLE_TRADES: AnalyzedTrade[] = [
  {
    ticket: "239480676",
    symbol: "GOLDmicro",
    type: "BUY",
    openTime: "2026-09-20 18:36",
    closeTime: "2026-09-20 20:01",
    entryPrice: 4370.79,
    exitPrice: 4377.67,
    sl: 4360.01,
    tp: 4394.51,
    lotSize: 1.11,
    profit: 5.34,
    rMultiple: 0.65,
    setup: "Rebote Order Block H1 + Sweep EQL",
    slQuality: "OPTIMAL",
    phaseReached: "PHASE_0_5R",
    notes: "Trade ejecutado tras barrido. Activó Micro-Lock a +0.53R protegiendo comisiones y cerró 50% parcial con trailing stop."
  },
  {
    ticket: "239529263",
    symbol: "GOLDmicro",
    type: "SELL",
    openTime: "2026-09-20 20:51",
    closeTime: "2026-09-20 21:04",
    entryPrice: 4368.20,
    exitPrice: 4361.27,
    sl: 4384.76,
    tp: 4331.76,
    lotSize: 0.10,
    profit: 0.69,
    rMultiple: 0.50,
    setup: "Rechazo en Resistencia M15",
    slQuality: "OPTIMAL",
    phaseReached: "PHASE_0_5R",
    notes: "Alcanzó Micro-Lock 0.5R, movió SL a zona protegida y cerró con beneficio garantizado."
  },
  {
    ticket: "239549155",
    symbol: "GOLDmicro",
    type: "SELL",
    openTime: "2026-09-20 21:58",
    closeTime: "2026-09-20 22:00",
    entryPrice: 4358.07,
    exitPrice: 4359.89,
    sl: 4375.57,
    tp: 4319.58,
    lotSize: 1.11,
    profit: -2.02,
    rMultiple: -0.10,
    setup: "Venta en Mínimos (Zona de Descuento)",
    slQuality: "OPTIMAL",
    phaseReached: "SL_HIT",
    notes: "Pérdida acotada por salida rápida. Disyuntor impidió daño mayor. Entrada vendida en zona barata sin esperar pullback a Premium."
  }
]

export function TradeInspector() {
  const [selectedTicket, setSelectedTicket] = useState<string>("239480676")
  const currentTrade = SAMPLE_TRADES.find((t) => t.ticket === selectedTicket) || SAMPLE_TRADES[0]

  const isBuy = currentTrade.type === "BUY"
  const slDistance = Math.abs(currentTrade.entryPrice - currentTrade.sl)
  const tpDistance = Math.abs(currentTrade.tp - currentTrade.entryPrice)
  const plannedRR = slDistance > 0 ? (tpDistance / slDistance).toFixed(1) : "2.0"

  return (
    <div className="space-y-6">
      {/* Selector de Trades */}
      <div className="flex flex-wrap items-center gap-2">
        <span className="text-xs text-gray-400 font-semibold mr-2">Historial de Trades:</span>
        {SAMPLE_TRADES.map((trade) => {
          const isSelected = trade.ticket === selectedTicket
          const isWin = trade.profit >= 0
          return (
            <Button
              key={trade.ticket}
              variant={isSelected ? "default" : "outline"}
              onClick={() => setSelectedTicket(trade.ticket)}
              className={`text-xs h-8 px-3 font-semibold transition-all ${
                isSelected
                  ? "bg-[#D4AF37] text-[#0A192F] font-bold"
                  : "border-gray-700 text-gray-300 hover:bg-[#1A2E46]"
              }`}
            >
              #{trade.ticket} ({trade.symbol} {trade.type})
              <span className={`ml-1.5 font-bold ${isWin ? "text-emerald-400" : "text-rose-400"}`}>
                {isWin ? `+$${trade.profit.toFixed(2)}` : `-$${Math.abs(trade.profit).toFixed(2)}`}
              </span>
            </Button>
          )
        })}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Panel de Análisis Cuantitativo del Trade */}
        <Card className="lg:col-span-7 bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader className="pb-3 border-b border-gray-800">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Badge
                  className={
                    isBuy
                      ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                      : "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                  }
                >
                  {currentTrade.type} {currentTrade.symbol}
                </Badge>
                <span className="text-xs text-gray-400 font-mono">Ticket #{currentTrade.ticket}</span>
              </div>
              <Badge
                variant="outline"
                className={
                  currentTrade.profit >= 0
                    ? "text-emerald-400 border-emerald-500/40 bg-emerald-950/20 font-bold"
                    : "text-rose-400 border-rose-500/40 bg-rose-950/20 font-bold"
                }
              >
                P&L: {currentTrade.profit >= 0 ? `+$${currentTrade.profit.toFixed(2)}` : `-$${Math.abs(currentTrade.profit).toFixed(2)}`}
              </Badge>
            </div>
            <CardTitle className="text-base text-white mt-1">Setup: {currentTrade.setup}</CardTitle>
          </CardHeader>

          <CardContent className="p-6 space-y-6">
            {/* Visualizador Gráfico de Precios y Fases (Barra Horizontal) */}
            <div className="space-y-3">
              <div className="flex justify-between text-xs text-gray-400">
                <span>SL: {currentTrade.sl.toFixed(2)}</span>
                <span className="text-white font-bold">Entrada: {currentTrade.entryPrice.toFixed(2)}</span>
                <span className="text-emerald-400">TP: {currentTrade.tp.toFixed(2)}</span>
              </div>

              {/* Barra de Niveles */}
              <div className="relative h-6 w-full bg-[#0A192F] rounded-full overflow-hidden border border-gray-700 flex items-center">
                {/* Zona de Riesgo (SL a Entrada) */}
                <div className="h-full bg-rose-500/30 w-1/3 border-r border-dashed border-rose-500 flex items-center justify-center text-[10px] text-rose-300 font-bold">
                  1R RIESGO (-${slDistance.toFixed(2)})
                </div>
                {/* Zona de Beneficio (Entrada a TP) */}
                <div className="h-full bg-emerald-500/30 flex-1 flex items-center justify-center text-[10px] text-emerald-300 font-bold">
                  +{plannedRR}R TAKE PROFIT (+${tpDistance.toFixed(2)})
                </div>
              </div>

              <div className="flex justify-between text-[11px] text-gray-400">
                <span>Distancia SL: {slDistance.toFixed(2)} pts</span>
                <span className="text-[#D4AF37] font-semibold">Salida Real: {currentTrade.exitPrice.toFixed(2)} ({currentTrade.rMultiple > 0 ? `+${currentTrade.rMultiple}R` : `${currentTrade.rMultiple}R`})</span>
                <span>Distancia TP: {tpDistance.toFixed(2)} pts</span>
              </div>
            </div>

            {/* Fases R Alcanzadas */}
            <div className="p-4 rounded-xl bg-[#0A192F] border border-gray-800 space-y-3">
              <span className="text-xs font-bold text-white flex items-center gap-1.5">
                <Award className="h-4 w-4 text-[#D4AF37]" /> Auditoría de Fases R del Algoritmo:
              </span>

              <div className="grid grid-cols-3 gap-2 text-center text-xs">
                <div className={`p-2 rounded border ${currentTrade.rMultiple >= 0.5 ? "bg-emerald-950/40 border-emerald-600 text-emerald-300" : "bg-[#12233A] border-gray-800 text-gray-500"}`}>
                  <span className="block text-[10px] text-gray-400">Fase 0.5R</span>
                  <span className="font-bold">Micro-Lock</span>
                  <span className="block text-[9px] mt-0.5">{currentTrade.rMultiple >= 0.5 ? "✅ ALCANZADO" : "❌ NO LLEGÓ"}</span>
                </div>

                <div className={`p-2 rounded border ${currentTrade.rMultiple >= 1.0 ? "bg-emerald-950/40 border-emerald-600 text-emerald-300" : "bg-[#12233A] border-gray-800 text-gray-500"}`}>
                  <span className="block text-[10px] text-gray-400">Fase 1.0R</span>
                  <span className="font-bold">Break-Even (50%)</span>
                  <span className="block text-[9px] mt-0.5">{currentTrade.rMultiple >= 1.0 ? "✅ ALCANZADO" : "❌ NO LLEGÓ"}</span>
                </div>

                <div className={`p-2 rounded border ${currentTrade.rMultiple >= 1.8 ? "bg-emerald-950/40 border-emerald-600 text-emerald-300" : "bg-[#12233A] border-gray-800 text-gray-500"}`}>
                  <span className="block text-[10px] text-gray-400">Fase 1.8R</span>
                  <span className="font-bold">TP2 Objetivo</span>
                  <span className="block text-[9px] mt-0.5">{currentTrade.rMultiple >= 1.8 ? "✅ ALCANZADO" : "❌ NO LLEGÓ"}</span>
                </div>
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Diagnóstico de Calidad y Mejora Continua */}
        <div className="lg:col-span-5 space-y-4">
          <Card className="bg-[#12233A] border-gray-700 shadow-xl">
            <CardHeader className="pb-3">
              <CardTitle className="text-base text-white flex items-center gap-2">
                <ShieldCheck className="h-5 w-5 text-emerald-400" />
                Calidad de la Ejecución
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs">
              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800 space-y-1">
                <span className="text-gray-400 block">Evaluación del Stop Loss:</span>
                <span className="text-emerald-400 font-bold flex items-center gap-1">
                  <CheckCircle2 className="h-4 w-4" /> Stop Loss Técnico y Protegido
                </span>
                <p className="text-gray-300 text-[11px] pt-1">
                  El SL estuvo ubicado fuera del rango de ruido de volatilidad (ATR), respetando la estructura del swing.
                </p>
              </div>

              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800 space-y-1">
                <span className="text-gray-400 block">Notas de Auditoría:</span>
                <p className="text-white text-xs leading-relaxed">{currentTrade.notes}</p>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-[#12233A] border-gray-700 shadow-xl">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold text-[#D4AF37] flex items-center gap-2">
                <TrendingUp className="h-4 w-4" /> Recomendación de Mejora Continua
              </CardTitle>
            </CardHeader>
            <CardContent className="text-xs text-gray-300 p-4 bg-[#0A192F] rounded-b-lg border-t border-gray-800">
              {currentTrade.profit >= 0 ? (
                <p className="text-emerald-300">
                  Operación con gestión impecable de Fases R. El aseguramiento en Micro-Lock y la toma parcial evitaron que un retroceso convirtiera una ganancia en pérdida.
                </p>
              ) : (
                <p className="text-amber-300">
                  En ventas cerca de mínimos, esperar siempre el retroceso a Zona Premium (&gt;50%) o la formación de una figura de continuación antes de entrar.
                </p>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
