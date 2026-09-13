# 🦅 AURUM VISION [BETA] — Manual Táctico e Institucional de Estrategia
> **Aviso de versión:** este manual describe la versión previa y queda archivado para referencia. Para instalación y operación use el perfil V15 documentado en `auditoria/IMPLEMENTACION_V15.md`; el EA no debe conectarse a una cuenta real hasta completar compilación nativa, Strategy Tester y forward en demo.
**Versión del Sistema:** V12.0 BETA (SMC & Institutional Order Flow Edition)  
**Plataformas:** TradingView (Visualizador de Estructura) & MetaTrader 5 (Ejecución AurumSniper)  
**Fecha de Publicación:** Septiembre 2026  
**Auditoría Previa:** Validado sobre 868 operaciones reales (Cuentas MT5 XM Global)

---

## 🧭 1. Resumen Ejecutivo y Filosofía Institucional

El sistema **Aurum Vision [BETA]** fusiona la precisión del scalping algorítmico con la arquitectura de **Smart Money Concepts (SMC)** e **Ingeniería de Liquidez Institucional**, basada en los motores analizados de `SMC.txt` (LuxAlgo Pro) y `OB.txt` (VEGA OB/Breakers).

A diferencia del trading minorista tradicional que reacciona a indicadores rezagados, este sistema opera siguiendo la huella de las grandes instituciones bancarias:
1. **Seguir la Liquidez:** Las instituciones necesitan contrapartida para llenar millones de dólares en órdenes. El mercado siempre se moverá hacia donde están acumulados los Stop Losses del retail (Equal Highs / Equal Lows).
2. **Entrar en Zonas de Descuento / Premium:** Comprar barato (Discount < 50% del rango) y vender caro (Premium > 50% del rango).
3. **Confirmación Estructural Dual:** No adivinamos giros; esperamos un **CHoCH (Change of Character)** o una reacción precisa a un **Orderblock (OB)** o **Breaker Block**.
4. **Disciplina de Francotirador:** Máximo **3 operaciones al día**, exclusivamente dentro de las **Killzones oficiales (Londres / NY Overlap)**.

---

## 🧬 2. Los 6 Pilares Algorítmicos del Sistema (Arquitectura SMC + OB)

```mermaid
graph TD
    A[AURUM VISION BETA] --> B[1. Estructura de Mercado: Swing & Internal]
    A --> C[2. Bloques de Órdenes: OB & Breaker Blocks]
    A --> D[3. Desequilibrios: Fair Value Gaps FVG]
    A --> E[4. Piscinas de Liquidez: EQH / EQL]
    A --> F[5. Rango y Precio Justo: Premium / Discount]
    A --> G[6. Aurum Shield: Gestión de Riesgo y Killzones]

    B --> B1[BOS: Continuación | CHoCH: Cambio de Carácter]
    C --> C1[OB: Última vela contraria | Breaker: OB fallido que invierte polaridad]
    D --> D1[Imbalance de 3 velas: Imán de retest]
    E --> E1[Double Tops/Bottoms: Caza de Stops previa al impulso]
    F --> F1[Equilibrio 50%: Compras en Descuento, Ventas en Premium]
    G --> G1[1% Riesgo, SL 1.5 ATR, Killzone CDMX 01:15-11:30]
```

---

### Pilar 1: Estructura de Mercado y Cambios de Carácter (BOS vs CHoCH)
Basado en la lógica algorítmica de `SMC.txt`, distinguimos dos niveles de estructura:
* **Swing Structure (Macro H1):** Determina la dirección primaria (Corriente mayor).
* **Internal Structure (Micro M15/M5):** Identifica las entradas tácticas y gatillos de ejecución.

| Evento Estructural | Símbolo Gráfico | Definición Algorítmica | Implicación Operativa |
| :--- | :---: | :--- | :--- |
| **BOS (Break of Structure)** | `⎯⎯⎯ BOS` | Cierre de vela por encima de un Swing High previo (alcista) o por debajo de un Swing Low previo (bajista). | **Confirmación de tendencia.** Buscamos sumarnos al retroceso. |
| **CHoCH (Change of Character)** | `---- CHoCH` | Ruptura del último mínimo estructural que generó un nuevo máximo (en compras), o viceversa. | **Alerta temprana de giro.** Primera señal de cambio de tendencia. |
| **Strong / Weak High & Low** | `Strong High / Weak Low` | Un máximo que logró romper estructura previa es **Fuerte** (difícil de romper). Un mínimo que no rompió es **Débil** (objetivo de liquidez a cazar). | Los Stop Loss se protegen detrás de niveles **Strong**. |

---

### Pilar 2: Bloques de Órdenes (Order Blocks) y Breakers
Integrando la formulación matemática de `OB.txt` y `SMC.txt`:

#### A. Order Block Tradicional (OB)
* **Bullish OB:** La última vela bajista antes del impulso institucional que rompió el último Swing High (`bullishMSB`).
* **Bearish OB:** La última vela alcista antes de la caída institucional que quebró el último Swing Low (`bearishMSB`).
* **Regla de Mitigación:** Cuando el precio regresa y toca el cuerpo o el 50% de esa vela (sin cerrarla en contra), el bloque se considera mitigado y actúa como un resorte de alta probabilidad.

#### B. Breaker Block (Inversión de Polaridad - Motor `OB.txt`)
* ¿Qué sucede cuando un Order Block alcista falla y es perforado hacia abajo con fuerza?
* El bloque institucional **no desaparece**: se transforma automáticamente en un **Bearish Breaker Block** (Resistencia).
* Cuando el precio suba a testearlo por debajo, esa zona de soporte quebrada se convierte en un techo institucional donde buscaremos **ventas masivas**.
* **Chop Control:** Si el precio cruza una zona más de 2 veces en consolidación lateral, el sistema anula el bloque para evitar trampas en rango.

---

### Pilar 3: Desequilibrios de Precio (Fair Value Gaps - FVG)
Un FVG representa una ineficiencia en la entrega del precio generada por órdenes agresivas de algoritmos de alta frecuencia (HFT).
* **Definición:** Patrón de 3 velas consecutivas donde la mecha de la vela 1 no se solapa con la mecha de la vela 3.
* **Comportamiento:** El mercado actúa como la naturaleza: **aborrece el vacío**. El precio tiende a regresar a rellenar el 50% del FVG (Consecutive Imbalance) antes de reanudar el movimiento.
* **Uso Táctico:** Si un Orderblock coincide espacialmente con un FVG (Confluencia OB + FVG), la probabilidad de rebote supera el **75%**.

---

### Pilar 4: Piscinas de Liquidez (Equal Highs / Equal Lows - EQH / EQL)
* **El Engaño del Doble Techo / Doble Suelo:** El retail piensa que dos máximos idénticos son una "fuerte resistencia para vender".
* **La Visión Institucional:** Dos máximos iguales (`EQH`) son un imán de liquidez lleno de miles de Stop Losses (órdenes de compra por stop).
* **El Gatillo Sniper (Liquidity Sweep):** Esperamos a que el precio perfore falsamente los `EQH`/`EQL` (toma de liquidez o trampa 🪤) y vuelva a cerrar dentro del rango con un **CHoCH**. Ese es el disparo institucional.

---

### Pilar 5: Zonas de Equilibrio, Descuento y Premium
Antes de operar, el algoritmo calcula el rango activo (Trailing Extremes):
$$\text{Equilibrio (EQ)} = \frac{\text{Máximo del Rango} + \text{Mínimo del Rango}}{2}$$
* **Zona Premium (> 50%):** El activo está "caro". **PROHIBIDO COMPRAR**. Solo se permiten Ventas en Orderblocks / Breakers superiores.
* **Zona Descuento (< 50%):** El activo está "barato". **PROHIBIDO VENDER**. Solo se permiten Compras en Orderblocks / Breakers inferiores.
* *Este filtro evita comprar en la punta superior de una tendencia o vender en el piso de una caída.*

---

## 📊 3. Parámetros Optimizados por Activo (Basado en la Auditoría de 868 Trades)

La auditoría demostró que cada par tiene una dinámica única. No se deben aplicar configuraciones universales:

| Par de Divisas / Activo | Temporalidad Entrada | Sesión Permitida (CDMX) | Win Rate Auditado | Target Óptimo | Stop Loss Sugerido |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **`USDJPYmicro`** 🏆 | **M15** | 01:15 AM - 05:30 AM (Londres) | **72.7%** | +1.8R a +2.2R | 15 - 20 pips detrás del OB |
| **`EURUSDmicro` / `EURUSD`** 🏆 | **M15 / H1** | 01:15 AM - 11:30 AM (Londres/NY) | **70.6% a 87.5%** | +2.0R a +3.0R | 18 - 25 pips detrás del Swing |
| **`GOLDmicro`** | **M15** | 06:30 AM - 11:30 AM (NY Overlap) | **60.7% a 78.6%** | Fase 1: +1.0R / Fase 2: +1.8R | $10.00 min / $18.00 max (ATR) |
| **`GBPUSD` (Estándar)** | **H1 (Swing)** | 01:15 AM - 05:30 AM (Londres) | **60.0% a 75.0%** | +2.5R | 25 - 35 pips (prohibido scalping M1) |
| **`BTCUSD`** | ⚠️ En Pausa | Fin de semana Prohibido | 40.0% | Solo setups H4/D1 | Muy amplio por volatilidad |

---

## 🎯 4. Protocolo de Ejecución Paso a Paso (Checklist Sniper)

Para abrir cualquier trade (manual o por señal del bot), se debe validar el **Checklist Institucional**:

### Escenario de COMPRA (Long) 🟢

```
[1] TENDENCIA MACRO (H1):
    □ Precio cotizando por encima de la EMA 200 de H1.
    □ Swing Structure en H1 marcando BOS alcista previo.

[2] LOCALIZACIÓN INSTITUCIONAL:
    □ El precio ha retrocedido a ZONA DE DESCUENTO (< 50% del rango).
    □ El precio entra en contacto con un Bullish Orderblock (OB) o un Bullish Breaker Block.
    □ Existe un Fair Value Gap (FVG) no mitigado cerca del nivel de reacción.

[3] LIQUIDEZ Y BARRIDO (Opcional pero de Alta Probabilidad):
    □ El precio barrió previamente unos Equal Lows (EQL) sacando stops de compradores minoristas.

[4] MICRO-GATILLO (M15 / M5):
    □ Ocurre un CHoCH alcista en temporalidad menor (cierre de vela confirmando absorción).
    □ El RSI está rebotando desde sobreventa (< 40 en Forex / < 42 en Oro).
    □ No existe una "Vela Elefante / Spike" cayendo en contra sin frenar.

[5] GESTIÓN Y PROTECCIÓN:
    □ Stop Loss colocado exactamente por debajo del mínimo del Order Block / Breaker + Spread.
    □ Botón de Algo Trading de MT5 ENCENDIDO (verde) para que el bot gestione las salidas.
```

---

### Escenario de VENTA (Short) 🔴

```
[1] TENDENCIA MACRO (H1):
    □ Precio cotizando por debajo de la EMA 200 de H1.
    □ Swing Structure en H1 marcando BOS bajista previo.

[2] LOCALIZACIÓN INSTITUCIONAL:
    □ El precio ha subido a ZONA PREMIUM (> 50% del rango).
    □ El precio entra en contacto con un Bearish Orderblock (OB) o un Bearish Breaker Block.
    □ Existe un Fair Value Gap (FVG) bajista no mitigado en la zona.

[3] LIQUIDEZ Y BARRIDO:
    □ El precio barrió previamente unos Equal Highs (EQH) cazando stops de vendedores.

[4] MICRO-GATILLO (M15 / M5):
    □ Ocurre un CHoCH bajista en temporalidad menor.
    □ El RSI está cayendo desde sobrecompra (> 60 en Forex / > 58 en Oro).
    □ Vela de rechazo con mecha superior en la zona de resistencia.

[5] GESTIÓN Y PROTECCIÓN:
    □ Stop Loss colocado inmediatamente arriba del máximo del Order Block + Spread.
    □ Límite diario verificado (< 3 operaciones abiertas hoy).
```

---

## 🛡️ 5. Aurum Shield: Gestión de Riesgo y Salidas Escalonadas

La auditoría demostró que **el 85% de las pérdidas históricas se debieron a fallas de gestión de riesgo** (sobre-operación, ausencia de Stop Loss y aguantar pérdidas durante días).

### 1. El Cinturón de Seguridad Diario
* **Riesgo por Trade:** Exactamente **1.0%** de la equidad de la cuenta (en cuentas micro, entre $1.00 y $3.00 USD por posición).
* **Límite Diario Innegociable:** **Máximo 3 operaciones al día.**
* **Regla de 2 Fails:** Si 2 operaciones consecutivas tocan Stop Loss en la misma sesión, **el terminal se apaga de inmediato.** No se permite "revancha".
* **Drawdown Máximo Diario:** Si la cuenta pierde el **3.0%** en un solo día, el bot se bloquea automáticamente hasta las 00:00 GMT del día siguiente.

### 2. Gestión de Salida por Fases (Sweet Spot M15)
A diferencia de dejar correr trades ciegamente por 24 horas (lo que generó pérdidas en Oro):

```
Entrada ──> +1.0R a +1.3R ──> FASE 1:
                              ├─ Cerrar 40% a 50% del volumen (Dinero seguro)
                              └─ Mover SL a Break-Even + 1 pip (Riesgo CERO)

          ──> +1.8R a +2.2R ──> FASE 2:
                              ├─ Cerrar el 40% restante (Take Profit Principal)
                              └─ En Oro: Cierre 100% de la orden intradía.

          ──> +3.0R (Runner)──> FASE 3 (Solo en Divisas Mayores):
                              └─ Trailing stop activo asegurando +2.0R protegidos.
```

---

## ⏰ 6. Horarios de Operación Inviolables (Killzones CDMX)

El mercado Forex y los Metales no son rentables las 24 horas del día para un scalper de precisión:

| Horario (CDMX) | Sesión de Mercado | Estado Operativo | Activos Recomendados |
| :--- | :--- | :---: | :--- |
| **01:15 AM - 05:30 AM** | **London Open Killzone** |  **ALTA ACTIVIDAD** | EURUSD, GBPUSD, USDJPY |
| **06:30 AM - 11:30 AM** | **NY Overlap (Golden Hour)** |  **ALTA ACTIVIDAD** | GOLDmicro, EURUSD, US30 |
| **11:30 AM - 05:00 PM** | Late NY / Fix de Londres | 🟡 Desaceleración | Prohibido abrir nuevas órdenes; solo gestionar abiertas. |
| **05:00 PM - 01:15 AM** | **Rollover & Asian Session** | 🛑 **ZONA PROHIBIDA** | **CERO ENTRADAS.** Spreads altos, manipulación y chop. |

> [!WARNING]
> En la sesión asiática y rollover (de 5:00 PM a 1:15 AM CDMX), el spread de XM en cuentas micro se multiplica por 3x a 5x. **El 45.2% de tus pérdidas históricas ocurrieron por operar en este horario.**

---

## 🤖 7. Configuración e Interpretación del Motor SMC en MT5 (AurumSniper V14.0 BETA)

El código de `AurumSniper.mq5` y `AurumSniperMicro.mq5` cuenta ahora con el motor algorítmico nativo de Smart Money Concepts y Order Blocks.

### Parámetros Configurables en MT5 (Propiedades del EA - F7):

| Parámetro | Valor Sugerido | Función Táctica |
| :--- | :---: | :--- |
| `InpUseSMCStructures` | `true` | Habilita el cálculo algorítmico de BOS, CHoCH, OBs y Breakers. |
| `InpSwingLength` | `5` | Sensibilidad de detección de Swing Pivots (5 velas según motor VEGA). |
| `InpUseOrderBlocks` | `true` | Exige que el precio esté mitigando un Order Block para validar el disparo. |
| `InpUseBreakerBlocks` | `true` | Detecta Order Blocks fallidos que invierten su polaridad (Resistencia $\leftrightarrow$ Soporte). |
| `InpUseFVGFilter` | `true` | Identifica desequilibrios de 3 velas (Fair Value Gaps) como imanes de liquidez. |
| `InpUseLiquiditySweeps` | `true` | Detecta cazas de liquidez en dobles techos/suelos (EQH / EQL Sweeps). |
| `InpDrawSMCVisuals` | `true` | **Dibuja las cajas en tiempo real sobre el gráfico de MT5**. |
| `InpMaxSMCBoxes` | `8` | Limita la cantidad de rectángulos simultáneos para no saturar el gráfico. |

### 🎨 Lectura Visual de las Cajas en el Gráfico de MT5:
* **Caja Verde Oscuro / Aqua (`smc_ob_`):** Bullish Order Block activo. Zona óptima de rebote alcista para Compras.
* **Caja Roja / Marrón (`smc_ob_`):** Bearish Order Block activo. Zona óptima de rechazo bajista para Ventas.
* **Caja Azul Oscuro / Midnight (`smc_brk_`):** **Breaker Block**. Un bloque de órdenes previo que fue quebrado y ahora actúa con la polaridad invertida.
* **Etiqueta Tooltip:** Al pasar el cursor sobre cualquier caja en MT5, verás: `[ORDERBLOCK] BULL | Top: 4385.20 Bot: 4378.10` o `[BREAKER] BEAR`.

---

## 📋 8. Guía Rápida para el Operador (Cheat Sheet de Bolsillo)

```
┌────────────────────────────────────────────────────────────────────────┐
│                   AURUM VISION BETA - REGLAS DE ORO                    │
├────────────────────────────────────────────────────────────────────────┤
│ 1. NUNCA operes en contra de la tendencia H1.                          │
│ 2. NUNCA compres en Zona Premium (>50%) ni vendas en Descuento (<50%). │
│ 3. NUNCA abras un trade sin Stop Loss precalculado.                    │
│ 4. NUNCA operes fuera de las 01:15 AM - 11:30 AM CDMX.                 │
│ 5. NUNCA excedas 3 trades en un solo día (Anti-Revenge Trading).       │
│ 6. Asegura el 50% y mueve a Break-Even en +1.0R/+1.3R.                 │
│ 7. Mantén el botón "Algo Trading" de MT5 siempre encendido.            │
└────────────────────────────────────────────────────────────────────────┘
```

---

**Aurum Capital Algorithmic Trading Systems**  
*Documentación confidencial para uso interno y operadores autorizados.*
