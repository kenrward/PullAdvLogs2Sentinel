# Input bindings are passed in via param block.
param($Every5Seconds)

# Get the current universal time in the default string format
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' porperty is 'true' when the current function invocation is later than scheduled.
if ($Every5Seconds.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
#########################################
# TODO:
# Set up ENVs for WorkspaceId & Key
# Date Time, UTC :  (Get-Date).ToUniversalTime()
#########################################
$tenantId = $env:tenantId
$clientId = $env:clientId
$appSecret = $env:clientSecret
$WorkspaceId = $env:WorkspaceId
$SharedKey = $env:workspaceKey
$azstoragestring = $env:AzureWebJobsStorage
$Access_Policy_Name="RootManageSharedAccessKey"
## Retrieve Environment Variables
$URI = $env:EventHubURI
$Access_Policy_Key = $env:EventHubAccessPolicyKey


function SendEvent ($body) {
    [Reflection.Assembly]::LoadWithPartialName("System.Web")| out-null
    #Token expires now+3000
    $Expires=([DateTimeOffset]::Now.ToUnixTimeSeconds())+3000
    $SignatureString=[System.Web.HttpUtility]::UrlEncode($URI)+ "`n" + [string]$Expires
    $HMAC = New-Object System.Security.Cryptography.HMACSHA256
    $HMAC.key = [Text.Encoding]::ASCII.GetBytes($Access_Policy_Key)
    $Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
    $Signature = [Convert]::ToBase64String($Signature)
    $SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($URI) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $Access_Policy_Name
    # $SASToken
    $method = "POST"
    $signature = $SASToken
    # API headers
    $headers = @{
                "Authorization"=$signature;
                "Content-Type"="application/atom+xml;type=entry;charset=utf-8";
                }
    # execute the Azure REST API
    $response
    try {
        $response = Invoke-RestMethod -Uri $URI -Method $method -Headers $headers -Body $body 
        Write-Host "Event Sent Successfully"
    }
    catch {
        "Error Code: {0}" -f $response.Code | Write-Host
        Write-Host "Error Sending the Event"
    }
    return $response.Code
}



function Build-signature ($CustomerID, $SharedKey, $Date, $ContentLength, $method, $ContentType, $resource) {
    $xheaders = 'x-ms-date:' + $Date
    $stringToHash = $method + "`n" + $contentLength + "`n" + $contentType + "`n" + $xHeaders + "`n" + $resource
    $bytesToHash = [text.Encoding]::UTF8.GetBytes($stringToHash)
    $keyBytes = [Convert]::FromBase64String($SharedKey)
    $sha256 = New-Object System.Security.Cryptography.HMACSHA256
    $sha256.key = $keyBytes
    $calculateHash = $sha256.ComputeHash($bytesToHash)
    $encodeHash = [convert]::ToBase64String($calculateHash)
    $authorization = 'SharedKey {0}:{1}' -f $CustomerID,$encodeHash
    return $authorization
}
#############################################################################
## Set-LogAnalyticsData
#############################################################################
Function Set-LogAnalyticsData ($WorkspaceId, $SharedKey, $Body, $Type) {
    $method = "POST"
    $ContentType = 'application/json'
    $resource = '/api/logs'
    $rfc1123date = $currentUTCtime.ToString('r')
    $ContentLength = $Body.Length
    $signature = Build-signature `
        -customerId $WorkspaceId `
        -sharedKey $SharedKey `
        -date $rfc1123date `
        -contentLength $ContentLength `
        -method $method `
        -contentType $ContentType `
        -resource $resource
    $uri = "https://" + $WorkspaceId + ".ods.opinsights.azure.com" + $resource + "?api-version=2016-04-01"
    Write-Host "Signature: $signature"
    Write-Host "URI: $uri"
    $headers = @{
        "Authorization" = $signature;
        "Log-Type" = $type;
        "x-ms-date" = $rfc1123date
        "time-generated-field" = $currentUTCtime
    }
    "Headers Log Post: {0}" -f $headers | Write-Host 
    try{
        $response = Invoke-WebRequest -Uri $uri -Method $method -ContentType $ContentType -Headers $headers -Body $body -UseBasicParsing
        "Response Code: {0}" -f $response.statuscode | Write-Host 
    } catch {
        "Log A Post Error Length: {0}" -f $ContentLength | Write-Host 
    }
    return $response.statuscode
}


#############################################################################
## Logon to API to grap token
#############################################################################
function Get-AuthToken{
    [cmdletbinding()]
        Param(
            [Parameter(Mandatory = $true, Position = 0)]
            [string]$clientId,
            [parameter(Mandatory = $true, Position = 1)]
            [string]$appSecret,
            [Parameter(Mandatory = $true, Position = 2)]
            [string]$tenantId
        )
# M365 Public Endpoints        
#$resourceAppIdUri = 'https://api.security.microsoft.us'
#$oAuthUri = "https://login.windows.net/$tenantId/oauth2/token"

# GCC URLs - see https://docs.microsoft.com/en-us/microsoft-365/security/defender/usgov?view=o365-worldwide
$resourceAppIdUri = 'https://api-gcc.security.microsoft.us'
$oAuthUri = "https://login.microsoftonline.com/$tenantId/oauth2/token"

$authBody = [Ordered] @{
  resource = $resourceAppIdUri
  client_id = $clientId
  client_secret = $appSecret
  grant_type = 'client_credentials'
}
$authResponse = Invoke-RestMethod -Method Post -Uri $oAuthUri -Body $authBody -ErrorAction Stop
$token = $authResponse | Select-Object -ExpandProperty access_token
# Out-File -FilePath "./Latest-token.txt" -InputObject $token
return $token
}
#############################################################################
## Start API Query
#############################################################################

function Get-APIData{
    [cmdletbinding()]
        Param(
            [Parameter(Mandatory = $true, Position = 0)]
            [string]$token,
            [parameter(Mandatory = $true, Position = 1)]
            [string]$advHTableName,
            [Parameter(Mandatory = $true, Position = 2)]
            [string]$lastRead
        )
$url = "https://api-gcc.security.microsoft.us/api/advancedhunting/run"

<# $Body = @{
    'Query' = '{0} | where Timestamp > datetime("{1}")' -f $advHTableName,$lastRead
} #>

$Body = @{
    'Query' = 'EmailEvents | take 2'
}

# Set the webrequest headers
$headers = @{
    'Content-Type' = 'application/json'
    'Accept' = 'application/json'
    'Authorization' = "Bearer $token"
}

$Body = $Body | ConvertTo-Json

try{
    $response = Invoke-WebRequest -Method Post -Body $body -Uri $url -Headers $headers -ErrorAction Stop
    $data =  ($response | ConvertFrom-Json).results | ConvertTo-Json -Depth 99
    return $data
} catch {
    "Error pulling Adv Data, could be no vaild results: {0}" -f $data.statuscode | Write-Host 
    return $null
}
<#
# Extract the results.
$data =  ($response | ConvertFrom-Json).results | ConvertTo-Json -Depth 99
if($data.statuscode -ge 300){
    Write-Host "Error pulling Adv Data, could be no vaild results: $data.statuscode"
    return $null
}else{
    return $data
}
#>
}

#############################################################################
## Main()
#############################################################################

# https://docs.microsoft.com/en-us/azure/storage/tables/table-storage-how-to-use-powershell

# Connect to Azure Storage
$ctx = New-AzStorageContext -ConnectionString $azstoragestring
$tableName = "LastRead"

# Get Adv Hunting Table Names from Azure Storage Table Service
$cloudTable = (Get-AzStorageTable -Name $tableName -Context $ctx).CloudTable
$advNames = Get-AzTableRow -table $cloudTable
$arrNames = $advnames.advTableName

# Loop through all the adv hunting tables
ForEach ($advName in $arrNames){
    Write-Host "--------- CURRENT Table: $advName ---------------------------"
    "Get-AzTableRow -table {0} -ColumnName 'advTableName'-value {1} -operator Equal" -f $cloudTable,$advName | Write-Host 
    $rowReturn = Get-AzTableRow -table $cloudTable -ColumnName "advTableName" -value $advName -operator Equal
    # Write-Debug "RowReturn: $rowReturn"
    #Check Last Read Value, if blank set for 30 days ago.
    if($rowReturn.LastRead -eq ""){
        $lastRead = (Get-Date).addDays(-30)
    } else {
        $lastRead = $rowReturn.LastRead
    }

    # Check if time is UTC, Convert to UTC if not.
    <# 
    if ($lastRead.kind.tostring() -ne 'Utc'){
        $lastRead = $lastRead.ToUniversalTime()
        Write-Verbose -Message $lastRead
    }
    #>
    # Auth to M365 API
    $headerParams = Get-AuthToken $clientId $appSecret $tenantId 
    # Get data for the table
    "Header params :  {0} AdvName: {1} LastRead: {2}" -f $headerParams,$advname,$lastRead | Write-Debug 
    $dataReturned = Get-APIData $headerParams $advName $lastRead
    "Data Recieved Length: {0} Next Page: {1}" -f $dataReturned.Length,$dataReturned.Headers.NextPageUrl | Write-Host 
    if($null -ne $dataReturned){
        Write-Host "Data Recieved $dataReturned.Length"
        if($dataReturned.Length -gt 0){
            "WorkspaceId: {0} SharedKey {1}  AdvName {2} Data Return Length: {3}" -f $advName,$SharedKey,$WorkspaceId,$dataReturned.Length | Write-Host 
            $returnCode = Set-LogAnalyticsData -WorkspaceId $WorkspaceId -SharedKey $SharedKey -Body $dataReturned -Type $advName
            SendEvent($dataReturned)
            "Post Statement Return Code {0}" -f $returnCode | Write-Host 
            if ($returnCode -eq 200){
                # Update LastRead to now
                $rowReturn.LastRead = $currentUTCtime
                # To commit the change, pipe the updated record into the update cmdlet.
                $rowReturn | Update-AzTableRow -table $cloudTable
            }
        }
    }
}

return $returnCode