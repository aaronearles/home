VULTR_API_KEY = "ABCD1234SAMPLE" //See https://my.vultr.com/settings/#settingsapi

plan     = "vc2-1c-1gb" //"vc2-1c-1gb","vc2-1c-2gb","vc2-2c-2gb","vc2-2c-4gb" //"vhp-1c-1gb-amd","vhp-1c-2gb-amd","vhp-2c-2gb-amd","vhp-2c-4gb-amd","vhp-4c-8gb-amd" //"voc-c-1c-2gb-25s-amd","voc-c-2c-4gb-50s-amd","voc-c-2c-4gb-75s-amd","voc-c-4c-8gb-75s-amd","voc-c-4c-8gb-150s-amd"
region   = "lax" //Los Angeles / ewr = New Jersey / atl, dfw, mia, ord, sea, sjc
os_id    = "1743" //Ubuntu 22.04 LTS, or "2136" //Debian 12, or "1869" //Rocky 9
label    = "instance01"
hostname = "instance01"
tags     = ["testing", "demo"]

ssh_key_ids = ["1234abcd-0000-ffff-aaa0-1234cd55ffff"] // https://my.vultr.com/settings/#settingssshkeys or https://www.vultr.com/api/#tag/ssh/operation/get-ssh-key