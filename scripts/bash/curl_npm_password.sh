#Authenticate and retrieve a token:
TOKEN=`curl -s -X POST "http://docker.earles.internal:4081/api/tokens" \
-H "accept: application/json" \
-H "Content-Type: application/json" \
-d "{ \"identity\": \"admin@example.com\", \"secret\": \"changeme\" }" | jq -r '.token'`

#Test authentication with a GET:
curl -X GET "http://docker.earles.internal:4081/api/users" \
-H "Authorization: Bearer $TOKEN"

#Change the Password:
curl -X PUT "http://docker.earles.internal:4081/api/users/1/auth" \
-H "Authorization: Bearer $TOKEN" \
-H "Content-Type: application/json" \
-d "{ \"type\":\"password\",\"current\":\"changeme\",\"secret\":\"newpassword\"}"