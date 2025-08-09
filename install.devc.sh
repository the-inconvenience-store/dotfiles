/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

source ./brew.sh

# Add missing commands to .zshrc if they don't exist
ZSHRC_FILE="$HOME/.zshrc"

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

# Check and add homebrew shellenv
if command -v brew &> /dev/null && ! grep -q "brew shellenv" "$ZSHRC_FILE"; then
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$ZSHRC_FILE"
    echo "Added homebrew shellenv to .zshrc"
fi

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