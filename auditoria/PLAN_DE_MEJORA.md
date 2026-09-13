# Plan de mejora y validación de Aurum

> **Actualización V15 (13-09-2026):** las correcciones P0/P1 de riesgo, propiedad, estado, conciliación, exportación y build aislado están implementadas en `Include/AurumEngine.mqh`, los wrappers `.mq5`, `tools/ExportAurumHistory.mq5`, `tools/reconcile_deals.py` y `scratch/compile_and_deploy.ps1`. Quedan pendientes exclusivamente las comprobaciones que requieren MetaEditor/Strategy Tester/TradingView y datos nativos del broker.

Fecha: 13 de septiembre de 2026. Estado: propuesta de trabajo basada en la auditoría; no configuración desplegada ni promesa de rentabilidad.

## Objetivo y orden de trabajo

Primero obtener resultados medibles y ejecución coherente; después probar si existe expectativa positiva después de costes. El criterio de éxito no será incrementar el número de señales o el win rate aislado. Será mejorar expectativa neta por posición y controlar riesgo de cuenta en datos no usados para elegir parámetros.

| Orden | Entregable | Prioridad | Condición de cierre |
|---|---|---|---|
| 1 | Historial conciliado y configuración identificada | P0 | Deals/posiciones/costes cuadran con estado de cuenta; faltantes explícitos |
| 2 | Núcleo de riesgo y ejecución corregido | P0 | Todas las pruebas de riesgo/retcodes/reinicios pasan en MT5 |
| 3 | Gestión por R inicial y fases persistentes | P1 | Parciales y SL consistentes en replay, reinicio y cambio de día |
| 4 | Señales SMC y visualización alineadas | P1 | Mismas reglas y decisiones en fixtures comunes; diferencias de feed explicadas |
| 5 | Experimentos limitados y fuera de muestra | P1 | Ventaja neta robusta y estable, o rechazo de la hipótesis |
| 6 | Forward demo y revisión documental final | P1 | Configuración congelada, trazabilidad completa y manual fiel al build |

## 1. Recuperar una base contable verificable

La exportación actual se mantiene intacta como evidencia. Para la siguiente captura desde MT5, producir tres conjuntos:

| Conjunto | Campos mínimos |
|---|---|
| Deals originales | Servidor/cuenta, moneda, tipo de cuenta, `deal_id`, `order_id`, `position_id`, `DEAL_ENTRY`, tipo, timestamp servidor con milisegundos, magic, símbolo, volumen, precio, profit, commission, swap, fee y motivo |
| Estado de posición y señal | Build/hash, hash de `.set`, símbolo/TF, señal y setup ID, entrada solicitada/ejecutada, SL0/TP0 confirmados, volumen inicial, R0 en precio/dinero, riesgo %, spread, slippage, indicadores de barras cerradas, OB/FVG/sweep IDs, offset horario |
| Cuenta y contrato | Balance/equity con fecha, depósitos/retiros/crédito, posiciones abiertas al inicio/final, contract size, tick size/value, volumen mínimo/paso/máximo, stops/freeze, modo de cálculo, conversión de moneda |

Conciliar por servidor + cuenta + deal ID y posición ID. Cada deal solo se contabiliza una vez. Costes de entrada y salida pertenecen a la misma posición; los ajustes no atribuibles se concilian a cuenta sin desaparecer del neto. Una reversión INOUT necesita repartir volumen/costes y distinguir cierre de apertura. Un parcial no aumenta el número de trades completos. Si falta la apertura o queda volumen abierto, clasificarlo como incompleto.

Comprobar la igualdad de balance inicial + movimientos externos + resultados/costes = balance final, con precisión de la moneda y explicación de cualquier diferencia. Equity necesita además valoración de posiciones abiertas. No reconstruirla solo con cierres.

El nuevo importador debe fallar claramente ante directorio vacío o datos inválidos, mostrar archivos/filas rechazados y impedir sobreescritura vacía accidental. CSV de MT5 y logs diagnósticos tienen funciones distintas: el primero concilia dinero, los segundos explican decisiones.

## 2. Reparaciones de riesgo antes de optimizar

Implementar un módulo compartido `.mqh` y dos wrappers finos Estándar/Micro. Conservar variantes solo por configuración explícita. Un build y preset deben identificar todo experimento.

1. Usar `InpMagicNumber`; crear una política explícita para posiciones heredadas con 777999. No dejar huérfanas las abiertas durante la migración.
2. Aislar gestión: magic propio y, si se habilita, manual magic 0. Nunca asumir que todo magic distinto es manual. Impedir dos instancias dueñas del mismo símbolo/posición.
3. Calcular SL técnico primero. Si está demasiado lejos para el presupuesto o límite aceptado, rechazar el setup; no acercarlo artificialmente al interior del OB para hacerlo caber.
4. Ajustar precios al tick y reglas del broker, recalcular pérdida por un lote con `OrderCalcProfit` en la dirección correcta y dimensionar volumen hacia abajo. Validar margen/filling y presupuesto después de normalizar. Si no cabe el lote mínimo, no abrir.
5. Persistir riesgo inicial y confirmar que SL realmente quedó instalado. Comparar riesgo posterior al fill contra tolerancia de slippage; registrar y aplicar política correctora previamente probada.
6. Validar `ResultRetcode`, volumen y deal ejecutados; una petición aceptada no significa operación terminada. Reintentos idempotentes con consulta del estado efectivo.
7. Centralizar riesgo por cuenta: entradas diarias, posiciones cerradas, pérdidas consecutivas, presupuesto simultáneo, pérdida diaria y drawdown total. Persistir el bloqueo y ajustar la base por flujos externos.
8. Bloquear entradas al alcanzar límites conservando la gestión de salidas. Si se exige liquidación por DD, implementar la política explícita y verificar cierre de cada ticket; no llamar a “apagar terminal” una pausa de entradas.

## 3. Salidas por posición y pruebas obligatorias

Una posición necesita `R0 = abs(precio_entrada_ejecutado - SL_inicial_confirmado)`, riesgo monetario inicial, volumen original, etapas ejecutadas y versión de política de salida. El ATR posterior puede ajustar un trailing, pero nunca redefinir R0.

Cada parcial debe tener identidad propia y basarse en volumen original cuando esa sea la especificación. Si el broker no permite fraccionar, registrar “no aplicable” y seguir la política alternativa, sin afirmar que se cobró. Separar protección del SL de realización del parcial para que ambas funcionen cuando el precio salta niveles.

Elegir entre TP final y runner: un TP fijo en 2.2R no puede coexistir como techo con un runner que empieza en 3R. Si TP=0 significa runner, tanto `CheckStops` como auto SL/TP deben respetarlo.

| Prueba MT5 | Resultado exigido |
|---|---|
| Cuenta pequeña y lote mínimo superior al presupuesto | Orden rechazada sin ejecución |
| Broker amplía distancia mínima del SL | Riesgo calculado sobre SL definitivo |
| Fill con slippage, rechazo o fill parcial | Estado y contador reflejan solo ejecución real |
| Saltos 0.4→1.4R y 0.4→2.3R | Etapas coherentes; sin perder ni duplicar parciales |
| ATR cambia tras apertura | Los niveles R0 no se desplazan |
| Reinicio/cambio de día con posición parcialmente cerrada | No repite parcial y conserva riesgo original |
| Dos cierres en el mismo segundo | Ambos conciliados por ID/milisegundo |
| Cuenta hedging y netting | Gestión compatible o bloqueo explícito del modo no soportado |
| Dos gráficos y posiciones manuales/otro EA | Sin doble propietario ni omisiones de riesgo de cuenta |
| DD alcanza límite y después equity recupera | Entradas siguen bloqueadas hasta reset autorizado por política |
| Spread alto, freeze level, mercado cerrado, datos incompletos | Gestión segura, rechazo explicado y sin falso “éxito” |
| Runner con TP cero | No se restablece un TP involuntario |

## 4. Especificación única de entradas

Crear una tabla de verdad para todos los filtros, en vez de inferirlos de comentarios. Definir separadamente tendencia, rango, ubicación, trigger y ejecución.

- Elegir barras cerradas H1/H4 y alineación exacta de timestamps. La confirmación del pivot llega después de sus barras derechas: nunca utilizarlo antes de ser conocido.
- Establecer si OB es obligatorio y FVG opcional, o confluencia OR. Los flags deben producir el comportamiento descrito. Un sweep bajista no valida una compra.
- Definir BOS y CHoCH distintos, TF de cada uno, igualdad de highs/lows con tolerancia explícita y SL de invalidación.
- Dar ciclo de vida a OB/FVG: creación, contacto, mitigación, invalidez, breaker y expiración. Reciclar arrays; reconstruir el mismo estado al reiniciar mediante replay causal.
- Corregir polaridad del breaker en Pine. Ocultar un dibujo no debe cambiar entradas.
- Alinear Pine/MT5 sobre fixtures de OHLC y luego cuantificar diferencias de feed. Las alertas deben usar barra confirmada; comparar resultados tras recarga.
- No llamar order flow a inferencias basadas solo en OHLC. Si se añade volumen real/delta, probarlo como experimento independiente con una fuente adecuada.

## 5. Experimentos para mejorar expectativa

Antes de cada experimento registrar hipótesis, parámetros, fechas, instrumento, coste, métrica principal y criterio de aceptación. Mantener fijo el riesgo nominal para comparar; no atribuir a una señal una ganancia causada por subir lotaje. Todos estos candidatos son hipótesis, no optimizaciones ya demostradas.

| Experimento | Comparación limitada | Qué resuelve |
|---|---|---|
| A. Salida base | TP completo 2.2R, sin parciales, versus 50% a 1R y resto a 2.2R, versus 50% a 0.5R y resto a 2.2R | Si Micro-Lock compensa la pérdida de payoff después de costes |
| B. Ubicación del SL | ATR de entrada versus invalidación estructural + buffer | Si el techo fijo del oro fuerza stops dentro del ruido |
| C. Tendencia | H1 confirmado versus H1+H4; rango en estrategia separada | Valor incremental del filtro, evitando mezclar seguimiento y reversión |
| D. Sesión | Dos ventanas predefinidas versus sesión más amplia con igual control de costes | Si mejora fuera de muestra; no elegir cada hora ganadora del histórico |
| E. Coste relativo | Umbral predefinido de coste estimado/R0, no solo spread absoluto | Cuándo una señal pequeña deja de compensar ejecución |
| F. Tiempo | Sin salida temporal versus 4/8 barras, con regla definida antes de observar resultado | Efecto causal sobre trayectoria de cada posición |
| G. Frecuencia | Máximo 3 entradas por cuenta y sin add-ons versus política base | Si mejora DD y expectativa por unidad de riesgo |

Para A, antes de costes y bajo trayectorias simples, el payoff de alcanzar todas las salidas es 2.2R, 1.6R y 1.35R respectivamente. Eso no determina cuál gana: hacen falta probabilidades de tocar cada nivel y resultado tras BE.

Orden sugerido: A después de corregir gestión; B y C después de corregir SMC; D/E cuando existan horarios y costes fiables; F/G como pruebas posteriores. Evitar el producto cartesiano de todos los parámetros.

### Instrumentos candidatos

EURUSD estándar y GOLDmicro son candidatos de investigación por señal preliminar y volumen de muestra, respectivamente. GOLDmicro **no está validado rentable**. USDJPYmicro puede ser tercer candidato si los costes y contratos se concilian. Mantener separados EURUSD/EURUSDmicro y USDJPY/USDJPYmicro.

No priorizar expansión a GBPUSDmicro, cripto, índices o commodities con este historial. Eso es una decisión para reducir el número de experimentos, no una afirmación universal de que esos mercados carecen de ventaja. Un contrato estándar solo es candidato ejecutable si el lote mínimo cabe en el presupuesto real.

## 6. Validación estadística y promoción

La muestra ya se ha usado para proponer filtros y horarios; **ningún tramo ya inspeccionado debe presentarse ahora como holdout virgen**. Se puede usar para depurar y explorar, siempre marcado como desarrollo. Reservar datos adicionales no vistos y registrar prospectivamente nuevas operaciones. Probar muchas variantes sobre el mismo histórico eleva el riesgo de sobreajuste; el protocolo propuesto responde a ese problema, estudiado por [Bailey y colaboradores](https://scholarworks.wmich.edu/math_pubs/42/).

Protocolo propuesto:

1. Compilar en MetaEditor sin errores, revisar warnings y guardar build, log y SHA. El backtest se ejecuta con el mismo fuente/preset que el forward.
2. Replay con ticks reales disponibles, spread variable, comisión, swap, slippage y stops/filling del símbolo. Si una barra alcanza SL y TP y faltan ticks, marcar ambigüedad en vez de elegir la salida favorable.
3. Validación temporal walk-forward con períodos suficientes para varios regímenes; separar/embargar posiciones que crucen fronteras de datos. Registrar todas las variantes probadas.
4. Medir P&L neto, expectativa en R, PF, DD de equity, cola de pérdidas, exposición, MAE/MFE, coste/R, ejecución y número de posiciones independientes. Segmentar por versión, cuenta, símbolo, setup, dirección, sesión y TF sin convertir cada celda en regla.
5. Estimar incertidumbre mediante bootstrap por bloques de días/semanas y sensibilidad a peores/mejores posiciones. No suponer que parciales o operaciones cercanas son independientes.
6. Estresar costes (por ejemplo, 1.5× y 2× los observados) y perturbaciones cercanas de parámetros. Preferir una zona estable de resultados a un máximo aislado.

**Puerta de promoción propuesta**, a fijar antes de datos nuevos: cero fallos críticos de ejecución; expectativa neta positiva en datos no vistos; PF neto objetivo ≥1.20 y >1 bajo estrés moderado; límite inferior del intervalo de expectativa por bloques >0; DD dentro del presupuesto acordado y sin depender de una sola operación. Estos umbrales son criterios de trabajo, no una certificación estadística por sí solos.

Primeras 50 posiciones nuevas: validación operativa y de captura. Después, revisar un mínimo orientativo de 200 posiciones independientes y 8–12 semanas; puede requerirse más tiempo/muestra para separar señal de ruido. Alcanzar el número no acredita ventaja si la incertidumbre sigue siendo grande. No forzar entradas para completar cuota.

## 7. Propuesta para actualizar el plan y la guía al final

La actualización oficial se realiza cuando coincidan especificación, build, preset y resultados. Hasta entonces, esta es la propuesta de contenido, pendiente de implementación y validación:

| Sección | Cambio concreto propuesto |
|---|---|
| Estado del sistema | “En validación técnica y estadística”; retirar “aprobado para cuentas reales e institucionales” hasta tener evidencia |
| Objetivo | Sustituir promesa/expectativa de 4–8% mensual por criterios de aceptación netos y DD verificables |
| Riesgo | Como perfil de validación, evaluar 0.25% por posición y 0.5% de riesgo inicial simultáneo; si mínimo de broker no cabe, omitir. Son presupuestos provisionales, no parámetros optimizados |
| Límites de cuenta | Mantener 3 entradas/día, 2 pérdidas de posiciones completas y definir 1% diario para perfil conservador de validación; conservar 6% total como tope de pausa sujeto a implementación persistente |
| Sesiones | Dos ventanas explícitas, inicialmente 01:15–05:30 y 06:30–11:30 America/Mexico_City como hipótesis operativa. No presentarlas como “horas óptimas” hasta verificar offsets y cambios estacionales de mercados |
| Entradas | Escribir exactamente la regla elegida, TF, barra de confirmación, tolerancias y uso de SMC; separar tendencia y rango |
| SL | Precio de invalidación antes de dimensionar; diferencia entre movimiento de cotización y pérdida monetaria |
| Salidas | Una política congelada por experimento; porcentajes referidos al volumen inicial, R0 fijo, fallback de lote mínimo y TP/runner explícitos |
| Break-even | Reemplazar “riesgo cero” por SL de protección sujeto a costes, ejecución y gaps |
| Noticias | Identificar calendario/fuente y política ante datos ausentes; no atribuir anticipación de noticias al ATR |
| Parada | Bloquear nuevas entradas y conservar gestión; procedimiento distinto para liquidación, reinicio y recuperación |
| Rendimiento | Tabla por posición y versión con costes, tamaño de muestra y período; etiquetar histórico FIFO como estimado |
| Manuales y panel | Un documento fuente vigente con HTML regenerado, banner de versión y fecha de datos; métricas dinámicas, precios con dígitos del símbolo y cuenta identificada |
| Legado | Archivar versiones antiguas como históricas, evitando que se confundan con configuración vigente |

### Guía operativa propuesta

Antes de la sesión: verificar build/preset, cuenta/símbolo, reloj y offset, disponibilidad de datos, noticias, riesgo disponible y estado de bloqueos. Confirmar quién gestiona posiciones manuales y heredadas.

Antes de cada entrada: señal cerrada y trazable, regla/versión identificadas, SL técnico válido, lote y margen dentro de presupuesto, coste relativo aceptable y ausencia de conflictos. No abrir si falta una condición obligatoria.

Durante la posición: verificar ejecución y SL confirmado; evaluar hitos sobre R0; registrar parcial real, rechazo y modificación. Nunca reiniciar para eludir límites ni desplazar SL para aumentar pérdida autorizada.

Después del cierre completo: sumar todos los deals y costes, calcular R realizado, actualizar racha y presupuesto de cuenta, clasificar motivo y cumplimiento. Un parcial no termina el trade.

Al final de la sesión: conciliar resultados y posiciones abiertas, revisar errores, guardar bitácora y snapshot. No cambiar parámetros por una pérdida aislada. Revisar cada experimento en la fecha o tamaño de muestra predefinidos.

## 8. Entregables y estado actual

- Completado: revisión estática, matriz plan/código, recálculo de 893 filas, contraste CSV/JSON, identificación de concentración y límites de inferencia.
- Completado: script reproducible independiente y reportes de auditoría; histórico preservado.
- Pendiente: estado de cuenta/deals originales con IDs/costes, `.set` y versión activa.
- Pendiente: correcciones de EA/Pine, compilación nativa y pruebas MT5, experimentos fuera de muestra y forward.
- Preparado: contenido de actualización del plan y guía; los documentos oficiales todavía describen el estado previo y no deben confundirse con esta propuesta.

## 9. Optimización técnica secundaria

Después de las correcciones funcionales, perfilar el EA con varios gráficos y una misma carga de ticks. Reutilizar buffers y snapshots coherentes; evitar recalcular extremos H1 en `IsInZone` y `CheckLiquidityTrap` cuando ya están en caché; actualizar ATR cerrado por barra y cotizaciones por tick según necesidad. Eliminar recreación repetitiva de rectángulos y escribir etiquetas solo cuando cambien. Limitar logs redundantes y conservar eventos estructurados de ejecución. Medir tiempo por evento y peticiones al servidor antes/después: menos CPU no acredita más P&L.

Separar el módulo de riesgo, ejecución, estado de posiciones, señales SMC, sesiones y UI. Unificar importadores de historial, usar rutas configurables y generar todas las métricas del dashboard desde datos. Fijar dependencias de visualización y mantener builds en directorio separado; un despliegue solo puede tomar un binario recién compilado cuya fuente/preset estén identificados.
