#!/usr/bin/env python3
"""Read-only profile rendering tests; run with python3 bootstrap/tests/test_profiles.py."""
import json
import pathlib
import os
import tempfile
import subprocess
import unittest

SOURCE = pathlib.Path(__file__).resolve().parents[2]


def render(name, profile=None, os_name="linux", init=False):
    data = {"chezmoi": {"os": os_name}}
    if profile is not None:
        data["profile"] = profile
    command = ["chezmoi", "--source", str(SOURCE), "--override-data", json.dumps(data), "execute-template"]
    if init:
        assert profile is not None
        command += ["--init", "--promptChoice", "Machine profile=" + profile]
    return subprocess.check_output(command, input=(SOURCE / name).read_text(), text=True)


class Profiles(unittest.TestCase):
    def test_init_persists_selected_profile_and_editor(self):
        for profile in ("server", "workstation"):
            with self.subTest(profile=profile):
                config = render(".chezmoi.toml.tmpl", profile, init=True)
                self.assertIn('profile = "' + profile + '"', config)
                self.assertIn('command = "nvim"', config)
        ignored = render(".chezmoiignore", "server")
        self.assertIn(".config/chezmoi/chezmoi.toml", ignored.splitlines())

    def test_server_disables_extras_but_keeps_tailscale(self):
        disabled = ["install-herdr", "install-herdr-plugins", "install-lspmux", "install-mise", "install-nerd-font-symbols", "install-nerd-fonts-cli", "configure-iterm2-preferences"]
        for installer in disabled:
            name = "run_once_after_" + installer + ".sh.tmpl"
            self.assertEqual(render(name, "server").strip(), "", name)
        self.assertIn("https://tailscale.com/install.sh", render("run_once_after_install-tailscale.sh.tmpl", "server"))
        for name in ["run_once_after_install-oh-my-zsh.sh.tmpl", "run_once_after_install-oh-my-zsh-plugins.sh.tmpl", "run_onchange_after_install-tmux-plugins.sh.tmpl"]:
            self.assertTrue(render(name, "server").startswith("#!/bin/sh\n"), name)
        ignored = render(".chezmoiignore", "server")
        for path in [".config/herdr/**", ".config/iterm2/**", "scripts/**"]:
            self.assertIn(path, ignored.splitlines())

    def test_hist_helpers_are_managed_on_fresh_servers(self):
        managed = subprocess.check_output(["chezmoi", "--source", str(SOURCE), "--override-data", '{"profile":"server","chezmoi":{"os":"linux"}}', "managed", "--path-style=relative"], text=True).splitlines()
        self.assertIn(".oh-my-zsh/custom/plugins/zsh-hist/functions/.hist.help", managed)
        self.assertNotIn(".config/chezmoi/chezmoi.toml", managed)
        self.assertFalse(any(p.startswith(".config/herdr") for p in managed))
        self.assertFalse(any(p.startswith(".config/iterm2") for p in managed))

    def test_server_packages_support_root_without_sudo_and_skip_recommends(self):
        scratch = pathlib.Path.home() / ".hermes/cache/scratch"
        with tempfile.TemporaryDirectory(dir=str(scratch) if scratch.is_dir() else None) as tmp:
            for name, body in {"id": "printf '0\\n'", "sudo": "exit 87", "apt-get": 'printf "%s\\n" "$*" >> "$TEST_LOG"'}.items():
                path = pathlib.Path(tmp) / name
                path.write_text("#!/bin/sh\n" + body + "\n")
                path.chmod(0o755)
            env = dict(os.environ, PATH=tmp + ":/usr/bin:/bin", TEST_LOG=tmp + "/calls")
            script = render("run_onchange_before_install-packages-linux.sh.tmpl", "server")
            result = subprocess.run(["/bin/sh"], input=script, text=True, env=env, capture_output=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("--no-install-recommends", pathlib.Path(tmp, "calls").read_text())

    def test_server_installs_nvim_plugins_without_mutating_managed_lock(self):
        name = "run_onchange_after_install-nvim-server-plugins.sh.tmpl"
        self.assertTrue((SOURCE / name).is_file(), "Server plugin bootstrap is missing")
        script = render(name, "server")
        self.assertIn("+Lazy! install", script)
        self.assertIn("+Lazy! restore", script)
        self.assertIn("git -C", script)
        self.assertIn("sha256", script)
        self.assertEqual(render(name, "workstation").strip(), "")

    def test_linux_server_tools_are_pinned_and_shell_resolves_them(self):
        name = "run_onchange_before_install-server-tools-linux.sh.tmpl"
        self.assertTrue((SOURCE / name).is_file(), "Linux server tools installer is missing")
        script = render(name, "server")
        self.assertTrue(script.startswith("#!/bin/sh\n"))
        self.assertIn("sha256sum", script)
        self.assertIn("v0.11.7", script)
        self.assertIn("v26.9.1", script)
        self.assertEqual(render(name, "workstation").strip(), "")
        self.assertEqual(render(name, "server", "darwin").strip(), "")
        shell = render("dot_zshenv.tmpl", "server")
        self.assertIn('$HOME/.local/bin', shell)
        self.assertNotIn('source $ZSH/oh-my-zsh.sh', shell)
        aliases = render("dot_oh-my-zsh/custom/server-commands.zsh.tmpl", "server")
        self.assertIn("batcat", aliases)
        self.assertIn("fdfind", aliases)

    def test_server_package_lists_are_small_and_workstation_default_is_unchanged(self):
        linux = render("run_onchange_before_install-packages-linux.sh.tmpl", "server")
        for package in ["zsh", "bat", "fd-find", "ripgrep", "fzf", "zoxide", "jq", "tmux", "btop", "direnv"]:
            self.assertIn('"' + package + '"', linux)
        for package in ["tailscale", "neovim", "tree-sitter-cli", "fonts-powerline", "fontconfig", "ufw"]:
            self.assertNotIn('"' + package + '"', linux)
        for name in ["run_onchange_before_install-packages-linux.sh.tmpl", "run_onchange_before_install-packages-darwin.sh.tmpl"]:
            self.assertEqual(render(name), render(name, "workstation"))
        darwin = render("run_onchange_before_install-packages-darwin.sh.tmpl", "server", "darwin")
        for package in ["yazi", "neovim", "tailscale", "bat"]:
            self.assertIn('brew "' + package + '"', darwin)
        self.assertNotIn('cask "', darwin)
        self.assertNotIn("brew link", darwin)


if __name__ == "__main__":
    unittest.main()
