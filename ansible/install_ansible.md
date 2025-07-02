# If Windows
wsl --install --distribution "Debian"


sudo apt update
sudo apt install pipx
pipx install --include-deps ansible
pipx inject ansible pywinrm


ansible-playbook playbooks/disable-services.yml -i inventory.yml -u user@corp.domain.local --ask-pass -e "target=env_prod" --check