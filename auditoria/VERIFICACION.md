# Verificación de la auditoría

Fecha: 2026-09-13. Base: `0d3e466`; implementación V15 sin commit separado.

Comprobaciones ejecutadas correctamente:

- Recálculo con `python3 tools/review_export.py`; CSV y JSON coinciden fila a fila tras normalizar nombres de campos.
- 893 fragmentos, suma exacta decimal −331.45, PF por signo 0.7547467184.
- Cada agrupación por cuenta, símbolo, dirección, mes de entrada/cierre, duración, hora y día conserva las 893 filas y el mismo P&L agregado.
- Caso pequeño independiente con +1, −0.50 y −0.01 etiquetado BE: neto 0.49 y PF 1/0.51. Entrada vacía produce métricas no definidas, no PF ficticio de 999.
- Reproducción con el auditor existente: dos deals de APERTURA hedging, BUY en posición A a 100 y SELL en posición B a 101, generan un cierre FIFO ficticio de +1 USD. Demuestra la limitación de reconstrucción; no demuestra que todos los trades reales tengan ese error.
- Evaluación de la cadena de fases con defaults: +1.3R entra en fase 1.5; fase 1 no se alcanza en recorrido 0–5R. Verificado también por desigualdades en el código: el umbral 1.0 precede al 1.3.
- Sintaxis Python válida mediante `ast.parse` en los siete scripts del repositorio, incluido el nuevo auditor. Eso no valida sus algoritmos ni equivale a pruebas de MT5.
- Búsqueda de `.log`, `.set` y `.ini` incluyendo archivos ignorados: no se encontraron dentro del proyecto.
- Comparación de fuentes Estándar/Micro: mismas funciones; diferencias limitadas a encabezados e inputs magic/lote.
- Verificación de firmas y semántica con documentación oficial de MetaQuotes/TradingView, enlazada en el diagnóstico.
- `python3 tools/run_checks.py`: 10 pruebas del ledger, análisis AST y 20,000 invariantes de volumen compartido pasan.
- `scratch/generate_dashboard_html.py` genera un dashboard autónomo en una ruta temporal y `git diff --check` no detecta errores.
- El reconciliador rechaza el CSV FIFO histórico, conserva IDs/costes en el esquema nativo y cubre parciales, coberturas y reversas `INOUT`.

No ejecutado: compilación nativa MQL5, compilación Pine, Strategy Tester, replay de ticks, conexión al broker o ejecución de órdenes. MetaEditor y Wine no se encontraron en PATH; el script PowerShell de despliegue apunta a otra máquina Windows.

Se preservaron los archivos de trading, binarios, CSV/JSON originales y los manuales previos. Los wrappers V15, motor compartido, exportador, reconciliador, presets, dashboard y guías nuevas son cambios de implementación; no se copió ningún binario al terminal. Un `.DS_Store` no relacionado apareció como archivo sin seguimiento y se dejó intacto.
