# https://github.com/githubdatabridge/sih-poc-powershell-scripts

if ($args.Length -eq 0) {
    Write-Host -f Red "No app id provided"
    Exit
}
else {
    $appId = $args[0]
}

. .\functions\fn-qrs-api.ps1

$config = Get-Content -Path ".\_config.json" -Raw | ConvertFrom-Json 
$logFile = $config.log.file
$config = $config.target
# Parse the JSON content into a PowerShell object
Write-Host "Import server is" $config.server_url

function logError {
    param ( 
        [Parameter(Mandatory = $true)] $log,
        [Parameter(Mandatory = $true)] $msg
    )

    Write-Host -f Red $msg

    $logData = @([PSCustomObject] @{
        
        "Timestamp"= $null
        "appName"= $null
        "srcAppId"= $null
        "srcServer"= $null
        "srcStream"= $null
        "privateOrCommunityObjects" = $null
        "newAppId"= $null
        "newSrv"= $null
        "errors"= $msg;
    })
    # Append the log data to the existing log file
    $logData | Export-Csv -Path $log -NoTypeInformation -Append
}


if ((Test-Path "$appId.qvf") -and (Test-Path "$appId.json")) {
    $appMeta = Get-Content -Path "$appId.json" -Raw | ConvertFrom-Json 
    

    $newApp = QRS_API -conn $config  -method "POST" `
        -api "qrs/app/upload?name=$($appMeta.name)" -silent $true `
        -file "$appId.qvf" -contenttype "application/vnd.qlik.sense.app"
    
    $errors = 0

    if ($newApp.id) {

        $logData = @([PSCustomObject] @{
            "Timestamp"                 = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "appName"                   = $appMeta.name
            "srcAppId"                  = $appId
            "srcServer"                 = $appMeta.server_url
            "srcStream"                 = $appMeta.stream_name
            "privateOrCommunityObjects" = $appMeta.objects.Count
            "newAppId"                  = $newApp.id
            "newSrv"                    = $config.server_url
            "errors"                    = $null
        })

        # Check if the log file exists, if not, create a new file with headers
        if (-not (Test-Path $logFile)) {
            $logData | Export-Csv -Path $logFile -NoTypeInformation
        }
        else {
            # Append the log data to the existing log file
            $logData | Export-Csv -Path $logFile -NoTypeInformation -Append
        }
        
        # --------------------------------------------------------------------------------------------
        Write-Host -f Cyan "Publishing app to stream '$($appMeta.stream_name)'"
    
        [array] $streamInfo = QRS_API -conn $config -method "GET" -silent $true `
            -api "qrs/stream?filter=name eq '$($appMeta.stream_name)'"

        if ($streamInfo.Length -gt 0) {
            $res = QRS_API -conn $config -method "PUT" `
                -api "qrs/app/$($newApp.id)/publish?stream=$($streamInfo.id)" -silent $true `
        
        }
        else {
            logError -log $logFile -msg "Could not find former stream '$($appMeta.stream_name)'"
            $errors++
        }

        # --------------------------------------------------------------------------------------------
        Write-Host -f Cyan "Setting app owner to $($appMeta.owner.userDirectory)\$($appMeta.owner.userId)"

        [array] $ownerInfo = QRS_API -conn $config -method "GET" -silent $true `
            -api "qrs/user?filter=userId eq '$($appMeta.owner.userId)' and userDirectory eq '$($appMeta.owner.userDirectory)'"

        if ($ownerInfo.Length -gt 0) {
            $res = QRS_API -conn $config -method "PUT" `
                -api "qrs/app/$($newApp.id)" -silent $true `
                -body (@{"modifiedDate" = "2099-12-31T23:59:59.999Z"; "owner" = @{"id" = $ownerInfo[0].id } } | ConvertTo-Json)
        }
        else {
            logError -log $logFile -msg "Could not find former app owner $($appMeta.owner.userDirectory)\$($appMeta.owner.userId)"
            $errors++
        }

        # --------------------------------------------------------------------------------------------
        foreach ($appObj in $appMeta.objects) {

            # determine object type
            if (!$appObj.approved -and !$appObj.published) {
                $objType = "private"
            }
            elseif (!$appObj.approved -and $appObj.published) {
                $objType = "community"
            }
            else {
                $objType = "base"
            }

            Write-Host -f Cyan "Fixing props of $objType $($appObj.objectType) '$($appObj.name)' ($($appObj.owner.userDirectory)\$($appObj.owner.userId))" 
            
            [array] $ownerInfo = QRS_API -conn $config -method "GET" -silent $true `
                -api "qrs/user?filter=userId eq '$($appObj.owner.userId)' and userDirectory eq '$($appObj.owner.userDirectory)'"

            [array] $newObjInfo = QRS_API -conn $config -method "GET" -silent $true `
                -api "qrs/app/object?filter=app.id eq $($newApp.id) and engineObjectId eq '$($appObj.engineObjectId)'"

            if ($ownerInfo.Length -eq 0) {
                logError -log $logFile -msg "Could not find former object owner $($appObj.owner.userDirectory)\$($appObj.owner.userId)"
                $errors++
                # Exception handling with user mapping needed here ...
            } 
            elseif ($newObjInfo.Length -eq 0) {
                logError -log $logFile -msg "Could not find former engineObjectId $($appMeta.engineObjectId)"
                $errors++
            } 
            else {
                $newSettings = @{
                    "modifiedDate" = "2099-12-31T23:59:59.999Z"
                    "approved"     = $appObj.approved
                    "owner"        = @{"id" = $ownerInfo[0].id }
                }

                $res = QRS_API -conn $config -method "PUT" -silent $true `
                    -api "qrs/app/object/$($newObjInfo[0].id)" `
                    -body ($newSettings | ConvertTo-Json)

                if (!$appObj.published) {
                    # unpublish the object if it was originally published=false
                    $res = QRS_API -conn $config -method "PUT" -silent $true `
                        -api "qrs/app/object/$($newObjInfo[0].id)/unpublish"       
                }

                # $checkObj = QRS_API -conn $config -method "GET" -silent $true `
                # -api "qrs/app/object/$($newObjInfo[0].id)" `

                Write-Host -f Green "Updated $ObjType object."
                # Write-Host "approved: should be $($appObj.approved) / is $($checkObj.approved)"
                # Write-Host "published: should be $($appObj.published) / is $($checkObj.published)"
                # Write-Host "Owner: should be $($appObj.owner.userId) / is $($checkObj.owner.userId)"
            }
        }

       if ($errors -eq 0) {
            $response = $args[1]
            while ($response -notin "Y", "N") {
                $response = Read-Host "Do you want to remove the files? (Y/N)"
                $response = $response.ToUpper()
            }
            if ($response -eq "Y") {
                Remove-Item "$appId.qvf"
                Remove-Item "$appId.json"
            }
        }
        else {
            Write-Host -f Red "$errors Errors happened. Scroll up and check ..."
            $response = ""
            while ($response -notin "Y", "N") {
                $response = Read-Host "Do you want to remove the incompletely imported app from $($config.server_url)? (Y/N)"
                $response = $response.ToUpper()
            }
            if ($response -eq "Y") {
                $res = QRS_API -conn $config -method "DELETE" -silent $true `
                    -api "qrs/app/$($newApp.id)"    
            }
        }
       
        
    } 
    else {
        Write-Host -f Red "Unexpected result while uploading .qvf file"
        Exit
    }

 
} 
else {
    Write-Host -f Red "Cannot find both files '$appId.qvf' and '$appId.json'"
    Exit
}

Write-Host -f Green "Finished script."
