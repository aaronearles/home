#!/bin/bash

# https://docs.brew.sh

# One line installation script
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Add to PATH (ZSH)
echo >> /home/aearles//.zshrc
echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> /home/aearles//.zshrc
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Install dependencies
sudo apt-get install build-essential

# Recommends installing gcc
brew install gcc