"use client"

import React, { useState, useEffect } from "react"
import Link from "next/link"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  TrendingUp,
  Shield,
  Activity,
  DollarSign,
  PieChart,
  Clock,
  Zap,
  ArrowUpRight,
  ArrowDownRight,
  CheckCircle2,
  AlertTriangle,
  LineChart,
  ClipboardList,
  GraduationCap,
  Sparkles,
  Lock,
  Layers,
  BarChart3,
  RefreshCw
} from "lucide-react"

export function DashboardView() {
  const [cdmxTime, setCdmxTime] = useState<string>("")
  const [activeSession, setActiveSession] = useState<string>("NY Overlap")
  const [isAlgoTradingOn, setIsAlgoTradingOn] = useState(true)

  // Actualizar hora CDMX
  useEffect(() => {
    const updateTime = () => {
      const now = new Date()
      const options: Intl.DateTimeFormatOptions = {
        timeZone: "America/Mexico_City",
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        hour12: true
      }
      setCdmxTime(new Intl.DateTimeFormat("es-MX", options).format(now))
    }
    updateTime()
    const timer = setInterval(updateTime, 1000)
    return () => clearInterval(timer)
  }, [])

  return (
    <div className="space-y-6 text-gray-100 font-sans">
      {/* ============================================================ */}
      {/* HERO BANNER: ESTADO DE CUENTA Y KILLZONES EN VIVO */}
      {/* ============================================================ */}
      <div className="p-6 rounded-2xl bg-gradient-to-r from-[#12233A] via-[#0D1D32] to-[#12233A] border border-[#D4AF37]/40 shadow-2xl space-y-4">
        <div className="flex flex-col md:flex-row md:items-center justify-between gap-4 border-b border-gray-700/60 pb-4">
          <div className="space-y-1">
            <div className="flex items-center gap-2">
              <Badge className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 text-[10px] font-bold tracking-wider">
                ● MT5 LIVE CONNECTED (14ms)
              </Badge>
              <Badge className="bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/30 text-[10px] font-mono">
                AURUM V15.35 ENGINE
              </Badge>
            </div>
            <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight">
              Panel Principal Institucional
            </h1>
            <p className="text-xs text-gray-300">
              Servidor: <span className="text-white font-mono font-bold">XM-Global-Real-22</span> • Magic Number: <span className="text-[#D4AF37] font-mono font-bold">150095</span>
            </p>
          </div>

          {/* Reloj y Estado de Killzone CDMX */}
          <div className="flex items-center gap-4 bg-[#0A192F] p-3.5 rounded-xl border border-gray-800 shrink-0">
            <div className="flex items-center gap-2">
              <Clock className="h-5 w-5 text-[#D4AF37] animate-pulse" />
              <div>
                <span className="text-[10px] text-gray-400 block font-semibold uppercase">Hora CDMX</span>
                <span className="text-sm font-mono font-bold text-white">{cdmxTime || "10:57:08 AM"}</span>
              </div>
            </div>
            <div className="h-8 w-[1px] bg-gray-800" />
            <div>
              <span className="text-[10px] text-gray-400 block font-semibold uppercase">Sesión Activa</span>
              <span className="text-xs font-bold text-emerald-400 flex items-center gap-1">
                <span> Golden NY Overlap</span>
              </span>
            </div>
          </div>
        </div>

        {/* METRICAS FINANCIERAS PRINCIPALES */}
        <div className="grid grid-cols-2 md:grid-cols-4 gap-3">
          <div className="p-3.5 rounded-xl bg-[#0A192F] border border-gray-800 space-y-1">
            <span className="text-[11px] text-gray-400 font-semibold block uppercase">BALANCE CUENTA</span>
            <div className="text-lg md:text-xl font-extrabold font-mono text-white">$10,000.00 <span className="text-xs text-gray-400">USD</span></div>
            <span className="text-[10px] text-emerald-400 font-medium">Capital base protegido</span>
          </div>

          <div className="p-3.5 rounded-xl bg-[#0A192F] border border-gray-800 space-y-1">
            <span className="text-[11px] text-gray-400 font-semibold block uppercase">EQUIDAD EN VIVO</span>
            <div className="text-lg md:text-xl font-extrabold font-mono text-emerald-400">$10,342.50 <span className="text-xs text-emerald-300">USD</span></div>
            <span className="text-[10px] text-emerald-400 font-bold flex items-center gap-0.5">
              <ArrowUpRight className="h-3 w-3" /> +3.42% Mes
            </span>
          </div>

          <div className="p-3.5 rounded-xl bg-[#0A192F] border border-gray-800 space-y-1">
            <span className="text-[11px] text-gray-400 font-semibold block uppercase">P&L FLOTANTE</span>
            <div className="text-lg md:text-xl font-extrabold font-mono text-[#D4AF37]">+$342.50 <span className="text-xs text-amber-300">USD</span></div>
            <span className="text-[10px] text-emerald-400 font-medium">1 Trade en Break-Even</span>
          </div>

          <div className="p-3.5 rounded-xl bg-[#0A192F] border border-gray-800 space-y-1">
            <span className="text-[11px] text-gray-400 font-semibold block uppercase">MARGEN LIBRE</span>
            <div className="text-lg md:text-xl font-extrabold font-mono text-white">$9,820.00 <span className="text-xs text-gray-400">USD</span></div>
            <span className="text-[10px] text-gray-400 font-medium">Nivel de Margen: 1,450%</span>
          </div>
        </div>
      </div>

      {/* ============================================================ */}
      {/* TARJETAS DE INDICADORES DE RIESGO Y ALGORITMO */}
      {/* ============================================================ */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        
        {/* Calibrador de Drawdown Diario */}
        <Card className="bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle className="text-sm font-bold text-white flex items-center gap-2">
                <Shield className="h-4 w-4 text-[#D4AF37]" />
                Límite de Pérdida Diaria (Drawdown)
              </CardTitle>
              <Badge className="bg-emerald-500/20 text-emerald-400 text-[10px]">Seguro (0.25%)</Badge>
            </div>
            <CardDescription className="text-[11px] text-gray-400">
              Presupuesto máximo diario de riesgo Aurum V15: 1.0% de equidad.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="space-y-1">
              <div className="flex justify-between text-xs font-mono font-bold">
                <span className="text-gray-300">Riesgo consumido hoy:</span>
                <span className="text-emerald-400">0.25% / 1.00%</span>
              </div>
              {/* Progreso del bar */}
              <div className="w-full bg-[#0A192F] rounded-full h-2.5 overflow-hidden border border-gray-800">
                <div className="bg-gradient-to-r from-emerald-500 to-[#D4AF37] h-2.5 rounded-full w-[25%]" />
              </div>
            </div>

            <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 text-[11px] text-gray-300 flex items-center justify-between">
              <span>Trades Hoy: <strong className="text-white">1 / 3 Máx</strong></span>
              <span>Límite Anti-Racha: <strong className="text-emerald-400">0 / 2 Losses</strong></span>
            </div>
          </CardContent>
        </Card>

        {/* Estado Bot Algo Trading MT5 */}
        <Card className="bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle className="text-sm font-bold text-white flex items-center gap-2">
                <Zap className="h-4 w-4 text-[#D4AF37]" />
                Bot MT5 AurumSniper
              </CardTitle>
              <Badge
                className={
                  isAlgoTradingOn
                    ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                    : "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                }
              >
                {isAlgoTradingOn ? "ON (Encendido)" : "OFF (Apagado)"}
              </Badge>
            </div>
            <CardDescription className="text-[11px] text-gray-400">
              Gestor automatizado de Break-Even (+1.0R) y Parciales (Fase 1 y 2).
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-3">
            <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 text-xs space-y-1">
              <div className="flex justify-between">
                <span className="text-gray-400">Break-Even Auto:</span>
                <span className="text-emerald-400 font-bold">Activo (+1.1R)</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Cierre Parcial Fase 1:</span>
                <span className="text-white font-bold">50% a +1.3R</span>
              </div>
              <div className="flex justify-between">
                <span className="text-gray-400">Fase 2 Target:</span>
                <span className="text-[#D4AF37] font-bold">TP2 2.2R</span>
              </div>
            </div>

            <Button
              size="sm"
              onClick={() => setIsAlgoTradingOn(!isAlgoTradingOn)}
              className={
                isAlgoTradingOn
                  ? "w-full bg-emerald-700 hover:bg-emerald-600 text-white text-xs font-bold"
                  : "w-full bg-rose-700 hover:bg-rose-600 text-white text-xs font-bold"
              }
            >
              {isAlgoTradingOn ? "Desactivar Bot Algo Trading" : "Activar Bot Algo Trading"}
            </Button>
          </CardContent>
        </Card>

        {/* Resumen Estadístico Institucional */}
        <Card className="bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader className="pb-2">
            <div className="flex items-center justify-between">
              <CardTitle className="text-sm font-bold text-white flex items-center gap-2">
                <BarChart3 className="h-4 w-4 text-[#D4AF37]" />
                Rendimiento de Estrategia
              </CardTitle>
              <Badge variant="outline" className="text-[10px] text-[#D4AF37] border-[#D4AF37]/40">SMC Edition</Badge>
            </div>
            <CardDescription className="text-[11px] text-gray-400">
              Métricas consolidadas de las operaciones auditadas.
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-2 text-xs">
            <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
              <span className="text-gray-300">Win Rate General:</span>
              <span className="font-mono text-emerald-400 font-extrabold">72.7% (M15)</span>
            </div>
            <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
              <span className="text-gray-300">Profit Factor Promedio:</span>
              <span className="font-mono text-[#D4AF37] font-extrabold">2.15</span>
            </div>
            <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
              <span className="text-gray-300">Ratio R:R Objetivo:</span>
              <span className="font-mono text-white font-extrabold">1:2.2</span>
            </div>
          </CardContent>
        </Card>

      </div>

      {/* ============================================================ */}
      {/* OPERACIÓN ACTIVA & TABLA DE TRADES RECIENTES */}
      {/* ============================================================ */}
      <Card className="bg-[#12233A] border-gray-700 shadow-xl">
        <CardHeader className="pb-3">
          <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-2">
            <div>
              <CardTitle className="text-base font-bold text-white flex items-center gap-2">
                <Activity className="h-5 w-5 text-[#D4AF37]" />
                Monitor de Posiciones & Auditoría Forense
              </CardTitle>
              <CardDescription className="text-xs text-gray-400">
                Registro en tiempo real sincronizado con el terminal MetaTrader 5.
              </CardDescription>
            </div>
            <Button size="sm" variant="outline" className="border-gray-600 text-xs text-gray-300 hover:text-white">
              <RefreshCw className="h-3.5 w-3.5 mr-1.5" />
              Sincronizar MT5
            </Button>
          </div>
        </CardHeader>

        <CardContent>
          <div className="overflow-x-auto">
            <table className="w-full text-left text-xs border-collapse">
              <thead>
                <tr className="border-b border-gray-700 bg-[#0A192F] text-gray-400 uppercase text-[10px] tracking-wider">
                  <th className="p-3">Símbolo</th>
                  <th className="p-3">Tipo</th>
                  <th className="p-3">Volumen</th>
                  <th className="p-3">Precio Entrada</th>
                  <th className="p-3">Stop Loss (SL)</th>
                  <th className="p-3">Take Profit (TP)</th>
                  <th className="p-3">P&L Actual</th>
                  <th className="p-3">Estatus Aurum</th>
                </tr>
              </thead>
              <tbody className="divide-y divide-gray-800 text-gray-200 font-mono">
                {/* Posición Activa en Vivo */}
                <tr className="bg-emerald-950/20 hover:bg-emerald-950/30 transition-colors">
                  <td className="p-3 font-bold text-white flex items-center gap-2">
                    <span className="h-2 w-2 rounded-full bg-emerald-400 animate-ping" />
                    USDJPYmicro
                  </td>
                  <td className="p-3 text-emerald-400 font-bold">COMPRA</td>
                  <td className="p-3">0.05 lotes</td>
                  <td className="p-3">148.200</td>
                  <td className="p-3 text-emerald-300 font-bold">148.210 (BE)</td>
                  <td className="p-3 text-[#D4AF37]">148.850</td>
                  <td className="p-3 text-emerald-400 font-extrabold">+$22.50 (+1.4R)</td>
                  <td className="p-3">
                    <Badge className="bg-emerald-500/20 text-emerald-300 border border-emerald-500/40 text-[10px]">
                      Fase 1 BE (+50% Parcial)
                    </Badge>
                  </td>
                </tr>

                {/* Trade Pasado 1 */}
                <tr className="hover:bg-[#0A192F]/50 transition-colors">
                  <td className="p-3 font-bold text-white">EURUSDmicro</td>
                  <td className="p-3 text-emerald-400 font-bold">COMPRA</td>
                  <td className="p-3">0.10 lotes</td>
                  <td className="p-3">1.08450</td>
                  <td className="p-3 text-gray-400">1.08300</td>
                  <td className="p-3 text-gray-400">1.08780</td>
                  <td className="p-3 text-emerald-400 font-extrabold">+$33.00 (+2.2R)</td>
                  <td className="p-3">
                    <Badge className="bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/30 text-[10px]">
                      TP2 Alcanzado
                    </Badge>
                  </td>
                </tr>

                {/* Trade Pasado 2 */}
                <tr className="hover:bg-[#0A192F]/50 transition-colors">
                  <td className="p-3 font-bold text-white">GOLDmicro</td>
                  <td className="p-3 text-rose-400 font-bold">VENTA</td>
                  <td className="p-3">0.02 lotes</td>
                  <td className="p-3">2,735.10</td>
                  <td className="p-3 text-gray-400">2,748.00</td>
                  <td className="p-3 text-gray-400">2,710.00</td>
                  <td className="p-3 text-rose-400 font-extrabold">-$2.50 (-1.0R)</td>
                  <td className="p-3">
                    <Badge variant="outline" className="text-gray-400 border-gray-700 text-[10px]">
                      SL Respetado (-0.25%)
                    </Badge>
                  </td>
                </tr>
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      {/* ============================================================ */}
      {/* ACCESOS RÁPIDOS A MÓDULOS DE LA ESTACIÓN */}
      {/* ============================================================ */}
      <div className="grid grid-cols-1 sm:grid-cols-3 gap-4">
        <Link href="/app/market" className="group">
          <div className="p-5 rounded-2xl bg-[#12233A] border border-gray-700 group-hover:border-[#D4AF37]/60 transition-all space-y-2 shadow-lg">
            <div className="flex items-center justify-between">
              <LineChart className="h-6 w-6 text-[#D4AF37]" />
              <ArrowUpRight className="h-4 w-4 text-gray-400 group-hover:text-white transition-colors" />
            </div>
            <h3 className="font-bold text-white text-base">Gráfico en Vivo & TradingView</h3>
            <p className="text-xs text-gray-400">Visualización de velas Opwens, marcas de agua y simulador TP/SL.</p>
          </div>
        </Link>

        <Link href="/app/academy" className="group">
          <div className="p-5 rounded-2xl bg-[#12233A] border border-gray-700 group-hover:border-[#D4AF37]/60 transition-all space-y-2 shadow-lg">
            <div className="flex items-center justify-between">
              <GraduationCap className="h-6 w-6 text-[#D4AF37]" />
              <ArrowUpRight className="h-4 w-4 text-gray-400 group-hover:text-white transition-colors" />
            </div>
            <h3 className="font-bold text-white text-base">Academia & Estrategia SMC</h3>
            <p className="text-xs text-gray-400">Guía de 7 módulos: Gatillos Opwens, Order Blocks y Fases R.</p>
          </div>
        </Link>

        <Link href="/app/plan" className="group">
          <div className="p-5 rounded-2xl bg-[#12233A] border border-gray-700 group-hover:border-[#D4AF37]/60 transition-all space-y-2 shadow-lg">
            <div className="flex items-center justify-between">
              <ClipboardList className="h-6 w-6 text-[#D4AF37]" />
              <ArrowUpRight className="h-4 w-4 text-gray-400 group-hover:text-white transition-colors" />
            </div>
            <h3 className="font-bold text-white text-base">Plan de Trading Oficial</h3>
            <p className="text-xs text-gray-400">Metodología de 8 secciones, firma digital y checklist diario pre-vuelo.</p>
          </div>
        </Link>
      </div>
    </div>
  )
}
