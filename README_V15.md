# Aurum V15: guía de instalación y validación

V15 es una implementación de investigación para MT5. Arranca en modo seguro: las entradas reales están desactivadas, el offset del servidor es obligatorio y falta un archivo de cobertura de noticias.

## Fuentes

- `AurumSniper.mq5` y `AurumSniperMicro.mq5`: wrappers para los perfiles estándar y micro.
- `Include/AurumEngine.mqh` y `Include/AurumMath.mqh`: motor y aritmética compartidos.
- `tools/ExportAurumHistory.mq5`: exportador nativo de MT5.
- `tools/reconcile_deals.py`: conciliación por deals/posiciones, con costes.
- `presets/*.set`: perfiles de validación. Todos requieren revisar offset, símbolo y contrato.

## Instalación en un terminal de prueba

Copiar los dos `.mq5` y la carpeta `Include/` a `MQL5/Experts/AurumV15/`. Copiar `aurum_news.csv` al directorio `MQL5/Files/` con una primera fila `coverage,AAAA.MM.DD HH:MM,AAAA.MM.DD HH:MM` y después `timestamp,currency,importance`. La cobertura ausente bloquea entradas.

Compilar únicamente con `scratch/compile_and_deploy.ps1`. El binario debe ser recién generado para esa fuente y preset; los `.ex5` incluidos en el repositorio son artefactos antiguos y no deben cargarse.

## Primer arranque

Usar una cuenta demo hedging en M15, indicar el offset UTC real del servidor y establecer una línea base de equidad verificada en las entradas `InpInitialDayEquity` e `InpInitialPeakEquity` cuando se conecte por primera vez a una cuenta real. Mantener `InpAllowLiveTrading=false` durante la validación. No activar `InpManageManualTrades` ni `InpManageLegacyMagic` sin una conciliación explícita de posiciones existentes.

El tester o forward debe usar ticks reales, costes del broker y el mismo preset. Guardar el log estructurado `A15.*.events.*.csv`, el reporte y los hashes del build. No cambiar el riesgo o la salida para completar una cuota de operaciones.

## Criterio para pasar a la siguiente fase

Primero cero fallos críticos de ejecución y conciliación reproducible. Luego expectativa neta positiva fuera de muestra, PF neto objetivo al menos 1.20 bajo costes observados y estable bajo estrés, drawdown dentro del presupuesto y sin dependencia de una sola operación. Estos criterios son una puerta de investigación; no garantizan beneficios.
