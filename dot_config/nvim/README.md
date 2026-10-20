**This repo is supposed to be used as config by NvChad users!**

- The main nvchad repo (NvChad/NvChad) is used as a plugin by this repo.
- So you just import its modules , like `require "nvchad.options" , require "nvchad.mappings"`
- So you can delete the .git from this repo ( when you clone it locally ) or fork it :)

# Machine profiles

Chezmoi renders `lua/machine.lua` from `lua/machine.lua.tmpl`. Only
`return { profile = "server" }` selects the reduced mode. A missing marker,
`workstation`, or an unknown value retains the existing workstation setup.
The template uses `index` so missing chezmoi profile data is also safe.

Server mode retains NvChad's gruvchad theme, tabs, splits, tree, terminal,
completion/snippets, Git signs, TODOs, colors and familiar editing mappings.
It disables fff/native builds, Mason, language LSP setup, formatting/linting,
Prettier/none-ls, Go/Rust helpers, DAP, Herdr and OpenFGA. The format key remains
safe and reports that tooling is disabled. Search keys use Telescope:

- `<leader>ff`: files
- `<leader>fg`: live grep
- `<leader>fw`: word/selection grep
- `<leader>fz`: fuzzy search in the current buffer

## Linux requirements

The Linux server profile pins LuaJIT Neovim 0.11.7 (the locked Telescope's
minimum); 0.12 is also supported. Use Git for lazy/plugin installation and ripgrep for
search. `find` is sufficient as a file-picker fallback; `fd` is optional.
No Go, Rust, Node, Python, LSP, formatter/linter, or tree-sitter CLI is required
to apply or use server mode. The first plugin install needs network access.
A Nerd Font in the connecting terminal improves icons; clipboard integration is
optional and depends on the terminal/host provider.

Server parser builds/automatic installs are disabled. On Neovim 0.12, the
Treesitter plugin and Markdown/context rendering remain available, using any
already-installed parsers. The opt-in `:TSInstallAll` list is exactly
`vim lua vimdoc bash json yaml markdown markdown_inline`; it replaces the inherited
parser list and skips OpenFGA registration. To install these optionally, the
locked Treesitter additionally requires tree-sitter CLI >=0.26.1, a C compiler,
`curl`, and `tar`. Until then, Vim syntax highlighting remains available. On
Neovim 0.11 the locked Treesitter targets an unsupported API, so server mode
omits it and its Markdown/context dependents entirely and uses basic syntax.
Workstation parser behavior/builds are unchanged.

## Verification

Tests are source-only: exclude `.config/nvim/tests` and `.config/nvim/tests/**`
from chezmoi deployment. Never prefix a test filename with `run_` (chezmoi
interprets that as an apply hook). Python is only needed for the offline smoke
test, not for deployment or editing.

From this source directory:

```sh
NVIM_CONFIG_ROOT="$PWD" nvim --headless -u NONE -l tests/profile_spec.lua
python3 tests/smoke.py --plugins "$HOME/.local/share/nvim/lazy"
python3 tests/smoke.py --plugins "$HOME/.local/share/nvim/lazy" --profile workstation
python3 tests/smoke.py --plugins "$HOME/.local/share/nvim/lazy" --profile missing
```

The first probe validates Lua syntax, server/workstation/default declarations,
tooling guards, parser policy and the simulated 0.11 dependency fallback. The
second launches real Neovim with isolated config/cache/data/state and copies of
existing installed plugin checkouts (no plugin downloads or native builds). It
runs base46's actual highlight-build function for the copied installation,
checks lazy's resolved dependency exclusions, opens/writes representative files,
triggers insert/write/FilePost hooks, checks no language servers start, and
exercises all four Telescope mappings including real file selection and grep.
This is not a substitute for a fresh Linux plugin-install verification.

# Credits

1) Lazyvim starter https://github.com/LazyVim/starter as nvchad's starter was inspired by Lazyvim's . It made a lot of things easier!
