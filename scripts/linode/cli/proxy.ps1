# This is a powershell script that creates a new Linode Nanode instance running Squid, opens an SSH session to the new instance tunnelling localhost:443 to proxy:3128
# Once connected SSH session, you can set your local browser proxy settings to use localhost:443 to access the internet using a Linode public IP
# Requires Linode CLI: https://www.linode.com/docs/products/tools/cli/guides/install/
# Requires Get-Random: https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.utility/get-random
# Requires a valid SSH key! You can generate a keypaid using 'ssh-keygen -m PEM -t rsa -b 2048'
# Requires a valid stackscript_id, 1117817 is private. It's contents are available in ../stackscripts/proxy.sh

# Check for PSPasswordGenerator module and install if missing
if (-not (Get-Module -ListAvailable -Name PSPasswordGenerator)) {
    Write-Host "PSPasswordGenerator module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name PSPasswordGenerator -Force -Scope CurrentUser
    Write-Host "PSPasswordGenerator module installed successfully." -ForegroundColor Green
}

# Import the module
Import-Module PSPasswordGenerator

# Generate password using correct syntax for PSPasswordGenerator module
$password = New-Password -Length 32
$output = linode-cli linodes create `
--label "proxy" `
--root_pass $password `
--region us-west `
--type g6-nanode-1 `
--image linode/alpine3.17 `
--authorized_keys "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILfgFgJzAiboiYACBkcCVEkc7LRcdT1JD77PQ56uCR5p weston_nt\aearles@LAP121-105863" `
--authorized_users "aearles" `
--stackscript_id "1117817" `
--text `
--delimiter ","

$output.split(",")
$splitOutput = $output |ConvertFrom-Csv -Header id, label, region, type, image, status, ipv4
$linodeCliOutput = $splitOutput | Select-Object -skip 2
$newhostip = $linodeCliOutput.ipv4
$newhostid = $linodeCliOutput.id
Remove-Variable password
clear
Write-Host New Linode ID is $newhostid
Write-Host IP Address: $newhostip
Write-Host 
Write-Host "Sleeping for 90 more seconds"
sleep 30
Write-Host "Sleeping for 60 more seconds"
sleep 30
Write-Host "Sleeping for 30 more seconds"
sleep 20
Write-Host "Sleeping for 10 more seconds"
sleep 10
Write-Host Attempting to connect to $newhostip on SSH...
Write-Host
ssh -L 127.0.0.1:443:localhost:3128 aearles@$newhostip -p 443
clear
Write-Host Sleeping for 10 seconds before deleting $newhostid
sleep 10
linode-cli linodes delete $newhostid

linode-cli linodes ls
