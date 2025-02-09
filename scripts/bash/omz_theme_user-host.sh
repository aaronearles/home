#!/bin/zsh
cp ~/.oh-my-zsh/themes/robbyrussell.zsh-theme $ZSH_CUSTOM/themes/
sed -i '/PROMPT/s/^/#/' "$ZSH_CUSTOM/themes/robbyrussell.zsh-theme"
echo 'PROMPT="%{$fg[white]%}$USER@%M %(?:%{$fg_bold[green]%}%1{➜%} :%{$fg_bold[red]%}%1{➜%} ) %{$fg[cyan]%}%c%{$reset_color%}"\''' >> "$ZSH_CUSTOM/themes/robbyrussell.zsh-theme"
omz theme set robbyrussell