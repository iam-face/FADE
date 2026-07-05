# Apply Scenario GUI layout fixes when description.ext is not locked (close Arma 3 first).
$root = Split-Path $PSScriptRoot -Parent
$src = Join-Path $root "description.ext.patched"
$dest = Join-Path $root "description.ext"
if (-not (Test-Path $src)) {
    Write-Error "Missing description.ext.patched"
    exit 1
}
try {
    Copy-Item -LiteralPath $src -Destination $dest -Force
    Write-Host "Applied Scenario GUI layout patch to description.ext"
} catch {
    Write-Error "Could not overwrite description.ext. Close Arma 3 and retry."
    exit 1
}
