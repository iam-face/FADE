# Apply Medical Training dialog layout (replaces block in description.ext).
$root = Split-Path -Parent $PSScriptRoot
$ext = Join-Path $root "description.ext"
$patch = Join-Path $root "rsc\MedicalTrainingDialog.patched.hpp"
if (-not (Test-Path $patch)) { Write-Error "Missing $patch"; exit 1 }
$content = Get-Content $ext -Raw
$start = $content.IndexOf("// Medical training terminal")
$end = $content.IndexOf("// rsc scripts loaded via execVM")
if ($start -lt 0 -or $end -lt 0) { Write-Error "Could not find medical dialog block in description.ext"; exit 1 }
$patched = Get-Content $patch -Raw
$newContent = $content.Substring(0, $start) + $patched + "`r`n" + $content.Substring($end)
Set-Content -Path $ext -Value $newContent -NoNewline
Write-Host "Applied Medical Training dialog to description.ext"
