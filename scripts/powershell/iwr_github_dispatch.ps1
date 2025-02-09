$uri = "https://api.github.com/repos/earlesio/linode_template/dispatches"
$token = ""

$headers = @{
    "accept" = "application/vnd.github+json"
    "authorization" = "Bearer $token"
    "X-GitHub-Api-Version" = "2022-11-28"
}

$body = @{
    event_type = "destroy" # "apply" or "destroy"
}

$RequestBody = ConvertTo-Json $body -Depth 100

Invoke-RestMethod -Uri $uri -Method POST -ContentType application/json -Headers $headers -Body $requestBody
