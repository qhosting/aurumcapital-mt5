$editor = "C:\Program Files\XM MT5\metaeditor64.exe"
$inc = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5"
$root = "c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5"
$terminalScripts = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Scripts"
$terminalExperts = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Experts"

# Asegurar directorios
if (-not (Test-Path $terminalScripts)) { New-Item -ItemType Directory -Path $terminalScripts -Force | Out-Null }
if (-not (Test-Path $terminalExperts)) { New-Item -ItemType Directory -Path $terminalExperts -Force | Out-Null }

$files = @("AurumHistorySync.mq5", "AurumSniperMicro.mq5", "AurumSniper.mq5")

foreach ($f in $files) {
    $src = Join-Path $root $f
    $log = Join-Path $root ("scratch\" + [System.IO.Path]::GetFileNameWithoutExtension($f) + ".log")
    $proc = Start-Process -FilePath $editor -ArgumentList "/compile:`"$src`" /inc:`"$inc`" /log:`"$log`"" -Wait -PassThru
    $out = Get-Content $log -Raw
    Write-Host "=== COMPILED: $f ==="
    Write-Host $out

    # Copiar binario a la terminal MT5 activa
    $ex5Name = [System.IO.Path]::ChangeExtension($f, ".ex5")
    $ex5Src = Join-Path $root $ex5Name
    if (Test-Path $ex5Src) {
        if ($f -eq "AurumHistorySync.mq5") {
            Copy-Item $ex5Src $terminalScripts -Force
            Copy-Item $src $terminalScripts -Force
            Write-Host "✅ Copiado a MT5 Scripts: $ex5Name"
        } else {
            Copy-Item $ex5Src $terminalExperts -Force
            Copy-Item $src $terminalExperts -Force
            Write-Host "✅ Copiado a MT5 Experts: $ex5Name"
        }
    }
}
