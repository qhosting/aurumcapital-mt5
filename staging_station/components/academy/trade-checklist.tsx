"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import { ShieldCheck, AlertTriangle, CheckCircle } from "lucide-react"

export interface ChecklistItem {
  id: string
  title: string
  description: string
  source: string
}

export const INSTITUTIONAL_CHECKLIST: ChecklistItem[] = [
  {
    id: "session",
    title: "1. Sesión & Horario Institucional",
    description: "El mercado se encuentra dentro de las Killzones de alta liquidez (Londres o NY Overlap) o en Oro fuera de la ventana de rollover del broker (23:55-00:05).",
    source: "Forex Blueprint Pág. 4"
  },
  {
    id: "structure",
    title: "2. Estructura SMC & Tendencia H1",
    description: "La estructura de mercado en M15 y H1 está alineada (BOS / CHoCH confirmado). No estás operando en contra de la tendencia principal sin justificación.",
    source: "Aurum V15 SMC"
  },
  {
    id: "poi",
    title: "3. Zona Institucional / POI en Descuento",
    description: "El precio se encuentra dentro de un Order Block (+OB), Breaker o tras un barrido de liquidez (SWEEP). Compras en zona de Descuento (<50%) o vendes en Premium (>50%).",
    source: "Libro Opwens & SMC"
  },
  {
    id: "trigger",
    title: "4. Gatillo de Acción del Precio (Opwens)",
    description: "Vela 1 cerrada confirmó absorción por mecha (≥ 30%), Martillo, Estrella Fugaz o Envolvente en el borde del nivel, validando la entrada de los institucionales.",
    source: "Libro Opwens Pág. 14-20"
  },
  {
    id: "risk",
    title: "5. Gestión de Riesgo & Ratio R:R ≥ 1:2",
    description: "El Stop Loss está ubicado en zona técnica de invalidación. El riesgo monetario no supera el 1% del capital y el Take Profit ofrece al menos el doble del riesgo asumido.",
    source: "Forex Blueprint Pág. 11"
  }
]

export function TradeChecklist() {
  const [checkedItems, setCheckedItems] = useState<Record<string, boolean>>({})

  const toggleItem = (id: string) => {
    setCheckedItems((prev) => ({
      ...prev,
      [id]: !prev[id]
    }))
  }

  const completedCount = Object.values(checkedItems).filter(Boolean).length
  const totalCount = INSTITUTIONAL_CHECKLIST.length
  const isAllApproved = completedCount === totalCount

  const handleReset = () => {
    setCheckedItems({})
  }

  return (
    <Card className="bg-[#12233A] border-gray-700 shadow-xl">
      <CardHeader>
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-2">
            <ShieldCheck className="h-5 w-5 text-[#D4AF37]" />
            <CardTitle className="text-base text-white">Checklist de Auditoría Pre-Operativa</CardTitle>
          </div>
          <Badge
            className={
              isAllApproved
                ? "bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 font-bold"
                : "bg-amber-500/20 text-amber-400 border border-amber-500/30"
            }
          >
            {completedCount} de {totalCount} Aprobados
          </Badge>
        </div>
        <CardDescription className="text-xs text-gray-400">
          Nunca ejecutes una orden en vivo si no se cumplen simultáneamente los 5 criterios de confluencia.
        </CardDescription>
      </CardHeader>

      <CardContent className="space-y-4">
        <div className="space-y-3">
          {INSTITUTIONAL_CHECKLIST.map((item) => {
            const isChecked = !!checkedItems[item.id]
            return (
              <div
                key={item.id}
                onClick={() => toggleItem(item.id)}
                className={`p-3 rounded-lg border cursor-pointer transition-all flex items-start gap-3 ${
                  isChecked
                    ? "bg-emerald-950/20 border-emerald-800/50 text-white"
                    : "bg-[#0A192F] border-gray-800 text-gray-300 hover:border-gray-700"
                }`}
              >
                <Checkbox
                  checked={isChecked}
                  onCheckedChange={() => toggleItem(item.id)}
                  className="mt-1 data-[state=checked]:bg-[#D4AF37] data-[state=checked]:border-[#D4AF37]"
                />
                <div className="space-y-1">
                  <div className="flex items-center gap-2">
                    <span className="text-sm font-semibold text-white">{item.title}</span>
                    <Badge variant="outline" className="text-[10px] text-gray-400 border-gray-700 py-0">
                      {item.source}
                    </Badge>
                  </div>
                  <p className="text-xs text-gray-400 leading-relaxed">{item.description}</p>
                </div>
              </div>
            )
          })}
        </div>

        {/* Estado de Aprobación */}
        <div className="pt-2 flex items-center justify-between">
          <Button
            variant="ghost"
            onClick={handleReset}
            className="text-xs text-gray-400 hover:text-white"
          >
            Reiniciar Checklist
          </Button>

          {isAllApproved ? (
            <div className="flex items-center gap-2 text-xs font-bold text-emerald-400 bg-emerald-950/40 px-3 py-1.5 rounded border border-emerald-800">
              <CheckCircle className="h-4 w-4" />
              <span>SETUP APROBADO PARA DISPARO</span>
            </div>
          ) : (
            <div className="flex items-center gap-2 text-xs text-amber-400 bg-amber-950/30 px-3 py-1.5 rounded border border-amber-800/40">
              <AlertTriangle className="h-4 w-4" />
              <span>Esperando confirmación total de confluencias</span>
            </div>
          )}
        </div>
      </CardContent>
    </Card>
  )
}
