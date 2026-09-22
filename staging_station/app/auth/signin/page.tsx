import { Metadata } from "next"
import { LoginView } from "@/components/auth/login-view"

export const metadata: Metadata = {
  title: "Acceso Operativo MT5 | Aurum Invest Station V15",
  description: "Acceso institucional a la plataforma de monitoreo y trading algorítmico Aurum Capital.",
}

export default function SignInPage() {
  return <LoginView />
}
