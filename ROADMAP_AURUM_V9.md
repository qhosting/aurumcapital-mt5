# Roadmap de Optimización AurumSniper V9

Este documento detalla el plan de acción para implementar las mejoras críticas y nuevas funcionalidades en el Asesor Experto AurumSniper V9.

## Objetivos Principales
1. **Estabilidad y Rendimiento**: Eliminar el "repintado" y optimizar el consumo de recursos.
2. **Seguridad del Capital**: Implementar filtros de spread y mejorar la gestión de entradas.
3. **Adaptabilidad**: Hacer que el EA se ajuste automáticamente al timeframe (M1/M5) e indicadores.

## Tareas Pendientes

### 1. Correcciones Críticas (Estabilidad)
- [x] **Implementar `IsNewBar()`**: Asegurar que la lógica de trading solo se evalúe al cierre de la vela para evitar repintado.
- [x] **Optimizar `HayNoticia()`**: Restringir la ejecución del filtro de noticias a la apertura de nueva vela para evitar saturación de CPU/Red.
- [x] **Mover Webhook**: Asegurar que el Webhook solo se envíe tras la confirmación de una operación exitosa.

### 2. Gestión de Riesgo y Filtros
- [x] **Filtro de Spread**: Agregar `InpMaxSpread` y validación antes de abrir operaciones.
- [x] **Referencia de Tendencia H1**: Cambiar la EMA de referencia a H1 para mayor solidez en la detección de tendencias.
- [x] **Normalización de Precios**: Asegurar que SL y TP estén normalizados correctamente (`NormalizeDouble`).

### 3. Adaptabilidad y Lógica Dinámica
- [x] **Inicialización Dinámica (`OnInit`)**: Configurar indicadores (RSI, ATR, ADX) para usar `_Period` (timeframe actual) en lugar de fijo a M5.
- [x] **Patrones Universales**: Actualizar `GetPatternName` para detectar patrones en el timeframe actual (`_Period`).
- [x] **"Cerebro" Dinámico (`OnTick`)**: Ajustar `LotSize` y `ADXThreshold` automáticamente según si se opera en M1 o M5.
   - M1: ADX > 25, Lote base.
   - M5: ADX > 20, Lote x2.

## Estado Actual
- [x] Análisis inicial completado.
- [x] Código base revisado.
- [x] Implementación de tareas completada en V10.
