# Plan de trading Aurum V15 (vigente para validación)

Este documento reemplaza las reglas V9–V14 para cualquier prueba nueva. Su estado es **validación técnica y estadística**, no aprobación para operar con dinero real.

## Perfil congelado

| Parámetro | Baseline V15 |
|---|---:|
| Timeframe de entrada | M15, vela cerrada |
| Filtro | EMA H1 y H4 cerradas; RSI 42/58; ADX ≥ 20 |
| Zona | OB o breaker causal dentro del rango de 20 H1 cerradas |
| Riesgo por entrada | 0.25% de la equidad |
| Riesgo inicial agregado | 0.50% de la equidad |
| Límite diario | 1%; 3 entradas; 2 pérdidas completas consecutivas |
| Drawdown total | 6%, bloqueo persistente |
| Salida base | TP 2.2R, sin parcial ni runner |
| Oro | SL mínimo 10 y máximo 18 unidades de precio |
| Sesiones CDMX | 01:15–05:30 y 06:30–11:30, con offset del servidor verificado |

El lote se calcula con `OrderCalcProfit` y se redondea hacia abajo al paso del broker. Si el mínimo del contrato supera el presupuesto, se omite la entrada. Un SL inicial ausente, una orden pendiente no valorable, un historial inconsistente o una respuesta incierta del servidor bloquean nuevas operaciones.

## Reglas de entrada y gestión

La señal exige tendencia, descuento/premium, contacto con OB/breaker, RSI/ADX y vela cerrada con dirección o mecha de rechazo. FVG y sweep son filtros opcionales del preset, no inferencias obligatorias. El SL se calcula antes del lote y se guarda como R0; el ATR actual nunca sustituye el riesgo original.

La posición pertenece solo al magic configurado. Las posiciones manuales o del magic anterior no se gestionan salvo adopción explícita. El motor conserva el SL del broker cuando no puede reconstruir el historial y registra el caso. Los parciales y trailing se activan por preset y se refieren al volumen inicial.

## Puerta de promoción

Compilar sin errores ni warnings; probar en hedging con ticks reales, spread, comisión, swap y slippage; conciliar cada deal por identificador; y completar forward demo sin cambios de parámetros. Promover solo con expectativa neta positiva fuera de muestra, PF neto objetivo ≥1.20 bajo costes y estrés moderado, drawdown dentro del presupuesto y sin fallos críticos. Ningún umbral garantiza rentabilidad.

Las exportaciones históricas disponibles fueron FIFO y negativas; no son una base para afirmar win rate, retorno mensual o superioridad de un activo.
