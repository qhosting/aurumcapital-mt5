# GUÍA MAESTRA DE TRADING INSTITUCIONAL & ESTRATEGIA AURUM V15.35
**De Principiante a Trader Institucional Avanzado**
*Aurum Invest Station & Aurum Capital SMC*

---

## ÍNDICE GENERAL

1. [Módulo 1: Fundamentos de Mercado y Forex (Forex Trading Blueprint)](#módulo-1-fundamentos-de-mercado-y-forex)
2. [Módulo 2: Anatomía de Velas Japonesas y Sistema Opwens (Libro Opwens A4)](#módulo-2-anatomía-de-velas-japonesas-y-sistema-opwens)
3. [Módulo 3: Chartismo Clásico, Geometría y Objetivos H (Módulo 2)](#módulo-3-chartismo-clásico-geometría-y-objetivos-h)
4. [Módulo 4: Smart Money Concepts (SMC) & Liquidez Institucional](#módulo-4-smart-money-concepts-smc--liquidez-institucional)
5. [Módulo 5: Gestión Matemática del Riesgo y Fórmulas de Asignación](#módulo-5-gestión-matemática-del-riesgo-y-fórmulas-de-asignación)
6. [Módulo 6: Protocolo de Ejecución de la Estrategia Aurum V15.35](#módulo-6-protocolo-de-ejecución-de-la-estrategia-aurum-v1535)
7. [Módulo 7: Auditoría Post-Trade, Replay y Mejora Continua](#módulo-7-auditoría-post-trade-replay-y-mejora-continua)

---

## MÓDULO 1: FUNDAMENTOS DE MERCADO Y FOREX

### 1.1 ¿Qué es el Mercado de Divisas (Forex)?
El mercado Forex (Foreign Exchange) es el mercado financiero descentralizado más grande del mundo, con un volumen diario superior a los **6.6 billones de dólares**. En él participan bancos centrales, fondos de cobertura (hedge funds), corporaciones multinacionales y traders minoristas.

### 1.2 Estructura de Pares de Divisas
Una cotización se compone de:
- **Divisa Base**: La primera divisa del par (ej. EUR en EUR/USD). Representa la unidad de compra o venta.
- **Divisa Cotizada**: La segunda divisa del par (ej. USD en EUR/USD). Representa el precio de una unidad de la divisa base.

#### Clasificación:
1. **Mayores (Majors)**: Pares que cruzan las divisas más líquidas contra el dólar estadounidense (EUR/USD, GBP/USD, USD/JPY, USD/CHF, AUD/USD, USD/CAD, NZD/USD).
2. **Cruces (Minors)**: Pares entre divisas principales sin el USD (EUR/GBP, EUR/JPY, GBP/JPY).
3. **Metales & Materias Primas**: Activos con alta volatilidad y liquidez institucional como el **Oro (XAU/USD)** y la **Plata (XAG/USD)**.

### 1.3 El Pip, Pipette y Valor del Pip
- **Pip (Price Interest Point)**: Medida estandarizada de variación de precio. En la mayoría de divisas corresponde al cuarto decimal (`0.0001`). En pares con JPY corresponde al segundo decimal (`0.01`).
- En el **Oro (XAU/USD)**: 1 Pip equivale normalmente a `0.10` puntos de cotización (10 centavos de dólar).
- **Fórmula de Valor del Pip**:
  $$\text{Valor Pip} = (\text{Tamaño del Pip} / \text{Tipo de Cambio}) \times \text{Tamaño del Lote}$$

### 1.4 Lotes y Apalancamiento
| Tipo de Lote | Unidades de Moneda | Volumen MT5 | Valor aprox. Pip EURUSD | Valor aprox. Pip Oro |
| :--- | :--- | :--- | :--- | :--- |
| **Estándar** | 100,000 unidades | `1.00` | ~$10.00 USD | ~$10.00 USD |
| **Mini** | 10,000 unidades | `0.10` | ~$1.00 USD | ~$1.00 USD |
| **Micro** | 1,000 unidades | `0.01` | ~$0.10 USD | ~$0.10 USD |

### 1.5 Sesiones de Mercado y Killzones
El mercado opera 24 horas al día, 5 días a la semana, a través de tres centros neurálgicos:
- **Sesión de Tokio (Asiática)**: 00:00 - 09:00 UTC. Genera acumulación y rangos estrechos (Rango de Asia).
- **Sesión de Londres**: 07:00 - 16:00 UTC. Gran volumen y manipulación (Judas Swing) de los altos/bajos de Asia.
- **Sesión de Nueva York**: 12:00 - 21:00 UTC. Confluencia con Londres (Solapamiento Londres-NY: 12:00 a 16:00 UTC), momento de mayor volatilidad del día.

---

## MÓDULO 2: ANATOMÍA DE VELAS JAPONESAS Y SISTEMA OPWENS

Las velas japonesas representan el equilibrio dinámico entre la oferta institucional y la demanda.

### 2.1 Anatomía de una Vela
- **Cuerpo Real**: Distancia entre el precio de Apertura (*Open*) y Cierre (*Close*).
- **Sombra Superior (*Wick/Tail*)**: Máximo alcanzado durante el periodo.
- **Sombra Inferior (*Wick/Tail*)**: Mínimo alcanzado durante el periodo.

### 2.2 Patrones de Alta Probabilidad Opwens

#### 1. Pinbar / Vela Martillo (Hammer) / Hanging Man
- **Estructura**: Cuerpo pequeño en un extremo con una mecha que representa al menos el **66% (2/3)** del rango total de la vela.
- **Significado**: Rechazo violento del precio por absorción institucional de liquidez. Si ocurre en un POI (Point of Interest) o tras un *Sweep*, marca la entrada ideal.

#### 2. Vela Envolvente (Engulfing)
- **Alcista**: Una vela bajista previa es completamente envuelta por una vela alcista con cuerpo mayor. Indica capitulación de vendedores y toma de control compradora.
- **Bajista**: Una vela alcista previa es completamente superada por una vela bajista contundente.

#### 3. Estrella de la Mañana (Morning Star) / Estrella del Atardecer (Evening Star)
- **Patrón de 3 velas**:
  1. Vela de tendencia fuerte.
  2. Vela de indecisión (Doji o Peonza) con gap o contracción de volumen.
  3. Vela contraria que cierra más allá del 50% del cuerpo de la primera vela.
- **Fiabilidad**: >75% cuando coincide con soporte/resistencia institucional.

#### 4. Vela Doji (Estrella, Libélula, Lápida)
- Apertura y cierre idénticos o casi idénticos. Representa equilibrio transitorio previo a una expansión explosiva.

#### 5. Tres Soldados Blancos / Tres Cuervos Negros
- Tres velas consecutivas de rango amplio y mechas mínimas. Señal de expansión direccional institucional sostenida.

---

## MÓDULO 3: CHARTISMO CLÁSICO, GEOMETRÍA Y OBJETIVOS H

### 3.1 Patrones de Cambio de Tendencia (Reversal)

#### Doble Suelo (Double Bottom / "W") & Doble Techo (Double Top / "M")
- Dos testeos de un mismo nivel clave con divergencia en el oscilador (RSI/MACD).
- **Entrada**: En la rotura o retesteo de la línea de cuello (*Neckline*).
- **Proyección Objetivo**: Se traslada la altura $H$ (distancia entre el pico y el cuello) hacia el punto de rotura.

#### Hombro - Cabeza - Hombro (HCH / Head & Shoulders)
- Tres impulsos sucesivos donde el central es el más extremo.
- El segundo hombro demuestra agotamiento del impulso previo.
- **Stop Loss**: Por encima del hombro derecho.

### 3.2 Patrones de Continuación de Tendencia

#### Banderas (Flags) y Banderines (Pennants)
- Movimiento impulsivo previo (*Mástil* o *Pole*).
- Consolidación correctiva inclinada contra la tendencia.
- **Objetivo**: Proyección del mástil completo a partir del quiebre.

#### Triángulos Simétricos, Ascendentes y Descendentes
- Contracción de volatilidad (compresión de liquidez).
- El quiebre con volumen institucional desencadena la expansión.

---

## MÓDULO 4: SMART MONEY CONCEPTS (SMC) & LIQUIDEZ INSTITUCIONAL

Los mercados financieros se mueven por **búsqueda y absorción de liquidez**. Las instituciones necesitan contraparte para llenar sus órdenes masivas.

### 4.1 Conceptos Fundamentales
1. **BOS (Break of Structure)**: Quiebre a favor de la tendencia que confirma continuación de la estructura.
2. **CHoCH (Change of Character)**: Primer quiebre de la estructura en contra de la tendencia previa. Señal temprana de giro institucional.
3. **Liquidity Sweeps (Barridos de Liquidez)**: El precio penetra temporalmente un máximo o mínimo previo (donde residen los Stop Loss minoristas) y es absorbido de inmediato cerrando de nuevo dentro del rango.
4. **Order Block (OB)**: La última vela contraria antes de un movimiento impulsivo que genera un desbalance. Representa las órdenes no mitigadas de los bancos.
5. **Fair Value Gap (FVG) / Desbalance**: Espacio de precio ineficiente generado por una vela de expansión donde el mercado tiende a rellenar liquidez.

### 4.2 Matriz de Confluencias Aurum V15.35
Para abrir una operación algorítmica o manual de alta probabilidad se exige:
- [x] **Tendencia de Macro Marco (H4 / D1)** identificada.
- [x] **Barrido de Liquidez (Sweep)** de un mínimo/máximo anterior en M15.
- [x] **Llegada a Zona POI (Point of Interest)**: Mitigación de Order Block o FVG.
- [x] **Vela de Reversión (Price Action Opwens)**: Martillo, pinbar o absorción de 1 barra con rechazo claro.
- [x] **Filtro RSI Adaptativo**: RSI < 48.0 en compras (zona de descuento) o RSI > 52.0 en ventas (zona de prima).
- [x] **Gestión de Horario**: Operativa preferente en Killzone de Londres/NY o 24h para Metales (Oro/Plata).

---

## MÓDULO 5: GESTIÓN MATEMÁTICA DEL RIESGO Y FÓRMULAS DE ASIGNACIÓN

Ninguna estrategia sobrevive a una mala gestión monetaria. La preservación del capital es la regla número 1.

### 5.1 Regla del Riesgo Máximo por Operación (1%)
Nunca arriesgues más del **1%** de tu balance en un solo trade.

$$\text{Monto en Riesgo ($)} = \text{Balance de la Cuenta} \times 0.01$$

### 5.2 Fórmula Exacta de Tamaño de Lote
$$\text{Lote} = \frac{\text{Monto en Riesgo ($)}}{\text{Distancia al Stop Loss (Pips)} \times \text{Valor del Pip por Lote Estándar}}$$

#### Ejemplo en Oro (XAU/USD):
- Balance: $10,000 USD
- Riesgo: 1% = $100 USD
- Stop Loss: 25 Pips (2.50 USD de precio)
- Valor del Pip en 1.00 lote estándar = $10 USD
$$\text{Lote} = \frac{100}{25 \times 10} = \frac{100}{250} = 0.40 \text{ Lotes}$$

---

## MÓDULO 6: PROTOCOLO DE EJECUCIÓN DE LA ESTRATEGIA AURUM V15.35

### 6.1 Fases del Trade (R-Múltiplos Dinámicos)

```
        ▲ TP Final (+1.8R): Cierre del 50% restante
        │
        ┼ Break-Even (+1.0R): SL movido a Entrada + Spread (Riesgo CERO)
        │
        ┼ Micro-Lock (+0.5R): Cierre parcial del 50% del volumen
        │
────────┴──────── Punto de Entrada (0.0R)
        │
        ▼ Stop Loss (-1.0R): Nivel técnico innegociable
```

1. **Fase 1: Entrada y Protección**:
   - Se ejecuta el trade con Stop Loss colocado 3 pips por debajo del mínimo del barrido (*Sweep Low*).
2. **Fase 2: Micro-Lock (+0.5R)**:
   - Al alcanzar +0.5R de beneficio, el sistema asegura el 50% de la posición tomando parciales.
3. **Fase 3: Break-Even (+1.0R)**:
   - Al alcanzar +1.0R, el Stop Loss se traslada automáticamente al precio de entrada más la comisión/spread. El trade ya no puede perder.
4. **Fase 4: Take Profit (+1.8R a 2.5R)**:
   - Cierre del volumen restante en el siguiente nivel de liquidez opuesta (Order Block contrario o alto del día anterior).

### 6.2 Independencia Operativa Total
- La versión V15.35 separa por completo las órdenes manuales de las automáticas mediante filtrado estricto por `Magic Number`.
- El trader puede abrir posiciones discrecionales sin deshabilitar los algoritmos de barrido automático.

---

## MÓDULO 7: AUDITORÍA POST-TRADE, REPLAY Y MEJORA CONTINUA

### 7.1 La Regla de los 3 Errores
- Si cometes 2 pérdidas consecutivas del 1%, apaga las pantallas durante la sesión. El mercado estará esperando mañana.

### 7.2 Bitácora de Registro Institucional
Cada trade ejecutado debe documentarse en **Aurum Invest Station**:
1. Captura de pantalla en el momento de la entrada (M15 y H1).
2. Razón técnica (¿Hubo barrido? ¿Patrón Opwens? ¿Nivel RSI?).
3. Ejecución del plan (¿Se respetó el BE en 1.0R? ¿Se cerró prematuramente?).
4. Resultado en R-Múltiplo (+1.8R, +0.5R, 0.0R, -1.0R).

---
*Aurum Capital Management — Desarrollado para traders profesionales y algoritmos de alta fidelidad.*
