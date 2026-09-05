#!/bin/bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

brew install coreutils git zoxide neofetch bat eza dua-cli ripgrep zsh-autosuggestions make fzf jq
# brew install git
# brew install zoxide
# brew install neofetch
# brew install bat
# brew install eza
# brew install dua-cli
# brew install ripgrep
# brew install zsh-autosuggestions
# brew install make
# brew install fzf
# brew install jq


# dev tools
brew install mongosh node rustup python uv pyenv
# brew install node
# brew install rustup
# brew install python
# brew install uv
