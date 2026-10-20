#!/bin/sh
# Run with: exec sh "$(chezmoi source-path)/bootstrap/server.sh"
set -eu

if [ "$#" -ne 0 ]; then
    printf '%s\n' 'Usage: sh bootstrap/server.sh (no arguments)' >&2
    exit 2
fi
if [ "$(uname -s)" != Linux ]; then
    printf '%s\n' 'This server bootstrap supports Linux only.' >&2
    exit 1
fi
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
chezmoi --source "$source_dir" init --prompt --promptChoice 'Machine profile=server'
chezmoi --source "$source_dir" apply

if [ -t 0 ] && [ -t 1 ]; then
    SHELL=$(command -v zsh)
    export SHELL
    exec "$SHELL" -l
fi
printf '%s\n' 'Server setup complete. Zsh is the default for new logins; no interactive terminal was available to enter it now.'
