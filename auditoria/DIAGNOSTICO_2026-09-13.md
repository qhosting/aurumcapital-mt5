# Auditoría técnica y de trading — Aurum Capital

Fecha: 13 de septiembre de 2026. Código base: commit `0d3e466`.

## Dictamen

**El plan no está validado para ejecución tal como está descrito.** La exportación disponible tiene expectativa monetaria negativa y el código incumple varias de sus reglas. La prioridad es corregir riesgo, ejecución y trazabilidad; después comparar estrategias con datos nuevos. No hay evidencia suficiente para sostener un retorno mensual del 4–8%, los porcentajes de acierto por temporalidad anunciados ni que Micro-Lock aumente la rentabilidad.

La revisión cubre los dos EA actuales, fuentes heredadas, visualizador, Pine, referencias SMC/OB, scripts Python y PowerShell, históricos y documentación. Es una revisión estática con recálculo completo de las exportaciones; no una compilación de MQL5 ni un backtest de ticks. No se localizaron logs `.log`, archivos `.set`, informes del Strategy Tester o estados de cuenta originales dentro del proyecto. El usuario confirmó `trade_history_complete.csv` como histórico disponible. La versión realmente cargada en MT5 queda sin verificar.

Los dos `.ex5` son binarios: su presencia no demuestra correspondencia con los `.mq5`. No se modificaron ni desplegaron robots. Las propuestas se documentan aparte para la posterior actualización del plan y la guía.

## 1. Calidad y resultados del histórico

Se compararon las 893 filas del CSV con el JSON normalizando `account/acc` y `points/pts`: **coinciden en todos los campos**. Herramienta reproducible: `python3 tools/review_export.py` desde la raíz. Resultados completos en [métricas](/Users/r00t/PROYECTOS/aurumcapital-mt5/auditoria/METRICAS_EXPORTACION.md) y JSON con hashes SHA-256.

| Métrica | Resultado | Interpretación |
|---|---:|---|
| Período entre primera entrada y último cierre | 2026-01-23 → 2026-09-11 | Hay registros en enero, febrero, julio, agosto y septiembre; marzo–junio no están representados |
| Filas reconstruidas | 893 | Fragmentos FIFO; no equivalen necesariamente a trades completos |
| Grupos de entrada candidatos | 683 | Agrupación por cuenta, símbolo, dirección, segundo de entrada y precio; tampoco sustituye `position_id` |
| Días con entradas | 59 | Cobertura irregular |
| P&L estimado | −$331.45 | Sin comisiones, swaps ni fees explícitos |
| Ganancias / pérdidas por signo | +$1,020.01 / −$1,351.46 | Incluye todos los resultados pequeños |
| Profit factor por signo | 0.75475 | Cada $1 perdido estuvo acompañado por ~$0.755 ganado |
| Media por fragmento | −$0.3712 | No es expectativa en R ni retorno porcentual |
| Etiquetas históricas | 369 WIN / 418 LOSS / 106 BE | BE usa tolerancia alrededor de $0.05 |
| WR usando etiquetas originales | 41.32% | Si se usa P&L estrictamente positivo, 45.13%; no mezclar definiciones |

El roadmap publica +$1,019.16 / −$1,349.89 porque excluye del PF los importes de filas etiquetadas BE. Esos grupos dejan fuera un saldo neto de −$0.72. No es una gran diferencia global, pero sí cambia subgrupos: USDJPYmicro tiene PF **0.9315** por signo frente al ~0.96 de las etiquetas.

Las filas de datos 50 y 51 son exactamente iguales: GBPUSD BUY, entrada 2026-07-14 11:20:01, salida 11:49:03, 0.01 lotes, +$1.02. Sin identificadores no se puede decidir si son dos fills legítimos o una duplicación. Se conservaron ambas y se marcaron; borrarlas automáticamente alteraría evidencia.

### Resultados por instrumento

| Símbolo | Fragmentos | P&L estimado USD | PF por signo | WR histórico |
|---|---:|---:|---:|---:|
| EURUSD | 17 | +44.23 | 4.790 | 70.6% |
| US30Cash | 2 | +1.52 | 4.040 | 50.0% |
| USDJPYmicro | 49 | −0.67 | 0.931 | 59.2% |
| BTCUSD | 11 | −1.90 | 0.873 | 36.4% |
| GBPUSD | 57 | −5.47 | 0.907 | 36.8% |
| GBPUSDmicro | 37 | −14.11 | 0.025 | 5.4% |
| EURUSDmicro | 83 | −20.89 | 0.320 | 33.7% |
| USDJPY | 116 | −48.49 | 0.488 | 25.0% |
| GOLDmicro | 460 | −138.82 | 0.803 | 45.4% |
| GOLD | 60 | −146.84 | 0.643 | 56.7% |
| BRENTCash | 1 | −0.01 | 0.000 | 0.0% |

Las dos cuentas son negativas: estándar −$156.57, micro −$174.88. GOLD y GOLDmicro suman −$285.66, el 86.2% de la pérdida neta agregada. EURUSD merece una prueba prospectiva, pero 17 fragmentos no lo convierten en activo validado. Tampoco se puede extender su resultado a EURUSDmicro, cuyo histórico es negativo.

### Concentración y sesgos que cambian las conclusiones

1. **Una pérdida GOLD de −$184.10 representa el 55.5% de la pérdida neta agregada.** Es un SELL de 0.10, entrada 31 de julio y salida 2 de agosto. Sin esa fila el agregado seguiría en −$147.35. Esto describe concentración, no una estrategia que pudiera evitarla.
2. **Hay un emparejamiento de unos 152 días:** GOLDmicro BUY desde 12 de febrero hasta 14 de julio, −$86.89. Puede representar exposición mantenida o emparejamiento incorrecto por datos incompletos/hedging. No se puede diagnosticar conducta del operador sin el ticket de posición original.
3. **SELL suma −$305.98 y BUY −$25.47.** No prueba que prohibir todas las ventas sea rentable: compra y venta mezclan instrumentos, tamaños, fechas y versiones. Hay que controlar esos factores.
4. **El grupo 5–30 minutos suma +$38.80, PF 1.159; >120 minutos, −$250.82.** La duración final solo se conoce al cerrar. Elegir trades por duración observada introduce selección posterior; no demuestra que cerrar a los 30/60 minutos hubiera mejorado resultados.
5. **Los martes suman +$115.18 y viernes −$231.20**, por fecha de entrada sin zona horaria verificada. Las tres mayores ganancias GOLD del 14 de julio suman +$115.30; una pérdida de −$184.10 domina gran parte del viernes. Los supuestos días óptimos son sensibles a unos pocos resultados y tamaño de posición.
6. **Agrupar por entrada desplaza P&L de un mes a otro.** Febrero aparece en −$93.08 por entrada, pero +$0.79 por fecha de cierre. Agosto pasa de −$24.67 por entrada a −$168.83 por cierre. El panel etiqueta la curva con entradas aunque la reconstrucción se produce por cierres; puede mostrar fechas fuera de orden.

No se pueden calcular con fiabilidad retorno mensual porcentual, drawdown de equity, Sharpe, R realizado, pérdidas por ausencia de SL, MAE/MFE, noticias, spread pagado ni rentabilidad por versión/timeframe. Faltan capital y movimientos de fondos, series de equity, SL inicial, ticks, identificadores y metadatos. El spread puede estar incorporado en precios de ejecución reales, pero no está desglosado; no corresponde restarlo otra vez automáticamente.

### Por qué FIFO no valida esta estrategia

`tools/audit_trades.py:63` empareja cualquier deal contrario por cuenta y símbolo. En una cuenta hedging, un BUY y un SELL pueden ser dos posiciones abiertas simultáneas; el auditor los convertiría en una operación cerrada. Tampoco conserva `DEAL_ENTRY`, ID de posición, IDs de deals en la salida, pendientes sin cerrar, ni deduplica IDs. Incluso en netting necesita un historial completo desde una posición plana y reglas para aumentos/reversiones.

Los tamaños de contrato se suponen por nombre del símbolo y el P&L se estima mediante fórmulas. No hay prueba de divisa de cuenta ni de especificaciones históricas del broker. La referencia oficial ofrece campos para identidad de posición, entrada/salida y costes que deben exportarse directamente. [Propiedades de deals de MetaQuotes](https://www.mql5.com/en/docs/constants/tradingconstants/dealproperties).

## 2. Hallazgos técnicos prioritarios

Las líneas de AurumSniper corresponden también a AurumSniperMicro: solo difieren encabezados y dos inputs. **P0**: integridad del riesgo/contabilidad antes de validar; **P1**: comportamiento incorrecto; **P2**: mantenimiento/observabilidad. Confianza alta significa que la condición está presente en la fuente, no que se haya probado su impacto monetario en vivo.

### P0 — Riesgo y ejecución

| ID | Evidencia en AurumSniper.mq5 | Hallazgo y efecto | Corrección necesaria |
|---|---|---|---|
| R01 | 32, 184–202, 852–910 | Protección estricta OFF, techo 5%, normalización eleva a lote mínimo. Con cuenta de $200, contrato oro de 100 oz/lote, 0.01 y SL de $18, la pérdida teórica es $18 = 9%, aunque el input diga 1% | Rechazar si lote mínimo supera presupuesto; bloquear si valoración falla; validar también lotaje fijo |
| R02 | 1355–1357, 1378–1380 | `CheckStops` puede ampliar SL y luego el lote se calcula con la distancia anterior | Dimensionar después del SL final normalizado usando dirección y precios efectivos, margen y colchón de ejecución |
| R03 | 1202–1210, 1735–1760 | Límite diario es una comparación sin cierre forzoso ni bloqueo persistente; reiniciar cambia la base de equity. Si equity recupera, puede permitir entradas otra vez | Estado de cuenta persistente, bloqueo enclavado, política explícita de cierre y ajuste por depósitos/retiros |
| R04 | 133, 713; Micro 27 | `InpMagicNumber` no se usa; ambos EA ejecutan con constante 777999 | Usar identificador configurado y conciliar posiciones existentes antes de migrar |
| R05 | 1464, 2106, 2169 | Con `InpManageManualTrades=true`, el gestor toma cualquier magic del mismo símbolo; puede modificar otro EA. Por defecto esos trades se omiten al bloquear entradas/riesgo USD | Separar magic propio, manual `0` y otros EA; un único dueño de cada posición |
| R06 | 1360, 1383, 1573–1620, 1673 | Se confunde el booleano de CTrade con ejecución confirmada; puede marcar parcial/cierre sin confirmación del servidor | Comprobar retcode y conciliar volumen/precio/deal; reintentos idempotentes |
| R07 | 334, 808–823, 873–874 | Contadores por símbolo e instancia, rachas por deal parcial, sin filtro magic en cierres. Dos pérdidas reducen tamaño pero no detienen jornada. Cierres del mismo segundo pueden omitirse | Contar posiciones completas y todas las entradas autorizadas a nivel cuenta; usar ID/ms; recuperar rachas y límites tras reinicio |

MetaQuotes indica que un retorno `true` de cierre parcial no garantiza ejecución y documenta `PositionClosePartial` para hedging. El EA no valida ese modo ni implementa una alternativa netting. [Documentación oficial de cierre parcial](https://www.mql5.com/en/docs/standardlibrary/tradeclasses/ctrade/ctradepositionclosepartial).

### P1 — Salidas y estados

| ID | Evidencia | Hallazgo y efecto |
|---|---|---|
| S01 | EA 1508–1512, 1870, 2051 | R cambia con ATR de vela actual y no aplica techo oro $18. Entrada con R0=$18 y ATR posterior 15 produce referencia $30: movimiento +$9 se interpreta como 0.3R, no 0.5R. Guardar R0, SL0, volumen y riesgo monetario inicial |
| S02 | EA 1562 antes de 1568 | Fase 1.5 ≥1.0R intercepta todo valor ≥1.3R que no haya llegado a fase 2; parcial de fase 1 es inalcanzable con defaults. Usar máquina de estados y pruebas de saltos entre umbrales |
| S03 | EA 357–367, 1573, 1599, 1751 | Un mismo flag cubre Micro-Lock y fase 1; se borra cada día y al reiniciar. Puede repetirse un parcial sobre posición aún abierta. Persistir estado por posición y fase; reconciliar ejecuciones |
| S04 | EA 1352, 1560, 1658–1666, 1478 | TP inicial 2.2R permanece: con R estable cerraría antes del runner 3R. Intento de quitar TP con valor 0 pasa por CheckStops, que puede reintroducirlo; AutoSetManualSLTP también repone TP faltante |
| S05 | EA 1577–1581 y 1603–1607 | Redondeo previo a 2 decimales no sirve para todos los pasos de volumen; si no admite parcial, se marca cerrado aunque no se ejecutó. Definir fallback y estado “no aplicable”, no “ejecutado” |
| S06 | EA 1624–1650 | Candle trailing cuenta barras desde apertura y exige R actual; no comprueba cuatro barras consecutivas en beneficio. Son ~60 min solo en M15. Documentar la semántica exacta |

### P1 — Señales, SMC, datos y horarios

| ID | Evidencia | Hallazgo y efecto |
|---|---|---|
| E01 | EA 533, 560, 604, 616 | OB y FVG se acumulan hasta 20 sin eliminación/reciclaje; al llenarse no entran zonas nuevas. Campos `is_mitigated` no se usan para invalidarlas. Persisten niveles obsoletos |
| E02 | EA 706–709 | `ob_valid` y `fvg_valid` se calculan pero se ignoran; `InpUseBreakerBlocks` no gobierna la validación. Se acepta cualquier OB/FVG/sweep y el retorno incorpora sweeps de ambos sentidos |
| E03 | EA 494–650, 1345 | Estructura solo en `_Period`; no se exige BOS H1 y CHoCH inferior como dice el manual. Barrido de swing no equivale a detector de dos máximos/mínimos iguales |
| E04 | EA 1028–1040, 1231–1266, 1349 | Descuento se relaja hasta 70% para compras y 30% para ventas; RSI llega a 55/45; rango habilitado; SL es ATR acotado, no detrás de OB. Son estrategias diferentes al plan escrito |
| E05 | EA 343–350 | `CopyBuffer > 0` no asegura los 2/3 valores leídos después. Puede acceder fuera de array o conservar caché vieja; H1/H4 usan barra abierta. Exigir longitud exacta, sincronización y bloquear entradas sin datos |
| E06 | EA 923, 958–960 | `TimeLocal` presupone PC en CDMX; killzone y filtro metales OFF. Ventana configurada no representa las dos sesiones separadas del plan. En el tester TimeLocal pasa a hora de servidor |
| E07 | EA 1335–1340 | ATR/rango de vela son filtros reactivos de volatilidad, no un calendario de noticias con ventana previa. No sostienen la regla de ±15 min CPI/NFP/FOMC |
| E08 | EA 2129–2198 | Exposición USD es un clasificador de signos, no presupuesto monetario agregado ni correlación estimada. Reentradas BE no tienen riesgo cero por gaps/costes; en netting alteran precio medio y riesgo |
| E09 | EA 1346–1394 | BUY y SELL son `if` separados con restricciones calculadas antes; conviene revalidar después de ejecución y admitir como máximo una nueva entrada por decisión |

La diferencia de `TimeLocal` entre vivo y tester está documentada por [MetaQuotes](https://www.mql5.com/en/docs/dateandtime/timelocal). El horario histórico del CSV no incluye offset: las asociaciones con Londres, NY o noticias del roadmap no quedan demostradas.

### P1 — TradingView no replica MT5

En [AurumVision.pine](/Users/r00t/PROYECTOS/aurumcapital-mt5/AurumVision.pine:280), el breaker cambia de color y `isBreaker`, pero **no invierte `isBullish`**. Más adelante se usa ese campo para clasificar soporte de compra o resistencia de venta: la dirección operativa queda invertida respecto al breaker mostrado y respecto a MQL5.

Otras diferencias verificadas:

- Rango llamado H1 usa 40 velas del gráfico, frente a 20 H1 cerradas del EA.
- TP de Pine 1.0/1.8/2.2R frente a 1.3/2.2/3.0R; RSI y multiplicadores por activo también difieren.
- Pine aplica 07:00–21:00 UTC fijo; EA permite metales fuera de killzone por defecto. No existe el mismo calendario.
- Pine usa EMA H1/H4 desplazada; EA usa EMA actual. Microgatillo M1, cooldown, spread, riesgo, límites y excepciones de rango no se replican.
- FVG se dibuja pero no participa en `smc_buy_zone/smc_sell_zone`; en EA puede autorizar confluencia.
- Ocultar OB desactiva su creación y cambia señales; una opción visual modifica la estrategia.
- `long_cond/short_cond` usan datos de barra actual sin exigir cierre. Las señales pueden aparecer/desaparecer intrabar. Esto exige política de confirmación y pruebas de recarga; no implica que todos los pivots sean inválidos. [TradingView: repainting](https://www.tradingview.com/pine-script-docs/concepts/repainting/).
- El archivo es `indicator()`: no simula órdenes ni mide P&L con comisiones. No valida rentabilidad por mostrar setups.

## 3. Revisión de los demás archivos

| Archivo | Diagnóstico |
|---|---|
| AurumSniper_V9.mq5 | En realidad declara V11; lote fijo, 16 entradas, guard diario no persistente, sin validación/release de hATR; confirmar retcodes y fallback de SL en SELL. Es legado, no referencia fiel del motor actual |
| AurumSniper_V9_utf8.mq5 | Codificación corrupta: texto UTF-8 con caracteres producto de interpretar bytes como UTF-16; casi una sola línea. Se reconstruyó una copia temporal para inspección: variante antigua V11, 3 trades, gestión sin aislamiento por símbolo. No es código compilable utilizable tal como está guardado |
| AurumVisualizer_V9.mq5 | Línea 182 llama iRSI con 5 argumentos estilo MQL4: firma incompatible con MQL5. RSI indexado como si gráfico fuera M5; datos M15 de barra contenedora pueden incluir futuro para barras M5 históricas. Sin release de handles; cálculo no procesa señales con <1000 barras |
| SMC.txt | Referencia Pine v6 con estructura interna/swing que la integración simplifica. FVG usa lookahead_on con high/low actuales HTF: fuga de datos históricos si TF superior. Elimina elementos al recorrer hacia delante (riesgo de saltar elementos). Arrays históricos crecen sin tope; fórmula de confluencia mezcla `min(close, open-low)` en vez de mecha inferior. FVG bajista almacena top/bottom en orden inverso al alcista, revisar invalidación |
| OB.txt | Referencia Pine v6 con pending OB y control chop; esos mecanismos no se trasladaron completamente. Arrays pending y bloques ocultos no tienen límite de almacenamiento/expiración. Color del breaker usa origen, no una dirección operativa invertida; copiar ese booleano al motor de señales produjo el defecto de Pine |
| tools/audit_trades.py | FIFO no conciliado, contratos supuestos, errores de lectura silenciados y directorio Windows fijo. `--symbol EURUSD` incluye EURUSDmicro. Permite exportar vacío sobre un archivo existente si no encuentra logs. “R:R” en docstring no se calcula |
| scratch/deep_analysis.py | Duplica reconstrucción y sus límites; agrupa por entrada y etiqueta horas “servidor” sin evidencia. Escribe sobre JSON mediante ruta absoluta Windows |
| scratch/test_trade_reconstruction.py | Es un script de reconstrucción, no una suite de pruebas: no contiene aserciones. Con cero trades, el main divide por cero |
| scratch/analyze_logs.py | Parser de cierres no captura cuenta/ticket/magic. Puede mezclar instancias o eventos repetidos. Silencia errores. Contar eventos de trailing no mide rentabilidad atribuible a trailing |
| scratch/hourly_analysis.py | Ruta Windows fija y hora sin zona; agrupar no verifica causalidad de las sesiones |
| scratch/generate_dashboard_html.py | KPIs/conclusiones y gráficos de duración/día están codificados a mano; solo parte sale del JSON. Filtros afectan tabla, no todos los KPIs/gráficos. Redondea Forex a 2 decimales; muestra solo 150 filas y omite cuenta. CDN Chart.js sin versión fijada; curva es suma de estimaciones, no equity |
| DASHBOARD_HISTORICO_TRADES.html | Snapshot generado, no panel vivo; hereda métricas y afirmaciones del generador. No debe usarse para verificar DD o versión actual |
| scratch/compile_and_deploy.ps1 | Copia fuentes directamente al terminal, no exige compilación limpia ni frescura/hash del ex5 antes de copiarlo de vuelta. Puede reutilizar binario anterior tras fallo. Necesita separar compilación aislada de despliegue |
| Plan y manual BETA | 868 trades, WR por TF, probabilidad OB+FVG >75%, atribución de 85% de pérdidas a gestión y 45.2% a Asia sin campos que permitan reproducirlo. Límites y salidas contradicen fuente |
| Manual V11 y roadmap V9 | Documentación histórica mezcla versiones, ATR, 3/16 trades, funciones completadas que no aparecen en la fuente actual. No es guía vigente |
| Roadmap de seguimiento | Reproduce agregado FIFO pero lo denomina validación matemática de V14. No tiene comparación antes/después por versión. Cambia riesgo de 1% a 1–2%, M15 a M1/M5 y horarios |
| Presentación a inversores (.md/.html) | DD global 15–20% frente a 6% en plan; promesas de riesgo cero, seguridad/regulación/fiscalidad no verificadas con documentos de cuenta/entidad. Requiere revisión separada antes de tratarla como información validada |
| Manuales HTML | Copias publicables de documentos contradictorios; regenerar desde una única fuente al cerrar revisión |
| .gitignore | Ignora `*.log`, `*.bak` y `__pycache__/`; los logs no viajan con git por defecto. Definir captura/archivo de evidencia fuera del control de versiones y tratamiento de históricos con identificadores de cuenta |

La firma MQL5 de iRSI devuelve un handle y recibe cuatro parámetros. [Referencia oficial](https://www.mql5.com/en/docs/indicators/irsi).

`SMC.txt` declara CC BY-NC-SA y `OB.txt` MPL-2.0. Registrar procedencia y revisar condiciones antes de distribuir derivados; esta auditoría no determina derechos comerciales ni valida las afirmaciones legales de la presentación.

## 4. Validez del plan de trading

| Regla declarada | Estado comprobado |
|---|---|
| 1% máximo por trade | No garantizado por lotaje mínimo, SL ajustado y protección OFF |
| 3 trades por día | Default 16 por instancia/símbolo; no global |
| 2 pérdidas y detener jornada | Solo reduce riesgo/cooldown; sin parada diaria |
| DD diario 3%, cierre forzoso | No cierra ni enclava bloqueo; base se reinicia |
| DD total 6% | No hay implementación del límite total |
| Londres y NY, cierre 11:30 CDMX | Incompatible con defaults y dependencia de hora PC |
| EMA200 H1 + BOS H1 + CHoCH inferior | EMA sí; resto no constituye requisito conjunto implementado |
| OB/Breaker obligatorio, FVG no mitigado | Validación OR, flags ignorados, zonas sin ciclo de vida |
| SL detrás del OB | SL por ATR con techo; puede quedar dentro de la estructura |
| Salidas 50%/40%/runner | Fases inaccesibles, flag único, TP que impide runner; porcentajes ambiguos |
| Activos validados por timeframe | CSV sin timeframe ni versión; afirmación no verificable |

Los indicadores OHLC son reglas de precio; no se observa un motor de order flow con DOM, delta o volumen agresor. La denominación “institucional” no prueba una ventaja estadística.

## 5. Qué puede mejorar rentabilidad y qué todavía es hipótesis

**Mejora técnica sustentada:** riesgo efectivamente acotado, stops/volúmenes correctos, R0 persistente, fase ejecutada una sola vez, rechazo de órdenes visible, coherencia de señales y contabilidad fiable. Esto reduce comportamientos no deseados; su magnitud en P&L requiere replay.

**Hipótesis a evaluar:** selección de instrumentos, ventanas horarias, filtros de tendencia, SL estructural versus ATR, Micro-Lock, salida por tiempo y frecuencia. Ninguna está validada por comparar subgrupos seleccionados del mismo histórico.

Ejemplo de por qué un mayor win rate puede empeorar ganancias: con 50% cerrado a 0.5R y resto a 2.2R, el ganador completo cobra **1.35R**, no 2.2R. Si esos fueran los únicos ganadores y cada perdedor fuera −1R, el acierto de equilibrio antes de costes sube de **31.25%** (TP completo 2.2R) a **42.55%**. Las salidas intermedias cambian la distribución real; hay que medirla con ticks, costes y riesgo inicial. El parcial puede ayudar o destruir expectativa.

Ver [plan de mejora y protocolo de validación](/Users/r00t/PROYECTOS/aurumcapital-mt5/auditoria/PLAN_DE_MEJORA.md). No se recomienda aumentar riesgo o ampliar activos con esta evidencia.
