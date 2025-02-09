#!/bin/bash
sudo apt update && sudo apt install curl git zsh powerline fonts-powerline
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" # "" --unattended
echo -e PROMPT="\"\$fg[cyan]%}\$USER@%{\$fg[blue]%}%m \${PROMPT}\"" >> .zshrc