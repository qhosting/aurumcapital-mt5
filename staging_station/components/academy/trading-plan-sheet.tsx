"use client"

import React, { useState, useEffect, useRef } from "react"
import { Card, CardContent, CardHeader, CardTitle, CardDescription } from "@/components/ui/card"
import { Badge } from "@/components/ui/badge"
import { Button } from "@/components/ui/button"
import { Checkbox } from "@/components/ui/checkbox"
import {
  Target,
  Shield,
  Coins,
  FileCheck,
  PiggyBank,
  TrendingUp,
  BrainCircuit,
  ClipboardList,
  Trophy,
  PenTool,
  Printer,
  RotateCcw,
  Sparkles,
  Save,
  CheckCircle2,
  AlertOctagon,
  Plane,
  Users,
  Building2,
  DollarSign
} from "lucide-react"

// Estructura de datos para el Plan de Trading
export interface TradingPlanData {
  // 1. Objetivo General
  yearsTarget: string
  financialGoalUSD: string
  financialGoalTerm: string
  generalVision: string

  // 2. Mi Estrategia
  initialMiniCapitalUSD: string
  brokerName: string
  accountTypes: {
    mini: boolean
    standard: boolean
    ecn: boolean
    otro: boolean
    otroText: string
  }
  strategyNotes: string

  // 3. Selección de Pares
  pairs: string[]
  criteria: {
    technicalAnalysis: boolean
    timeframes: boolean // 5M, 15M, 30M
    trendCheck: boolean // 1H y 4H
    priceActionOpwens: boolean // Acción del precio, velas, soportes, resistencias, EMAs
  }

  // 4. Reglas de Trading
  rules: string[]

  // 5. Gestión de Dinero
  maxRiskPerTradePercent: string
  maxRiskPerTradeUSD: string
  maxDailyTrades: string
  slPips: string
  slRiskUSD: string
  dailyGoalPips: string
  dailyGoalPercent: string
  weeklyGoalPips: string
  weeklyGoalPercent: string
  monthlyGoalPips: string
  monthlyGoalPercent: string
  maxDailyDrawdownPercent: string
  maxWeeklyDrawdownPercent: string

  // 6. Objetivos de Trading
  targetReturnPercent: string
  capitalInitialUSD: string
  monthlyTargetUSD: string
  monthlyTargetPips: string
  annualTargetUSD: string
  growthPlanText: string

  // 7. Gestión Emocional & Mentalidad
  emotionalCommitments: {
    keepCalm: boolean
    followPlan: boolean
    learnFromTrades: boolean
    bePatient: boolean
    disciplineIsFreedom: boolean
  }

  // 8. Seguimiento y Revisión
  dailyReview: string
  weeklyReview: string
  monthlyReview: string

  // Compromiso y Firma
  signatureName: string
  signatureDataUrl: string
  signatureDate: string

  // Checklist Diario
  dailyChecklist: {
    definedRisk: boolean
    hasStopLoss: boolean
    setupValid: boolean
    emotionallyStable: boolean
    acceptResult: boolean
  }
}

// Valores por defecto institucionales Aurum V15
export const DEFAULT_AURUM_V15_PLAN: TradingPlanData = {
  yearsTarget: "3",
  financialGoalUSD: "50,000",
  financialGoalTerm: "3 años",
  generalVision: "Generar consistencia y crecimiento sostenido a través de una gestión de riesgo sólida (R:R ≥ 1:1.8) y mejora continua basada en el algoritmo Aurum V15 y la metodología SMC.",

  initialMiniCapitalUSD: "1,000",
  brokerName: "XM / Broker Regulado MT5",
  accountTypes: {
    mini: true,
    standard: false,
    ecn: true,
    otro: false,
    otroText: ""
  },
  strategyNotes: "Operar con enfoque, paciencia y sin emociones. Seguir la confirmación SMC + Velas Opwens en M15.",

  pairs: [
    "USDJPYmicro",
    "EURUSD",
    "GOLDmicro",
    "GBPUSD",
    "EURUSDmicro",
    "US30",
    "",
    "",
    "",
    "",
    "",
    ""
  ],
  criteria: {
    technicalAnalysis: true,
    timeframes: true,
    trendCheck: true,
    priceActionOpwens: true
  },

  rules: [
    "Cada operación que abra tendrá un Stop Loss técnico inviolable.",
    "Siempre fijaré el Stop Loss antes de presionar el botón de compra o venta.",
    "Nunca moveré el Stop Loss en contra ni promediaré posiciones en pérdida.",
    "La operación se dimensiona adecuadamente (ej: 0.25% - 1.0% de riesgo por trade).",
    "Solo operaré setups calificados que cumplan con la confluencia de la estrategia Aurum.",
    "No operaré por emociones, venganza o impulsos.",
    "No sobreoperaré. Máximo 3 trades al día. Menos es más."
  ],

  maxRiskPerTradePercent: "0.25%",
  maxRiskPerTradeUSD: "2.50",
  maxDailyTrades: "3",
  slPips: "15 - 25",
  slRiskUSD: "2.50",
  dailyGoalPips: "20",
  dailyGoalPercent: "0.5%",
  weeklyGoalPips: "60",
  weeklyGoalPercent: "1.5%",
  monthlyGoalPips: "200",
  monthlyGoalPercent: "5.0%",
  maxDailyDrawdownPercent: "1.0%",
  maxWeeklyDrawdownPercent: "3.0%",

  targetReturnPercent: "5% a 8%",
  capitalInitialUSD: "1,000",
  monthlyTargetUSD: "50.00",
  monthlyTargetPips: "200",
  annualTargetUSD: "600.00",
  growthPlanText: "Espero lograr un retorno constante en la primera etapa. Con disciplina, constancia y reinversión del capital, aumentaré progresivamente el tamaño de la cuenta.",

  emotionalCommitments: {
    keepCalm: true,
    followPlan: true,
    learnFromTrades: true,
    bePatient: true,
    disciplineIsFreedom: true
  },

  dailyReview: "Auditoría de ejecuciones al cierre de sesión NY (11:30 AM CDMX). Captura de pantalla del gráfico.",
  weeklyReview: "Análisis del Win Rate y Profit Factor el fin de semana. Verificación de regla anti-racha.",
  monthlyReview: "Evaluación del retorno mensual neto, Max Drawdown alcanzado y concilio de curva de capital.",

  signatureName: "Operador Institucional Aurum",
  signatureDataUrl: "",
  signatureDate: new Date().toISOString().split("T")[0],

  dailyChecklist: {
    definedRisk: false,
    hasStopLoss: false,
    setupValid: false,
    emotionallyStable: false,
    acceptResult: false
  }
}

const STORAGE_KEY = "aurum_trading_plan_v15_data"

export function TradingPlanSheet() {
  const [plan, setPlan] = useState<TradingPlanData>(DEFAULT_AURUM_V15_PLAN)
  const [saveNotification, setSaveNotification] = useState<string | null>(null)
  const [isDrawing, setIsDrawing] = useState(false)
  
  const canvasRef = useRef<HTMLCanvasElement | null>(null)

  // Cargar datos al montar
  useEffect(() => {
    try {
      const saved = localStorage.getItem(STORAGE_KEY)
      if (saved) {
        setPlan(JSON.parse(saved))
      }
    } catch (e) {
      console.error("Error al cargar plan de trading:", e)
    }
  }, [])

  // Inicializar canvas si existe firma guardada
  useEffect(() => {
    if (canvasRef.current && plan.signatureDataUrl) {
      const canvas = canvasRef.current
      const ctx = canvas.getContext("2d")
      if (ctx) {
        const img = new Image()
        img.onload = () => {
          ctx.clearRect(0, 0, canvas.width, canvas.height)
          ctx.drawImage(img, 0, 0)
        }
        img.src = plan.signatureDataUrl
      }
    }
  }, [plan.signatureDataUrl])

  // Guardar en localStorage
  const handleSave = () => {
    try {
      localStorage.setItem(STORAGE_KEY, JSON.stringify(plan))
      setSaveNotification("¡Plan de Trading guardado correctamente!")
      setTimeout(() => setSaveNotification(null), 3000)
    } catch (e) {
      console.error("Error guardando plan:", e)
    }
  }

  // Cargar Preset Aurum V15
  const handleLoadPreset = () => {
    setPlan(DEFAULT_AURUM_V15_PLAN)
    setSaveNotification("Se han cargado los parámetros oficiales de Aurum V15")
    setTimeout(() => setSaveNotification(null), 3000)
  }

  // Imprimir / Exportar a PDF
  const handlePrint = () => {
    window.print()
  }

  // Limpiar campos
  const handleReset = () => {
    const emptyPlan: TradingPlanData = {
      yearsTarget: "",
      financialGoalUSD: "",
      financialGoalTerm: "",
      generalVision: "",
      initialMiniCapitalUSD: "",
      brokerName: "",
      accountTypes: { mini: false, standard: false, ecn: false, otro: false, otroText: "" },
      strategyNotes: "",
      pairs: Array(12).fill(""),
      criteria: { technicalAnalysis: false, timeframes: false, trendCheck: false, priceActionOpwens: false },
      rules: Array(7).fill(""),
      maxRiskPerTradePercent: "",
      maxRiskPerTradeUSD: "",
      maxDailyTrades: "",
      slPips: "",
      slRiskUSD: "",
      dailyGoalPips: "",
      dailyGoalPercent: "",
      weeklyGoalPips: "",
      weeklyGoalPercent: "",
      monthlyGoalPips: "",
      monthlyGoalPercent: "",
      maxDailyDrawdownPercent: "",
      maxWeeklyDrawdownPercent: "",
      targetReturnPercent: "",
      capitalInitialUSD: "",
      monthlyTargetUSD: "",
      monthlyTargetPips: "",
      annualTargetUSD: "",
      growthPlanText: "",
      emotionalCommitments: { keepCalm: false, followPlan: false, learnFromTrades: false, bePatient: false, disciplineIsFreedom: false },
      dailyReview: "",
      weeklyReview: "",
      monthlyReview: "",
      signatureName: "",
      signatureDataUrl: "",
      signatureDate: new Date().toISOString().split("T")[0],
      dailyChecklist: { definedRisk: false, hasStopLoss: false, setupValid: false, emotionallyStable: false, acceptResult: false }
    }
    setPlan(emptyPlan)
    if (canvasRef.current) {
      const ctx = canvasRef.current.getContext("2d")
      if (ctx) ctx.clearRect(0, 0, canvasRef.current.width, canvasRef.current.height)
    }
  }

  // Lógica del Canvas de Firma
  const startDrawing = (e: React.MouseEvent<HTMLCanvasElement> | React.TouchEvent<HTMLCanvasElement>) => {
    setIsDrawing(true)
    draw(e)
  }

  const stopDrawing = () => {
    if (!isDrawing) return
    setIsDrawing(false)
    if (canvasRef.current) {
      const dataUrl = canvasRef.current.toDataURL()
      setPlan(prev => ({ ...prev, signatureDataUrl: dataUrl }))
    }
  }

  const draw = (e: React.MouseEvent<HTMLCanvasElement> | React.TouchEvent<HTMLCanvasElement>) => {
    if (!isDrawing || !canvasRef.current) return
    const canvas = canvasRef.current
    const ctx = canvas.getContext("2d")
    if (!ctx) return

    const rect = canvas.getBoundingClientRect()
    let clientX = 0
    let clientY = 0

    if ("touches" in e) {
      clientX = e.touches[0].clientX
      clientY = e.touches[0].clientY
    } else {
      clientX = e.clientX
      clientY = e.clientY
    }

    const x = clientX - rect.left
    const y = clientY - rect.top

    ctx.lineWidth = 2
    ctx.lineCap = "round"
    ctx.strokeStyle = "#D4AF37"

    ctx.lineTo(x, y)
    ctx.stroke()
    ctx.beginPath()
    ctx.moveTo(x, y)
  }

  const clearSignature = () => {
    if (canvasRef.current) {
      const ctx = canvasRef.current.getContext("2d")
      if (ctx) {
        ctx.clearRect(0, 0, canvasRef.current.width, canvasRef.current.height)
        ctx.beginPath()
      }
    }
    setPlan(prev => ({ ...prev, signatureDataUrl: "" }))
  }

  const updatePair = (index: number, val: string) => {
    const newPairs = [...plan.pairs]
    newPairs[index] = val
    setPlan(prev => ({ ...prev, pairs: newPairs }))
  }

  const updateRule = (index: number, val: string) => {
    const newRules = [...plan.rules]
    newRules[index] = val
    setPlan(prev => ({ ...prev, rules: newRules }))
  }

  return (
    <div className="space-y-6 print:space-y-3 print:p-0 print:bg-white text-gray-100 font-sans">
      {/* Botones de Acción (No imprimibles) */}
      <div className="flex flex-wrap items-center justify-between gap-3 p-4 bg-[#12233A] border border-gray-700 rounded-xl shadow-lg print:hidden">
        <div className="flex items-center gap-2">
          <ClipboardList className="h-6 w-6 text-[#D4AF37]" />
          <div>
            <h2 className="text-base font-bold text-white leading-tight">Plan de Trading Interactivo</h2>
            <p className="text-xs text-gray-400">Diseñado según la metodología visual oficial Aurum Invest Station</p>
          </div>
        </div>

        <div className="flex flex-wrap items-center gap-2">
          <Button
            size="sm"
            onClick={handleLoadPreset}
            className="bg-[#D4AF37]/20 hover:bg-[#D4AF37]/30 text-[#D4AF37] border border-[#D4AF37]/40 text-xs font-semibold"
          >
            <Sparkles className="h-3.5 w-3.5 mr-1.5" />
            Cargar Criterios Aurum V15
          </Button>

          <Button
            size="sm"
            onClick={handleSave}
            className="bg-emerald-600 hover:bg-emerald-500 text-white text-xs font-semibold"
          >
            <Save className="h-3.5 w-3.5 mr-1.5" />
            Guardar Plan
          </Button>

          <Button
            size="sm"
            onClick={handlePrint}
            variant="outline"
            className="border-gray-600 text-gray-300 hover:text-white text-xs"
          >
            <Printer className="h-3.5 w-3.5 mr-1.5" />
            Imprimir / Exportar PDF
          </Button>

          <Button
            size="sm"
            onClick={handleReset}
            variant="ghost"
            className="text-gray-400 hover:text-rose-400 text-xs"
          >
            <RotateCcw className="h-3.5 w-3.5 mr-1.5" />
            Limpiar
          </Button>
        </div>
      </div>

      {saveNotification && (
        <div className="p-3 bg-emerald-950/80 border border-emerald-500/50 text-emerald-300 text-xs font-semibold rounded-lg flex items-center gap-2 print:hidden animate-fade-in">
          <CheckCircle2 className="h-4 w-4 shrink-0" />
          <span>{saveNotification}</span>
        </div>
      )}

      {/* ============================================================ */}
      {/* POSTER PRINCIPAL DE PLAN DE TRADING */}
      {/* ============================================================ */}
      <div className="p-6 md:p-8 bg-[#0A192F] border-2 border-[#D4AF37]/40 rounded-2xl shadow-2xl space-y-6 print:border-none print:shadow-none print:p-2 print:text-black">
        
        {/* ENCABEZADO DEL AFICHE */}
        <div className="text-center space-y-2 border-b border-[#D4AF37]/30 pb-5">
          <div className="flex items-center justify-center gap-3">
            <Trophy className="h-8 w-8 text-[#D4AF37]" />
            <h1 className="text-3xl md:text-4xl font-extrabold tracking-wider text-[#D4AF37] uppercase print:text-black">
              MI PLAN DE TRADING
            </h1>
            <Trophy className="h-8 w-8 text-[#D4AF37]" />
          </div>
          <p className="text-xs text-gray-300 max-w-xl mx-auto tracking-wide print:text-gray-700">
            Aurum Invest Station • Hoja de Ruta Operativa, Disciplina Institucional y Gestión Integral de Riesgo
          </p>
        </div>

        {/* GRILLA PRINCIPAL DE 8 SECCIONES */}
        <div className="grid grid-cols-1 md:grid-cols-2 gap-6 print:gap-4">
          
          {/* ============================================================ */}
          {/* 1. MI OBJETIVO GENERAL */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center gap-2 border-b border-gray-700/60 pb-2">
              <Target className="h-5 w-5 text-[#D4AF37]" />
              <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                1. MI OBJETIVO GENERAL
              </h3>
            </div>

            <p className="text-xs text-gray-300 leading-relaxed print:text-black">
              En los próximos{" "}
              <input
                type="text"
                value={plan.yearsTarget}
                onChange={e => setPlan({ ...plan, yearsTarget: e.target.value })}
                className="w-12 px-1 text-center bg-[#0A192F] border-b border-[#D4AF37] text-[#D4AF37] font-bold outline-none print:bg-white print:text-black"
                placeholder="___"
              />{" "}
              años, planeo establecer un negocio rentable en el trading. Mi objetivo es generar consistencia y crecimiento a través de una gestión de riesgo sólida y mejora continua.
            </p>

            <div className="grid grid-cols-2 gap-2 pt-1">
              <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 space-y-1 print:bg-gray-100 print:border-gray-300">
                <span className="text-[10px] text-gray-400 font-semibold block uppercase">MI META FINANCIERA:</span>
                <div className="flex items-center gap-1 text-xs font-bold text-white print:text-black">
                  <span className="text-[#D4AF37]">USD$</span>
                  <input
                    type="text"
                    value={plan.financialGoalUSD}
                    onChange={e => setPlan({ ...plan, financialGoalUSD: e.target.value })}
                    className="w-full bg-transparent border-b border-gray-700 text-white font-mono outline-none print:text-black"
                    placeholder="Monto USD$"
                  />
                </div>
              </div>

              <div className="p-2.5 rounded bg-[#0A192F] border border-gray-800 space-y-1 print:bg-gray-100 print:border-gray-300">
                <span className="text-[10px] text-gray-400 font-semibold block uppercase">PLAZO:</span>
                <input
                  type="text"
                  value={plan.financialGoalTerm}
                  onChange={e => setPlan({ ...plan, financialGoalTerm: e.target.value })}
                  className="w-full bg-transparent border-b border-gray-700 text-xs text-white font-semibold outline-none print:text-black"
                  placeholder="Ej: 5 años"
                />
              </div>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 2. MI ESTRATEGIA */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center gap-2 border-b border-gray-700/60 pb-2">
              <Shield className="h-5 w-5 text-[#D4AF37]" />
              <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                2. MI ESTRATEGIA
              </h3>
            </div>

            <p className="text-xs text-gray-300 leading-relaxed print:text-black">
              Comenzaré con una cuenta mini de{" "}
              <span className="text-[#D4AF37] font-bold">USD$</span>{" "}
              <input
                type="text"
                value={plan.initialMiniCapitalUSD}
                onChange={e => setPlan({ ...plan, initialMiniCapitalUSD: e.target.value })}
                className="w-20 px-1 bg-[#0A192F] border-b border-[#D4AF37] text-white font-mono text-xs outline-none print:bg-white print:text-black"
                placeholder="_____"
              />
              . Una vez que supere mis objetivos en la primera etapa, consideraré aumentar los fondos según mi gestión de riesgo y consistencia. Trabajaré con enfoque, paciencia y sin emociones.
            </p>

            <div className="space-y-2 pt-1 text-xs">
              <div className="flex items-center gap-2">
                <span className="font-bold text-gray-300 uppercase text-[11px]">BROKER:</span>
                <input
                  type="text"
                  value={plan.brokerName}
                  onChange={e => setPlan({ ...plan, brokerName: e.target.value })}
                  className="flex-1 bg-[#0A192F] border-b border-gray-700 px-2 py-0.5 text-white outline-none print:bg-white print:text-black"
                  placeholder="Nombre de broker"
                />
              </div>

              <div className="flex flex-wrap items-center gap-3 pt-1">
                <span className="font-bold text-gray-300 uppercase text-[11px]">TIPO DE CUENTA:</span>
                <label className="flex items-center gap-1 cursor-pointer">
                  <Checkbox
                    checked={plan.accountTypes.mini}
                    onCheckedChange={c => setPlan({ ...plan, accountTypes: { ...plan.accountTypes, mini: !!c } })}
                  />
                  <span>Mini</span>
                </label>
                <label className="flex items-center gap-1 cursor-pointer">
                  <Checkbox
                    checked={plan.accountTypes.standard}
                    onCheckedChange={c => setPlan({ ...plan, accountTypes: { ...plan.accountTypes, standard: !!c } })}
                  />
                  <span>Standard</span>
                </label>
                <label className="flex items-center gap-1 cursor-pointer">
                  <Checkbox
                    checked={plan.accountTypes.ecn}
                    onCheckedChange={c => setPlan({ ...plan, accountTypes: { ...plan.accountTypes, ecn: !!c } })}
                  />
                  <span>ECN</span>
                </label>
                <label className="flex items-center gap-1 cursor-pointer">
                  <Checkbox
                    checked={plan.accountTypes.otro}
                    onCheckedChange={c => setPlan({ ...plan, accountTypes: { ...plan.accountTypes, otro: !!c } })}
                  />
                  <span>Otro</span>
                </label>
              </div>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 3. SELECCIÓN DE PARES DE DIVISAS */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center justify-between border-b border-gray-700/60 pb-2">
              <div className="flex items-center gap-2">
                <Coins className="h-5 w-5 text-[#D4AF37]" />
                <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                  3. SELECCIÓN DE PARES DE DIVISAS
                </h3>
              </div>
              <Badge className="bg-[#D4AF37]/20 text-[#D4AF37] text-[10px]">Activos Institucionales</Badge>
            </div>

            <p className="text-[11px] text-gray-300 print:text-black">
              Haré trading en una cuenta mini usando los siguientes pares de divisas:
            </p>

            <div className="grid grid-cols-2 gap-2 text-xs">
              {plan.pairs.map((pair, idx) => (
                <div key={idx} className="flex items-center gap-1 bg-[#0A192F] border border-gray-800 px-2 py-1 rounded print:bg-gray-50 print:border-gray-300">
                  <span className="text-[10px] text-[#D4AF37] font-bold w-5">{idx + 1}.</span>
                  <input
                    type="text"
                    value={pair}
                    onChange={e => updatePair(idx, e.target.value)}
                    className="w-full bg-transparent text-white font-mono outline-none print:text-black"
                    placeholder="Símbolo"
                  />
                </div>
              ))}
            </div>

            {/* Criterios de Selección */}
            <div className="p-3 rounded-lg bg-[#0A192F] border border-[#D4AF37]/30 space-y-2 mt-2 print:bg-gray-100">
              <span className="text-[11px] font-bold text-[#D4AF37] uppercase block">CRITERIOS DE SELECCIÓN:</span>
              <div className="space-y-1.5 text-xs text-gray-300 print:text-black">
                <label className="flex items-center gap-2 cursor-pointer">
                  <Checkbox
                    checked={plan.criteria.technicalAnalysis}
                    onCheckedChange={c => setPlan({ ...plan, criteria: { ...plan.criteria, technicalAnalysis: !!c } })}
                  />
                  <span>Usaré análisis técnico para seleccionar mis operaciones.</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <Checkbox
                    checked={plan.criteria.timeframes}
                    onCheckedChange={c => setPlan({ ...plan, criteria: { ...plan.criteria, timeframes: !!c } })}
                  />
                  <span>Marcos de tiempo principales: 5M, 15M, 30M.</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <Checkbox
                    checked={plan.criteria.trendCheck}
                    onCheckedChange={c => setPlan({ ...plan, criteria: { ...plan.criteria, trendCheck: !!c } })}
                  />
                  <span>Revisaré tendencia en 1H y 4H.</span>
                </label>
                <label className="flex items-center gap-2 cursor-pointer">
                  <Checkbox
                    checked={plan.criteria.priceActionOpwens}
                    onCheckedChange={c => setPlan({ ...plan, criteria: { ...plan.criteria, priceActionOpwens: !!c } })}
                  />
                  <span>Métodos: Acción del precio, velas, soportes, resistencias y medias móviles simples.</span>
                </label>
              </div>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 4. REGLAS DE TRADING */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center justify-between border-b border-gray-700/60 pb-2">
              <div className="flex items-center gap-2">
                <FileCheck className="h-5 w-5 text-[#D4AF37]" />
                <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                  4. REGLAS DE TRADING
                </h3>
              </div>
              <Badge className="bg-rose-500/20 text-rose-300 text-[10px]">Inviolables</Badge>
            </div>

            <p className="text-[11px] text-gray-300 print:text-black">Seguiré estas reglas en cada operación:</p>

            <div className="space-y-2 text-xs">
              {plan.rules.map((rule, idx) => (
                <div key={idx} className="flex items-start gap-2 bg-[#0A192F] border border-gray-800 p-2 rounded print:bg-gray-50 print:border-gray-300">
                  <span className="bg-[#D4AF37] text-[#0A192F] font-extrabold text-[10px] h-4 w-4 rounded-full flex items-center justify-center shrink-0 mt-0.5">
                    {idx + 1}
                  </span>
                  <input
                    type="text"
                    value={rule}
                    onChange={e => updateRule(idx, e.target.value)}
                    className="w-full bg-transparent text-gray-200 outline-none print:text-black"
                  />
                </div>
              ))}
            </div>
          </div>

          {/* ============================================================ */}
          {/* 5. GESTIÓN DE DINERO */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center justify-between border-b border-gray-700/60 pb-2">
              <div className="flex items-center gap-2">
                <PiggyBank className="h-5 w-5 text-[#D4AF37]" />
                <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                  5. GESTIÓN DE DINERO
                </h3>
              </div>
              <Badge className="bg-emerald-500/20 text-emerald-300 text-[10px]">Protección Capital</Badge>
            </div>

            <div className="space-y-2 text-xs text-gray-300 print:text-black">
              <div className="flex items-center gap-1">
                <span className="font-bold text-[#D4AF37] w-4">①</span>
                <span>Riesgo máximo por operación:</span>
                <input
                  type="text"
                  value={plan.maxRiskPerTradePercent}
                  onChange={e => setPlan({ ...plan, maxRiskPerTradePercent: e.target.value })}
                  className="w-16 px-1 bg-[#0A192F] border-b border-gray-700 text-center font-bold text-white outline-none print:bg-white print:text-black"
                />
                <span>del capital = USD$</span>
                <input
                  type="text"
                  value={plan.maxRiskPerTradeUSD}
                  onChange={e => setPlan({ ...plan, maxRiskPerTradeUSD: e.target.value })}
                  className="w-16 px-1 bg-[#0A192F] border-b border-gray-700 text-center font-mono text-white outline-none print:bg-white print:text-black"
                />
              </div>

              <div className="flex items-center gap-1">
                <span className="font-bold text-[#D4AF37] w-4">②</span>
                <span>Máximo de operaciones para abrirse al día:</span>
                <input
                  type="text"
                  value={plan.maxDailyTrades}
                  onChange={e => setPlan({ ...plan, maxDailyTrades: e.target.value })}
                  className="w-12 px-1 bg-[#0A192F] border-b border-gray-700 text-center font-bold text-white outline-none print:bg-white print:text-black"
                />
              </div>

              <div className="flex items-center gap-1">
                <span className="font-bold text-[#D4AF37] w-4">③</span>
                <span>Si stop loss:</span>
                <input
                  type="text"
                  value={plan.slPips}
                  onChange={e => setPlan({ ...plan, slPips: e.target.value })}
                  className="w-14 px-1 bg-[#0A192F] border-b border-gray-700 text-center text-white outline-none print:bg-white print:text-black"
                />
                <span>pips, el riesgo por operación será: USD$</span>
                <input
                  type="text"
                  value={plan.slRiskUSD}
                  onChange={e => setPlan({ ...plan, slRiskUSD: e.target.value })}
                  className="w-16 px-1 bg-[#0A192F] border-b border-gray-700 text-center font-mono text-white outline-none print:bg-white print:text-black"
                />
              </div>

              <div className="grid grid-cols-3 gap-2 pt-1 text-[11px]">
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                  <span className="text-[10px] text-gray-400 block font-semibold">④ Meta diaria:</span>
                  <input
                    type="text"
                    value={`${plan.dailyGoalPips} pips / ${plan.dailyGoalPercent}`}
                    onChange={e => {
                      const parts = e.target.value.split("/")
                      setPlan({ ...plan, dailyGoalPips: parts[0] || "", dailyGoalPercent: parts[1] || "" })
                    }}
                    className="w-full bg-transparent text-white font-mono text-xs outline-none print:text-black"
                  />
                </div>
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                  <span className="text-[10px] text-gray-400 block font-semibold">⑤ Meta semanal:</span>
                  <input
                    type="text"
                    value={`${plan.weeklyGoalPips} pips / ${plan.weeklyGoalPercent}`}
                    onChange={e => {
                      const parts = e.target.value.split("/")
                      setPlan({ ...plan, weeklyGoalPips: parts[0] || "", weeklyGoalPercent: parts[1] || "" })
                    }}
                    className="w-full bg-transparent text-white font-mono text-xs outline-none print:text-black"
                  />
                </div>
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 space-y-1">
                  <span className="text-[10px] text-gray-400 block font-semibold">⑥ Meta mensual:</span>
                  <input
                    type="text"
                    value={`${plan.monthlyGoalPips} pips / ${plan.monthlyGoalPercent}`}
                    onChange={e => {
                      const parts = e.target.value.split("/")
                      setPlan({ ...plan, monthlyGoalPips: parts[0] || "", monthlyGoalPercent: parts[1] || "" })
                    }}
                    className="w-full bg-transparent text-white font-mono text-xs outline-none print:text-black"
                  />
                </div>
              </div>

              <div className="flex items-center justify-between pt-1 text-[11px]">
                <div>
                  <span className="font-bold text-[#D4AF37]">⑦</span> Máx. pérdida diaria:{" "}
                  <input
                    type="text"
                    value={plan.maxDailyDrawdownPercent}
                    onChange={e => setPlan({ ...plan, maxDailyDrawdownPercent: e.target.value })}
                    className="w-14 px-1 bg-[#0A192F] border-b border-rose-500 text-rose-300 font-bold outline-none print:bg-white print:text-black"
                  />
                </div>
                <div>
                  <span className="font-bold text-[#D4AF37]">⑧</span> Máx. pérdida semanal:{" "}
                  <input
                    type="text"
                    value={plan.maxWeeklyDrawdownPercent}
                    onChange={e => setPlan({ ...plan, maxWeeklyDrawdownPercent: e.target.value })}
                    className="w-14 px-1 bg-[#0A192F] border-b border-rose-500 text-rose-300 font-bold outline-none print:bg-white print:text-black"
                  />
                </div>
              </div>
            </div>

            {/* Regla de Protección */}
            <div className="p-2.5 rounded-lg bg-rose-950/40 border border-rose-800/60 text-center space-y-0.5 print:bg-gray-100 print:border-rose-400">
              <span className="text-[11px] font-bold text-rose-400 uppercase block tracking-wider">REGLA DE PROTECCIÓN:</span>
              <p className="text-xs font-semibold text-rose-200 print:text-black">
                Si alcanzo el límite de pérdida diaria o semanal, dejaré de operar inmediatamente.
              </p>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 6. OBJETIVOS DE TRADING */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center gap-2 border-b border-gray-700/60 pb-2">
              <TrendingUp className="h-5 w-5 text-[#D4AF37]" />
              <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                6. OBJETIVOS DE TRADING
              </h3>
            </div>

            <p className="text-xs text-gray-300 print:text-black">
              Busco un retorno del{" "}
              <input
                type="text"
                value={plan.targetReturnPercent}
                onChange={e => setPlan({ ...plan, targetReturnPercent: e.target.value })}
                className="w-20 px-1 bg-[#0A192F] border-b border-[#D4AF37] text-emerald-400 font-bold text-center outline-none print:bg-white print:text-black"
              />{" "}
              sobre el capital de trading.
            </p>

            <div className="space-y-1.5 text-xs text-gray-300 print:text-black">
              <div className="flex items-center justify-between">
                <span>Capital inicial:</span>
                <div className="flex items-center gap-1">
                  <span className="text-[#D4AF37]">USD$</span>
                  <input
                    type="text"
                    value={plan.capitalInitialUSD}
                    onChange={e => setPlan({ ...plan, capitalInitialUSD: e.target.value })}
                    className="w-24 bg-[#0A192F] border-b border-gray-700 px-1 text-right text-white font-mono outline-none print:bg-white print:text-black"
                  />
                </div>
              </div>

              <div className="flex items-center justify-between">
                <span>Meta mensual:</span>
                <div className="flex items-center gap-1">
                  <span className="text-[#D4AF37]">USD$</span>
                  <input
                    type="text"
                    value={plan.monthlyTargetUSD}
                    onChange={e => setPlan({ ...plan, monthlyTargetUSD: e.target.value })}
                    className="w-20 bg-[#0A192F] border-b border-gray-700 px-1 text-right text-emerald-400 font-mono outline-none print:bg-white print:text-black"
                  />
                  <span className="text-[10px] text-gray-400">(Equivale a</span>
                  <input
                    type="text"
                    value={plan.monthlyTargetPips}
                    onChange={e => setPlan({ ...plan, monthlyTargetPips: e.target.value })}
                    className="w-12 bg-[#0A192F] border-b border-gray-700 px-0.5 text-center text-white outline-none print:bg-white print:text-black"
                  />
                  <span className="text-[10px] text-gray-400">pips)</span>
                </div>
              </div>

              <div className="flex items-center justify-between">
                <span>Meta anual:</span>
                <div className="flex items-center gap-1">
                  <span className="text-[#D4AF37]">USD$</span>
                  <input
                    type="text"
                    value={plan.annualTargetUSD}
                    onChange={e => setPlan({ ...plan, annualTargetUSD: e.target.value })}
                    className="w-24 bg-[#0A192F] border-b border-gray-700 px-1 text-right text-emerald-400 font-mono font-bold outline-none print:bg-white print:text-black"
                  />
                </div>
              </div>
            </div>

            {/* Plan de Crecimiento */}
            <div className="p-3 rounded-lg bg-[#0A192F] border border-[#D4AF37]/30 space-y-1 print:bg-gray-100">
              <span className="text-[10px] font-bold text-[#D4AF37] uppercase block tracking-wide">PLAN DE CRECIMIENTO:</span>
              <textarea
                value={plan.growthPlanText}
                onChange={e => setPlan({ ...plan, growthPlanText: e.target.value })}
                rows={2}
                className="w-full bg-transparent text-xs text-gray-300 outline-none resize-none print:text-black"
              />
            </div>

            {/* Beneficios Esperados */}
            <div className="pt-1">
              <span className="text-[10px] font-bold text-[#D4AF37] uppercase block mb-1.5 text-center">BENEFICIOS ESPERADOS:</span>
              <div className="grid grid-cols-2 sm:grid-cols-4 gap-2 text-center text-[10px]">
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 flex flex-col items-center gap-1">
                  <Building2 className="h-4 w-4 text-[#D4AF37]" />
                  <span className="text-gray-300">Libertad financiera</span>
                </div>
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 flex flex-col items-center gap-1">
                  <Plane className="h-4 w-4 text-[#D4AF37]" />
                  <span className="text-gray-300">Viajes</span>
                </div>
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 flex flex-col items-center gap-1">
                  <Users className="h-4 w-4 text-[#D4AF37]" />
                  <span className="text-gray-300">Tiempo con familia</span>
                </div>
                <div className="p-1.5 rounded bg-[#0A192F] border border-gray-800 flex flex-col items-center gap-1">
                  <DollarSign className="h-4 w-4 text-[#D4AF37]" />
                  <span className="text-gray-300">Inversión y crecimiento</span>
                </div>
              </div>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 7. GESTIÓN EMOCIONAL Y MENTALIDAD */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center gap-2 border-b border-gray-700/60 pb-2">
              <BrainCircuit className="h-5 w-5 text-[#D4AF37]" />
              <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                7. GESTIÓN EMOCIONAL Y MENTALIDAD
              </h3>
            </div>

            <p className="text-[11px] text-gray-300 print:text-black">Me comprometo a:</p>

            <div className="space-y-2 text-xs text-gray-300 print:text-black">
              <label className="flex items-center gap-2 cursor-pointer p-1.5 rounded bg-[#0A192F] border border-gray-800">
                <Checkbox
                  checked={plan.emotionalCommitments.keepCalm}
                  onCheckedChange={c => setPlan({ ...plan, emotionalCommitments: { ...plan.emotionalCommitments, keepCalm: !!c } })}
                />
                <span>Mantener la calma y controlar mis emociones.</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer p-1.5 rounded bg-[#0A192F] border border-gray-800">
                <Checkbox
                  checked={plan.emotionalCommitments.followPlan}
                  onCheckedChange={c => setPlan({ ...plan, emotionalCommitments: { ...plan.emotionalCommitments, followPlan: !!c } })}
                />
                <span>Seguir mi plan sin importar el resultado inmediato.</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer p-1.5 rounded bg-[#0A192F] border border-gray-800">
                <Checkbox
                  checked={plan.emotionalCommitments.learnFromTrades}
                  onCheckedChange={c => setPlan({ ...plan, emotionalCommitments: { ...plan.emotionalCommitments, learnFromTrades: !!c } })}
                />
                <span>Aprender de cada operación (ganadora o perdedora).</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer p-1.5 rounded bg-[#0A192F] border border-gray-800">
                <Checkbox
                  checked={plan.emotionalCommitments.bePatient}
                  onCheckedChange={c => setPlan({ ...plan, emotionalCommitments: { ...plan.emotionalCommitments, bePatient: !!c } })}
                />
                <span>Ser paciente y constante.</span>
              </label>

              <label className="flex items-center gap-2 cursor-pointer p-1.5 rounded bg-[#0A192F] border border-gray-800">
                <Checkbox
                  checked={plan.emotionalCommitments.disciplineIsFreedom}
                  onCheckedChange={c => setPlan({ ...plan, emotionalCommitments: { ...plan.emotionalCommitments, disciplineIsFreedom: !!c } })}
                />
                <span>Recordar que la disciplina hoy, es la libertad mañana.</span>
              </label>
            </div>
          </div>

          {/* ============================================================ */}
          {/* 8. SEGUIMIENTO Y REVISIÓN */}
          {/* ============================================================ */}
          <div className="p-4 rounded-xl bg-[#12233A] border border-[#D4AF37]/30 space-y-3 print:bg-white print:border-gray-400">
            <div className="flex items-center gap-2 border-b border-gray-700/60 pb-2">
              <ClipboardList className="h-5 w-5 text-[#D4AF37]" />
              <h3 className="font-extrabold text-sm text-[#D4AF37] uppercase tracking-wide">
                8. SEGUIMIENTO Y REVISIÓN
              </h3>
            </div>

            <p className="text-[11px] text-gray-300 print:text-black">Revisaré mi desempeño de forma constante.</p>

            <div className="space-y-2 text-xs">
              <div className="flex items-center gap-2">
                <span className="text-gray-400 font-semibold w-24">Revisión diaria:</span>
                <input
                  type="text"
                  value={plan.dailyReview}
                  onChange={e => setPlan({ ...plan, dailyReview: e.target.value })}
                  className="flex-1 bg-[#0A192F] border-b border-gray-700 px-2 py-0.5 text-white outline-none print:bg-white print:text-black"
                />
              </div>
              <div className="flex items-center gap-2">
                <span className="text-gray-400 font-semibold w-24">Revisión semanal:</span>
                <input
                  type="text"
                  value={plan.weeklyReview}
                  onChange={e => setPlan({ ...plan, weeklyReview: e.target.value })}
                  className="flex-1 bg-[#0A192F] border-b border-gray-700 px-2 py-0.5 text-white outline-none print:bg-white print:text-black"
                />
              </div>
              <div className="flex items-center gap-2">
                <span className="text-gray-400 font-semibold w-24">Revisión mensual:</span>
                <input
                  type="text"
                  value={plan.monthlyReview}
                  onChange={e => setPlan({ ...plan, monthlyReview: e.target.value })}
                  className="flex-1 bg-[#0A192F] border-b border-gray-700 px-2 py-0.5 text-white outline-none print:bg-white print:text-black"
                />
              </div>
            </div>

            {/* Métricas Clave */}
            <div className="p-3 rounded-lg bg-[#0A192F] border border-[#D4AF37]/30 space-y-1.5 mt-2 print:bg-gray-100">
              <span className="text-[10px] font-bold text-[#D4AF37] uppercase block tracking-wider">MÉTRICAS CLAVE:</span>
              <ul className="grid grid-cols-2 gap-1 text-[11px] text-gray-300 list-disc list-inside print:text-black">
                <li>% de aciertos (Win Rate)</li>
                <li>Ratio Ganancia/Pérdida</li>
                <li>Pips ganados</li>
                <li>Pips perdidos</li>
                <li className="col-span-2">Consistencia operativa y PF</li>
              </ul>
            </div>
          </div>

        </div>

        {/* ============================================================ */}
        {/* MI COMPROMISO & FIRMA DIGITAL */}
        {/* ============================================================ */}
        <div className="p-5 rounded-xl bg-gradient-to-r from-[#12233A] via-[#0D1D32] to-[#12233A] border-2 border-[#D4AF37]/50 space-y-4 print:bg-white print:border-gray-400">
          <div className="flex flex-col md:flex-row items-center justify-between gap-4">
            <div className="space-y-1 text-center md:text-left">
              <div className="flex items-center justify-center md:justify-start gap-2">
                <Trophy className="h-5 w-5 text-[#D4AF37]" />
                <h3 className="font-extrabold text-base text-[#D4AF37] uppercase tracking-wide">
                  MI COMPROMISO
                </h3>
              </div>
              <p className="text-xs text-gray-300 max-w-md print:text-black">
                &quot;Me comprometo a seguir este plan con disciplina, constancia y mentalidad ganadora.&quot;
              </p>
              <div className="flex items-center gap-2 pt-1 text-xs">
                <span className="text-gray-400">Nombre Operador:</span>
                <input
                  type="text"
                  value={plan.signatureName}
                  onChange={e => setPlan({ ...plan, signatureName: e.target.value })}
                  className="bg-[#0A192F] border-b border-[#D4AF37] px-2 py-0.5 text-white font-bold outline-none print:bg-white print:text-black"
                />
              </div>
            </div>

            {/* Canvas de Firma Digital */}
            <div className="flex flex-col items-center space-y-1">
              <span className="text-[10px] text-gray-400 uppercase font-semibold flex items-center gap-1">
                <PenTool className="h-3 w-3 text-[#D4AF37]" /> FIRMA DIGITAL DEL OPERADOR:
              </span>
              <div className="relative border border-[#D4AF37]/40 rounded bg-[#0A192F] print:bg-white">
                <canvas
                  ref={canvasRef}
                  width={240}
                  height={70}
                  onMouseDown={startDrawing}
                  onMouseUp={stopDrawing}
                  onMouseOut={stopDrawing}
                  onMouseMove={draw}
                  onTouchStart={startDrawing}
                  onTouchEnd={stopDrawing}
                  onTouchMove={draw}
                  className="cursor-crosshair block"
                />
              </div>
              <div className="flex items-center gap-3 text-[10px] print:hidden">
                <button
                  type="button"
                  onClick={clearSignature}
                  className="text-gray-400 hover:text-rose-400 underline"
                >
                  Borrar Firma
                </button>
                <span className="text-gray-500">
                  Fecha: {plan.signatureDate}
                </span>
              </div>
            </div>
          </div>
        </div>

        {/* ============================================================ */}
        {/* CHECKLIST DIARIO (FOOTER POSTER) */}
        {/* ============================================================ */}
        <div className="p-4 rounded-xl bg-[#12233A] border border-gray-700 space-y-3 print:bg-white print:border-gray-400">
          <div className="flex items-center justify-between">
            <h4 className="font-extrabold text-xs text-[#D4AF37] uppercase tracking-wider flex items-center gap-2">
              <AlertOctagon className="h-4 w-4 text-[#D4AF37]" />
              CHECKLIST DIARIO PRE-VUELO
            </h4>
            <span className="text-[10px] text-gray-400">Valida antes de cada entrada a mercado</span>
          </div>

          <div className="grid grid-cols-1 sm:grid-cols-5 gap-2 text-xs">
            <label className={`p-2 rounded border cursor-pointer transition-all flex items-center gap-2 ${plan.dailyChecklist.definedRisk ? "bg-emerald-950/40 border-emerald-500 text-white" : "bg-[#0A192F] border-gray-800 text-gray-300"}`}>
              <Checkbox
                checked={plan.dailyChecklist.definedRisk}
                onCheckedChange={c => setPlan({ ...plan, dailyChecklist: { ...plan.dailyChecklist, definedRisk: !!c } })}
              />
              <span className="text-[11px]">¿Definí mi riesgo?</span>
            </label>

            <label className={`p-2 rounded border cursor-pointer transition-all flex items-center gap-2 ${plan.dailyChecklist.hasStopLoss ? "bg-emerald-950/40 border-emerald-500 text-white" : "bg-[#0A192F] border-gray-800 text-gray-300"}`}>
              <Checkbox
                checked={plan.dailyChecklist.hasStopLoss}
                onCheckedChange={c => setPlan({ ...plan, dailyChecklist: { ...plan.dailyChecklist, hasStopLoss: !!c } })}
              />
              <span className="text-[11px]">¿Tengo mi stop loss?</span>
            </label>

            <label className={`p-2 rounded border cursor-pointer transition-all flex items-center gap-2 ${plan.dailyChecklist.setupValid ? "bg-emerald-950/40 border-emerald-500 text-white" : "bg-[#0A192F] border-gray-800 text-gray-300"}`}>
              <Checkbox
                checked={plan.dailyChecklist.setupValid}
                onCheckedChange={c => setPlan({ ...plan, dailyChecklist: { ...plan.dailyChecklist, setupValid: !!c } })}
              />
              <span className="text-[11px]">¿Mi setup cumple la estrategia?</span>
            </label>

            <label className={`p-2 rounded border cursor-pointer transition-all flex items-center gap-2 ${plan.dailyChecklist.emotionallyStable ? "bg-emerald-950/40 border-emerald-500 text-white" : "bg-[#0A192F] border-gray-800 text-gray-300"}`}>
              <Checkbox
                checked={plan.dailyChecklist.emotionallyStable}
                onCheckedChange={c => setPlan({ ...plan, dailyChecklist: { ...plan.dailyChecklist, emotionallyStable: !!c } })}
              />
              <span className="text-[11px]">¿Estoy emocionalmente estable?</span>
            </label>

            <label className={`p-2 rounded border cursor-pointer transition-all flex items-center gap-2 ${plan.dailyChecklist.acceptResult ? "bg-emerald-950/40 border-emerald-500 text-white" : "bg-[#0A192F] border-gray-800 text-gray-300"}`}>
              <Checkbox
                checked={plan.dailyChecklist.acceptResult}
                onCheckedChange={c => setPlan({ ...plan, dailyChecklist: { ...plan.dailyChecklist, acceptResult: !!c } })}
              />
              <span className="text-[11px]">¿Acepto el resultado sin ego?</span>
            </label>
          </div>
        </div>

      </div>
    </div>
  )
}
