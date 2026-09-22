"use client"

import { useState } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Input } from "@/components/ui/input"
import { Label } from "@/components/ui/label"
import { Select, SelectContent, SelectItem, SelectTrigger, SelectValue } from "@/components/ui/select"
import { Calculator, ShieldAlert, CheckCircle2, TrendingUp } from "lucide-react"

export function RiskCalculator() {
  const [balance, setBalance] = useState<number>(1000)
  const [riskPercent, setRiskPercent] = useState<number>(1.0)
  const [asset, setAsset] = useState<string>("GOLDmicro")
  const [slPips, setSlPips] = useState<number>(25)
  const [riskReward, setRiskReward] = useState<number>(2.0)

  // Cálculos matemáticos basados en el Forex Trading Blueprint y Aurum V15
  const riskAmountUSD = (balance * (riskPercent / 100))
  
  // Pip value aproximado según activo (Forex estándar vs Micro vs Oro)
  let pipValuePerLot = 10.0 // EURUSD estándar ($10 / pip por 1.0 lote)
  if (asset === "GOLDmicro") {
    // En GOLDmicro de XM, contrato de 10 oz. 1 pip ($0.10 de precio) = $1.0 por lote estándar de micro
    pipValuePerLot = 1.0
  } else if (asset === "EURUSDmicro") {
    pipValuePerLot = 0.10 // 1 micro lote = $0.10 por pip
  } else if (asset === "XAUUSD") {
    pipValuePerLot = 10.0 // 100 oz estándar
  }

  // Lote sugerido = Riesgo $ / (SL Pips * Valor del Pip por Lote)
  const calculatedLot = slPips > 0 && pipValuePerLot > 0 ? (riskAmountUSD / (slPips * pipValuePerLot)) : 0.01
  const normalizedLot = Math.max(0.01, Math.min(5.0, Number(calculatedLot.toFixed(2))))

  const potentialProfitUSD = riskAmountUSD * riskReward
  const microLockProfit = riskAmountUSD * 0.5
  const phase1Profit = riskAmountUSD * 1.0 * 0.5 // 50% parcial en 1R

  // Matriz de Seguridad del Forex Trading Blueprint (pág. 11)
  let blueprintMaxLot = "0.01 a 0.02"
  if (balance >= 10000) blueprintMaxLot = "0.90 a 1.00"
  else if (balance >= 5000) blueprintMaxLot = "0.50 a 0.55"
  else if (balance >= 2000) blueprintMaxLot = "0.15 a 0.20"
  else if (balance >= 1000) blueprintMaxLot = "0.08 a 0.10"
  else if (balance >= 500) blueprintMaxLot = "0.04 a 0.06"
  else if (balance >= 300) blueprintMaxLot = "0.02 a 0.04"

  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 lg:grid-cols-12 gap-6">
        {/* Formulario de Entrada */}
        <Card className="lg:col-span-6 bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader>
            <div className="flex items-center gap-2">
              <Calculator className="h-5 w-5 text-[#D4AF37]" />
              <CardTitle className="text-base text-white">Calculadora Institucional de Lote & Risco</CardTitle>
            </div>
            <CardDescription className="text-xs text-gray-400">
              Ajustada a la matriz del Forex Trading Blueprint y gestión de Fases R Aurum V15
            </CardDescription>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="text-xs text-gray-300">Balance de la Cuenta ($ USD)</Label>
                <Input
                  type="number"
                  value={balance}
                  onChange={(e) => setBalance(Number(e.target.value))}
                  className="bg-[#0A192F] border-gray-700 text-white text-sm"
                />
              </div>

              <div className="space-y-2">
                <Label className="text-xs text-gray-300">Riesgo por Trade (%)</Label>
                <div className="flex items-center gap-2">
                  <Input
                    type="number"
                    step="0.1"
                    max="3.0"
                    value={riskPercent}
                    onChange={(e) => setRiskPercent(Number(e.target.value))}
                    className="bg-[#0A192F] border-gray-700 text-white text-sm"
                  />
                  <Badge variant="outline" className="text-xs text-[#D4AF37] border-gray-700 shrink-0">
                    Max 1%
                  </Badge>
                </div>
              </div>
            </div>

            <div className="grid grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label className="text-xs text-gray-300">Activo Financiero</Label>
                <Select value={asset} onValueChange={setAsset}>
                  <SelectTrigger className="bg-[#0A192F] border-gray-700 text-white text-sm">
                    <SelectValue />
                  </SelectTrigger>
                  <SelectContent className="bg-[#12233A] border-gray-700 text-white">
                    <SelectItem value="GOLDmicro">GOLDmicro (Oro Micro 10oz)</SelectItem>
                    <SelectItem value="XAUUSD">XAUUSD (Oro Estándar 100oz)</SelectItem>
                    <SelectItem value="EURUSDmicro">EURUSDmicro (Micro Forex)</SelectItem>
                    <SelectItem value="EURUSD">EURUSD (Forex Estándar)</SelectItem>
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label className="text-xs text-gray-300">Distancia al Stop Loss (Pips)</Label>
                <Input
                  type="number"
                  value={slPips}
                  onChange={(e) => setSlPips(Number(e.target.value))}
                  className="bg-[#0A192F] border-gray-700 text-white text-sm"
                />
              </div>
            </div>

            <div className="space-y-2">
              <Label className="text-xs text-gray-300">Ratio Riesgo / Beneficio Objetivo (R:R)</Label>
              <div className="flex gap-2">
                {[1.5, 2.0, 2.5, 3.0].map((rr) => (
                  <Button
                    key={rr}
                    type="button"
                    variant={riskReward === rr ? "default" : "outline"}
                    onClick={() => setRiskReward(rr)}
                    className={`flex-1 text-xs py-1 h-8 ${
                      riskReward === rr
                        ? "bg-[#D4AF37] text-[#0A192F] font-bold"
                        : "border-gray-700 text-gray-300 hover:bg-[#1A2E46]"
                    }`}
                  >
                    1:{rr}
                  </Button>
                ))}
              </div>
            </div>
          </CardContent>
        </Card>

        {/* Resultados del Cálculo & Plan de Fases */}
        <Card className="lg:col-span-6 bg-[#12233A] border-gray-700 shadow-xl">
          <CardHeader>
            <div className="flex items-center justify-between">
              <CardTitle className="text-base text-white">Resultados de la Operación</CardTitle>
              <Badge className="bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">
                Lote Calculado: {normalizedLot}
              </Badge>
            </div>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid grid-cols-2 gap-3">
              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-gray-400 block mb-1">Riesgo Monetario Máximo:</span>
                <span className="text-base font-bold text-rose-400">-${riskAmountUSD.toFixed(2)} USD</span>
                <span className="text-[10px] text-gray-500 block">({riskPercent}% de tu patrimonio)</span>
              </div>

              <div className="p-3 rounded-lg bg-[#0A192F] border border-gray-800">
                <span className="text-xs text-gray-400 block mb-1">Beneficio Proyectado (TP):</span>
                <span className="text-base font-bold text-emerald-400">+${potentialProfitUSD.toFixed(2)} USD</span>
                <span className="text-[10px] text-gray-500 block">Ratio 1:{riskReward}</span>
              </div>
            </div>

            {/* Fases R Aurum V15 */}
            <div className="space-y-2 pt-2 border-t border-gray-800">
              <span className="text-xs font-semibold text-[#D4AF37] block">Plan de Ejecución por Fases Aurum V15:</span>
              
              <div className="flex items-center justify-between p-2 rounded bg-[#0A192F] text-xs">
                <span className="text-gray-300">Fase 1 (0.5R Micro-Lock):</span>
                <span className="text-emerald-400 font-semibold">+${microLockProfit.toFixed(2)} (SL a comisiones)</span>
              </div>

              <div className="flex items-center justify-between p-2 rounded bg-[#0A192F] text-xs">
                <span className="text-gray-300">Fase 2 (1.0R Break-Even + Parcial 50%):</span>
                <span className="text-[#D4AF37] font-semibold">+${phase1Profit.toFixed(2)} asegurado al bolsillo</span>
              </div>

              <div className="flex items-center justify-between p-2 rounded bg-[#0A192F] text-xs">
                <span className="text-gray-300">Fase 3 (Take Profit Final):</span>
                <span className="text-emerald-400 font-semibold">+${potentialProfitUSD.toFixed(2)} total</span>
              </div>
            </div>

            {/* Alerta de Matriz Blueprint */}
            <div className="p-3 rounded-lg bg-blue-950/20 border border-blue-800/40 flex items-start gap-2 text-xs text-blue-200">
              <CheckCircle2 className="h-4 w-4 text-[#D4AF37] shrink-0 mt-0.5" />
              <div>
                <span className="font-semibold text-white">Matriz Blueprint para ${balance} USD:</span>
                <p className="text-gray-300 mt-0.5">
                  El libro sugiere un lotaje máximo seguro de <strong className="text-[#D4AF37]">{blueprintMaxLot}</strong>.
                  Nunca excedas esta cota para proteger tu cuenta de drawdowns severos.
                </p>
              </div>
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  )
}
