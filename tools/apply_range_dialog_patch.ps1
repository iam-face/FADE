# Apply RangeDialog.hpp layout patch when Arma 3 has the file locked.
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "rsc\RangeDialog.hpp.patched"
$dst = Join-Path $root "rsc\RangeDialog.hpp"
if (-not (Test-Path $src)) { Write-Error "Missing $src"; exit 1 }
Copy-Item -Path $src -Destination $dst -Force
Write-Host "Applied RangeDialog.hpp patch."
