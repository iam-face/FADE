# Shared helpers for FADE headless dedicated-server testing.
$script:FadeHeadlessDefaults = @{
    A3ServerRoot         = 'C:\Arma3Server'
    A3ClientRoot         = 'D:\SteamLibrary\steamapps\common\Arma 3'
    LocalServerDir       = 'C:\Users\matth\Documents\Arma 3 - Other Profiles\Face\local_server'
    MissionName          = 'CTB_FAC_FADE.Altis'
    Port                 = 2302
    BootTimeoutSec       = 600
    CompileTimeoutSec    = 900
    PlaythroughTimeoutSec = 1800
}

function Get-FadeHeadlessConfig {
    param(
        [string] $RepoRoot,
        [hashtable] $Overrides = @{}
    )
    $cfg = @{} + $script:FadeHeadlessDefaults
    $localJson = Join-Path $RepoRoot 'tools\headless\headless.local.json'
    if (Test-Path -LiteralPath $localJson) {
        $fromFile = Get-Content -LiteralPath $localJson -Raw | ConvertFrom-Json
        foreach ($prop in $fromFile.PSObject.Properties) {
            $key = $prop.Name
            switch -Regex ($key) {
                '^a3ServerRoot$' { $cfg.A3ServerRoot = $prop.Value; continue }
                '^a3ClientRoot$' { $cfg.A3ClientRoot = $prop.Value; continue }
                '^localServerDir$' { $cfg.LocalServerDir = $prop.Value; continue }
                '^missionName$' { $cfg.MissionName = $prop.Value; continue }
                '^port$' { $cfg.Port = [int]$prop.Value; continue }
                '^bootTimeoutSec$' { $cfg.BootTimeoutSec = [int]$prop.Value; continue }
                '^compileTimeoutSec$' { $cfg.CompileTimeoutSec = [int]$prop.Value; continue }
                '^playthroughTimeoutSec$' { $cfg.PlaythroughTimeoutSec = [int]$prop.Value; continue }
                default { $cfg[$key] = $prop.Value }
            }
        }
    }
    foreach ($key in $Overrides.Keys) {
        if ($null -ne $Overrides[$key] -and "$($Overrides[$key])" -ne '') { $cfg[$key] = $Overrides[$key] }
    }
    if ($env:FADE_A3_SERVER_ROOT) { $cfg.A3ServerRoot = $env:FADE_A3_SERVER_ROOT.Trim() }
    if ($env:FADE_A3_CLIENT_ROOT) { $cfg.A3ClientRoot = $env:FADE_A3_CLIENT_ROOT.Trim() }
    if ($env:FADE_LOCAL_SERVER_DIR) { $cfg.LocalServerDir = $env:FADE_LOCAL_SERVER_DIR.Trim() }
    return $cfg
}

function Stop-FadeArmaServer {
    Get-Process -Name 'arma3server_x64' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

function Get-FadeServerRpt {
    param(
        [string] $ProfilesPath,
        [datetime] $NotBefore = [datetime]::MinValue
    )
    $all = Get-ChildItem -LiteralPath $ProfilesPath -Filter 'arma3server_x64_*.rpt' -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -ge $NotBefore } |
        Sort-Object LastWriteTime -Descending
    if ($all) { return $all | Select-Object -First 1 }
    Get-ChildItem -LiteralPath $ProfilesPath -Filter 'arma3server_x64_*.rpt' -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
}

function Wait-FadeRptMatch {
    param(
        [string] $ProfilesPath,
        [datetime] $NotBefore,
        [string[]] $Patterns,
        [int] $TimeoutSec,
        [string] $Label = 'marker'
    )
    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    $lastLog = [datetime]::MinValue
    while ((Get-Date) -lt $deadline) {
        $rpt = Get-FadeServerRpt -ProfilesPath $ProfilesPath -NotBefore $NotBefore
        if ($rpt) {
            $text = Get-Content -LiteralPath $rpt.FullName -Raw -ErrorAction SilentlyContinue
            if ($text) {
                foreach ($p in $Patterns) {
                    if ($text -match $p) { return @{ Rpt = $rpt; Match = $Matches[0]; Text = $text } }
                }
            }
            if (((Get-Date) - $lastLog).TotalSeconds -ge 30) {
                $mb = [math]::Round($rpt.Length / 1MB, 1)
                Write-Host ("  ... waiting for {0} ({1} MB RPT, updated {2})" -f $Label, $mb, $rpt.LastWriteTime.ToString('HH:mm:ss'))
                $lastLog = Get-Date
            }
        } elseif (((Get-Date) - $lastLog).TotalSeconds -ge 30) {
            Write-Host '  ... waiting for server RPT file...'
            $lastLog = Get-Date
        }
        Start-Sleep -Seconds 5
    }
    return $null
}

function Ensure-FadeMissionJunction {
    param(
        [string] $MissionSrc,
        [string] $MissionDst
    )
    if (-not (Test-Path -LiteralPath $MissionSrc)) {
        throw "Mission source not found: $MissionSrc"
    }
    if (-not (Test-Path -LiteralPath $MissionDst)) {
        Write-Host "Creating mission junction: $MissionDst -> $MissionSrc"
        New-Item -ItemType Junction -Path $MissionDst -Target $MissionSrc | Out-Null
        return
    }
    $item = Get-Item -LiteralPath $MissionDst
    if ($item.LinkType -ne 'Junction') {
        Write-Warning "Mission path exists but is not a junction: $MissionDst"
    } else {
        Write-Host "Mission junction OK: $MissionDst"
    }
}

function Set-FadeHeadlessFlag {
    param(
        [string] $MissionRoot,
        [string] $Mode
    )
    $flg = Join-Path $MissionRoot 'headless_test.flg'
    Set-Content -LiteralPath $flg -Value $Mode.Trim().ToLowerInvariant() -Encoding ASCII -NoNewline
    Write-Host "Wrote headless flag: $flg ($Mode)"
}

function Clear-FadeHeadlessArtifacts {
    param([string] $MissionRoot)
    foreach ($name in @('headless_test.flg', 'headless_test_result.txt')) {
        $path = Join-Path $MissionRoot $name
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force -ErrorAction SilentlyContinue
        }
    }
}

function Read-FadeHeadlessResultFile {
    param([string] $MissionRoot)
    $path = Join-Path $MissionRoot 'headless_test_result.txt'
    if (-not (Test-Path -LiteralPath $path)) { return $null }
    $data = @{}
    Get-Content -LiteralPath $path | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') { $data[$Matches[1]] = $Matches[2] }
    }
    return $data
}

function Get-FadeHeadlessRptSummary {
    param([string] $RptText)
    $summary = @{
        Pass          = $null
        Fail          = $null
        Skip          = $null
        Done          = $false
        ScriptErrors  = @()
        FailLines     = @()
    }
    if ($RptText -match '\[FAC Headless\] ========== DONE ==========') {
        $summary.Done = $true
    }
    if ($RptText -match '\[FAC TestSuite\] ========== SERVER SUITE END: (\d+) passed, (\d+) failed ==========') {
        $summary.Pass = [int]$Matches[1]
        $summary.Fail = [int]$Matches[2]
    }
    if ($RptText -match '\[FAC Playthrough\] ========== PLAYTHROUGH SUITE END: (\d+) pass, (\d+) fail, (\d+) skipped') {
        $summary.Pass = [int]$Matches[1]
        $summary.Fail = [int]$Matches[2]
        $summary.Skip = [int]$Matches[3]
    }
    $summary.ScriptErrors = [regex]::Matches($RptText, 'Error in expression[^\r\n]*\\rsc\\[^\r\n]*') |
        ForEach-Object { $_.Value } | Select-Object -Unique
    $summary.FailLines = [regex]::Matches($RptText, '\[FAC TestSuite\] FAIL[^\r\n]*') |
        ForEach-Object { $_.Value } | Select-Object -Last 25
    if ($summary.FailLines.Count -eq 0) {
        $summary.FailLines = [regex]::Matches($RptText, '\[FAC Playthrough\][^\r\n]*FAIL[^\r\n]*') |
            ForEach-Object { $_.Value } | Select-Object -Last 25
    }
    return $summary
}

function Start-FadeDedicatedServer {
    param(
        [string] $LocalServerDir,
        [string] $A3ServerRoot,
        [int] $Port
    )
    $startScript = Join-Path $LocalServerDir 'StartServer.ps1'
    if (-not (Test-Path -LiteralPath $startScript)) {
        throw "StartServer.ps1 not found: $startScript"
    }
    Push-Location -LiteralPath $LocalServerDir
    try {
        & $startScript -A3Root $A3ServerRoot -Port $Port -Detach
        if ($LASTEXITCODE -ne 0) {
            throw "StartServer.ps1 -Detach failed (code $LASTEXITCODE)."
        }
    } finally {
        Pop-Location
    }
    Start-Sleep -Seconds 3
    $arma = Get-Process -Name 'arma3server_x64' -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $arma) {
        throw 'arma3server_x64.exe did not start.'
    }
    return $arma
}

function Wait-FadeServerBoot {
    param(
        [string] $ProfilesPath,
        [datetime] $BootStart,
        [int] $BootTimeoutSec,
        [string] $MissionName
    )
    $steamHit = Wait-FadeRptMatch -ProfilesPath $ProfilesPath -NotBefore $BootStart -Patterns @(
        'Connected to Steam servers'
    ) -TimeoutSec $BootTimeoutSec -Label 'Steam connect (mod load)'
    if (-not $steamHit) { throw 'Timed out waiting for mod load / Steam connect in server RPT.' }
    Write-Host "Mod load complete: $($steamHit.Match)"

    $missionBase = if ($MissionName -match '^(.+)\.[^.]+$') { $Matches[1] } else { $MissionName }
    $missionHit = Wait-FadeRptMatch -ProfilesPath $ProfilesPath -NotBefore $BootStart -Patterns @(
        "Mission file:\s*$([regex]::Escape($missionBase))",
        "Mission directory:\s*mpmissions\\\\$([regex]::Escape($MissionName))"
    ) -TimeoutSec 180 -Label 'mission start'
    if (-not $missionHit) { throw "Timed out waiting for mission start ($MissionName)." }
    Write-Host "Mission load detected: $($missionHit.Match)"

    $readyHit = Wait-FadeRptMatch -ProfilesPath $ProfilesPath -NotBefore $BootStart -Patterns @(
        '\[FAC profile\] FADE_serverInitReady',
        '\[FAC profile\] initServer total',
        '\[AmbientCivilians\] v4 loading'
    ) -TimeoutSec ([Math]::Max(120, $BootTimeoutSec - 60)) -Label 'FADE server init ready'
    if (-not $readyHit) { throw 'Timed out waiting for FADE server init ready marker in RPT.' }
    Write-Host "Server init ready: $($readyHit.Match)"
}
