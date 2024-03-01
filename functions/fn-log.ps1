

function appLog {
    param ( 
        [Parameter(Mandatory = $true)] $f, # logfile
        [Parameter(Mandatory = $false)] $m = $null, # log message
        [Parameter(Mandatory = $false)] $t = 0, # message type 0 = info, 1 = warning, 2 = error
        [Parameter(Mandatory = $false)] $appName = $null,
        [Parameter(Mandatory = $false)] $srcAppId = $null,
        [Parameter(Mandatory = $false)] $srcServer = $null,
        [Parameter(Mandatory = $false)] $srcStream = $null,
        [Parameter(Mandatory = $false)] $newAppId = $null,
        [Parameter(Mandatory = $false)] $newSrv = $null
    )

    if ($t -eq 2) {
        $msgType = "error"
        $color = "Red"
    }
    elseif ($t -eq 1) {
        $msgType = "warn"    
        $color = "Yellow"
    }
    else {
        $color = "Green"
        $msgType = "info"
    }
        
    Write-Host -f $color $m

    
    $logData = @([PSCustomObject] @{
            "msgType"   = $msgType
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "appName"   = $appName
            "msg"       = $m;
            "srcAppId"  = $srcAppId
            "srcServer" = $srcServer
            "srcStream" = $srcStream
            "newAppId"  = $newAppId
            "newSrv"    = $newSrv
        })

    # Check if the log file exists, if not, create a new file with headers
    if (-not (Test-Path $f)) {
        $logData | Export-Csv -Path $f -NoTypeInformation
    }
    else {
        # Append the log data to the existing log file
        $logData | Export-Csv -Path $f -NoTypeInformation -Append
    }
}


function objLog {
    param ( 
        [Parameter(Mandatory = $true)] $f, # logfile
        [Parameter(Mandatory = $false)] $m = $null, # log message
        [Parameter(Mandatory = $false)] $t = 0, # message type 0 = info, 1 = warning, 2 = error
        [Parameter(Mandatory = $false)] $appName = $null,
        [Parameter(Mandatory = $false)] $objId = $null,
        [Parameter(Mandatory = $false)] $objType = $null,
        [Parameter(Mandatory = $false)] $resource = $null,
        [Parameter(Mandatory = $false)] $objName = $null,
        [Parameter(Mandatory = $false)] $objOwner = $null,
        [Parameter(Mandatory = $false)] $appId = $null
    )
    
    if ($t -eq 2) {
        $msgType = "error"
        $color = "Red"
    }
    elseif ($t -eq 1) {
        $msgType = "warn"    
        $color = "Yellow"
    }
    else {
        $color = "Green"
        $msgType = "info"
    }
    Write-Host -f $color "$resource $objType '$objName' by $($objOwner): $m"
        

    $logData = @([PSCustomObject] @{
            "msgType"   = $msgType
            "Timestamp" = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            "appName"   = $appName
            "msg"       = $m
            "objType"   = $objType
            "resource"  = $resource
            "objName"   = $objName
            "objOwner"  = $objOwner
            "objId"     = $objId
            "appId"     = $appId
        })

    # Check if the log file exists, if not, create a new file with headers
    if (-not (Test-Path $f)) {
        $logData | Export-Csv -Path $f -NoTypeInformation
    }
    else {
        # Append the log data to the existing log file
        $logData | Export-Csv -Path $f -NoTypeInformation -Append
    }
}