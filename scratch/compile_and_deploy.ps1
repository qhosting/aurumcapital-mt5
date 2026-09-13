# V15: compile in an isolated directory. No terminal deployment by this script.
param(
  [Parameter(Mandatory=$true)][string]$Editor,
  [Parameter(Mandatory=$true)][string]$Mql5IncludeDirectory,
  [string]$OutputDirectory = (Join-Path $PSScriptRoot '..\build')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$build = Join-Path $OutputDirectory (Get-Date -Format 'yyyyMMdd-HHmmss-fff')
New-Item -ItemType Directory -Path $build | Out-Null
Copy-Item (Join-Path $root 'Include') (Join-Path $build 'Include') -Recurse
# MetaEditor /inc root must contain standard Include\Trade and related libraries.
$incRoot = Join-Path $build 'standard'
New-Item -ItemType Directory -Path $incRoot | Out-Null
Copy-Item $Mql5IncludeDirectory (Join-Path $incRoot 'Include') -Recurse
$manifest = @()
foreach ($name in @('AurumSniper','AurumSniperMicro','ExportAurumHistory')) {
  $source = if ($name -eq 'ExportAurumHistory') { Join-Path $root "tools\$name.mq5" } else { Join-Path $root "$name.mq5" }
  $copy = Join-Path $build "$name.mq5"
  Copy-Item $source $copy
  $log = Join-Path $build "$name.compile.log"
  $binary = Join-Path $build "$name.ex5"
  $start = Get-Date
  $process = Start-Process -FilePath $Editor -ArgumentList "/compile:`"$copy`" /inc:`"$incRoot`" /log:`"$log`"" -Wait -PassThru
  if (!(Test-Path $log)) { throw "Compilation log missing: $name" }
  $content = Get-Content $log -Raw
  if ($content -notmatch '\b0 errors, 0 warnings\b') { throw "Compiler did not report clean build: $log`n$content" }
  if (!(Test-Path $binary) -or (Get-Item $binary).LastWriteTime -lt $start) { throw "Fresh binary missing: $binary" }
  $manifest += [pscustomobject]@{ name=$name; sourceSHA256=(Get-FileHash $copy -Algorithm SHA256).Hash; binarySHA256=(Get-FileHash $binary -Algorithm SHA256).Hash; log=$log; compilerExitCode=$process.ExitCode }
}
$sourceFiles = Get-ChildItem (Join-Path $root 'Include') -File | ForEach-Object { @{ path=$_.Name; sha256=(Get-FileHash $_.FullName -Algorithm SHA256).Hash } }
@{ generated=(Get-Date -Format o); build='15.00'; outputs=$manifest; includes=$sourceFiles } | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $build 'manifest.json') -Encoding UTF8
Write-Host "Build ready for MT5 testing: $build. No files deployed to a trading terminal."
