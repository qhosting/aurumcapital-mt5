# 🦅 AURUM VISION V11 [ULTIMATE]: Manual de Operador Táctico (Sniper)
**Versión del Sistema:** V11 [Ultimate]  
**Plataforma de Entrenamiento:** TradingView  
**Plataforma de Ejecución:** MetaTrader 5 (Bot AurumSniper)

---

## 🎓 Introducción: La Filosofía del Francotirador
Bienvenido, futuro operador. Estás a punto de aprender a usar **Aurum Vision**, un sistema de "Scalping de Precisión".  

A diferencia de los traders novatos que "disparan a todo lo que se mueve", el operador Aurum es un **Francotirador**:
1.  **Paciencia Infinita:** Esperamos horas para disparar en segundos.
2.  **Disciplina Militar:** Si falta 1 sola confirmación, NO se opera.
3.  **Protección Primero:** Antes de pensar en ganar, pensamos en no perder.

---

## 🧠 Conceptos Básicos (Pre-Requisitos)
Antes de mirar el gráfico, debes entender las 5 fuerzas que mueven este sistema:

### 1. La Corriente (Tendencia H1) 🌊
Imagina un río. Si el río fluye hacia el sur, ¿nadarías hacia el norte? No.
*   **Regla de Oro:** Solo operamos a favor de la tendencia mayor (1 Hora).
*   Si H1 es **ALCISTA**, solo buscamos COMPRAS.
*   Si H1 es **BAJISTA**, solo buscamos VENTAS.

### 2. El Muro (Zonas de Reacción) 🧱
El precio tiene memoria. Donde rebotó antes, rebotará de nuevo.
*   **Zona H1:** Son techos y suelos fuertes.
*   **Zona Dinámica (Nueva V11):** La línea de tendencia (EMA) también actúa como un muro.
*   **Regla:** Compramos si el precio toca un soporte H1... **O si regresa a tocar la EMA (Pullback).**
*   *Esto nos permite montarnos en tendencias fuertes aunque no estemos en máximos/mínimos.*

### 3. El Resorte (RSI) 🌀
El precio es como un resorte. Si lo estiras mucho hacia abajo, **tiene** que rebotar hacia arriba.
*   **Sobreventa (RSI < 30):** El resorte está estirado al máximo hacia abajo. Probable rebote (Compra).
*   **Sobrecompra (RSI > 70):** El resorte está estirado al máximo hacia arriba. Probable caída (Venta).
*   *(Nota: Versiones anteriores usaban 25/75, la V11 usa 30/70 para mayor sensibilidad).*

### 4. La Fuerza (ADX) 🚀
**Nuevo en V11.** No basta con tener la dirección, necesitamos fuerza.
*   **Condición:** El ADX (Índice de Movimiento Direccional) debe ser mayor a **20**.
*   Esto evita operar en mercados muertos o laterales sin volumen. Es un filtro interno del bot.

### 5. La Inercia (Anti-Spike) 🚄
Imagina un tren a toda velocidad. Aunque veas una señal de "PARE", el tren no frena en seco.
*   **Vela Elefante (Spike):** Si ves una vela gigante (>3x el promedio), indica mucha fuerza contraria.
*   **La Regla:** No te pongas delante del tren. Espera a que termine esa vela. El bot bloqueará la entrada si detecta esta "Inercia Peligrosa".

### 6. Lectura Visual del Gráfico (Iconos) 👁️
El sistema te habla con símbolos:

| Símbolo | Significado | Acción |
| :--- | :--- | :--- |
| **Línea Azul/Roja** | Es la EMA de H1 (Tendencia). | Solo operar a favor de su color. |
| **Círculos Rojos/Verdes** | Son las Zonas H1 (Techos y Suelos). | Esperar a que el precio las toque. |
| **⚠️ SPIKE!** | ¡Peligro! Vela gigante detectada. | **NO OPERAR** (El Bot se bloquea aquí). |
| **🔨 Martillo / 💫 Estrella** | Velas de rechazo. | Confirmación extra (Opcional). |

### 7. Herramientas Visuales Avanzadas (Nuevas en V22) 🛠️
El sistema ahora incluye ayudas visuales para la ejecución manual en TradingView:

*   **Detector de Trampas (🪤):** Identifica "Fakeouts". Si el precio rompe una zona pero cierra dentro, aparece esta etiqueta. Es una señal de reversión muy fuerte.
*   **Visualizador de Setup:** Cuando aparece una señal (Triángulo), el sistema dibuja automáticamente:
    *   Línea **Roja**: Stop Loss sugerido (ATR).
    *   Línea **Verde**: Take Profit sugerido.
    *   *Uso:* Solo copia estos precios a tu MetaTrader.

---

## 🖥️ Conociendo tu Herramienta: El Dashboard
En la esquina superior derecha de tu TradingView verás el panel de control. Así se lee:

| Indicador | Qué Dice | Interpretación | Acción |
| :--- | :--- | :--- | :--- |
| **RSI (M1)** | `22.50` (Verde) | Precio "Barato" (< 30) | ✅ Listo para Comprar |
| **Trend H1** | `ALCISTA` (Verde) | La tendencia mayor sube | ✅ Solo Compras |
| **Anti-Spike** | `⚠️ RECHAZADO` | Vela anterior fue explosiva | 🛑 **ESPERAR** (Peligro) |
| **Zona H1** | `ZONA COMPRA` | Estamos en un soporte fuerte | ✅ Confirmado |

**TU MISIÓN:** Esperar a que **TODO** esté en Verde. Si hay un solo Rojo o Naranja, anulas la operación.

---

## 🎯 La Estrategia: Paso a Paso (Checklist)

### Escenario: Buscando una COMPRA (Long) 🟢

1.  **Observación Macro:** Mira el Dashboard. ¿Dice **Trend H1: ALCISTA**?
    *   *Si NO:* Aborta. No operamos contra tendencia.
2.  **Ubicación:** ¿El precio bajó y tocó una **ZONA DE COMPRA** (Línea o área marcada)?
    *   *Si NO:* Paciencia. Deja que llegue al precio.
3.  **El Gatillo (RSI):** ¿El RSI bajó por debajo de **30**?
    *   Esto indica que los vendedores están agotados.
4.  **⛔ EL FILTRO DE SEGURIDAD (Vital):**
    *   Mira la última vela que cerró. ¿Fue una vela roja GIGANTE?
    *   Si el Dashboard dice **"⚠️ RECHAZADO"**, ¡QUIETO!
    *   Espera a que cierre una vela "normal" o pequeña.
    *   Cuando el Dashboard diga **"✅ SEGURO"**, disparas.

---

## 🛡️ Gestión de Riesgo y Seguridad (Aurum Shield)
El sistema V11 Ultimate incluye protecciones automáticas en el Bot (AurumSniper):

### 1. En la Operación Individual
*   **Stop Loss (SL):** Automático a **1.5 veces el ATR** (Volatilidad). Nunca se mueve en contra.
*   **Cierre Parcial (BreakEven):**
    *   Cuando ganas **10 Pips (100 puntos)** o un ratio aprox 1:1...
    *   El Bot cierra el **50% del lote** (Dinero al bolsillo).
    *   Mueve el Stop Loss al precio de entrada (Riesgo Cero).
    *   *Resultado:* "Free Trade". Dejas correr el resto.

### 2. Seguridad de la Cuenta (Daily Guard)
El bot tiene un "Cinturón de Seguridad" diario:
*   **Max Drawdown Diario:** Si pierdes el **3%** de tu cuenta en un día, el bot se apaga hasta mañana.
*   **Max Operaciones:** Límite de **3 Trades** al día (Configurable). Evita el sobre-operar (Overtrading).

---

## ⚠️ Errores Comunes de Novatos

1.  **"El Rebote en V" y la Ansiedad:**
    *   *Situación:* El precio cae en picada y rebota rapidísimo.
    *   *Error:* Querer entrar justo en la punta de abajo.
    *   *Antídoto:* Acepta perder el movimiento si hay un "Spike". Es mejor perder una oportunidad que perder dinero.

2.  **Ignorar la Tendencia H1:**
    *   *Error:* Ver un RSI en 90 (Venta) y vender, cuando la tendencia H1 es Alcista.
    *   *Consecuencia:* El precio te atropella. En tendencias fuertes, el RSI puede mentir.

3.  **Operar con Noticias:**
    *   Si hay noticias de impacto (Nóminas, Inflación), apaga el sistema.

---

## 📝 Ejercicio Práctico
1.  Abre TradingView con **Aurum Vision V11**.
2.  Busca 5 señales de "Sniper Buy" (Triángulo Verde).
3.  Verifica: ¿Estaba el RSI < 30? ¿Había Zona H1? ¿Estaba el ADX confirmando (movimiento claro)?
4.  Simula la salida: ¿Hubiera tocado el BreakEven (10 pips)?

> *"El mercado es un mecanismo para transferir dinero del impaciente al paciente."* - Warren Buffett.

**Aurum Capital - Academia de Trading**
