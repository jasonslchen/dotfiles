#!/bin/bash

# Install zsh if it's not already installed
if ! command -v zsh &> /dev/null
then
    echo "zsh not found, installing..."
    sudo apt-get update && sudo apt-get install -y zsh
fi

# Change the default shell to zsh
sudo chsh -s $(which zsh)

# Source the .aliases file
echo 'source ~/.aliases' >> ~/.zshrc

# Reload the zsh configuration
source ~/.zshrc

# Print a message
echo "Setup complete. The terminal has been updated to use zsh with your aliases."
