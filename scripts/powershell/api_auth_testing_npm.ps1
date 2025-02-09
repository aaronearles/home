## THIS IS TESTED WORKING AS-IS RUNNING UNDER POWERSHELL

# Provide current credentials. By default, this will be admin@example.com:changeme.
$credentials = @{
    identity='admin@example.com'
    secret='changeme'
}

$headers = ""

$RequestBody = ConvertTo-Json $credentials -Depth 100

# Authenticate and retrieve $Token
$response = Invoke-RestMethod -Uri 'http://docker.earles.internal:4081/api/tokens' -Method Post -Body $RequestBody -ContentType 'application/json'
$token = $response.token

$headers = @{
    'Authorization'="Bearer $token"
}

$RequestBody = ""

#Test authentication with a GET:
Invoke-RestMethod -Uri 'http://docker.earles.internal:4081/api/users' -Headers $headers


#Change the password:
$JSONBody = @{
    type='password'
    current='changeme'
    secret='newpassword'
}

$RequestBody = ConvertTo-Json $JSONBody -Depth 100

Invoke-RestMethod -Uri 'http://docker.earles.internal:4081/api/users/1/auth' -Headers $headers -Method Put -Body $RequestBody -ContentType 'application/json'
