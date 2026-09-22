"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Tabs, TabsContent, TabsList, TabsTrigger } from "@/components/ui/tabs"
import { CandleDiagram } from "@/components/academy/candle-diagram"
import { PatternDiagram } from "@/components/academy/pattern-diagram"
import { RiskCalculator } from "@/components/academy/risk-calculator"
import { TradeChecklist } from "@/components/academy/trade-checklist"
import { TradingPlanSheet } from "@/components/academy/trading-plan-sheet"
import {
  GraduationCap,
  BookOpen,
  CandlestickChart,
  Shapes,
  Layers,
  Calculator,
  ShieldAlert,
  Clock,
  Award,
  CheckCircle2,
  TrendingUp,
  ArrowRight,
  ClipboardList
} from "lucide-react"

export function AcademyView() {
  const [activeTab, setActiveTab] = useState<string>("mod1")

  return (
    <div className="container mx-auto px-4 py-8 space-y-8">
      {/* Hero Header */}
      <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 p-6 rounded-2xl bg-gradient-to-r from-[#12233A] via-[#0d1d32] to-[#12233A] border border-gray-700 shadow-2xl">
        <div className="space-y-2">
          <div className="flex items-center gap-2">
            <GraduationCap className="h-6 w-6 text-[#D4AF37]" />
            <Badge className="bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/30 text-xs">
              PROGRAMA DE FORMACIÓN INSTITUCIONAL
            </Badge>
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight">
            Academia Aurum: De Inicio a Avanzado
          </h1>
          <p className="text-xs md:text-sm text-gray-300 max-w-2xl leading-relaxed">
            Metodología unificada basada en el <em>Forex Trading Blueprint</em>, el <em>Libro Opwens</em> de velas japonesas,
            el <em>Módulo 2 de Chartismo Clásico</em> y el motor algorítmico <em>Aurum V15</em>.
          </p>
        </div>

        <div className="flex items-center gap-4 bg-[#0A192F] p-4 rounded-xl border border-gray-800 shrink-0">
          <div className="text-center">
            <span className="text-xs text-gray-400 block">Itinerario</span>
            <span className="text-lg font-bold text-[#D4AF37]">7 Módulos</span>
          </div>
          <div className="h-8 w-[1px] bg-gray-800" />
          <div className="text-center">
            <span className="text-xs text-gray-400 block">Nivel</span>
            <span className="text-lg font-bold text-emerald-400">Institucional</span>
          </div>
        </div>
      </div>

      {/* Navegación por Módulos */}
      <Tabs value={activeTab} onValueChange={setActiveTab} className="space-y-6">
        <TabsList className="bg-[#12233A] border border-gray-700 p-1 flex flex-wrap h-auto gap-1">
          <TabsTrigger
            value="mod1"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <BookOpen className="h-3.5 w-3.5 mr-1.5" />
            1. Forex Blueprint
          </TabsTrigger>
          <TabsTrigger
            value="mod2"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <CandlestickChart className="h-3.5 w-3.5 mr-1.5" />
            2. Gatillos Opwens
          </TabsTrigger>
          <TabsTrigger
            value="mod3"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <Shapes className="h-3.5 w-3.5 mr-1.5" />
            3. Chartismo Clásico
          </TabsTrigger>
          <TabsTrigger
            value="mod4"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <Layers className="h-3.5 w-3.5 mr-1.5" />
            4. SMC & Aurum V15
          </TabsTrigger>
          <TabsTrigger
            value="mod5"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <Calculator className="h-3.5 w-3.5 mr-1.5" />
            5. Gestión & Fases R
          </TabsTrigger>
          <TabsTrigger
            value="mod6"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <ShieldAlert className="h-3.5 w-3.5 mr-1.5" />
            6. Mejora Continua
          </TabsTrigger>
          <TabsTrigger
            value="mod7"
            className="data-[state=active]:bg-[#D4AF37] data-[state=active]:text-[#0A192F] text-xs font-semibold py-2 px-3 text-gray-300"
          >
            <ClipboardList className="h-3.5 w-3.5 mr-1.5" />
            7. Plan de Trading
          </TabsTrigger>
        </TabsList>

        {/* ============================================================ */}
        {/* MÓDULO 1: FOREX BLUEPRINT */}
        {/* ============================================================ */}
        <TabsContent value="mod1" className="space-y-6">
          <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
            <Card className="bg-[#12233A] border-gray-700 md:col-span-2">
              <CardHeader>
                <div className="flex items-center justify-between">
                  <CardTitle className="text-lg text-white">Módulo 1: Fundamentos y Mecánica del Mercado</CardTitle>
                  <Badge variant="outline" className="text-xs text-[#D4AF37] border-[#D4AF37]/40">Forex Blueprint</Badge>
                </div>
                <CardDescription className="text-xs text-gray-400">
                  Conceptos fundamentales para comprender la naturaleza electrónica, el volumen y la liquidez global.
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-4 text-sm text-gray-300">
                <div className="space-y-2">
                  <h4 className="font-bold text-white text-sm">1. El Mercado Extrabursátil (OTC)</h4>
                  <p className="text-xs leading-relaxed text-gray-300">
                    Forex es el mercado financiero más grande del planeta, con un volumen diario superior a <strong>$5 billones de dólares</strong>.
                    A diferencia de las bolsas tradicionales de acciones, Forex no tiene una sede física central; opera como una red interbancaria descentralizada las 24 horas del día.
                  </p>
                </div>

                <div className="space-y-2 pt-2 border-t border-gray-800">
                  <h4 className="font-bold text-white text-sm">2. Las Sesiones y Horarios Institucionales (Killzones)</h4>
                  <p className="text-xs text-gray-300">
                    La liquidez sigue al sol. Existen 4 grandes centros financieros:
                  </p>
                  <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 pt-1">
                    <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 text-center">
                      <span className="text-[11px] text-gray-400 block">Sídney</span>
                      <span className="text-xs font-bold text-white">Apertura Pacífico</span>
                    </div>
                    <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 text-center">
                      <span className="text-[11px] text-gray-400 block">Tokio (Asia)</span>
                      <span className="text-xs font-bold text-white">Volumen Moderado</span>
                    </div>
                    <div className="p-2.5 rounded bg-[#0A192F] border border-emerald-900/50 text-center">
                      <span className="text-[11px] text-emerald-400 block">Londres (Europa)</span>
                      <span className="text-xs font-bold text-emerald-300">Alta Liquidez</span>
                    </div>
                    <div className="p-2.5 rounded bg-[#0A192F] border border-[#D4AF37]/40 text-center">
                      <span className="text-[11px] text-[#D4AF37] block">Nueva York</span>
                      <span className="text-xs font-bold text-white">Máxima Expansión</span>
                    </div>
                  </div>
                  <p className="text-[11px] text-amber-300/90 pt-1">
                    ⚡ <strong>Golden Overlap:</strong> La confluencia entre Londres y Nueva York (12:00 - 16:00 UTC) concentra más del 65% del volumen diario y genera los impulsos más limpios.
                  </p>
                </div>

                <div className="space-y-2 pt-2 border-t border-gray-800">
                  <h4 className="font-bold text-white text-sm">3. Pips, Lotes y Apalancamiento</h4>
                  <p className="text-xs text-gray-300">
                    * <strong>Pip (Percentage in Point):</strong> 4to decimal en divisas ($0.0001) o segundo decimal en pares con JPY y Oro.
                  </p>
                  <p className="text-xs text-gray-300">
                    * <strong>Lote Estándar (1.00):</strong> 100,000 unidades de moneda base. Mini (0.10) = 10,000. Micro (0.01) = 1,000 unidades.
                  </p>
                </div>
              </CardContent>
            </Card>

            {/* Matriz de Seguridad Blueprint */}
            <Card className="bg-[#12233A] border-gray-700">
              <CardHeader className="pb-3">
                <CardTitle className="text-sm font-bold text-[#D4AF37] flex items-center gap-2">
                  <Award className="h-4 w-4" /> Matriz de Riesgo Blueprint
                </CardTitle>
                <CardDescription className="text-xs text-gray-400">
                  Guía estricta de capital vs. lotaje máximo permitido (Pág. 11)
                </CardDescription>
              </CardHeader>
              <CardContent className="space-y-2">
                <div className="space-y-1.5 text-xs">
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$100 - $300 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.01 a 0.02</span>
                  </div>
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$400 - $500 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.02 a 0.04</span>
                  </div>
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$800 - $1,000 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.04 a 0.08</span>
                  </div>
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$2,000 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.10 a 0.15</span>
                  </div>
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$5,000 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.50 a 0.55</span>
                  </div>
                  <div className="flex justify-between p-2 rounded bg-[#0A192F] border border-gray-800">
                    <span className="text-gray-300">$10,000 USD:</span>
                    <span className="font-mono text-emerald-400 font-bold">0.90 a 1.00</span>
                  </div>
                </div>
                <p className="text-[11px] text-rose-400/90 pt-2 italic">
                  &quot;El primer objetivo de un trader no es ganar dinero, sino proteger el capital disponible.&quot;
                </p>
              </CardContent>
            </Card>
          </div>
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 2: GATILLOS OPWENS */}
        {/* ============================================================ */}
        <TabsContent value="mod2" className="space-y-6">
          <div className="p-4 rounded-xl bg-[#12233A] border border-gray-700">
            <h3 className="text-base font-bold text-white mb-1">
              Catálogo Interactivo de Gatillos Candlestick (Libro Opwens A4)
            </h3>
            <p className="text-xs text-gray-300 mb-4">
              Visualiza de forma anatómica los 14 patrones cuantitativos programados en el detector institucional Aurum,
              con sus cotas milimétricas de mecha, cuerpo y zona de disparo.
            </p>
            <CandleDiagram />
          </div>
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 3: CHARTISMO CLÁSICO */}
        {/* ============================================================ */}
        <TabsContent value="mod3" className="space-y-6">
          <div className="p-4 rounded-xl bg-[#12233A] border border-gray-700">
            <h3 className="text-base font-bold text-white mb-1">
              Modelos Cartistas Clásicos & Geometría Fractal (Módulo 2)
            </h3>
            <p className="text-xs text-gray-300 mb-4">
              Estructuras geométricas de inversión y continuación de tendencia con proyección técnica del objetivo H
              y delimitación de la línea de cuello (Neckline).
            </p>
            <PatternDiagram />
          </div>
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 4: SMART MONEY CONCEPTS & AURUM V15 */}
        {/* ============================================================ */}
        <TabsContent value="mod4" className="space-y-6">
          <Card className="bg-[#12233A] border-gray-700">
            <CardHeader>
              <CardTitle className="text-lg text-white">Módulo 4: Smart Money Concepts (SMC) & Fusión Algorítmica V15</CardTitle>
              <CardDescription className="text-xs text-gray-400">
                La confluencia definitiva: Cómo los grandes bancos mueven el precio y cómo el algoritmo Aurum se posiciona a su favor.
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-6 text-sm text-gray-300">
              <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
                <div className="p-4 rounded-xl bg-[#0A192F] border border-gray-800 space-y-2">
                  <div className="flex items-center gap-2 text-emerald-400 font-bold text-sm">
                    <span>🧱</span> Order Blocks (+OB / -OB)
                  </div>
                  <p className="text-xs text-gray-300 leading-relaxed">
                    La última vela contraria antes de un movimiento impulsivo que rompe estructura (BOS).
                    Representa el bloque de órdenes donde los bancos acumularon compras o ventas institucionales.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-[#0A192F] border border-gray-800 space-y-2">
                  <div className="flex items-center gap-2 text-amber-400 font-bold text-sm">
                    <span>⚡</span> Barridos de Liquidez (SWEEP)
                  </div>
                  <p className="text-xs text-gray-300 leading-relaxed">
                    Manipulación donde el precio perfora máximos (EQH) o mínimos (EQL) anteriores para cazar los Stop Losses
                    de los operadores minoristas y absorber contrapartida antes de revertir con violencia.
                  </p>
                </div>

                <div className="p-4 rounded-xl bg-[#0A192F] border border-gray-800 space-y-2">
                  <div className="flex items-center gap-2 text-sky-400 font-bold text-sm">
                    <span>🎯</span> Descuento vs. Premium
                  </div>
                  <p className="text-xs text-gray-300 leading-relaxed">
                    División del rango operativo al 50%: Solo se compran activos baratos en Zona de Descuento (&lt;50%)
                    y solo se venden activos caros en Zona Premium (&gt;50%).
                  </p>
                </div>
              </div>

              {/* El Setup Maestro de Francotirador */}
              <div className="p-5 rounded-xl bg-gradient-to-r from-emerald-950/40 via-[#0A192F] to-emerald-950/40 border border-emerald-800/60 space-y-3">
                <div className="flex items-center justify-between">
                  <h4 className="font-extrabold text-emerald-400 text-sm flex items-center gap-2">
                    <span>👑</span> EL SETUP MAESTRO DE FRANCOTIRADOR AURUM
                  </h4>
                  <Badge className="bg-emerald-500/20 text-emerald-300 border-none">Confluencia V15.35</Badge>
                </div>
                <div className="grid grid-cols-1 sm:grid-cols-4 gap-3 text-xs">
                  <div className="p-2.5 rounded bg-[#12233A] border border-gray-800">
                    <span className="text-[#D4AF37] font-bold block mb-1">Paso 1</span>
                    Identificar Order Block Diario o H1 en Zona de Descuento.
                  </div>
                  <div className="p-2.5 rounded bg-[#12233A] border border-gray-800">
                    <span className="text-[#D4AF37] font-bold block mb-1">Paso 2</span>
                    Esperar barrido de mínimos previos (etiqueta <strong>SWEEP</strong>).
                  </div>
                  <div className="p-2.5 rounded bg-[#12233A] border border-gray-800">
                    <span className="text-[#D4AF37] font-bold block mb-1">Paso 3</span>
                    Gatillo Opwens de absorción por mecha (≥ 30%) o Martillo de 1 vela.
                  </div>
                  <div className="p-2.5 rounded bg-[#12233A] border border-gray-800">
                    <span className="text-[#D4AF37] font-bold block mb-1">Paso 4</span>
                    Disparo inmediato con SL bajo el mínimo y TP1 en el Fair Value Gap contrario.
                  </div>
                </div>
              </div>
            </CardContent>
          </Card>
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 5: GESTIÓN & FASES R */}
        {/* ============================================================ */}
        <TabsContent value="mod5" className="space-y-6">
          <RiskCalculator />
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 6: MEJORA CONTINUA & CHECKLIST */}
        {/* ============================================================ */}
        <TabsContent value="mod6" className="space-y-6">
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            <div className="lg:col-span-7">
              <TradeChecklist />
            </div>

            <div className="lg:col-span-5 space-y-4">
              <Card className="bg-[#12233A] border-gray-700 shadow-xl">
                <CardHeader>
                  <CardTitle className="text-base text-white flex items-center gap-2">
                    <Clock className="h-4 w-4 text-[#D4AF37]" />
                    Protocolo de Auditoría y Mejora Continua
                  </CardTitle>
                </CardHeader>
                <CardContent className="space-y-3 text-xs text-gray-300">
                  <p>
                    El éxito sostenido en el trading no proviene de un 100% de aciertos, sino del estricto cumplimiento
                    de un <strong>bucle de retroalimentación semanal</strong>:
                  </p>

                  <div className="p-3 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                    <span className="font-bold text-white block">1. Registro de Trades (Journaling):</span>
                    <span className="text-gray-400 block">
                      Guarda captura del gráfico antes y después de cada operación. Anota si fue gatillo de 1 vela o 3 velas.
                    </span>
                  </div>

                  <div className="p-3 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                    <span className="font-bold text-white block">2. Disyuntor Mental Anti-Racha:</span>
                    <span className="text-rose-400 font-semibold block">
                      Si acumulas 2 o 3 pérdidas consecutivas, se activa un Cooldown obligatorio de 4 horas sin abrir mercado.
                    </span>
                  </div>

                  <div className="p-3 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                    <span className="font-bold text-white block">3. Auditoría de Fin de Semana:</span>
                    <span className="text-gray-400 block">
                      Revisa tu Winrate y Profit Factor. Si una pérdida ocurrió por indisciplina (mover SL o sobrelotaje),
                      anótala como penalización en tu plan.
                    </span>
                  </div>
                </CardContent>
              </Card>
            </div>
          </div>
        </TabsContent>

        {/* ============================================================ */}
        {/* MÓDULO 7: MI PLAN DE TRADING (METODOLOGÍA OFICIAL) */}
        {/* ============================================================ */}
        <TabsContent value="mod7" className="space-y-6">
          <TradingPlanSheet />
        </TabsContent>
      </Tabs>
    </div>
  )
}
