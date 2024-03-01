param(
    [Parameter(Mandatory=$true)] $env
)
. .\functions\fn-qrs-api.ps1

$config = Get-Content -Path ".\_config.json" -Raw | ConvertFrom-Json 
$myEnv = $config.env."$env"

if ($config.env."$env".server_url) {
    Write-Host "`nEnvironment $env is linked to server " -NoNewLine
    Write-Host -f Cyan $myEnv.server_url
}
else {
    Write-Host -f Red "No such environment '$env'."
}

$s = QRS_API -conn $myEnv  -method "GET" `
    -api "qrs/app/count" -trace 0

if ($a) {
    Write-Host "User " -NoNewLine
    Write-Host -f Cyan $($myEnv.auth_header.PSObject.Properties.Value) -NoNewLine 
    Write-Host " has access to " -NoNewLine
    if ($s.value -gt 0) {
        Write-Host -f Green $s.value -NoNewLine 
    } else {
        Write-Host -f Red $s.value -NoNewLine 
    }
    Write-Host " apps.`n"
}