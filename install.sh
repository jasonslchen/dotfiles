#!/bin/bash

# Install zsh if it's not already installed
if ! command -v zsh &> /dev/null
then
    echo "zsh not found, installing..."
    sudo apt-get update && sudo apt-get install -y zsh
fi

# Change the default shell to zsh
sudo chsh -s $(which zsh) || echo "Unable to change shell to zsh. Please run the following command manually: chsh -s $(which zsh)"

# Source the .aliases file
if [ ! -f ~/.aliases ]; then
    touch ~/.aliases
fi
echo 'source ~/.aliases' >> ~/.zshrc

# Check if inside a Codespace
if [ "$CODESPACES" = "true" ]; then
    # If running in Codespaces, source .zshrc without requiring restart
    exec zsh -l
else
    # Otherwise, prompt user to restart shell
    echo "Please restart your terminal or run 'exec zsh' to apply changes."
fi

# Print a message
echo "Setup complete. The terminal has been updated to use zsh with your aliases."