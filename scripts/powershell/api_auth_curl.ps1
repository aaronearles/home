## THIS IS TESTED WORKING AS-IS RUNNING UNDER POWERSHELL

# Provide current credentials. By default, this will be admin@example.com:changeme.
$credentials = @{
    identity='admin@example.com'
    secret='backtochangeme'
}

$RequestBody = ConvertTo-Json $credentials -Depth 100

# Authenticate and retrieve $Token
$ResponseJson = curl -s -X POST "http://docker.earles.internal:4081/api/tokens" `
-H "accept: application/json" `
-H "Content-Type: application/json" `
-d $RequestBody
# -d "{ \"identity\": \"admin@example.com\", \"secret\": \"changeme\" }"
$Response = $ResponseJson | ConvertFrom-Json
$Token = $Response.token

#Test authentication with a GET:
curl -X GET "http://docker.earles.internal:4081/api/users" `
-H "accept: application/json" `
-H "Authorization: Bearer $Token"

#Change the password:
$JSONBody = @{
    type='password'
    current='changeme'
    secret='newpassword'
}

$RequestBody = ConvertTo-Json $JSONBody -Depth 100

curl -X PUT "http://docker.earles.internal:4081/api/users/1/auth" `
-H "Authorization: Bearer $Token" `
-H "Content-Type: application/json" `
-d $RequestBody