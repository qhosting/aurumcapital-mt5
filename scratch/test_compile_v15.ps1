$editor = "C:\Program Files\XM MT5\metaeditor64.exe"
$terminalMql5 = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5"
$root = (Resolve-Path .).Path

# Copy Include to Experts\Include and MQL5\Include
Copy-Item "$root\Include" "$terminalMql5\Experts\Include" -Recurse -Force
Copy-Item "$root\Include" "$terminalMql5\Include" -Recurse -Force

# Compile AurumSniper
Copy-Item "$root\AurumSniper.mq5" "$terminalMql5\Experts\AurumSniper.mq5" -Force
Start-Process -FilePath $editor -ArgumentList "/compile:`"$terminalMql5\Experts\AurumSniper.mq5`" /log:`"$root\scratch\compile_sniper.log`"" -Wait

# Compile AurumSniperMicro
Copy-Item "$root\AurumSniperMicro.mq5" "$terminalMql5\Experts\AurumSniperMicro.mq5" -Force
Start-Process -FilePath $editor -ArgumentList "/compile:`"$terminalMql5\Experts\AurumSniperMicro.mq5`" /log:`"$root\scratch\compile_micro.log`"" -Wait

# Compile ExportAurumHistory
Copy-Item "$root\tools\ExportAurumHistory.mq5" "$terminalMql5\Experts\ExportAurumHistory.mq5" -Force
Start-Process -FilePath $editor -ArgumentList "/compile:`"$terminalMql5\Experts\ExportAurumHistory.mq5`" /log:`"$root\scratch\compile_export.log`"" -Wait

# Copy back binaries
Copy-Item "$terminalMql5\Experts\AurumSniper.ex5" "$root\AurumSniper.ex5" -Force -ErrorAction SilentlyContinue
Copy-Item "$terminalMql5\Experts\AurumSniperMicro.ex5" "$root\AurumSniperMicro.ex5" -Force -ErrorAction SilentlyContinue

Write-Host "=== SNIPER LOG ==="
Get-Content "$root\scratch\compile_sniper.log" -Tail 4
Write-Host "=== MICRO LOG ==="
Get-Content "$root\scratch\compile_micro.log" -Tail 4
Write-Host "=== EXPORT LOG ==="
Get-Content "$root\scratch\compile_export.log" -Tail 4
