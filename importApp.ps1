param(
    [Parameter(Mandatory = $true)] $env, # name of the env in _config.json
    [Parameter(Mandatory = $true)] $appId, # id of the app
    [Parameter(Mandatory = $false)] $delFiles = "" # setting to delete .json and .qvf file after successful upload
    
)

. "$PSScriptRoot\functions\fn-qrs-api.ps1"
. "$PSScriptRoot\functions\fn-log.ps1"

$config = Get-Content -Path "$PSScriptRoot\_config.json" -Raw | ConvertFrom-Json
$myEnv = $config.env."$env"
# Parse the JSON content into a PowerShell objec
If ($myEnv.server_url) {
    Write-Host "Import server is" $myEnv.server_url
} 
else {
    Write-Host -f Red "'$env' is not a valid env in _config.json"
    Exit
}

$appLog = $config.appLog
$objLog = $config.objLog

Write-Host "... a few pre-flight checks ..."

if ($myEnv.default_owner.userId -and $myEnv.default_owner.userDirectory) {

    [array] $defaultOwnerInfo = QRS_API -conn $myEnv -method "GET" -trace 0 `
        -api "qrs/user?filter=userId eq '$($myEnv.default_owner.userId)' and userDirectory eq '$($myEnv.default_owner.userDirectory)'"

    if ($defaultOwnerInfo.Length -eq 0) {
        Write-Host -f Red "Default owner '$($myEnv.default_owner.userDirectory)\$($myEnv.default_owner.userId)' cannot be found."
        Exit       
    } 
    else {
        Write-Host -f Cyan "Found default owner '$($myEnv.default_owner.userDirectory)\$($myEnv.default_owner.userId)' (id $($defaultOwnerInfo[0].id))."
    } 
  
} 
else {
    Write-Host -f Red "`"default_owner`":{} is not defined in this env in _config.json"
    Exit
}
# --------------------------------------------------------------------------------------------

if ($myEnv.default_stream) {
          
    [array] $defaultStreamInfo = QRS_API -conn $myEnv -method "GET" -trace 0 `
        -api "qrs/stream?filter=name eq '$($myEnv.default_stream)'"

    if ($defaultStreamInfo.Length -eq 0) {
        Write-Host -f Red "Default stream '$($myEnv.default_stream)' cannot be found."
        Exit       
    } 
    else {
        Write-Host -f Cyan "Found default stream '$($myEnv.default_stream)' (id $($defaultStreamInfo.id))."
    } 
}
else {
    Write-Host -f Red "`"default_stream`" is not defined in this env in _config.json"
    Exit
}


if (-not (Test-Path "$appId.qvf")) {
    Write-Host -f Red "Cannot find '$appId.qvf'"
    Exit
}
if (-not (Test-Path "$appId.json")) {
    Write-Host -f Red "Cannot find '$appId.json'"
    Exit
}

# -------------------------------- Main code --------------------------------

$owners = @{}
$owners2 = @{}
$appMeta = Get-Content -Path "$appId.json" -Raw | ConvertFrom-Json 

$owners["$($appMeta.owner.userDirectory)\$($appMeta.owner.userId)"] = $null

foreach ($appObj in $appMeta.objects) {
    $owners["$($appObj.owner.userDirectory)\$($appObj.owner.userId)"] = $null
}

Write-Host "Here are all owners involved in this app:"
foreach ($owner in $owners.Keys) {
    $uid = $owner.Split("\")[1]
    $ud = $owner.Split("\")[0]
    [array] $uInfo = QRS_API -conn $myEnv -method "GET" -trace 0 `
        -api "qrs/user?filter=userId eq '$uid' and userDirectory eq '$ud'"
    if ($uInfo.Length -eq 0) {
        $owners2[$owner] = @{"id" = $defaultOwnerInfo.id; "default" = $true }
        Write-Host -f Yellow "$ud\$uid not found, using default owner $($myEnv.default_owner.userDirectory)\$($myEnv.default_owner.userId) instead."
    }
    else {
        $owners2[$owner] = @{"id" = $uInfo[0].id; "default" = $false }
        Write-Host -f Green "$ud\$uid found: $($uInfo[0].id)"
    }
}

$fileSize = [Math]::Round((Get-Item -Path "$appId.qvf").Length / 1024 / 1024)
Write-Host -f Cyan "`nUploading app '$($appMeta.name)', size $fileSize MB ..."

$newApp = QRS_API -conn $myEnv  -method "POST" `
    -api "qrs/app/upload?name=$($appMeta.name)" -trace 1 `
    -file "$appId.qvf" -contenttype "application/vnd.qlik.sense.app"
    
$errors = 0

if ($newApp.id) {

    appLog -f $appLog -appName $appMeta.name -srcAppId $appId -srcServer $appMeta.server_url `
        -srcStream $appMeta.stream_name -newAppId $newApp.id -newSrv $myEnv.server_url
    #            "privateOrCommunityObjects" = $appMeta.objects.Count
                
    # --------------------------------------------------------------------------------------------
    Write-Host -f Cyan "Publishing app to stream '$($appMeta.stream_name)'"
    
    [array] $streamInfo = QRS_API -conn $myEnv -method "GET" -trace 1 `
        -api "qrs/stream?filter=name eq '$($appMeta.stream_name)'"
        
    if ($streamInfo.Length -eq 0) {

        $res = QRS_API -conn $myEnv -method "PUT" `
            -api "qrs/app/$($newApp.id)/publish?stream=$($defaultStreamInfo.id)" -trace 1 `

        appLog -t 1 -f $appLog -appName $appMeta.name -newAppId $newApp.id `
            -m "Could not find former stream '$($appMeta.stream_name)'. Using '$($myEnv.default_stream)'."
        
    } 
    else {
        $res = QRS_API -conn $myEnv -method "PUT" `
            -api "qrs/app/$($newApp.id)/publish?stream=$($streamInfo.id)" -trace 1 `
        
        appLog -t 0 -f $appLog -appName $appMeta.name -newAppId $newApp.id `
            -m "Publishing app to stream '$($appMeta.stream_name)' like at the source."
    }

    # --------------------------------------------------------------------------------------------

    $newOwner = $owners2["$($appMeta.owner.userDirectory)\$($appMeta.owner.userId)"]
    if ($newOwner.default) {
        
        appLog -t 1 -f $appLog -appName $appMeta.name -newAppId $newApp.id `
            -m "Could not find former app owner $($appMeta.owner.userDirectory)\$($appMeta.owner.userId), using default app owner $($myEnv.default_owner.userDirectory)\$($myEnv.default_owner.userId) instead."
    }
    else {
        appLog -t 0 -f $appLog -appName $appMeta.name -newAppId $newApp.id `
            -m "Setting app owner $($appMeta.owner.userDirectory)\$($appMeta.owner.userId) like at the source."
    }

    $res = QRS_API -conn $myEnv -method "PUT" `
        -api "qrs/app/$($newApp.id)" -trace 1 `
        -body (@{
            "modifiedDate" = "2099-12-31T23:59:59.999Z"; 
            "owner"        = @{"id" = $newOwner.id } 
        } | ConvertTo-Json)

    # --------------------------------------------------------------------------------------------
    foreach ($appObj in $appMeta.objects) {

        Write-Host ""

        # determine object type
        if (!$appObj.approved -and !$appObj.published) {
            $resource = "private"
        }
        elseif (!$appObj.approved -and $appObj.published) {
            $resource = "community"
        }
        else {
            $resource = "base"
        }

        #Write-Host -f Cyan "Fixing props of $resource $($appObj.objectType) '$($appObj.name)' (orig. owner $($appObj.owner.userDirectory)\$($appObj.owner.userId))" 
            
        [array] $newObjInfo = QRS_API -conn $myEnv -method "GET" -trace 1 `
            -api "qrs/app/object?filter=app.id eq $($newApp.id) and engineObjectId eq '$($appObj.engineObjectId)'"
            
        if ($newObjInfo.Length -eq 0) {
            objLog -t 2 -f $objLog -objId $appObj.engineObjectId -objType $appObj.objectType `
                -resource $resource -objOwner "$($appObj.owner.userDirectory)\$($appObj.owner.userId)" `
                -objName $appObj.name -appId $newApp.id -appName $appMeta.name `
                -m "Could not find former engineObjectId"
            $errors++
        } 
        else {
            $newOwner = $owners2["$($appObj.owner.userDirectory)\$($appObj.owner.userId)"]

            if ($newOwner.default) {
                objLog -t 1 -f $objLog -objId $appObj.engineObjectId -objType $appObj.objectType `
                    -resource $resource -objOwner "$($appObj.owner.userDirectory)\$($appObj.owner.userId)" `
                    -objName $appObj.name -appId $newApp.id -appName $appMeta.name `
                    -m "Could not find owner, using default app owner $($myEnv.default_owner.userDirectory)\$($myEnv.default_owner.userId) instead."
            }
            else {
                objLog -t 0 -f $objLog -objId $appObj.engineObjectId -objType $appObj.objectType `
                    -resource $resource -objOwner "$($appObj.owner.userDirectory)\$($appObj.owner.userId)" `
                    -objName $appObj.name -appId $newApp.id -appName $appMeta.name `
                    -m "Setting owner like at the source"
                
            }
            $res = QRS_API -conn $myEnv -method "PUT" -trace 1 `
                -api "qrs/app/object/$($newObjInfo[0].id)" `
                -body (@{
                    "modifiedDate" = "2099-12-31T23:59:59.999Z"
                    "approved"     = $appObj.approved
                    "owner"        = @{"id" = $newOwner.id }
                } | ConvertTo-Json)

            if (!$appObj.published) {
                # unpublish the object if it was originally published=false
                $res = QRS_API -conn $myEnv -method "PUT" -trace 1 `
                    -api "qrs/app/object/$($newObjInfo[0].id)/unpublish"       
            }
            
            # Write-Host -f Green "Updated $resource $($appObj.objectType) '$($appObj.name)'."

        }
    }

    $delApp = ""
    $delFiles = $delFiles.ToUpper()

    if ($errors -eq 0) {
        while ($delFiles -notin "Y", "N") {
            $delFiles = Read-Host "Do you want to remove the .qvf file and .json file? (Y/N)"
            $delFiles = $delFiles.ToUpper()
        }
        if ($delFiles -eq "Y") {
            Remove-Item "$appId.qvf"
            Remove-Item "$appId.json"
        }
    }
    else {
        Write-Host -f Red "$errors Errors happened. Scroll up and check ..."
        while ($delApp -notin "Y", "N") {
            $delApp = Read-Host "Do you want to remove the incompletely imported app from $($myEnv.server_url)? (Y/N)"
            $delApp = $delApp.ToUpper()
        }
        if ($delApp -eq "Y") {
            $res = QRS_API -conn $myEnv -method "DELETE" -trace 1 `
                -api "qrs/app/$($newApp.id)"    
        }
    }
       
        
} 
else {
    Write-Host -f Red "Unexpected result while uploading .qvf file"
    Exit
}

 
 
Write-Host -f Green "Finished script."

if ($delApp -ne "Y") {
    Write-Host -f Green "Test app here $($myEnv.server_url)/sense/app/$($newApp.id)/overview"
}

