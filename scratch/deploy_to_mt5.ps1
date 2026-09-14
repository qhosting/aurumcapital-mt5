$term = 'C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5'
$root = (Resolve-Path .).Path

Write-Host "=== DESPLEGANDO ARCHIVOS AURUM V15 A METATRADER 5 ==="

# 1. Presets
$presetsDir = Join-Path $term 'Presets'
if (!(Test-Path $presetsDir)) { New-Item -ItemType Directory -Path $presetsDir -Force | Out-Null }
Copy-Item (Join-Path $root 'presets\*.set') $presetsDir -Force
Write-Host "[OK] Presets copiados a: $presetsDir"
Get-ChildItem $presetsDir | Select-Object Name, Length

# 2. Includes
Copy-Item (Join-Path $root 'Include\*') (Join-Path $term 'Include') -Recurse -Force
$expInc = Join-Path $term 'Experts\Include'
if (!(Test-Path $expInc)) { New-Item -ItemType Directory -Path $expInc -Force | Out-Null }
Copy-Item (Join-Path $root 'Include\*') $expInc -Recurse -Force
Write-Host "[OK] Includes copiados a MQL5 Include y Experts Include"

# 3. Copy source files to Experts
Copy-Item (Join-Path $root 'AurumSniper.mq5') (Join-Path $term 'Experts\AurumSniper.mq5') -Force
Copy-Item (Join-Path $root 'AurumSniperMicro.mq5') (Join-Path $term 'Experts\AurumSniperMicro.mq5') -Force
Copy-Item (Join-Path $root 'tools\ExportAurumHistory.mq5') (Join-Path $term 'Experts\ExportAurumHistory.mq5') -Force
Write-Host "[OK] Archivos .mq5 actualizados en MQL5 Experts"

# 4. Compile with MetaEditor directly inside terminal
$editor = 'C:\Program Files\XM MT5\metaeditor64.exe'
Write-Host "[COMPILANDO] AurumSniper.mq5..."
Start-Process -FilePath $editor -ArgumentList "/compile:`"$term\Experts\AurumSniper.mq5`" /log:`"$term\compile_sniper.log`"" -Wait

Write-Host "[COMPILANDO] AurumSniperMicro.mq5..."
Start-Process -FilePath $editor -ArgumentList "/compile:`"$term\Experts\AurumSniperMicro.mq5`" /log:`"$term\compile_micro.log`"" -Wait

Write-Host "[COMPILANDO] ExportAurumHistory.mq5..."
Start-Process -FilePath $editor -ArgumentList "/compile:`"$term\Experts\ExportAurumHistory.mq5`" /log:`"$term\compile_export.log`"" -Wait

# 5. Copy generated binaries back to repository
Copy-Item (Join-Path $term 'Experts\AurumSniper.ex5') (Join-Path $root 'AurumSniper.ex5') -Force
Copy-Item (Join-Path $term 'Experts\AurumSniperMicro.ex5') (Join-Path $root 'AurumSniperMicro.ex5') -Force

Write-Host "=== RESULTADOS DE COMPILACION EN TERMINAL ==="
Get-Content (Join-Path $term 'compile_sniper.log') -Tail 3
Get-Content (Join-Path $term 'compile_micro.log') -Tail 3
Get-Content (Join-Path $term 'compile_export.log') -Tail 3

Write-Host "=== BINARIOS Y ARCHIVOS EN MQL5 EXPERTS ==="
Get-ChildItem (Join-Path $term 'Experts\*Aurum*') | Select-Object Name, LastWriteTime, Length
