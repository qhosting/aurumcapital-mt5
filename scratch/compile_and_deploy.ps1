$dest = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Experts"
$editor = "C:\Program Files\XM MT5\metaeditor64.exe"

Copy-Item "c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\AurumSniperMicro.mq5" "$dest\AurumSniperMicro.mq5" -Force
Start-Process -FilePath $editor -ArgumentList "/compile:`"$dest\AurumSniperMicro.mq5`" /log:`"$dest\compile_micro.log`"" -Wait

Copy-Item "$dest\AurumSniperMicro.ex5" "c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\AurumSniperMicro.ex5" -Force

Copy-Item "c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\AurumSniper.mq5" "$dest\AurumSniper.mq5" -Force
Start-Process -FilePath $editor -ArgumentList "/compile:`"$dest\AurumSniper.mq5`" /log:`"$dest\compile_sniper.log`"" -Wait

Copy-Item "$dest\AurumSniper.ex5" "c:\Users\AurumArch\Documents\PROYECTOS\aurumcapital-mt5\AurumSniper.ex5" -Force

Write-Host "=== COMPILE MICRO RESULT ==="
Get-Content "$dest\compile_micro.log" -Tail 4
Write-Host "=== COMPILE SNIPER RESULT ==="
Get-Content "$dest\compile_sniper.log" -Tail 4
