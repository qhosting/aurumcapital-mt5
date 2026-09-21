# Manual Técnico y Operativo: AurumClassicSniper EA (MT5)

## 1. Visión General
**AurumClassicSniper** es un Asesor Experto (EA) institucional para MetaTrader 5 desarrollado íntegramente a partir del análisis y codificación rigurosa de tres obras de referencia:
1. **Módulo 2 (World Capital / Kevin Rubio)**: Principios de Análisis Técnico Clásico, Teoría de Dow, Dinámica de Canales, Principio Abanico, y Reconocimiento Geométrico de Modelos de Giro (HCH, Doble/Triple Techo-Suelo) y Continuidad (Triángulos, Banderas/Banderines).
2. **Libro Opwens**: Formación de Velas Japonesas y Gatillos de Acción del Precio de Alta Probabilidad (*Hammer*, *Shooting Star*, *Engulfing*, *Tweezer Tops/Bottoms*, *Morning/Evening Stars*, *Three White Soldiers/Black Crows*, *Three Inside Up/Down*).
3. **Forex Trading Blueprint**: Estructura de Órdenes Pendientes/Mercado, Matemática de Pips, Dimensionamiento Dinámico de Posición por Riesgo Porcentual Fijo (Regla del 1.0%) y Preservación de Capital.

---

## 2. Arquitectura de Código

```
Include/
  └── AurumClassic/
        ├── AurumTrendGeometry.mqh     # Fractales Swings, Directrices, Canales, Abanicos y Fibonacci
        ├── AurumCandleTriggers.mqh    # Detector cuantitativo de las 14 formaciones candlestick de Opwens
        ├── AurumClassicPatterns.mqh   # Reconocimiento de HCH, Dobles/Triples, Triángulos y Banderas
        └── AurumClassicRisk.mqh       # Gestión de riesgo institucional 1%, Pre-Flight y Órdenes
AurumClassicSniper.mq5                 # Asesor Experto (Robot Autónomo) con Dashboard HUD
AurumClassicVisualizer.mq5             # Indicador Gráfico para Proyectar Figuras y Señales en Vivo
```

---

## 3. Modos de Ejecución Disponibles

El EA permite seleccionar entre 3 filosofías de entrada a través del input `InpExecutionMode`:

1. **`EXEC_PULLBACK_CANDLE` (Recomendado / Conservador)**:
   - Espera que el precio rompa la directriz o línea de cuello (*Neckline*) y realice un retroceso (*Pullback* o *Throwback*).
   - En la zona de retesteo (dentro de un radio de 15 pips), escanea en barra cerrada un gatillo de vela japonesa del Libro Opwens (*ej. Martillo de rechazo o Vela Envolvente*).
   - Entra a mercado solo cuando la vela confirma el rechazo.

2. **`EXEC_BREAKOUT_MARKET` (Ruptura Confirmada)**:
   - Espera que una vela completa cierre claramente por fuera de la línea de cuello / directriz del patrón.
   - Dispara inmediatamente a mercado al abrir la siguiente barra.

3. **`EXEC_BREAKOUT_PENDING` (Ruptura Dinámica por Órdenes Stop)**:
   - Coloca órdenes pendientes institucionales `Buy Stop` o `Sell Stop` milimétricamente en la línea de cuello del patrón activo, con su SL y TP pre-programados.

---

## 4. Gestión de Riesgo y Salidas

- **Cálculo de Lote Dinámico (1.0% Blueprint Rule)**:
  El EA lee el balance de la cuenta, la distancia exacta al Stop Loss estructural en pips y el valor del tick del broker para calcular el tamaño de lote exacto:
  $$\text{Riesgo en Divisa} = \text{Balance} \times \frac{\text{RiskPercent}}{100}$$
  $$\text{Lote} = \frac{\text{Riesgo en Divisa}}{\text{Distancia al SL en Ticks} \times \text{Tick Value}}$$
- **Take Profit por Proyección Técnica ($H$)**:
  Calcula la distancia vertical $H$ de la formación geométrica (ej. altura de la cabeza al cuello en HCH, altura de la base en triángulos, longitud del mástil en banderas) y la proyecta desde el punto de quiebre.
- **Protección Breakeven a 1R**:
  Cuando el precio avanza una distancia equivalente al riesgo inicial (+1R), el Stop Loss se mueve automáticamente a precio de apertura protegiendo el trade y bloqueando el spread.
- **Daily Risk Guard (Hard Circuit Breaker)**:
  Pausa automática de operaciones si la pérdida diaria acumulada alcanza el límite configurado (porcentaje o dólares) o tras 3 pérdidas consecutivas.

---

## 5. Parámetros Principales (Inputs)

| Grupo | Parámetro | Default | Descripción |
|---|---|---|---|
| **Gestión de Riesgo** | `InpRiskPercent` | `1.0` | Riesgo fijo por trade (% del balance) |
| | `InpUseDailyGuard` | `true` | Activar disyuntor de pérdida diaria |
| | `InpMaxDailyLossPct` | `3.0` | Máxima pérdida porcentual diaria permitida |
| | `InpMaxDailyLossUSD` | `150.0` | Máxima pérdida en USD diaria permitida |
| | `InpMaxSpread` | `25` | Spread máximo tolerado en puntos |
| **Modelos Cartistas** | `InpTradeHCH` | `true` | Operar Hombro-Cabeza-Hombro y HCH Invertido |
| | `InpTradeDoubleTopBottom`| `true` | Operar Dobles/Triples Techos y Suelos |
| | `InpTradeTriangles` | `true` | Operar Triángulos (Simétrico, Ascendente, Descendente)|
| | `InpTradeFlags` | `true` | Operar Banderas y Banderines con mástil |
| **Ejecución & Gatillo**| `InpExecutionMode` | `EXEC_PULLBACK_CANDLE` | Modo de entrada (Pullback, Breakout o Pendiente) |
| | `InpRequireCandleConfirm`| `true`| Exigir confirmación por vela japonesa de Opwens |
| | `InpUseTechnicalTargetH` | `true` | Usar proyección técnica de altura $H$ como TP |
| | `InpUseBreakevenAt1R` | `true` | Mover a Breakeven al alcanzar +1R |
| **Sesiones Horarias** | `InpUseSessionFilter` | `true` | Operar solo en sesiones con volumen institucional |
| | `InpStartHour` / `InpEndHour` | `2` a `17` | Ventana horaria (Londres a cierre de Nueva York)|

---

## 6. Instalación y Uso en MetaTrader 5

1. Los archivos ejecutables compilados ya están listos en la carpeta de MetaTrader 5:
   - **Robot (EA)**: `MQL5\Experts\AurumClassicSniper.ex5`
   - **Indicador**: `MQL5\Indicators\AurumClassicVisualizer.ex5`
2. En MetaTrader 5:
   - Abre un gráfico de un par mayor de Forex (*ej. EURUSD, GBPUSD*) o materias primas (*XAUUSD / Oro*) en temporalidad **M15** o **H1**.
   - Arrastra **`AurumClassicSniper`** desde el Navegador (sección *Asesores Expertos*) hacia el gráfico.
   - Asegúrate de habilitar la casilla **"Permitir trading algorítmico"** en la pestaña *Común*.
   - El dashboard aparecerá en la esquina superior izquierda mostrando el estado de escaneo, el patrón activo, los niveles de cuello/target y la gestión de riesgo en vivo.
