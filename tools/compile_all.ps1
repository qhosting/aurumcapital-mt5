$editor = "C:\Program Files\XM Global MT5\MetaEditor64.exe"
$terminalBase = "C:\Users\Administrator\AppData\Roaming\MetaQuotes\Terminal\BB16F565FAAA6B23A20C26C49416FF05\MQL5"
$root = "c:\Users\Administrator\Documents\PROYECTOS\aurumcapital-mt5"
$terminalScripts = Join-Path $terminalBase "Scripts"
$terminalExperts = Join-Path $terminalBase "Experts"
$terminalInclude = Join-Path $terminalBase "Include"

# Asegurar directorios
if (-not (Test-Path $terminalScripts)) { New-Item -ItemType Directory -Path $terminalScripts -Force | Out-Null }
if (-not (Test-Path $terminalExperts)) { New-Item -ItemType Directory -Path $terminalExperts -Force | Out-Null }
if (-not (Test-Path $terminalInclude)) { New-Item -ItemType Directory -Path $terminalInclude -Force | Out-Null }
$scratchDir = Join-Path $root "scratch"
if (-not (Test-Path $scratchDir)) { New-Item -ItemType Directory -Path $scratchDir -Force | Out-Null }

# Sincronizar includes del repositorio hacia la terminal
$repoInclude = Join-Path $root "Include"
if (Test-Path $repoInclude) {
    Copy-Item -Path (Join-Path $repoInclude "*") -Destination $terminalInclude -Recurse -Force
}

$files = @("AurumHistorySync.mq5", "AurumSniperMicro.mq5", "AurumSniper.mq5")

foreach ($f in $files) {
    $src = Join-Path $root $f
    $log = Join-Path $scratchDir ([System.IO.Path]::GetFileNameWithoutExtension($f) + ".log")
    
    # Compilar con el include base de la terminal MT5
    $proc = Start-Process -FilePath $editor -ArgumentList "/compile:`"$src`" /inc:`"$terminalBase`" /log:`"$log`"" -Wait -PassThru
    $out = ""
    if (Test-Path $log) {
        $out = Get-Content $log -Raw
    }
    Write-Host "=== COMPILED: $f (ExitCode: $($proc.ExitCode)) ==="
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
