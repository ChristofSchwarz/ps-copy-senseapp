
. .\functions\fn-qrs-api.ps1

$config = Get-Content -Path ".\_config.json" -Raw | ConvertFrom-Json 

$s = QRS_API -conn $config.source  -method "GET" `
    -api "qrs/app/count" -silent $true

$t = QRS_API -conn $config.target  -method "GET" `
    -api "qrs/app/count" -silent $true

Write-Host "`nSource:"
Write-Host "On " -NoNewLine
Write-Host -f Cyan $config.source.server_url -NoNewLine
Write-Host " user " -NoNewLine
Write-Host -f Cyan $($config.source.auth_header.PSObject.Properties.Value) -NoNewLine 
Write-Host " has access to " -NoNewLine
if ($s.value -gt 0) {
    Write-Host -f Green $s.value -NoNewLine 
} else {
    Write-Host -f Red $s.value -NoNewLine 
}
Write-Host " apps."

Write-Host "`nTarget:"
Write-Host "On " -NoNewLine
Write-Host -f Cyan $config.target.server_url -NoNewLine
Write-Host " user " -NoNewLine
Write-Host -f Cyan $($config.target.auth_header.PSObject.Properties.Value) -NoNewLine 
Write-Host " has access to " -NoNewLine
if ($t.value -gt 0) {
    Write-Host -f Green $t.value -NoNewLine 
} else {
    Write-Host -f Red $t.value -NoNewLine 
}
Write-Host " apps."
