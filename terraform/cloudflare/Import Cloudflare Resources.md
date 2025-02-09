https://developers.cloudflare.com/terraform/advanced-topics/import-cloudflare-resources/

winget install golang.go

go install github.com/cloudflare/cf-terraforming/cmd/cf-terraforming@latest

cf-terraforming generate --email $CF_EMAIL_ADDRESS --token $CD_TOKEN_ID -z $CF_ZONE_ID --resource-type cloudflare_record > import-zone.internal.tf
 - This tool generated terraform config with deprecated 'value' field, I just commented this line out.

cf-terraforming import --email $CF_EMAIL_ADDRESS --token $CD_TOKEN_ID -z $CF_ZONE_ID --resource-type cloudflare_record

Copy/Paste the results to 'terraform import'