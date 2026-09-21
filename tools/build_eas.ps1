$editor = "C:\Program Files\XM Global MT5\metaeditor64.exe"
$terminalMql5 = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5"
$root = "c:\Users\Administrator\Documents\PROYECTOS\aurumcapital-mt5"

if (-not (Test-Path "$root\scratch")) { New-Item -ItemType Directory -Path "$root\scratch" -Force | Out-Null }

Copy-Item "$root\Include\*" "$terminalMql5\Include" -Recurse -Force
Copy-Item "$root\Include\*" "$terminalMql5\Experts\Include" -Recurse -Force

Copy-Item "$root\AurumSniper.mq5" "$terminalMql5\Experts\AurumSniper.mq5" -Force
Copy-Item "$root\AurumSniperMicro.mq5" "$terminalMql5\Experts\AurumSniperMicro.mq5" -Force

$logSniper = "$root\scratch\compile_sniper.log"
if (Test-Path $logSniper) { Remove-Item $logSniper -Force }
Start-Process -FilePath $editor -ArgumentList "/compile:`"$terminalMql5\Experts\AurumSniper.mq5`" /log:`"$logSniper`"" -Wait

$logMicro = "$root\scratch\compile_micro.log"
if (Test-Path $logMicro) { Remove-Item $logMicro -Force }
Start-Process -FilePath $editor -ArgumentList "/compile:`"$terminalMql5\Experts\AurumSniperMicro.mq5`" /log:`"$logMicro`"" -Wait

Copy-Item "$terminalMql5\Experts\AurumSniper.ex5" "$root\AurumSniper.ex5" -Force -ErrorAction SilentlyContinue
Copy-Item "$terminalMql5\Experts\AurumSniperMicro.ex5" "$root\AurumSniperMicro.ex5" -Force -ErrorAction SilentlyContinue

Write-Host "Done compilation."
