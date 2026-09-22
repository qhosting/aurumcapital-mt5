import { Metadata } from "next"
import { AcademyView } from "@/components/academy/academy-view"

export const metadata: Metadata = {
  title: "Academia Institucional SMC & Opwens | Aurum Invest Station",
  description: "Guía completa de Trading de 0 a Avanzado: SMC, Velas Opwens, Patrones de Reversión y Gestión de Riesgo.",
}

export default function AcademyPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <AcademyView />
    </div>
  )
}
