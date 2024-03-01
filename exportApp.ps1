param(
    [Parameter(Mandatory = $true)] $env, # name of the env in _config.json
    [Parameter(Mandatory = $true)] $appId # id of the app
)

. "$PSScriptRoot\functions\fn-qrs-api.ps1"

$config = Get-Content -Path "$PSScriptRoot\_config.json" -Raw | ConvertFrom-Json
$myEnv = $config.env."$env"
# Parse the JSON content into a PowerShell objec
If ($myEnv.server_url) {
    Write-Host "Export server is" $myEnv.server_url
} 
else {
    Write-Host -f Red "'$env' is not a valid env in _config.json"
    Exit
}
# if ($args.Length -eq 0) {
#     $appId = Read-Host "Enter id of app to export"
#     if ($appid.Length -ne 36) {         
#         Write-Host -f Red "No app id provided"
#         Exit
#     }
# }
# else {
#     $appId = $args[0]
# }


# Get app info
$app = QRS_API -conn $myEnv -method "GET" -api "qrs/app/$appId" -trace 1
if (!$app) {
    Write-Host -f Red "Unexisting app id:" $appId
    Exit
} 

Write-Host -f Cyan "App: `"$($app.name)`" in stream `"$($app.stream.name)`", file size $([Math]::Round($app.fileSize / 1024 / 1024)) MB" 


[array] $appObjList = QRS_API -conn $myEnv -trace 1 -method "GET" `
    -api "qrs/app/object/full?filter=app.id eq $appId and approved eq false"

Write-Host -f Cyan $appObjList.Length " private/community objects found in app."

$appMeta = @{
    "name"        = $app.name
    "app_id"      = $app.id
    "fileSize"    = $app.fileSize
    "server_url"  = $myEnv.server_url
    "owner"       = @{"userId" = $app.owner.userId; "userDirectory" = $app.owner.userDirectory }
    "stream_name" = $app.stream.name
    "objects"     = @()
}

foreach ($appObj in $appObjList) {
    $appMeta.objects += @{
        "engineObjectId" = $appObj.engineObjectId;
        "objectType"     = $appObj.objectType;
        "owner"          = @{"userId" = $appObj.owner.userId; "userDirectory" = $appObj.owner.userDirectory };
        "name"           = $appObj.name;
        "approved"       = $appObj.approved;
        "published"      = $appObj.published
    }
    # Write-Host $appObj.engineObjectId $appObj.objectType $appObj.approved $appObj.published "`"$($appObj.name)`"" $appObj.owner.userDirectory $appObj.owner.userId
}

$appMeta | ConvertTo-Json -Depth 5 | Out-File -FilePath "$appId.json" -Encoding UTF8

Write-Host -f Green "Created `"$appId.json`""

$exportInfo = QRS_API -conn $myEnv -method "POST" -trace 1 `
    -api "qrs/app/$($appId)/export/$(New-Guid)?exportScope=all"


QRS_API -conn $myEnv -method "GET" `
    -api "$($exportInfo.downloadPath.Substring(1))&exportToken=$($exportInfo.exportToken)" -download "$appId.qvf"

Write-Host -f Green "Finished script."

EXIT

