
function QRS_API {

    # This function communicates with QRS API
    
    param ( 
        [Parameter(Mandatory = $true)] $conn, # format: { "server_url": "https://.../qrs", "auth_header": { ... }}
        [Parameter(Mandatory = $true)] $method,
        [Parameter(Mandatory = $true)] $api, 
        # [Parameter(Mandatory = $true)] $cert,
        [Parameter(Mandatory = $false)] $body,
        [Parameter(Mandatory = $false)] $file,
        [Parameter(Mandatory = $false)] $contenttype,
        [Parameter(Mandatory = $false)] [string] $download,
        [Parameter(Mandatory = $false)] $trace = 1
        # trace parameter is for making screen output 0 = trace nothing, 1 = api call only, 2 = call + response
    ) 

    $url = $conn.server_url
    if ($conn.vproxy) { 
        $url += "/$($conn.vproxy)" 
    }
    $url += "/$($api)"
    
    #convert $conn.auth_header (PSObject) into Hashtable
    $hdrs = @{}
    if ($conn.auth_header) {
        $conn.auth_header | Get-Member -MemberType Properties | ForEach-Object {
            # Write-Host $_.Name $config."auth_header"."$($_.Name)"
            $hdrs[$_.Name] = $conn."auth_header"."$($_.Name)"
        }
    }

    $characters = "abcdefghijklmnopqrstuvwxyz0123456789"
    # Generate a random string by selecting 16 random characters from the defined set
    $xrfkey = -join ((Get-Random -Count 16 -InputObject $characters.ToCharArray()))
    
    # if (!$noxrfkey) {
        $hdrs["X-Qlik-Xrfkey"] = $xrfkey
        if ($url -match '\?') {
            $url = "$($url)&xrfkey=$($xrfkey)"
        }
        else {
            $url = "$($url)?xrfkey=$($xrfkey)"
        }
    # }

    if ($contenttype) {
        # $hdrs.Add("Content-Type", $contenttype)
        $hdrs["Content-Type"] = $contenttype
    }
  
    if ($trace -gt 0) {
        Write-Host -f DarkGray $method $api 
    }
    
    if ($download) {

        # Make the REST call to download the file
        $res = Invoke-WebRequest -Uri "$url" -Headers $hdrs -OutFile $download
        if (Test-Path $download) {
            Write-Host "File downloaded successfully to $download"
        } else {
            Write-Host -f Red "Failed to download the file."
        }
    } 
    elseif ($body) {
        # add Content-Type to http header
        if (!$contenttype) {
            $hdrs.Add("Content-Type", "application/json")
        }
        
        $res = Invoke-RestMethod -Uri "$url" -Method $method -UseDefaultCredentials `
            -Headers $hdrs  -Body $body 

    } 
    elseif ($file) {
        # file parameter is defined
        # if ($debuginfo) { Write-Host 'file attached' }
        $res = Invoke-RestMethod -Uri "$url" -Method $method -UseDefaultCredentials `
            -Headers $hdrs  -inFile $file 
    }
    else {
        # no http body and no file defined
        # if ($debuginfo) { Write-Host ($hdrs | ConvertTo-Json) }
        $res = Invoke-RestMethod -Uri "$url" -Method $method -UseDefaultCredentials `
            -Headers $hdrs 
    }

    if ($res -and ($trace -gt 1)) {
        Write-Host -f Green 'Response:'
        Write-Host "$(ConvertTo-Json $res -Depth 7)"
    }
    return $res
}