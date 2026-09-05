#!/bin/bash
cd "$(dirname "${BASH_SOURCE}")";

skip_pull=false
force_update=false

for arg in "$@"; do
    case "$arg" in
        -np|--no-pull)
            skip_pull=true
            ;;
        -f|--force)
            force_update=true
            ;;
    esac
done

if [ "$skip_pull" = false ]; then
    git pull origin main;
fi

function doIt() {
    # Read exclusions from .dotignore file if it exists
    local exclude_args=""
    if [ -f ".dotignore" ]; then
        while IFS= read -r line; do
            # Skip empty lines and comments
            if [[ -n "$line" && ! "$line" =~ ^# ]]; then
                exclude_args+="--exclude=$line "
            fi
        done < ".dotignore"
    fi
    
    # Default exclusions (can be overridden by .dotignore)
    local default_excludes=(
        ".git/"
        ".DS_Store"
        "update.sh"
        "brew.sh"
        "README.md"
        "LICENSE-MIT.txt"
        ".dotignore"
        ".gitignore"
    )
    
    # Add default exclusions if .dotignore doesn't exist
    if [ ! -f ".dotignore" ]; then
        for exclude in "${default_excludes[@]}"; do
            exclude_args+="--exclude=$exclude "
        done
    fi
    
    # Use rsync to copy files, preserving directory structure but only updating files
    eval "rsync $exclude_args -avh --no-perms --existing . ~/"
    
    # Copy new files and directories that don't exist in home
    eval "rsync $exclude_args -avh --no-perms --ignore-existing . ~/"
    
    zsh;
}

if [ "$force_update" = true ]; then
    doIt;
else
    read -p "This may overwrite existing files in your home directory. Are you sure? (y/n) " -n 1;
    echo "";
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        doIt;
    fi;
fi;
unset doIt;