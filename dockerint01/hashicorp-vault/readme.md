TODO:
    Need to move db to NAS and configure backups!

https://ambar-thecloudgarage.medium.com/hashicorp-vault-with-docker-compose-0ea2ce1ca5ab

Unseal keys and root token are on https://earles.vault.azure.net/

vault operator init
vault operator unseal $key1
vault operator unseal $key2
vault operator unseal $key3

echo $env:VAULT_DEV_ROOT_TOKEN_ID=$root_token

vault login
vault secrets enable -path="kv-v1" -description="Test K/V v1" kv
vault secrets list
vault kv put kv-v1/test key=value
vault kv get kv-v1/test
vault kv get -format json kv-v1/test | jq -r .data.key
    value

