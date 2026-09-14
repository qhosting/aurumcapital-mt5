$dest = "C:\Users\AurumArch\AppData\Roaming\MetaQuotes\Terminal\656C351524AFFE300FAFE576FA4C7845\MQL5\Experts"
$editor = "C:\Program Files\XM MT5\MetaEditor64.exe"

Write-Host "Copying AurumSniper.mq5 to $dest..."
Copy-Item "AurumSniper.mq5" "$dest\AurumSniper.mq5" -Force
Write-Host "Compiling AurumSniper.mq5..."
$p1 = Start-Process -FilePath $editor -ArgumentList "/compile:`"$dest\AurumSniper.mq5`" /log:`"$dest\compile_sniper.log`"" -Wait -PassThru
Copy-Item "$dest\AurumSniper.ex5" "AurumSniper.ex5" -Force

Write-Host "Copying AurumSniperMicro.mq5 to $dest..."
Copy-Item "AurumSniperMicro.mq5" "$dest\AurumSniperMicro.mq5" -Force
Write-Host "Compiling AurumSniperMicro.mq5..."
$p2 = Start-Process -FilePath $editor -ArgumentList "/compile:`"$dest\AurumSniperMicro.mq5`" /log:`"$dest\compile_micro.log`"" -Wait -PassThru
Copy-Item "$dest\AurumSniperMicro.ex5" "AurumSniperMicro.ex5" -Force

Write-Host "=== SNIPER COMPILE RESULT ==="
Get-Content "$dest\compile_sniper.log" -Tail 4
Write-Host "=== MICRO COMPILE RESULT ==="
Get-Content "$dest\compile_micro.log" -Tail 4

Get-Item "AurumSniper.ex5", "AurumSniperMicro.ex5", "$dest\AurumSniper.ex5", "$dest\AurumSniperMicro.ex5" | Select-Object Name, LastWriteTime, Length
