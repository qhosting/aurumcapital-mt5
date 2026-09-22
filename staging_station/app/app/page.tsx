import { Metadata } from "next"
import { DashboardView } from "@/components/dashboard/dashboard-view"

export const metadata: Metadata = {
  title: "Dashboard Principal & Control MT5 | Aurum Invest Station V15",
  description: "Panel de control institucional en tiempo real: Equidad, PnL flotante, monitor de Killzones CDMX y operaciones auditadas.",
}

export default function DashboardPage() {
  return (
    <div className="container mx-auto px-4 py-8">
      <DashboardView />
    </div>
  )
}
