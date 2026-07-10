# Parse-check FADE .sqf / description.ext with SQF-VM runtime (no Arma 3 required).
param(
    [string] $Path = '',
    [switch] $InstallIfMissing,
    [switch] $IncludeTools,
    [switch] $PreprocessOnly
)

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$BinDir = Join-Path $RepoRoot 'tools\sqfvm\bin'

function Get-SqfVmExe {
    $exe = Get-ChildItem -LiteralPath $BinDir -Filter 'sqfvm*.exe' -Recurse -ErrorAction SilentlyContinue |
        Sort-Object FullName |
        Select-Object -First 1
    if (-not $exe) { return $null }
    return $exe.FullName
}

$sqfvm = Get-SqfVmExe
if (-not $sqfvm -and $InstallIfMissing) {
    & (Join-Path $PSScriptRoot 'Install-SqfVmRuntime.ps1')
    $sqfvm = Get-SqfVmExe
}
if (-not $sqfvm) {
    throw @"
SQF-VM runtime not found under tools\sqfvm\bin.
Run: powershell -ExecutionPolicy Bypass -File tools\sqfvm\Install-SqfVmRuntime.ps1
Or install the 'SQF-VM Language Server' VS Code/Cursor extension for editor diagnostics.
"@
}

function Get-LintTargets {
    param([string] $Root, [bool] $WithTools)
    $excludeFile = Join-Path $PSScriptRoot 'lint-exclude.txt'
    $exclude = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    if (Test-Path -LiteralPath $excludeFile) {
        Get-Content -LiteralPath $excludeFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and $line -notmatch '^\s*#') { [void]$exclude.Add(($line -replace '/', '\')) }
        }
    }
    $patterns = @('*.sqf', 'description.ext')
    $files = foreach ($pat in $patterns) {
        Get-ChildItem -LiteralPath $Root -Recurse -File -Filter $pat -ErrorAction SilentlyContinue
    }
    if (-not $WithTools) {
        $files = $files | Where-Object { $_.FullName -notmatch '\\tools\\' }
    }
    $files | Where-Object {
        $_.FullName -notmatch '\\rsc\\archive\\' -and
        $_.Name -notmatch '\.new$'
    } | ForEach-Object {
        $rel = $_.FullName.Substring($Root.Length).TrimStart('\')
        if (-not $exclude.Contains($rel)) { $_ }
    } | Sort-Object FullName -Unique
}

$targets = if ($Path) {
    $resolved = Resolve-Path -LiteralPath $Path
    ,@(Get-Item -LiteralPath $resolved)
} else {
    Get-LintTargets -Root $RepoRoot -WithTools:$IncludeTools
}

$virtualMap = "${RepoRoot}|/"
$failures = [System.Collections.Generic.List[string]]::new()
$passed = 0
$preprocessOnlyNames = @('description.ext')

Write-Host "SQF-VM: $($targets.Count) file(s) via $sqfvm"

foreach ($file in $targets) {
    $rel = $file.FullName.Substring($RepoRoot.Length).TrimStart('\')
    $isPreprocessCheck = $PreprocessOnly -or ($file.Name -in $preprocessOnlyNames)
    $args = @(
        '--automated',
        '--suppress-welcome',
        '--no-execute-print',
        '-v', $virtualMap
    )
    if ($PreprocessOnly) {
        $args += @('-E', $file.FullName)
    } elseif ($file.Name -ieq 'description.ext') {
        $args += @('-E', $file.FullName)
    } else {
        $args += @(
            '--parse-only',
            '-i', $file.FullName
        )
    }

    $output = & $sqfvm @args 2>&1
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        $failures.Add($rel)
        Write-Host "FAIL [$code] $rel" -ForegroundColor Red
        if ($output) { $output | Select-Object -First 12 | ForEach-Object { Write-Host "  $_" } }
    } else {
        $passed++
        if ($isPreprocessCheck) {
            Write-Host "OK (preprocess) $rel"
        }
    }
}

Write-Host "SQF-VM lint: $passed passed, $($failures.Count) failed."
if ($failures.Count -gt 0) {
    Write-Host 'Failed files:'
    $failures | ForEach-Object { Write-Host "  $_" }
    exit 1
}
exit 0
