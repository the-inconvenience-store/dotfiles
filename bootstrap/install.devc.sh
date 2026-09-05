NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
ZSHRC_FILE="$HOME/.zshrc"

# Check and add brew completion setup
if command -v brew &> /dev/null && ! grep -q 'FPATH="$(brew --prefix)/share/zsh/site-functions' "$ZSHRC_FILE"; then
    cat >> "$ZSHRC_FILE" << 'EOF'
if type brew &>/dev/null; then
FPATH="$(brew --prefix)/share/zsh/site-functions:${FPATH}"
autoload -Uz compinit
compinit
fi
EOF
    echo "Added brew completion setup to .zshrc"
fi

# Check and add homebrew shellenv
if command -v brew &> /dev/null && ! grep -q "brew shellenv" "$ZSHRC_FILE"; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$ZSHRC_FILE"
    echo "Added homebrew shellenv to .zshrc"
fi
eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

brew install zoxide bat eza dua-cli

# Copy .oh-my-zsh directory if it exists in dotfiles
if [ -d ".oh-my-zsh" ]; then
    echo "Copying .oh-my-zsh to home directory..."
    cp -r .oh-my-zsh "$HOME/"
    echo "Copied .oh-my-zsh to $HOME/.oh-my-zsh"
fi

# Add missing commands to .zshrc if they don't exist

# Check and add zoxide init
if ! grep -q "zoxide init" "$ZSHRC_FILE"; then
    echo 'eval "$(zoxide init zsh)"' >> "$ZSHRC_FILE"
    echo "Added zoxide init to .zshrc"
fi

# Check and add kubectl completion
if command -v kubectl &> /dev/null && ! grep -q "kubectl completion" "$ZSHRC_FILE"; then
    echo 'source <(kubectl completion zsh)' >> "$ZSHRC_FILE"
    echo "Added kubectl completion to .zshrc"
fi

