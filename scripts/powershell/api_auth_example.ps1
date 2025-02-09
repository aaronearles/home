$username = ""
$password = ""
$today = Get-date -Format "yyyy-MM-dd"

$headers = ""

$JSONBody = [PSCustomObject][Ordered]@{
    'email'      = $username
    'password'   = $password
}

$RequestBody = ConvertTo-Json $JSONBody -Depth 100

$Response = Invoke-RestMethod -Uri https://app-api.yumuuv.com/api/rpc/login -Method POST -ContentType application/json -Body $RequestBody
$SessionId = $Response.sessionId
$headers = @{
    cookie = "SESSION=$SessionId"
}

$AppData = [PSCustomObject][Ordered]@{
    'appVersion'      = "1.31.1"
    'osVersion'       = "17.3.1"
    'platform'        = "ios"
}

$RequestBody = ConvertTo-Json $AppData -Depth 100

$WhoAmI = Invoke-RestMethod -Uri https://app-api.yumuuv.com/api/rpc/getWhoAmI -Method POST -Headers $headers -ContentType application/json -Body $RequestBody