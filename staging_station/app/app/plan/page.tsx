import { Metadata } from "next"
import { TradingPlanSheet } from "@/components/academy/trading-plan-sheet"

export const metadata: Metadata = {
  title: "Mi Plan de Trading Oficial | Aurum Invest Station",
  description: "Plan de Trading Oficial e Interactivo alineado a la estrategia Aurum V15 & SMC: Gestión de riesgo, objetivos, firma digital y checklist pre-vuelo.",
}

export default function TradingPlanPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <TradingPlanSheet />
    </div>
  )
}
