# FADE headless dedicated-server test runner.
# Uses Face\local_server (StartServer.ps1, client_modline.txt, server.cfg) + C:\Arma3Server.
#
# Usage (from mission repo root):
#   powershell -ExecutionPolicy Bypass -File tools\headless\Run-FadeHeadlessTest.ps1
#   powershell -ExecutionPolicy Bypass -File tools\headless\Run-FadeHeadlessTest.ps1 -Mode compile
#   powershell -ExecutionPolicy Bypass -File tools\headless\Run-FadeHeadlessTest.ps1 -Mode playthrough
#   powershell -ExecutionPolicy Bypass -File tools\headless\Run-FadeHeadlessTest.ps1 -Mode boot -KeepServer
#
# Modes:
#   boot        — mission init smoke only (no MissionTestSuite)
#   compile     — MissionTestSuite server checks (default)
#   testsuite   — alias for compile
#   playthrough — MissionPlaythroughSuite (live mission init, ~10 min budget)
#   all         — MissionTestSuite then MissionPlaythroughSuite (~20–25 min after boot)
#
# Config: copy tools\headless\headless.local.json.example -> headless.local.json
# Env overrides: FADE_A3_SERVER_ROOT, FADE_A3_CLIENT_ROOT, FADE_LOCAL_SERVER_DIR

[CmdletBinding()]
param(
    [ValidateSet('boot', 'compile', 'testsuite', 'suite', 'playthrough', 'all')]
    [string] $Mode = 'compile',
    [string] $A3ServerRoot = '',
    [string] $A3ClientRoot = '',
    [string] $LocalServerDir = '',
    [string] $MissionName = '',
    [int] $Port = 0,
    [switch] $SkipModSync,
    [switch] $KeepServer,
    [switch] $NoShutdownWait
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
. (Join-Path $PSScriptRoot 'FadeHeadlessLib.ps1')

$cfg = Get-FadeHeadlessConfig -RepoRoot $RepoRoot -Overrides @{
    A3ServerRoot   = $A3ServerRoot
    A3ClientRoot   = $A3ClientRoot
    LocalServerDir = $LocalServerDir
    MissionName    = $MissionName
    Port           = if ($Port -gt 0) { $Port } else { $null }
}

$Mode = $Mode.ToLowerInvariant()
if ($Mode -in @('testsuite', 'suite')) { $Mode = 'compile' }

$a3Root = $cfg.A3ServerRoot
$localServer = $cfg.LocalServerDir
$missionName = $cfg.MissionName
$port = [int]$cfg.Port
$missionRoot = $RepoRoot
$missionSrc = $missionRoot
$missionDst = Join-Path $a3Root "mpmissions\$missionName"
$profiles = Join-Path $a3Root 'profiles_local'
$syncScript = Join-Path $localServer 'Sync-ClientModlineFromLauncher.ps1'
$heliOpsLink = Join-Path $a3Root 'mpmissions\FAC_HeliOps.SefrouRamal'

$bootTimeoutSec = [int]$cfg.BootTimeoutSec
$suiteTimeoutSec = switch ($Mode) {
    'boot' { 120 }
    'playthrough' { [int]$cfg.PlaythroughTimeoutSec }
    'all' { [int]$cfg.CompileTimeoutSec + [int]$cfg.PlaythroughTimeoutSec + 300 }
    default { [int]$cfg.CompileTimeoutSec }
}

Write-Host "=== FADE headless test (mode=$Mode, bootTimeout=${bootTimeoutSec}s, suiteTimeout=${suiteTimeoutSec}s) ==="
Write-Host "Repo:    $missionRoot"
Write-Host "Server:  $a3Root"
Write-Host "Profile: $localServer"

if (-not (Test-Path -LiteralPath (Join-Path $a3Root 'arma3server_x64.exe'))) {
    throw "arma3server_x64.exe not found under $a3Root"
}
if (-not (Test-Path -LiteralPath $localServer)) {
    throw "local_server folder not found: $localServer"
}

if (-not $SkipModSync -and (Test-Path -LiteralPath $syncScript)) {
    Write-Host 'Syncing client_modline.txt from latest launcher RPT...'
    & $syncScript -Arma3ClientRoot $cfg.A3ClientRoot
}

if (Test-Path -LiteralPath $heliOpsLink) {
    Write-Host "Removing stale HeliOps junction: $heliOpsLink"
    cmd /c "rmdir `"$heliOpsLink`"" 2>$null
}

Ensure-FadeMissionJunction -MissionSrc $missionSrc -MissionDst $missionDst
Clear-FadeHeadlessArtifacts -MissionRoot $missionRoot

if ($Mode -ne 'boot') {
    Set-FadeHeadlessFlag -MissionRoot $missionRoot -Mode $Mode
}

Stop-FadeArmaServer
$bootStart = Get-Date
$serverProc = $null

try {
    Write-Host 'Starting dedicated server...'
    $serverProc = Start-FadeDedicatedServer -LocalServerDir $localServer -A3ServerRoot $a3Root -Port $port
    Wait-FadeServerBoot -ProfilesPath $profiles -BootStart $bootStart -BootTimeoutSec $bootTimeoutSec -MissionName $missionName

    if ($Mode -eq 'boot') {
        Write-Host 'Watching boot stability (30s)...'
        Start-Sleep -Seconds 30
        if ($serverProc.HasExited) { throw 'Server process exited during boot stability window.' }
        $rpt = Get-FadeServerRpt -ProfilesPath $profiles -NotBefore $bootStart
        $rptText = if ($rpt) { Get-Content -LiteralPath $rpt.FullName -Raw } else { '' }
        $summary = Get-FadeHeadlessRptSummary -RptText $rptText
        if ($summary.ScriptErrors.Count -gt 0) {
            throw "Mission script errors in RPT ($($summary.ScriptErrors.Count) in rsc\)."
        }
        Write-Host 'PASS: boot smoke.'
        exit 0
    }

    Write-Host "Waiting for headless suite (mode=$Mode)..."
    $doneHit = Wait-FadeRptMatch -ProfilesPath $profiles -NotBefore $bootStart -Patterns @(
        '\[FAC Headless\] ========== DONE =========='
    ) -TimeoutSec $suiteTimeoutSec -Label "headless $Mode complete"

    $resultFile = Read-FadeHeadlessResultFile -MissionRoot $missionRoot
    $rpt = if ($doneHit) { $doneHit.Rpt } else { Get-FadeServerRpt -ProfilesPath $profiles -NotBefore $bootStart }
    $rptText = if ($doneHit) { $doneHit.Text } elseif ($rpt) { Get-Content -LiteralPath $rpt.FullName -Raw } else { '' }
    $summary = Get-FadeHeadlessRptSummary -RptText $rptText

    if (-not $doneHit -and -not $resultFile) {
        throw "Timed out waiting for headless test completion (${suiteTimeoutSec}s)."
    }

    $pass = $null
    $fail = $null
    $skip = 0
    if ($resultFile) {
        if ($resultFile.ContainsKey('pass')) { $pass = [int]$resultFile['pass'] }
        if ($resultFile.ContainsKey('fail')) { $fail = [int]$resultFile['fail'] }
        if ($resultFile.ContainsKey('skip')) { $skip = [int]$resultFile['skip'] }
        Write-Host "Result file: pass=$pass fail=$fail skip=$skip note=$($resultFile['note'])"
    }
    if ($null -eq $pass -and $null -ne $summary.Pass) { $pass = $summary.Pass }
    if ($null -eq $fail -and $null -ne $summary.Fail) { $fail = $summary.Fail }
    if ($summary.Skip) { $skip = $summary.Skip }

    if ($summary.ScriptErrors.Count -gt 0) {
        Write-Host 'Script errors in RPT:'
        $summary.ScriptErrors | ForEach-Object { Write-Host "  $_" }
        throw "Mission script errors in RPT ($($summary.ScriptErrors.Count))."
    }

    if ($null -eq $fail -or $fail -gt 0) {
        if ($summary.FailLines.Count -gt 0) {
            Write-Host 'Recent FAIL lines:'
            $summary.FailLines | ForEach-Object { Write-Host "  $_" }
        }
        throw "Headless $Mode failed (pass=$pass fail=$fail skip=$skip)."
    }

    Write-Host "PASS: headless $Mode (pass=$pass fail=$fail skip=$skip)."
    if ($rpt) { Write-Host "RPT: $($rpt.FullName)" }
    exit 0
}
catch {
    $rpt = Get-FadeServerRpt -ProfilesPath $profiles
    Write-Error $_
    if ($rpt) {
        Write-Host "Latest RPT: $($rpt.FullName)"
        Get-Content -LiteralPath $rpt.FullName -Tail 50
    }
    exit 1
}
finally {
    Clear-FadeHeadlessArtifacts -MissionRoot $missionRoot
    if (-not $KeepServer) {
        Write-Host 'Stopping dedicated server...'
        Stop-FadeArmaServer
        if ($serverProc -and ($serverProc -is [System.Diagnostics.Process]) -and -not $serverProc.HasExited) {
            Stop-Process -Id $serverProc.Id -Force -ErrorAction SilentlyContinue
        }
        if (-not $NoShutdownWait) { Start-Sleep -Seconds 2 }
    } else {
        Write-Host 'KeepServer set — arma3server left running.'
    }
}
