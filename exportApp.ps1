# https://github.com/githubdatabridge/sih-poc-powershell-scripts
if ($args.Length -eq 0) {
    Write-Host -f Red "No app id provided"
    Exit
}
else {
    $appId = $args[0]
}

. .\functions\fn-qrs-api.ps1

$config = Get-Content -Path ".\_config.json" -Raw | ConvertFrom-Json -Depth 7
$config = $config.source
# Parse the JSON content into a PowerShell object
Write-Host "Export server is" $config.server_url



# Get app info
$app = QRS_API -conn $config -method "GET" -api "qrs/app/$appId" -silent $true
if (!$app) {
    Write-Host -f Red "Unexisting app id:" $appId
    Exit
} 

Write-Host -f Cyan "App: `"$($app.name)`" in stream `"$($app.stream.name)`"" 


[array] $appObjList = QRS_API -conn $config -silent $true -method "GET" `
-api "qrs/app/object/full?filter=app.id eq $appId and approved eq false"

Write-Host -f Cyan $appObjList.Length " private/community objects found in app."

$appMeta = @{
    "name" = $app.name
    "app_id" = $app.id
    "server_url" = $config.server_url
    "owner" = @{"userId" = $app.owner.userId; "userDirectory" = $app.owner.userDirectory }
    "stream_name" = $app.stream.name
    "objects" = @()
}

foreach($appObj in $appObjList) {
        $appMeta.objects += @{
            "engineObjectId" = $appObj.engineObjectId;
            "objectType" = $appObj.objectType;
            "owner" = @{"userId" = $appObj.owner.userId; "userDirectory" = $appObj.owner.userDirectory };
            "name" = $appObj.name;
            "approved" = $appObj.approved;
            "published" = $appObj.published
        }
        # Write-Host $appObj.engineObjectId $appObj.objectType $appObj.approved $appObj.published "`"$($appObj.name)`"" $appObj.owner.userDirectory $appObj.owner.userId
}

$appMeta | ConvertTo-Json -Depth 7 | Out-File -FilePath "$appId.json" -Encoding UTF8

Write-Host -f Green "Created `"$appId.json`""

$exportInfo = QRS_API -conn $config -method "POST" -silent $true `
  -api "qrs/app/$($appId)/export/$(New-Guid)?exportScope=all"


QRS_API -conn $config -method "GET" `
    -api "$($exportInfo.downloadPath.Substring(1))&exportToken=$($exportInfo.exportToken)" -download "$appId.qvf"

Write-Host -f Green "Finished script."

EXIT

