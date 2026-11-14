# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
  Checks (and optionally applies) the Vader360 kernel patches over XBDM.

.DESCRIPTION
  Reads the two patch sites and the XeUnshackle Usbdsec patch from a console
  running Bad Update + XeUnshackle with Xbdm.xex loaded, and tells you whether
  the Vader360 plugin did its job. With -Apply it writes the patches itself
  (same signature checks as the plugin), which is handy for testing without the
  plugin or if the plugin could not load.

.EXAMPLE
  .\vader360-check.ps1 -Ip 192.168.0.50
.EXAMPLE
  .\vader360-check.ps1 -Ip 192.168.0.50 -Apply
#>
param(
    [Parameter(Mandatory = $true)][string]$Ip,
    [switch]$Apply
)
$ErrorActionPreference = 'Stop'

$Sites = @(
    @{ Addr = 0x800F98F8; Before = '2B030001'; Orig = '39400020'; New = '39400040'; After = '419A0008'; What = 'WgcAddDevice max packet 32 -> 64' },
    @{ Addr = 0x800F9490; Before = '995F0098'; Orig = '409A0164'; New = '41980164'; After = '897D0000'; What = 'input report length == 20 -> >= 20' }
)

$client = New-Object Net.Sockets.TcpClient
if (-not $client.ConnectAsync($Ip, 730).Wait(3000)) { throw "No XBDM at ${Ip}:730. Is Xbdm.xex loaded (launch.ini plugin1)?" }
$client.ReceiveTimeout = 5000
$stream = $client.GetStream()
$reader = New-Object IO.StreamReader($stream, [Text.Encoding]::ASCII)
$writer = New-Object IO.StreamWriter($stream, [Text.Encoding]::ASCII); $writer.NewLine = "`r`n"; $writer.AutoFlush = $true
if ($reader.ReadLine() -notlike '201*') { throw 'Unexpected XBDM banner' }

function Invoke-Xbdm([string]$cmd) {
    $writer.WriteLine($cmd)
    $line = $reader.ReadLine()
    if ($line -like '202*') { $out = @(); while (($l = $reader.ReadLine()) -ne '.') { $out += $l }; return ($out -join '') }
    if ($line -notlike '200*') { throw "XBDM: $line" }
    return $line
}
function Read-Word([uint32]$addr) { (Invoke-Xbdm ("getmem addr=0x{0:X8} length=4" -f $addr)).Trim().ToUpper() }

try {
    $info = Invoke-Xbdm 'systeminfo'
    Write-Host "Console: $($info -replace '\s+', ' ')"

    $usbd = (Invoke-Xbdm 'getmem addr=0x800D8748 length=8').Trim().ToUpper()
    if ($usbd -eq '386000014E800020') { Write-Host 'XeUnshackle Usbdsec patch: present' -ForegroundColor Green }
    else { Write-Host "XeUnshackle Usbdsec patch: NOT found ($usbd) - run the exploit / XeUnshackle first" -ForegroundColor Yellow }

    $ok = $true
    foreach ($s in $Sites) {
        $before = Read-Word ($s.Addr - 4); $cur = Read-Word $s.Addr; $after = Read-Word ($s.Addr + 4)
        $label = '{0:X8} {1}' -f $s.Addr, $s.What
        if ($before -ne $s.Before -or $after -ne $s.After) {
            Write-Host "$label : unexpected code around the site (not kernel 17559?)" -ForegroundColor Red; $ok = $false; continue
        }
        if ($cur -eq $s.New) { Write-Host "$label : patched" -ForegroundColor Green; continue }
        if ($cur -ne $s.Orig) { Write-Host "$label : unexpected value $cur" -ForegroundColor Red; $ok = $false; continue }
        if (-not $Apply) { Write-Host "$label : NOT patched (stock)" -ForegroundColor Yellow; $ok = $false; continue }
        Invoke-Xbdm ("setmem addr=0x{0:X8} data={1}" -f $s.Addr, $s.New) | Out-Null
        if ((Read-Word $s.Addr) -eq $s.New) { Write-Host "$label : applied now" -ForegroundColor Green }
        else { Write-Host "$label : write failed" -ForegroundColor Red; $ok = $false }
    }
    if ($ok) { Write-Host 'Result: Vader360 patches active. Re-plug the receiver if it was connected before.' -ForegroundColor Green }
    else { Write-Host 'Result: patches not active.' -ForegroundColor Yellow }
}
finally {
    try { $writer.WriteLine('bye') } catch {}
    $client.Close()
}
