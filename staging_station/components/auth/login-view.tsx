"use client"

import React, { useState } from "react"
import { useRouter } from "next/navigation"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import {
  TrendingUp,
  ShieldCheck,
  Lock,
  Eye,
  EyeOff,
  User,
  Server,
  KeyRound,
  Sparkles,
  ArrowRight,
  CheckCircle2,
  AlertCircle,
  Cpu
} from "lucide-react"

export function LoginView() {
  const router = useRouter()

  const [accountType, setAccountType] = useState<"live" | "demo" | "guest">("live")
  const [loginId, setLoginId] = useState("aurum_trader_v15")
  const [password, setPassword] = useState("••••••••••••")
  const [showPassword, setShowPassword] = useState(false)
  const [server, setServer] = useState("XM-Global-Real-22")
  const [isLoading, setIsLoading] = useState(false)
  const [errorMsg, setErrorMsg] = useState<string | null>(null)

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault()
    setIsLoading(true)
    setErrorMsg(null)

    setTimeout(() => {
      setIsLoading(false)
      router.push("/app")
    }, 900)
  }

  const handleQuickDemo = () => {
    setIsLoading(true)
    setTimeout(() => {
      router.push("/app")
    }, 600)
  }

  return (
    <div className="min-h-screen w-full flex items-center justify-center bg-[#0A192F] relative overflow-hidden px-4 py-12">
      {/* Resplandor ambiental de fondo */}
      <div className="absolute top-1/4 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[500px] h-[500px] bg-[#D4AF37]/10 rounded-full blur-[120px] pointer-events-none" />
      <div className="absolute bottom-10 right-10 w-[300px] h-[300px] bg-emerald-500/10 rounded-full blur-[100px] pointer-events-none" />

      <div className="w-full max-w-md space-y-6 relative z-10">
        {/* Logo y Encabezado Principal */}
        <div className="text-center space-y-2">
          <div className="inline-flex items-center gap-2 px-3 py-1.5 rounded-full bg-[#12233A] border border-[#D4AF37]/40 shadow-lg mb-2">
            <TrendingUp className="h-5 w-5 text-[#D4AF37]" />
            <span className="text-xs font-bold text-white tracking-widest uppercase">
              AURUM INVEST <span className="text-[#D4AF37]">STATION V15</span>
            </span>
          </div>
          <h1 className="text-2xl md:text-3xl font-extrabold text-white tracking-tight">
            Acceso Operativo Institucional
          </h1>
          <p className="text-xs text-gray-400 max-w-xs mx-auto leading-relaxed">
            Terminal de monitoreo algorítmico en tiempo real, auditoría forense SMC y gestión de riesgo Aurum.
          </p>
        </div>

        {/* Tarjeta de Login Glassmorphism */}
        <Card className="bg-[#12233A]/80 backdrop-blur-xl border-2 border-[#D4AF37]/30 shadow-2xl rounded-2xl overflow-hidden">
          <CardHeader className="pb-4 border-b border-gray-800/80">
            {/* Pestañas de Servidor / Tipo de Cuenta */}
            <div className="grid grid-cols-3 gap-1 bg-[#0A192F] p-1 rounded-xl border border-gray-800 text-xs font-semibold">
              <button
                type="button"
                onClick={() => {
                  setAccountType("live")
                  setServer("XM-Global-Real-22")
                }}
                className={`py-1.5 px-2 rounded-lg transition-all text-center ${
                  accountType === "live"
                    ? "bg-[#D4AF37] text-[#0A192F] font-bold shadow-md"
                    : "text-gray-400 hover:text-white"
                }`}
              >
                Real MT5
              </button>
              <button
                type="button"
                onClick={() => {
                  setAccountType("demo")
                  setServer("XM-Global-Demo")
                }}
                className={`py-1.5 px-2 rounded-lg transition-all text-center ${
                  accountType === "demo"
                    ? "bg-[#D4AF37] text-[#0A192F] font-bold shadow-md"
                    : "text-gray-400 hover:text-white"
                }`}
              >
                Demo Validada
              </button>
              <button
                type="button"
                onClick={() => {
                  setAccountType("guest")
                  setServer("Aurum-Simulation-Bridge")
                }}
                className={`py-1.5 px-2 rounded-lg transition-all text-center ${
                  accountType === "guest"
                    ? "bg-[#D4AF37] text-[#0A192F] font-bold shadow-md"
                    : "text-gray-400 hover:text-white"
                }`}
              >
                Invitado
              </button>
            </div>
          </CardHeader>

          <CardContent className="pt-6 space-y-4">
            {errorMsg && (
              <div className="p-3 bg-rose-950/80 border border-rose-500/50 text-rose-300 text-xs rounded-lg flex items-center gap-2">
                <AlertCircle className="h-4 w-4 shrink-0" />
                <span>{errorMsg}</span>
              </div>
            )}

            <form onSubmit={handleSubmit} className="space-y-4 text-xs">
              {/* Login / Usuario / Cuenta MT5 */}
              <div className="space-y-1.5">
                <label className="text-gray-300 font-medium flex items-center justify-between">
                  <span>ID de Usuario / Cuenta MT5</span>
                  <span className="text-[10px] text-[#D4AF37] font-mono">ID Requerido</span>
                </label>
                <div className="relative">
                  <User className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                  <input
                    type="text"
                    required
                    value={loginId}
                    onChange={e => setLoginId(e.target.value)}
                    className="w-full bg-[#0A192F] border border-gray-700 rounded-xl pl-9 pr-3 py-2.5 text-white placeholder-gray-500 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all font-mono text-xs"
                    placeholder="Ej: 86420193"
                  />
                </div>
              </div>

              {/* Contraseña */}
              <div className="space-y-1.5">
                <label className="text-gray-300 font-medium flex items-center justify-between">
                  <span>Contraseña del Operador</span>
                  <a href="#forgot" onClick={e => { e.preventDefault(); alert("Contacte al administrador de Aurum Capital para restablecer credenciales MT5."); }} className="text-[10px] text-gray-400 hover:text-[#D4AF37] transition-colors">
                    ¿Olvidaste tu contraseña?
                  </a>
                </label>
                <div className="relative">
                  <KeyRound className="absolute left-3 top-1/2 -translate-y-1/2 h-4 w-4 text-gray-400" />
                  <input
                    type={showPassword ? "text" : "password"}
                    required
                    value={password}
                    onChange={e => setPassword(e.target.value)}
                    className="w-full bg-[#0A192F] border border-gray-700 rounded-xl pl-9 pr-10 py-2.5 text-white placeholder-gray-500 outline-none focus:border-[#D4AF37] focus:ring-1 focus:ring-[#D4AF37] transition-all font-mono text-xs"
                    placeholder="••••••••••••"
                  />
                  <button
                    type="button"
                    onClick={() => setShowPassword(!showPassword)}
                    className="absolute right-3 top-1/2 -translate-y-1/2 text-gray-400 hover:text-white"
                  >
                    {showPassword ? <EyeOff className="h-4 w-4" /> : <Eye className="h-4 w-4" />}
                  </button>
                </div>
              </div>

              {/* Servidor MT5 */}
              <div className="space-y-1.5">
                <label className="text-gray-300 font-medium flex items-center gap-1">
                  <Server className="h-3.5 w-3.5 text-[#D4AF37]" />
                  <span>Servidor de Ejecución MT5</span>
                </label>
                <select
                  value={server}
                  onChange={e => setServer(e.target.value)}
                  className="w-full bg-[#0A192F] border border-gray-700 rounded-xl px-3 py-2.5 text-white outline-none focus:border-[#D4AF37] transition-all text-xs font-mono"
                >
                  <option value="XM-Global-Real-22">XM-Global-Real-22 (Servidor Principal)</option>
                  <option value="XM-Global-Real-18">XM-Global-Real-18 (Servidor Secundario)</option>
                  <option value="XM-Global-Demo">XM-Global-Demo (Pruebas Forward)</option>
                  <option value="Aurum-Simulation-Bridge">Aurum-Simulation-Bridge (Local Staging)</option>
                </select>
              </div>

              {/* Botón Principal de Iniciar Sesión */}
              <Button
                type="submit"
                disabled={isLoading}
                className="w-full h-11 bg-[#D4AF37] hover:bg-[#c29f2e] text-[#0A192F] font-extrabold text-xs tracking-wider uppercase rounded-xl transition-all shadow-lg hover:shadow-[#D4AF37]/20 flex items-center justify-center gap-2 mt-2"
              >
                {isLoading ? (
                  <>
                    <div className="h-4 w-4 border-2 border-[#0A192F] border-t-transparent rounded-full animate-spin" />
                    <span>Autenticando en MT5...</span>
                  </>
                ) : (
                  <>
                    <span>INGRESAR A LA ESTACIÓN</span>
                    <ArrowRight className="h-4 w-4" />
                  </>
                )}
              </Button>
            </form>

            {/* Separador */}
            <div className="relative py-2">
              <div className="absolute inset-0 flex items-center">
                <div className="w-full border-t border-gray-800" />
              </div>
              <div className="relative flex justify-center text-[10px]">
                <span className="bg-[#12233A] px-2 text-gray-500 font-semibold uppercase">O prueba la plataforma</span>
              </div>
            </div>

            {/* Botón de Acceso Rápido 1-Click Demo */}
            <Button
              type="button"
              variant="outline"
              onClick={handleQuickDemo}
              disabled={isLoading}
              className="w-full border-gray-700 hover:border-[#D4AF37]/50 text-gray-200 hover:text-white bg-[#0A192F]/60 text-xs font-semibold h-10 rounded-xl"
            >
              <Sparkles className="h-3.5 w-3.5 mr-2 text-[#D4AF37]" />
              Acceso Rápido Demo (1-Click)
            </Button>
          </CardContent>
        </Card>

        {/* Distintivos de Seguridad (Footer) */}
        <div className="flex items-center justify-between text-[11px] text-gray-400 px-2">
          <div className="flex items-center gap-1.5">
            <ShieldCheck className="h-4 w-4 text-emerald-400" />
            <span>Encriptación 256-bit SSL</span>
          </div>
          <div className="flex items-center gap-1.5">
            <Cpu className="h-4 w-4 text-[#D4AF37]" />
            <span>Aurum V15 Engine Active</span>
          </div>
        </div>
      </div>
    </div>
  )
}
