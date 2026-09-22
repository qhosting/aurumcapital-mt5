"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"

export interface CandlePatternData {
  id: string
  name: string
  subtitle: string
  type: "BULLISH" | "BEARISH" | "REVERSAL" | "CONTINUATION"
  page: number
  description: string
  anatomy: {
    upperWick: string
    body: string
    lowerWick: string
    rejectionRatio: string
  }
  entryRule: string
  slRule: string
}

export const OPWENS_PATTERNS: CandlePatternData[] = [
  {
    id: "hammer",
    name: "Hammer (Martillo)",
    subtitle: "Giro Alcista de Alta Probabilidad",
    type: "BULLISH",
    page: 14,
    description: "Vela con cuerpo pequeño en la parte superior y una larga sombra inferior tras una caída prolongada. Refleja rechazo masivo de mínimos por absorción compradora.",
    anatomy: {
      upperWick: "Mínima o inexistente (≤ 15% del rango)",
      body: "Pequeño en tercio superior (alcista o bajista)",
      lowerWick: "Larga (≥ 2.0x el tamaño del cuerpo)",
      rejectionRatio: "Mecha inferior ≥ 55% del rango total de la vela"
    },
    entryRule: "Al cierre de la vela martillo sobre POI (Order Block o Soporte)",
    slRule: "2 a 5 pips por debajo del mínimo de la mecha inferior"
  },
  {
    id: "shooting_star",
    name: "Shooting Star (Estrella Fugaz)",
    subtitle: "Giro Bajista Institucional",
    type: "BEARISH",
    page: 15,
    description: "Vela con cuerpo pequeño en la parte inferior y larga sombra superior tras un rally alcista. Los compradores intentaron subir el precio pero los vendedores tomaron el control total.",
    anatomy: {
      upperWick: "Larga (≥ 2.0x el cuerpo, ≥ 55% del rango total)",
      body: "Pequeño en tercio inferior",
      lowerWick: "Mínima o inexistente (≤ 15% del rango)",
      rejectionRatio: "Mecha superior ≥ 55% del rango total"
    },
    entryRule: "Al cierre de la barra en zona Premium / Resistencia / Bearish OB",
    slRule: "2 a 5 pips por encima del máximo de la mecha superior"
  },
  {
    id: "bullish_engulfing",
    name: "Bullish Engulfing (Envolvente Alcista)",
    subtitle: "Demanda Agresiva Institucional",
    type: "BULLISH",
    page: 16,
    description: "Vela verde cuyo cuerpo cubre y supera por completo el cuerpo de la vela roja anterior. Representa entrada de volumen institucional comprador.",
    anatomy: {
      upperWick: "Moderada",
      body: "Cuerpo verde ≥ 110% del cuerpo rojo anterior",
      lowerWick: "Moderada",
      rejectionRatio: "Cierre por encima de la apertura de la vela previa"
    },
    entryRule: "Al cierre de la vela envolvente sobre nivel de descuento",
    slRule: "Por debajo del mínimo de ambas velas de la formación"
  },
  {
    id: "bearish_engulfing",
    name: "Bearish Engulfing (Envolvente Bajista)",
    subtitle: "Oferta Agresiva Institucional",
    type: "BEARISH",
    page: 16,
    description: "Vela roja cuyo cuerpo cubre completamente el cuerpo de la vela verde anterior. La presión de venta absorbe toda la liquidez alcista.",
    anatomy: {
      upperWick: "Moderada",
      body: "Cuerpo rojo ≥ 110% del cuerpo verde anterior",
      lowerWick: "Moderada",
      rejectionRatio: "Cierre por debajo de la apertura de la vela previa"
    },
    entryRule: "Al cierre de la vela envolvente bajista en zona Premium",
    slRule: "Por encima del máximo de la estructura envolvente"
  },
  {
    id: "morning_star",
    name: "Morning Star (Estrella Matutina)",
    subtitle: "Patrón de Reversión de 3 Velas",
    type: "BULLISH",
    page: 18,
    description: "Formación de 3 barras: vela bajista fuerte, vela intermedia de indecisión (cuerpo pequeño ≤ 45% de vela 1) y vela alcista que penetra > 50% de la primera vela.",
    anatomy: {
      upperWick: "Variable en vela central",
      body: "Vela 1 bajista fuerte, Vela 2 pequeña, Vela 3 alcista fuerte",
      lowerWick: "Mecha de absorción en vela central",
      rejectionRatio: "Vela 3 cierra por encima del 50% de la Vela 1"
    },
    entryRule: "Al cierre de la tercera vela (confirmación)",
    slRule: "Por debajo del mínimo de la vela central de la estrella"
  },
  {
    id: "three_soldiers",
    name: "Three White Soldiers (3 Soldados Blancos)",
    subtitle: "Continuación y Fortaleza Alcista",
    type: "BULLISH",
    page: 19,
    description: "Tres velas alcistas consecutivas con cierres progresivamente más altos y cuerpos sólidos con mechas cortas.",
    anatomy: {
      upperWick: "Corta en cada vela",
      body: "Cuerpos verdes progresivos y sanos",
      lowerWick: "Corta, apertura dentro del cuerpo previo",
      rejectionRatio: "Cierre 3 > Cierre 2 > Cierre 1"
    },
    entryRule: "Al cierre de la 2da o 3ra vela (cuidar que no choque con FVG contrario)",
    slRule: "Por debajo del mínimo de la primera o segunda vela"
  }
]

export function CandleDiagram() {
  const [selectedId, setSelectedId] = useState<string>("hammer")
  const activePattern = OPWENS_PATTERNS.find((p) => p.id === selectedId) || OPWENS_PATTERNS[0]

  return (
    <div className="space-y-6">
      {/* Selector de Patrones */}
      <div className="flex flex-wrap gap-2">
        {OPWENS_PATTERNS.map((pattern) => {
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

      {/* Tarjeta Principal del Patrón */}
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
        {/* Renderizado Gráfico SVG de la Vela */}
        <Card className="lg:col-span-5 bg-[#12233A] border-gray-700 shadow-xl overflow-hidden">
          <CardHeader className="border-b border-gray-800 pb-3">
            <div className="flex items-center justify-between">
              <Badge
                className={
                  activePattern.type === "BULLISH"
                    ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30"
                    : "bg-rose-500/20 text-rose-400 border border-rose-500/30"
                }
              >
                {activePattern.type === "BULLISH" ? "ALCISTA (BUY)" : "BAJISTA (SELL)"}
              </Badge>
              <span className="text-xs text-gray-400 font-mono">Libro Opwens Pág. {activePattern.page}</span>
            </div>
            <CardTitle className="text-lg font-bold text-white mt-2">{activePattern.name}</CardTitle>
            <CardDescription className="text-xs text-[#D4AF37]">{activePattern.subtitle}</CardDescription>
          </CardHeader>

          <CardContent className="p-6 flex flex-col items-center justify-center bg-[#0d1b2e]">
            {/* Gráfico SVG de Anatomía */}
            <div className="relative w-full max-w-[280px] h-[320px] flex items-center justify-center">
              {activePattern.id === "hammer" && (
                <svg viewBox="0 0 200 300" className="w-full h-full drop-shadow-md">
                  {/* Línea de Cota Superior */}
                  <line x1="100" y1="30" x2="100" y2="50" stroke="#94A3B8" strokeWidth="3" />
                  {/* Cuerpo Martillo */}
                  <rect x="75" y="50" width="50" height="40" rx="3" fill="#10B981" stroke="#34D399" strokeWidth="2" />
                  {/* Mecha Larga Inferior */}
                  <line x1="100" y1="90" x2="100" y2="260" stroke="#10B981" strokeWidth="4" strokeLinecap="round" />

                  {/* Etiquetas de Cotas */}
                  <text x="135" y="42" fill="#94A3B8" fontSize="10" fontFamily="sans-serif">Sombra ≤ 15%</text>
                  <text x="135" y="75" fill="#34D399" fontSize="10" fontWeight="bold" fontFamily="sans-serif">Cuerpo Real</text>
                  <text x="135" y="175" fill="#10B981" fontSize="11" fontWeight="bold" fontFamily="sans-serif">Mecha ≥ 2x Cuerpo (≥ 55%)</text>
                  
                  {/* Zona de Stop Loss */}
                  <line x1="60" y1="275" x2="140" y2="275" stroke="#EF4444" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="100" y="292" fill="#EF4444" fontSize="10" textAnchor="middle" fontWeight="bold">STOP LOSS (Seguridad)</text>
                </svg>
              )}

              {activePattern.id === "shooting_star" && (
                <svg viewBox="0 0 200 300" className="w-full h-full drop-shadow-md">
                  {/* Mecha Larga Superior */}
                  <line x1="100" y1="40" x2="100" y2="210" stroke="#EF4444" strokeWidth="4" strokeLinecap="round" />
                  {/* Cuerpo */}
                  <rect x="75" y="210" width="50" height="40" rx="3" fill="#EF4444" stroke="#F87171" strokeWidth="2" />
                  {/* Sombra Inferior Mínima */}
                  <line x1="100" y1="250" x2="100" y2="270" stroke="#94A3B8" strokeWidth="3" />

                  {/* Etiquetas */}
                  <text x="135" y="125" fill="#EF4444" fontSize="11" fontWeight="bold" fontFamily="sans-serif">Mecha Rechazo ≥ 55%</text>
                  <text x="135" y="235" fill="#F87171" fontSize="10" fontWeight="bold" fontFamily="sans-serif">Cuerpo Vendedor</text>
                  <line x1="60" y1="25" x2="140" y2="25" stroke="#EF4444" strokeWidth="2" strokeDasharray="4 2" />
                  <text x="100" y="18" fill="#EF4444" fontSize="10" textAnchor="middle" fontWeight="bold">STOP LOSS</text>
                </svg>
              )}

              {activePattern.id === "bullish_engulfing" && (
                <svg viewBox="0 0 220 300" className="w-full h-full drop-shadow-md">
                  {/* Vela 1: Bajista pequeña */}
                  <line x1="60" y1="100" x2="60" y2="200" stroke="#F87171" strokeWidth="2" />
                  <rect x="45" y="120" width="30" height="50" rx="2" fill="#EF4444" />
                  <text x="60" y="85" fill="#94A3B8" fontSize="10" textAnchor="middle">Vela 1</text>

                  {/* Vela 2: Alcista Envolvente Gigante */}
                  <line x1="140" y1="80" x2="140" y2="230" stroke="#34D399" strokeWidth="3" />
                  <rect x="120" y="105" width="40" height="85" rx="3" fill="#10B981" stroke="#34D399" strokeWidth="2" />
                  <text x="140" y="65" fill="#10B981" fontSize="11" textAnchor="middle" fontWeight="bold">Vela 2 (Envolvente ≥ 110%)</text>
                  
                  {/* Flecha de confirmación */}
                  <path d="M 180 180 L 195 180 L 195 130 L 205 130 L 187 110 L 170 130 L 180 130 Z" fill="#D4AF37" />
                </svg>
              )}

              {activePattern.id === "bearish_engulfing" && (
                <svg viewBox="0 0 220 300" className="w-full h-full drop-shadow-md">
                  {/* Vela 1: Alcista */}
                  <line x1="60" y1="110" x2="60" y2="200" stroke="#34D399" strokeWidth="2" />
                  <rect x="45" y="130" width="30" height="45" rx="2" fill="#10B981" />
                  
                  {/* Vela 2: Bajista Envolvente */}
                  <line x1="140" y1="80" x2="140" y2="235" stroke="#F87171" strokeWidth="3" />
                  <rect x="120" y="115" width="40" height="85" rx="3" fill="#EF4444" stroke="#F87171" strokeWidth="2" />
                  <text x="140" y="65" fill="#EF4444" fontSize="11" textAnchor="middle" fontWeight="bold">Envolvente Bajista</text>
                </svg>
              )}

              {activePattern.id === "morning_star" && (
                <svg viewBox="0 0 240 300" className="w-full h-full drop-shadow-md">
                  {/* Vela 1 */}
                  <line x1="50" y1="70" x2="50" y2="200" stroke="#F87171" strokeWidth="2" />
                  <rect x="35" y="90" width="30" height="80" rx="2" fill="#EF4444" />
                  
                  {/* Vela 2 (Estrella pequeña en gap abajo) */}
                  <line x1="120" y1="180" x2="120" y2="240" stroke="#94A3B8" strokeWidth="2" />
                  <rect x="110" y="200" width="20" height="20" rx="2" fill="#D4AF37" />
                  
                  {/* Vela 3 (Recuperación) */}
                  <line x1="190" y1="90" x2="190" y2="210" stroke="#34D399" strokeWidth="2" />
                  <rect x="175" y="110" width="30" height="75" rx="2" fill="#10B981" />

                  {/* Nivel 50% de penetración */}
                  <line x1="20" y1="130" x2="220" y2="130" stroke="#D4AF37" strokeWidth="1" strokeDasharray="3 3" />
                  <text x="225" y="133" fill="#D4AF37" fontSize="9">50% V1</text>
                </svg>
              )}

              {activePattern.id === "three_soldiers" && (
                <svg viewBox="0 0 240 300" className="w-full h-full drop-shadow-md">
                  {/* Soldado 1 */}
                  <line x1="50" y1="170" x2="50" y2="260" stroke="#34D399" strokeWidth="2" />
                  <rect x="38" y="190" width="25" height="50" rx="2" fill="#10B981" />

                  {/* Soldado 2 */}
                  <line x1="110" y1="120" x2="110" y2="220" stroke="#34D399" strokeWidth="2" />
                  <rect x="98" y="140" width="25" height="55" rx="2" fill="#10B981" />

                  {/* Soldado 3 */}
                  <line x1="170" y1="70" x2="170" y2="170" stroke="#34D399" strokeWidth="2" />
                  <rect x="158" y="90" width="25" height="60" rx="2" fill="#10B981" />

                  {/* Flecha ascendente */}
                  <line x1="30" y1="270" x2="190" y2="60" stroke="#D4AF37" strokeWidth="2" strokeDasharray="4 2" />
                </svg>
              )}
            </div>
            <p className="text-[11px] text-gray-400 mt-3 text-center">
              Diagrama geométrico con las cotas milimétricas del manual Opwens A4
            </p>
          </CardContent>
        </Card>

        {/* Detalles Técnicos y Reglas de Ejecución */}
        <div className="lg:col-span-7 space-y-4">
          <Card className="bg-[#12233A] border-gray-700">
            <CardHeader className="pb-3">
              <CardTitle className="text-base text-white flex items-center gap-2">
                <span>📖</span> Descripción Cuantitativa
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-4 text-sm text-gray-300">
              <p>{activePattern.description}</p>
              
              <div className="grid grid-cols-1 sm:grid-cols-2 gap-3 pt-2">
                <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                  <span className="text-xs text-gray-400 block mb-1">Sombra Superior:</span>
                  <span className="text-xs font-semibold text-white">{activePattern.anatomy.upperWick}</span>
                </div>
                <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                  <span className="text-xs text-gray-400 block mb-1">Cuerpo Real:</span>
                  <span className="text-xs font-semibold text-white">{activePattern.anatomy.body}</span>
                </div>
                <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                  <span className="text-xs text-gray-400 block mb-1">Sombra Inferior:</span>
                  <span className="text-xs font-semibold text-white">{activePattern.anatomy.lowerWick}</span>
                </div>
                <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                  <span className="text-xs text-[#D4AF37] block mb-1">Fórmula de Detección:</span>
                  <span className="text-xs font-semibold text-emerald-400">{activePattern.anatomy.rejectionRatio}</span>
                </div>
              </div>
            </CardContent>
          </Card>

          {/* Reglas de Ejecución Institucional */}
          <Card className="bg-[#12233A] border-gray-700">
            <CardHeader className="pb-2">
              <CardTitle className="text-sm font-semibold text-white flex items-center gap-2">
                <span>🎯</span> Parámetros de Disparo & Blindaje (SL/TP)
              </CardTitle>
            </CardHeader>
            <CardContent className="space-y-3 text-xs">
              <div className="flex items-start gap-3 p-3 rounded-md bg-emerald-950/30 border border-emerald-800/40">
                <Badge className="bg-emerald-500/20 text-emerald-300 border-none shrink-0">ENTRADA</Badge>
                <p className="text-gray-200">{activePattern.entryRule}</p>
              </div>

              <div className="flex items-start gap-3 p-3 rounded-md bg-rose-950/30 border border-rose-800/40">
                <Badge className="bg-rose-500/20 text-rose-300 border-none shrink-0">STOP LOSS</Badge>
                <p className="text-gray-200">{activePattern.slRule}</p>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}
