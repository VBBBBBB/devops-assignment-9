$ErrorActionPreference = 'Continue'
$base = Split-Path -Parent $PSCommandPath
$sig = Join-Path $base 'signals'
New-Item -ItemType Directory -Force -Path $sig | Out-Null
Get-ChildItem $sig -File -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue

$Host.UI.RawUI.WindowTitle = 'Ass9 Helm Lab - devops-cluster'

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
[StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
public struct CONSOLE_FONT_INFO_EX {
    public uint cbSize;
    public uint nFont;
    public short dwFontSizeX;
    public short dwFontSizeY;
    public int FontFamily;
    public int FontWeight;
    [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)]
    public string FaceName;
}
public class ConsoleFont9 {
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern IntPtr GetStdHandle(int nStdHandle);
    [DllImport("kernel32.dll", SetLastError = true)]
    public static extern bool SetCurrentConsoleFontEx(IntPtr hConsoleOutput, bool bMaximumWindow, ref CONSOLE_FONT_INFO_EX lpConsoleCurrentFontEx);
    public static void Set(string face, short size) {
        CONSOLE_FONT_INFO_EX f = new CONSOLE_FONT_INFO_EX();
        f.cbSize = (uint)Marshal.SizeOf(f);
        f.FaceName = face;
        f.dwFontSizeX = 0;
        f.dwFontSizeY = size;
        f.FontFamily = 54;
        f.FontWeight = 400;
        SetCurrentConsoleFontEx(GetStdHandle(-11), false, ref f);
    }
}
"@
[ConsoleFont9]::Set('Consolas', 13)
Start-Sleep -Milliseconds 500

$max = $Host.UI.RawUI.MaxPhysicalWindowSize
$bufH = [Math]::Max(3000, $max.Height)
$Host.UI.RawUI.BufferSize = New-Object System.Management.Automation.Host.Size($max.Width, $bufH)
try {
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($max.Width, $max.Height)
} catch {
    $Host.UI.RawUI.WindowSize = New-Object System.Management.Automation.Host.Size($max.Width, ($max.Height - 1))
}
Clear-Host
$Host.UI.RawUI.WindowTitle = 'Ass9 Helm Lab - devops-cluster'

Set-Location 'C:\Users\bhamr\anti\Devops\Assignment\Ass9'

$tmpKube = Join-Path $env:TEMP 'ass9-kubeconfig'
Copy-Item "$HOME\.kube\config" $tmpKube -Force
kubectl config use-context kind-devops-cluster --kubeconfig $tmpKube | Out-Null
$env:KUBECONFIG = $tmpKube

function Show-Header {
    Write-Host '==============================================================' -ForegroundColor Cyan
    Write-Host ' Assignment 9 - Container Orchestration Using Helm Charts' -ForegroundColor Cyan
    Write-Host ' Cluster: kind-devops-cluster   Release: student-webapp' -ForegroundColor Cyan
    Write-Host '==============================================================' -ForegroundColor Cyan
}

function Show-Cmd([string]$text) {
    Write-Host ''
    Write-Host 'PS Ass9> ' -NoNewline -ForegroundColor DarkCyan
    Write-Host $text -ForegroundColor White
}

function Wait-Go([string]$name) {
    $Host.UI.RawUI.WindowPosition = New-Object System.Management.Automation.Host.Coordinates(0, 0)
    New-Item -ItemType File -Force (Join-Path $sig "$name.ready") | Out-Null
    while (-not (Test-Path (Join-Path $sig "$name.go"))) { Start-Sleep -Milliseconds 150 }
    Remove-Item (Join-Path $sig "$name.ready") -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $sig "$name.go") -Force -ErrorAction SilentlyContinue
}

helm uninstall student-webapp 2>$null | Out-Null
kubectl delete deployment,service -l app.kubernetes.io/instance=student-webapp --ignore-not-found=true 2>$null | Out-Null
Start-Sleep -Seconds 2

Clear-Host
Show-Header
Show-Cmd 'helm lint student-webapp'
helm lint student-webapp
Wait-Go '01-lint'

Clear-Host
Show-Header
Show-Cmd 'helm template student-webapp ./student-webapp'
helm template student-webapp ./student-webapp
Wait-Go '02-template'

Clear-Host
Show-Header
Show-Cmd 'helm install student-webapp ./student-webapp'
helm install student-webapp ./student-webapp
kubectl rollout status deployment/student-webapp --timeout=180s | Out-Null
Start-Sleep -Seconds 2
Show-Cmd 'helm list'
helm list
Show-Cmd 'kubectl get deploy,svc,pods -l app.kubernetes.io/instance=student-webapp'
kubectl get deploy,svc,pods -l app.kubernetes.io/instance=student-webapp
Wait-Go '03-install'

Clear-Host
Show-Header
Show-Cmd 'helm upgrade student-webapp ./student-webapp --set replicaCount=3 --set image.tag=1.26'
helm upgrade student-webapp ./student-webapp --set replicaCount=3 --set image.tag=1.26
kubectl rollout status deployment/student-webapp --timeout=180s | Out-Null
Start-Sleep -Seconds 2
Show-Cmd 'kubectl get deployment student-webapp'
kubectl get deployment student-webapp
kubectl get pods -l app.kubernetes.io/instance=student-webapp
Wait-Go '04-upgrade'

Clear-Host
Show-Header
Show-Cmd 'helm uninstall student-webapp'
helm uninstall student-webapp
for ($i = 0; $i -lt 60; $i++) {
    $remaining = kubectl get pods -l app.kubernetes.io/instance=student-webapp --no-headers 2>$null
    if (-not $remaining) { break }
    Start-Sleep -Seconds 1
}
Start-Sleep -Seconds 2
Show-Cmd 'kubectl get all -l app.kubernetes.io/instance=student-webapp'
kubectl get all -l app.kubernetes.io/instance=student-webapp
Wait-Go '05-uninstall'

Write-Host ''
Write-Host 'All steps completed.' -ForegroundColor Green
Start-Sleep -Seconds 15
