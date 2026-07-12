## Install
`npm install -g @bitwarden/cli`

## Configure
```
bw config server https://vaultwarden.internal.earles.io
bw login
```

## Maintain session
```
bw unlock
export BW_SESSION="**TOKEN-FROM-BW-UNLOCK**"
```
or automate with:
```
export BW_SESSION=$(bw unlock --raw)
```

## Search and retrieve
```
bw list items --search developer.service-now.com
bw get item 869dcf75-3f78-49ac-a80e-06b9eaa00a7a
bw get password 869dcf75-3f78-49ac-a80e-06b9eaa00a7a
```
or automate with:
```
export SNOW_PASSWORD=$(bw get password 869dcf75-3f78-49ac-a80e-06b9eaa00a7a --raw)
```