"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

export interface ChartPatternData {
  id: string
  name: string
  category: "REVERSAL" | "CONTINUATION"
  bias: "BULLISH" | "BEARISH"
  modulePage: string
  description: string
  necklineDesc: string
  targetFormula: string
  slPlacement: string
  entryMethod: string
}

export const CHART_PATTERNS: ChartPatternData[] = [
  {
    id: "hch",
    name: "Hombro - Cabeza - Hombro (HCH)",
    category: "REVERSAL",
    bias: "BEARISH",
    modulePage: "Módulo 2, Pág. 5",
    description: "Patrón de inversión bajista de alta fiabilidad. Consta de un pico izquierdo (hombro), un pico más alto (cabeza) y un tercer pico más bajo (hombro derecho).",
    necklineDesc: "Línea trazada uniendo los valles entre los hombros y la cabeza.",
    targetFormula: "Take Profit = Altura H proyectada hacia abajo desde la ruptura de la línea de cuello.",
    slPlacement: "Por encima del hombro derecho (nivel de invalidación técnica).",
    entryMethod: "Ruptura del cuello o Pullback/Throwback con confirmación de vela Opwens."
  },
  {
    id: "inv_hch",
    name: "HCH Invertido",
    category: "REVERSAL",
    bias: "BULLISH",
    modulePage: "Módulo 2, Pág. 5",
    description: "Patrón de giro alcista que concluye una tendencia bajista previa. Consta de un valle izquierdo, un valle más profundo (cabeza invertida) y un valle derecho más alto.",
    necklineDesc: "Directriz de resistencia uniendo los picos de retroceso.",
    targetFormula: "Take Profit = Distancia vertical H (desde la cabeza al cuello) proyectada hacia arriba.",
    slPlacement: "Por debajo del hombro derecho invertido.",
    entryMethod: "Entrada en el retesteo (pullback) sobre la línea de cuello con vela martillo/envolvente."
  },
  {
    id: "double_top",
    name: "Doble Techo (M)",
    category: "REVERSAL",
    bias: "BEARISH",
    modulePage: "Módulo 2, Pág. 4",
    description: "Dos máximos al mismo nivel que demuestran el agotamiento de la presión compradora y la incapacidad de hacer nuevos altos.",
    necklineDesc: "Soporte horizontal situado en el valle intermedio entre ambos techos.",
    targetFormula: "Take Profit = Altura H entre el doble techo y el valle, proyectada hacia abajo.",
    slPlacement: "2 a 5 pips por encima de los máximos del doble techo.",
    entryMethod: "Al cerrar por debajo del soporte central o en el pullback hacia este nivel."
  },
  {
    id: "double_bottom",
    name: "Doble Suelo (W)",
    category: "REVERSAL",
    bias: "BULLISH",
    modulePage: "Módulo 2, Pág. 4",
    description: "Dos mínimos al mismo nivel tras una tendencia bajista prolongada. Muestra absorción institucional y fin de la presión de venta.",
    necklineDesc: "Resistencia horizontal situada en el pico intermedio entre ambos suelos.",
    targetFormula: "Take Profit = Altura H entre el valle y el pico, proyectada hacia arriba.",
    slPlacement: "2 a 5 pips por debajo del mínimo de los suelos.",
    entryMethod: "Ruptura confirmada del pico central o pullback con vela de giro Opwens."
  },
  {
    id: "bull_flag",
    name: "Bandera Alcista (Bullish Flag)",
    category: "CONTINUATION",
    bias: "BULLISH",
    modulePage: "Módulo 2, Pág. 12",
    description: "Patrón de continuación compuesto por un mástil explosivo (impulso institucional) seguido de un canal de consolidación descendente estrecho.",
    necklineDesc: "Directriz superior del canal de consolidación.",
    targetFormula: "Take Profit = Longitud del mástil inicial proyectada desde el punto de ruptura.",
    slPlacement: "Por debajo del último mínimo del canal de la bandera.",
    entryMethod: "Ruptura del canal descendente con vela de volumen o retesteo del borde superior."
  },
  {
    id: "asc_triangle",
    name: "Triángulo Ascendente",
    category: "CONTINUATION",
    bias: "BULLISH",
    modulePage: "Módulo 2, Pág. 3",
    description: "Techo horizontal de resistencia con mínimos crecientes continuos. Refleja que los compradores están dispuestos a comprar cada vez más caro hasta romper el techo.",
    necklineDesc: "Resistencia horizontal superior.",
    targetFormula: "Take Profit = Altura máxima del triángulo en su base, proyectada hacia arriba.",
    slPlacement: "Por debajo de la directriz alcista de mínimos crecientes.",
    entryMethod: "Cierre de vela M15 por encima de la resistencia horizontal."
  }
]

export function PatternDiagram() {
  const [selectedId, setSelectedId] = useState<string>("hch")
  const activePattern = CHART_PATTERNS.find((p) => p.id === selectedId) || CHART_PATTERNS[0]

  return (
    <div className="space-y-6">
      {/* Selector de Patrones */}
      <div className="flex flex-wrap gap-2">
        {CHART_PATTERNS.map((pattern) => {
          const isSelected = pattern.id === selectedId
          return (
            <Button
              key={pattern.id}
              variant={isSelected ? "default" : "outline"}
              onClick={() => setSelectedId(pattern.id)}
              className={`text-xs md:text-sm font-semibold transition-all ${
                isSelected
                  ? "bg-[#D4AF37] text-[#0A192F] hover:bg-[#c49f27]"
                  : "border-gray-700 text-gray-300 hover:text-white hover:bg-[#1A2E46]"
              }`}
            >
              {pattern.name}
            </Button>
          )
        })}
      </div>

      {/* Tarjeta con Renderizado Vectorial */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        <Card className="lg:col-span-6 bg-[#12233A] border-gray-700 shadow-xl overflow-hidden">
          <CardHeader className="border-b border-gray-800 pb-3">
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-2">
                <Badge
                  className={
                    activePattern.bias === "BULLISH"
                      ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                      : "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                  }
                >
                  {activePattern.bias}
                </Badge>
                <Badge variant="outline" className="text-gray-300 border-gray-600">
                  {activePattern.category === "REVERSAL" ? "INVERSIÓN" : "CONTINUACIÓN"}
                </Badge>
              </div>
              <span className="text-xs text-gray-400 font-mono">{activePattern.modulePage}</span>
            </div>
            <CardTitle className="text-lg font-bold text-white mt-2">{activePattern.name}</CardTitle>
          </CardHeader>

          <CardContent className="p-6 flex flex-col items-center justify-center bg-[#0d1b2e]">
            <div className="relative w-full max-w-[340px] h-[300px] flex items-center justify-center">
              {activePattern.id === "hch" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  {/* Trayectoria del precio */}
                  <polyline
                    points="30,200 60,110 90,170 160,40 230,170 260,110 290,200 310,240"
                    fill="none"
                    stroke="#38BDF8"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {/* Línea de Cuello (Neckline) */}
                  <line x1="70" y1="170" x2="310" y2="170" stroke="#D4AF37" strokeWidth="2" strokeDasharray="5 3" />
                  <text x="180" y="163" fill="#D4AF37" fontSize="10" fontWeight="bold">LÍNEA DE CUELLO (NECKLINE)</text>

                  {/* Etiquetas de Puntos Clave */}
                  <circle cx="60" cy="110" r="4" fill="#38BDF8" />
                  <text x="60" y="95" fill="#E2E8F0" fontSize="10" textAnchor="middle">Hombro I</text>
                  
                  <circle cx="160" cy="40" r="5" fill="#EF4444" />
                  <text x="160" y="25" fill="#EF4444" fontSize="11" fontWeight="bold" textAnchor="middle">CABEZA (Alto)</text>
                  
                  <circle cx="260" cy="110" r="4" fill="#38BDF8" />
                  <text x="260" y="95" fill="#E2E8F0" fontSize="10" textAnchor="middle">Hombro D</text>

                  {/* Cota de Altura H */}
                  <line x1="160" y1="40" x2="160" y2="170" stroke="#F59E0B" strokeWidth="2" strokeDasharray="3 3" />
                  <text x="165" y="110" fill="#F59E0B" fontSize="11" fontWeight="bold">H</text>

                  {/* Proyección Target H */}
                  <line x1="290" y1="170" x2="290" y2="250" stroke="#10B981" strokeWidth="2" strokeDasharray="3 3" />
                  <text x="295" y="220" fill="#10B981" fontSize="11" fontWeight="bold">Objetivo H</text>
                  
                  {/* Punto de Entrada */}
                  <circle cx="290" cy="170" r="5" fill="#EF4444" />
                  <text x="290" y="188" fill="#EF4444" fontSize="9" textAnchor="middle" fontWeight="bold">RUPTURA</text>
                </svg>
              )}

              {activePattern.id === "inv_hch" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  {/* Trayectoria invertida */}
                  <polyline
                    points="30,60 60,150 90,90 160,220 230,90 260,150 290,90 310,30"
                    fill="none"
                    stroke="#10B981"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {/* Neckline */}
                  <line x1="70" y1="90" x2="310" y2="90" stroke="#D4AF37" strokeWidth="2" strokeDasharray="5 3" />
                  <text x="180" y="83" fill="#D4AF37" fontSize="10" fontWeight="bold">NECKLINE RESISTENCIA</text>

                  <text x="60" y="170" fill="#E2E8F0" fontSize="10" textAnchor="middle">Hombro I</text>
                  <text x="160" y="240" fill="#10B981" fontSize="11" fontWeight="bold" textAnchor="middle">CABEZA INVERTIDA</text>
                  <text x="260" y="170" fill="#E2E8F0" fontSize="10" textAnchor="middle">Hombro D</text>

                  {/* Proyección H hacia arriba */}
                  <line x1="290" y1="90" x2="290" y2="20" stroke="#10B981" strokeWidth="2" strokeDasharray="3 3" />
                  <text x="295" y="55" fill="#10B981" fontSize="11" fontWeight="bold">Target +H</text>
                </svg>
              )}

              {activePattern.id === "double_top" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  <polyline
                    points="40,220 100,60 160,160 220,60 280,160 300,220"
                    fill="none"
                    stroke="#EF4444"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {/* Línea de Techo Doble */}
                  <line x1="80" y1="60" x2="240" y2="60" stroke="#F87171" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="100" y="45" fill="#F87171" fontSize="10" fontWeight="bold" textAnchor="middle">Techo 1</text>
                  <text x="220" y="45" fill="#F87171" fontSize="10" fontWeight="bold" textAnchor="middle">Techo 2</text>

                  {/* Soporte Neckline */}
                  <line x1="120" y1="160" x2="300" y2="160" stroke="#D4AF37" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="160" y="152" fill="#D4AF37" fontSize="10" fontWeight="bold" textAnchor="middle">Soporte Central</text>

                  {/* Target H */}
                  <line x1="280" y1="160" x2="280" y2="240" stroke="#10B981" strokeWidth="2" strokeDasharray="3 3" />
                  <text x="285" y="205" fill="#10B981" fontSize="10" fontWeight="bold">Target H</text>
                </svg>
              )}

              {activePattern.id === "double_bottom" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  <polyline
                    points="40,40 100,200 160,100 220,200 280,100 300,40"
                    fill="none"
                    stroke="#10B981"
                    strokeWidth="3"
                    strokeLinecap="round"
                    strokeLinejoin="round"
                  />
                  {/* Suelo Doble */}
                  <line x1="80" y1="200" x2="240" y2="200" stroke="#34D399" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="100" y="220" fill="#34D399" fontSize="10" fontWeight="bold" textAnchor="middle">Suelo 1</text>
                  <text x="220" y="220" fill="#34D399" fontSize="10" fontWeight="bold" textAnchor="middle">Suelo 2</text>

                  {/* Resistencia Central */}
                  <line x1="120" y1="100" x2="300" y2="100" stroke="#D4AF37" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="160" y="92" fill="#D4AF37" fontSize="10" fontWeight="bold" textAnchor="middle">Resistencia</text>

                  {/* Target H */}
                  <line x1="280" y1="100" x2="280" y2="20" stroke="#10B981" strokeWidth="2" strokeDasharray="3 3" />
                  <text x="285" y="55" fill="#10B981" fontSize="10" fontWeight="bold">Target +H</text>
                </svg>
              )}

              {activePattern.id === "bull_flag" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  {/* Mástil */}
                  <line x1="50" y1="220" x2="130" y2="60" stroke="#10B981" strokeWidth="4" />
                  <text x="75" y="130" fill="#10B981" fontSize="11" fontWeight="bold">MÁSTIL</text>

                  {/* Canal Bandera */}
                  <line x1="130" y1="60" x2="220" y2="100" stroke="#38BDF8" strokeWidth="2" />
                  <line x1="110" y1="100" x2="200" y2="140" stroke="#38BDF8" strokeWidth="2" />

                  {/* Rebotes dentro de la bandera */}
                  <polyline
                    points="130,60 140,112 170,80 180,130 210,95 240,40"
                    fill="none"
                    stroke="#D4AF37"
                    strokeWidth="2"
                  />

                  {/* Proyección del mástil */}
                  <line x1="210" y1="95" x2="270" y2="15" stroke="#10B981" strokeWidth="3" strokeDasharray="4 2" />
                  <text x="260" y="45" fill="#10B981" fontSize="10" fontWeight="bold">Target Proyectado</text>
                </svg>
              )}

              {activePattern.id === "asc_triangle" && (
                <svg viewBox="0 0 320 260" className="w-full h-full drop-shadow-md">
                  {/* Techo Horizontal */}
                  <line x1="60" y1="70" x2="280" y2="70" stroke="#EF4444" strokeWidth="3" />
                  <text x="170" y="60" fill="#EF4444" fontSize="10" fontWeight="bold" textAnchor="middle">RESISTENCIA HORIZONTAL</text>

                  {/* Directriz Ascendente */}
                  <line x1="60" y1="210" x2="250" y2="70" stroke="#10B981" strokeWidth="3" />
                  <text x="130" y="170" fill="#10B981" fontSize="10" fontWeight="bold">MÍNIMOS CRECIENTES</text>

                  {/* Rebotes */}
                  <polyline
                    points="60,210 100,70 140,150 180,70 210,110 240,70 270,25"
                    fill="none"
                    stroke="#38BDF8"
                    strokeWidth="2"
                  />
                </svg>
              )}
            </div>
          </CardContent>
        </Card>

        {/* Reglas Cuantitativas del Chartismo Clásico */}
        <div className="lg:col-span-6 space-y-4">
          <Card className="bg-[#12233A] border-gray-700">
            <CardHeader className="pb-3">
              <CardTitle className="text-base text-white flex items-center gap-2">
                <span>📐</span> Geometría y Medición Técnica
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs text-gray-300">
              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-gray-400 block mb-1">Descripción:</span>
                <p className="text-white text-xs">{activePattern.description}</p>
              </div>

              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-[#D4AF37] block mb-1">Línea de Cuello (Neckline):</span>
                <p className="text-white text-xs">{activePattern.necklineDesc}</p>
              </div>

              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-emerald-400 block mb-1">Cálculo de Take Profit (H):</span>
                <p className="text-emerald-300 font-semibold text-xs">{activePattern.targetFormula}</p>
              </div>

              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-rose-400 block mb-1">Stop Loss (Invalidación Técnica):</span>
                <p className="text-rose-300 font-semibold text-xs">{activePattern.slPlacement}</p>
              </div>
            </CardContent>
          </Card>

          <Card className="bg-[#12233A] border-gray-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold text-white flex items-center gap-2">
                <span>⚡</span> Método de Ejecución con Confluencia
              </CardTitle>
            </CardHeader>
            <CardContent className="text-xs text-gray-200 p-4 bg-[#0A192F] rounded-b-lg border-t border-gray-800">
              <p>{activePattern.entryMethod}</p>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
