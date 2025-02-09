pm_api_url = "https://pve.sample.internal:8006/api2/json"
pm_api_token_id = "terraform@pve!sampletoken"
pm_api_token_secret = "12345678-abcd-4321-aaaa-123456789ab"
target_node = "pve"

id_start = 401
instance_count = 1
clone_source = "ubuntu-22.04-template"
# instance_list          = [401,402,403]


hostname_pfx = "vm"
admin_password = "password"

memory = "1024"
sockets = "1"
cores = "1"
vcpus = "0"

os_type = "ubuntu"
vm_state = "running"