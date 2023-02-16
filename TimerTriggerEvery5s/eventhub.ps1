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
        $response = Invoke-RestMethod -Uri $URI -Method $method -Headers $headers -Body $body  -OutFile "my-posts.json" -PassThru
        Write-Host "Event Sent Successfully"
    }
    catch {
        #"Error Code: {0}" -f $response.Code | Write-Host
        Write-Host "Error Sending the Event"
    }
    return $response.Code
}