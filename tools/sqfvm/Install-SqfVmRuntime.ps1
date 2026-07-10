# Download SQF-VM runtime (Windows x64) into tools/sqfvm/bin for CLI linting.
param(
    [string] $ReleaseTag = '',
    [string] $AssetName = 'sqfvm_windows_x64.zip',
    [switch] $Force
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BinDir = Join-Path $RepoRoot 'tools\sqfvm\bin'
$ConfigPath = Join-Path $PSScriptRoot 'sqfvm.local.json'

if (Test-Path -LiteralPath $ConfigPath) {
    $cfg = Get-Content -LiteralPath $ConfigPath -Raw | ConvertFrom-Json
    if ($cfg.releaseTag -and -not $ReleaseTag) { $ReleaseTag = $cfg.releaseTag }
    if ($cfg.assetName -and $AssetName -eq 'sqfvm_windows_x64.zip') { $AssetName = $cfg.assetName }
}
if (-not $ReleaseTag) { $ReleaseTag = 'v2026.04.03-ed9f5f5' }

$exe = Get-ChildItem -LiteralPath $BinDir -Filter 'sqfvm*.exe' -ErrorAction SilentlyContinue | Select-Object -First 1
if ($exe -and -not $Force) {
    Write-Host "SQF-VM runtime already present: $($exe.FullName)"
    & $exe.FullName --version
    exit 0
}

New-Item -ItemType Directory -Path $BinDir -Force | Out-Null
$zipPath = Join-Path $env:TEMP "sqfvm-$ReleaseTag.zip"
$url = "https://github.com/SQFvm/runtime/releases/download/$ReleaseTag/$AssetName"

Write-Host "Downloading $url ..."
Invoke-WebRequest -Uri $url -OutFile $zipPath -UseBasicParsing
Expand-Archive -LiteralPath $zipPath -DestinationPath $BinDir -Force
Remove-Item -LiteralPath $zipPath -Force -ErrorAction SilentlyContinue

$exe = Get-ChildItem -LiteralPath $BinDir -Filter 'sqfvm*.exe' -Recurse | Select-Object -First 1
if (-not $exe) {
    throw "sqfvm executable not found under $BinDir after extract."
}

Write-Host "Installed: $($exe.FullName)"
& $exe.FullName --version
