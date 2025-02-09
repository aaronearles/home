# If Windows
wsl --install --distribution "Debian"


sudo apt update
sudo apt install pipx
pipx install --include-deps ansible
pipx inject ansible pywinrm


ansible-playbook playbooks/disable-outsys-services.yml -i outsystems_inventory.yml -u aearles@corp.pediatrix.net --ask-pass -e "target=env_old_prod" --check