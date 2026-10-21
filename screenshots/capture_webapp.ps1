$ErrorActionPreference = 'Stop'
$base = Split-Path -Parent $PSCommandPath

Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Win32Web {
    [StructLayout(LayoutKind.Sequential)]
    public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
}
"@
[Win32Web]::SetProcessDPIAware() | Out-Null

$env:Path = [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine')
$helm = (Get-Command helm.exe).Source
$kubectl = (Get-Command kubectl.exe).Source
$edge = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
$localPort = 8888
$url = "http://localhost:$localPort"

Write-Output 'Installing release student-webapp ...'
& $helm upgrade --install student-webapp "$base\..\student-webapp" --kube-context kind-devops-cluster --namespace default 2>&1 | Out-Null
& $kubectl --context kind-devops-cluster rollout status deployment/student-webapp -n default --timeout=180s | Out-Null

Write-Output "Starting port-forward svc/student-webapp ${localPort}:80 ..."
$pf = Start-Process -FilePath $kubectl -ArgumentList '--context','kind-devops-cluster','port-forward','svc/student-webapp',"$localPort`:80",'-n','default' -WindowStyle Hidden -PassThru

$ready = $false
for ($i = 0; $i -lt 60; $i++) {
    Start-Sleep -Milliseconds 500
    if ($pf.HasExited) { throw 'port-forward exited early.' }
    if (Test-NetConnection -ComputerName '127.0.0.1' -Port $localPort -InformationLevel Quiet -WarningAction SilentlyContinue) { $ready = $true; break }
}
if (-not $ready) { Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue; throw 'Port-forward did not become ready.' }

$content = ''
for ($i = 0; $i -lt 20; $i++) {
    try {
        $resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 10
        if ($resp.StatusCode -eq 200 -and $resp.Content -match 'nginx') { $content = $resp.Content; break }
    } catch { Start-Sleep -Milliseconds 500 }
}
if (-not $content) { Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue; throw "Did not receive the expected nginx page from $url." }
Write-Output "Served page OK from $url"

$profile = Join-Path $env:TEMP 'ass9-edge-profile'
Remove-Item $profile -Recurse -Force -ErrorAction SilentlyContinue
$edgeProc = Start-Process -FilePath $edge `
    -ArgumentList '--new-window','--no-first-run','--no-default-browser-check','--disable-sync','--disable-features=msEdgeIdentitySyncPromo',"--user-data-dir=$profile",$url `
    -PassThru

$handle = [IntPtr]::Zero
for ($i = 0; $i -lt 80; $i++) {
    Start-Sleep -Milliseconds 250
    $candidates = Get-Process msedge -ErrorAction SilentlyContinue | Where-Object {
        $_.MainWindowHandle -ne [IntPtr]::Zero -and ($_.MainWindowTitle -match 'nginx|localhost')
    }
    if ($candidates) { $handle = ($candidates | Select-Object -First 1).MainWindowHandle; break }
}
if ($handle -eq [IntPtr]::Zero) { Stop-Process -Id $edgeProc.Id -Force -ErrorAction SilentlyContinue; Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue; throw 'Could not find the browser window.' }

Start-Sleep -Seconds 3
[Win32Web]::ShowWindow($handle, 3) | Out-Null
[Win32Web]::SetForegroundWindow($handle) | Out-Null
Start-Sleep -Seconds 3
try { [System.Windows.Forms.SendKeys]::SendWait('{ESC}') } catch { }
Start-Sleep -Milliseconds 800

$rect = New-Object Win32Web+RECT
[Win32Web]::GetWindowRect($handle, [ref]$rect) | Out-Null
$width = $rect.Right - $rect.Left
$height = $rect.Bottom - $rect.Top
$bmp = New-Object System.Drawing.Bitmap($width, $height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bmp.Size)
$out = Join-Path $base '06-browser.png'
$bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
$g.Dispose()
$bmp.Dispose()
Write-Output "Captured: $out ($width x $height)"

Stop-Process -Id $edgeProc.Id -Force -ErrorAction SilentlyContinue
Get-CimInstance Win32_Process -Filter "Name='msedge.exe'" -ErrorAction SilentlyContinue |
    Where-Object { $_.CommandLine -like "*$profile*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Stop-Process -Id $pf.Id -Force -ErrorAction SilentlyContinue

Write-Output 'Uninstalling release student-webapp ...'
& $helm uninstall student-webapp --kube-context kind-devops-cluster --namespace default 2>&1 | Out-Null
Write-Output 'Done.'
