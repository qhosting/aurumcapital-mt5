# Manual Aurum Vision V15

TradingView es un visor de candidatos OHLC. El único componente que puede enviar una orden es el EA de MT5, y en este build las entradas reales están desactivadas por defecto.

1. Instala `AurumSniper.mq5` o `AurumSniperMicro.mq5` junto con `Include/` y compila con `scratch/compile_and_deploy.ps1`.
2. Ejecuta en una cuenta demo con margen hedging y gráfico M15. Configura el offset UTC exacto del servidor. Deja `InpAllowLiveTrading=false`.
3. Coloca `aurum_news.csv` en `MQL5/Files/`; su primera fila debe declarar la cobertura temporal y las siguientes filas `timestamp,currency,importance`. Sin cobertura válida no hay entradas.
4. Usa un preset de `presets/`. No adoptes posiciones manuales ni el magic antiguo sin revisar el historial y fijar una política de cuenta.
5. Guarda el log `A15.*.events.*.csv`, el reporte del tester y el manifest de hashes. Exporta deals con `tools/ExportAurumHistory.mq5` y reconcilia con `tools/reconcile_deals.py`.

El indicador Pine no conoce spread, margen, noticias, retcodes ni estado de cuenta. Sus alertas son candidatos informativos; deben coincidir con una señal cerrada y pasar todos los bloqueos del EA. Los resultados anteriores y el dashboard histórico son estimaciones de un CSV FIFO y no deben presentarse como validación.
