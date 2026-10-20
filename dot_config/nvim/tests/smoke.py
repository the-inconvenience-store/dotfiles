#!/usr/bin/env python3
"""Offline real-Neovim probe, reusing installed plugin checkouts, not live state.

Run: python3 tests/smoke.py --plugins ~/.local/share/nvim/lazy
A fresh installation must install plugins first; this deliberately performs no
network calls or builds. Config, cache, state, data and fixture edits are isolated.
"""
import argparse
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--plugins", type=Path, required=True)
parser.add_argument("--nvim", default="nvim")
parser.add_argument("--profile", choices=("server", "workstation", "missing"), default="server")
args = parser.parse_args()
source = Path(__file__).resolve().parents[1]
plugins = args.plugins.expanduser().resolve()
assert (plugins / "lazy.nvim/lua/lazy/init.lua").is_file(), "--plugins must contain lazy.nvim"
scratch = Path.home() / ".hermes/cache/scratch"
scratch.mkdir(parents=True, exist_ok=True)
with tempfile.TemporaryDirectory(prefix="nvim-server-", dir=scratch) as temp:
    root = Path(temp)
    config = root / "config/nvim"
    shutil.copytree(source, config)
    if args.profile != "missing":
        (config / "lua/machine.lua").write_text(f'return {{ profile = "{args.profile}" }}\n')
    lazy = root / "data/nvim/lazy"
    lazy.mkdir(parents=True)
    for plugin in plugins.iterdir():
        if plugin.is_dir():
            # lazy's installed scan does not count symlink plugin directories.
            # Copy without Git internals so no probe can mutate the live plugins.
            shutil.copytree(plugin, lazy / plugin.name, ignore=shutil.ignore_patterns(".git"))
    project = root / "project"
    project.mkdir()
    fixtures = {
        "example.lua": 'local value = "hello"\n', "example.go": "package main\n",
        "example.rs": "fn main() {}\n", "example.fga": "model\n  schema 1.1\n",
        "example.md": "# Hello\n\nSome **text**.\n", "example.sh": "#!/bin/sh\nprintf hello\n",
        "example.json": '{"hello": true}\n',
    }
    for name, text in fixtures.items():
        (project / name).write_text(text)
    env = {**os.environ, "NVIM_APPNAME": "nvim"}
    for key, directory in {"XDG_CONFIG_HOME": "config", "XDG_DATA_HOME": "data", "XDG_CACHE_HOME": "cache", "XDG_STATE_HOME": "state"}.items():
        env[key] = str(root / directory)
    # Reproduce base46's real install/build hook before startup, since copied
    # plugins are already "installed" and lazy will not run their build hooks.
    prelude = (
        "lua package.path = vim.fn.stdpath('config') .. '/lua/?.lua;' .. package.path; "
        "for _, name in ipairs({'NvChad', 'ui', 'base46', 'plenary.nvim'}) do "
        "vim.opt.rtp:append(vim.fn.stdpath('data') .. '/lazy/' .. name) end; "
        "vim.g.base46_cache = vim.fn.stdpath('data') .. '/base46/'; "
        "require('base46').load_all_highlights(); "
        "local c = require('configs.lazy'); c.install.missing = false; "
        "c.checker = { enabled = false }; c.change_detection = { enabled = false }; "
        "c.readme = { enabled = false }"
    )
    command = [args.nvim, "--headless", "--cmd", prelude, "-c",
               "lua dofile(vim.fn.stdpath('config') .. '/tests/server_smoke.lua')"]
    result = subprocess.run(command, cwd=project, env=env, text=True, capture_output=True, timeout=90)
    print(result.stdout + result.stderr, end="")
    if "Error" in result.stderr or "stack traceback" in result.stderr:
        raise SystemExit(result.returncode or 1)
    raise SystemExit(result.returncode)
