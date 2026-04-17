Invoke-WebRequest `
  -Uri "https://www.autohotkey.com/download/ahk-v2.exe" `
  -OutFile "ahk.exe"

Start-Process ahk.exe -ArgumentList "/S" -Wait

& "C:\Program Files\AutoHotkey\Compiler\Ahk2Exe.exe" `
  /in NetSpeedTaskbar.ahk `
  /out NetSpeedTaskbar.exe