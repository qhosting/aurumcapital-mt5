# Implementación Aurum V15

Fecha de esta revisión: 13 de septiembre de 2026. V15 es un build de validación técnica; no es una certificación de rentabilidad ni está desplegado en un terminal.

## Qué quedó implementado

- `AurumSniper.mq5` y `AurumSniperMicro.mq5` son wrappers mínimos sobre `Include/AurumEngine.mqh`; el cálculo de volumen comparte `Include/AurumMath.mqh` con las pruebas C++.
- El riesgo usa pérdida monetaria de `OrderCalcProfit`, lote redondeado hacia abajo y rechazo cuando el lote mínimo excede el presupuesto. El presupuesto considera posiciones de toda la cuenta, margen, órdenes pendientes y un margen configurable de coste.
- La propiedad se limita al magic configurado. Las posiciones manuales y el magic heredado se dejan fuera salvo adopción explícita. Se bloquea una segunda instancia sobre la misma cuenta y símbolo.
- La entrada usa exclusivamente velas cerradas M15, EMA H1/H4 cerradas, RSI/ADX, rango H1, OB/breaker y replay causal acotado. El estado de posición guarda R0, volumen inicial y SL original; no reconstruye el riesgo con el ATR actual.
- Los límites diarios, racha de pérdidas, drawdown diario y drawdown total se guardan como estado de cuenta. Una respuesta incierta del servidor fija un bloqueo de ejecución que requiere conciliación manual.
- Parciales, break-even, runner y trailing son políticas explícitas y opcionales. La intención de un parcial se persiste antes de enviar la petición para impedir cierres dobles después de un reinicio.
- `tools/ExportAurumHistory.mq5` genera deals nativos con IDs y costes. `tools/reconcile_deals.py` reconstruye por `position_id`, separa coberturas, marca faltantes y no presenta un CSV FIFO como auditoría conciliada.
- El indicador Pine V15 es un candidato OHLC para investigación. No tiene acceso a spread, margen, noticias ni ejecución y sus alertas nunca son órdenes.
- Los presets en `presets/` mantienen `InpAllowLiveTrading=false` y bloquean entradas hasta indicar offset UTC del servidor y cobertura de noticias.

## Secuencia obligatoria de validación

1. En un PC con MetaEditor, ejecutar `scratch/compile_and_deploy.ps1` indicando explícitamente el Editor y la carpeta estándar `MQL5/Include`. El script compila en un directorio fechado, comprueba `0 errors, 0 warnings`, guarda hashes y no copia binarios al terminal.
2. Ejecutar `python3 tools/run_checks.py`. Esta comprobación cubre el reconciliador, las invariantes de volumen y la sintaxis Python; no sustituye a MetaEditor, TradingView ni al Strategy Tester.
3. En MT5 demo, exportar `aurum_deals.csv` y el snapshot de cuenta. Ejecutar `python3 tools/reconcile_deals.py aurum_deals.csv --output audit-v15.json`. Si se conocen los saldos antes/después, añadir ambos valores para obtener una diferencia explícita; el snapshot actual por sí solo no es un saldo histórico.
4. Probar cada preset en “Every tick based on real ticks”, con comisión, swap, spread variable, slippage, modo hedging y fechas fuera de muestra. Guardar el reporte junto con fuente, preset, build y hashes.
5. Hacer forward demo sin cambiar parámetros durante las primeras 50 posiciones. Revisar primero captura de deals, SL inicial, retcodes, parciales y bloqueos; solo después medir expectativa neta.

## Límites conocidos

No se pudo hacer la compilación MQL5 ni el replay de TradingView en este entorno porque no hay MetaEditor/terminal de escritorio. Los `.ex5` antiguos no se reemplazaron y no son compatibles con esta implementación. La estrategia V15 simplifica el modelo anterior: no conserva los gatillos micro/range heredados ni afirma order flow a partir de OHLC. La equivalencia Pine/MT5 queda pendiente de fixtures de velas y feeds del broker.

Las exportaciones `scratch/trade_history_complete.csv/json` permanecen inmutables y sus métricas siguen siendo estimaciones históricas. No se debe usar su PF 0.75, win rate ni los objetivos mensuales antiguos para activar una cuenta real.
