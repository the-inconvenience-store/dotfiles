#!/bin/bash

# Install command-line tools using Homebrew.

# Make sure we’re using the latest Homebrew.
brew update

# Upgrade any already-installed formulae.
brew upgrade

# Save Homebrew’s installed location.
BREW_PREFIX=$(brew --prefix)

brew install coreutils
brew install git
brew install zoxide
brew install neofetch
brew install bat
brew install eza
brew install dua-cli
brew install ripgrep
brew install zsh-autosuggestions
brew install make
brew install fzf


# dev tools
brew install mongosh
brew install node
brew install rustup
brew install python
brew install uv
