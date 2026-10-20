#!/usr/bin/env python3
"""Read-only profile rendering tests; run with python3 bootstrap/tests/test_profiles.py."""
import json
import pathlib
import os
import tempfile
import pty
import select
import shutil
import time
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

    def test_server_prompt_adds_identity_without_replacing_stock_theme(self):
        name = "dot_oh-my-zsh/custom/themes/robbyrussell.zsh-theme.tmpl"
        self.assertTrue((SOURCE / name).is_file(), "Server prompt theme is missing")
        self.assertEqual(render(name, "workstation").strip(), "")
        self.assertEqual(render(name).strip(), "")
        theme = render(name, "server")
        subprocess.run(["zsh", "-n"], input=theme, text=True, check=True)
        omz = pathlib.Path.home() / ".oh-my-zsh"
        self.assertTrue((omz / "themes/robbyrussell.zsh-theme").is_file())
        probe = '''autoload -Uz colors; colors
source "$ZSH/themes/robbyrussell.zsh-theme"
stock=$PROMPT
stock_git_prefix=$ZSH_THEME_GIT_PROMPT_PREFIX
'''
        probe += theme + '''
[[ "$PROMPT" == '%n@%m '"$stock" ]] || exit 1
[[ "$ZSH_THEME_GIT_PROMPT_PREFIX" == "$stock_git_prefix" ]] || exit 2
'''
        probe += theme + '''
[[ "$PROMPT" == '%n@%m '"$stock" ]] || exit 3
print -P -- "$PROMPT"
'''
        result = subprocess.run(["zsh", "-f"], input=probe, text=True, capture_output=True, env=dict(os.environ, ZSH=str(omz)))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("@", result.stdout)
        self.assertIn("➜", result.stdout)

    def test_server_sets_login_shell_once_without_starting_interactive_shell(self):
        name = "run_after_zz-set-default-shell.sh.tmpl"
        self.assertTrue((SOURCE / name).is_file(), "Server login-shell hook is missing")
        script = render(name, "server")
        self.assertEqual(render(name, "workstation").strip(), "")
        self.assertEqual(render(name, "server", "darwin").strip(), "")
        self.assertNotIn("exec zsh", script)
        scratch = pathlib.Path.home() / ".hermes/cache/scratch"
        with tempfile.TemporaryDirectory(dir=str(scratch) if scratch.is_dir() else None) as tmp:
            tools = {
                "id": 'case "$1" in -un) printf "tester\\n";; -u) printf "1000\\n";; esac',
                "getent": 'read -r shell < "$STATE"; printf "tester:x:1000:1000::/home/tester:%s\\n" "$shell"',
                "zsh": "exit 0",
                "grep": "exit 0",
                "sudo": 'printf "%s\\n" "$*" >> "$CALLS"; exec "$@"',
                "chsh": 'printf "%s\\n" "$2" > "$STATE"',
            }
            for tool, body in tools.items():
                path = pathlib.Path(tmp, tool)
                path.write_text("#!/bin/sh\n" + body + "\n")
                path.chmod(0o755)
            pathlib.Path(tmp, "state").write_text("/bin/bash\n")
            env = dict(os.environ, PATH=tmp + ":/usr/bin:/bin", STATE=tmp + "/state", CALLS=tmp + "/calls")
            for _ in range(2):
                subprocess.run(["/bin/sh"], input=script, env=env, text=True, check=True, capture_output=True)
            self.assertEqual(pathlib.Path(tmp, "state").read_text().strip(), tmp + "/zsh")
            self.assertEqual(pathlib.Path(tmp, "calls").read_text().splitlines(), ["chsh -s " + tmp + "/zsh tester"])

    def test_server_setup_wrapper_applies_before_entering_zsh(self):
        path = SOURCE / "bootstrap/server.sh"
        self.assertTrue(path.is_file(), "Server setup wrapper is missing")
        script = path.read_text()
        self.assertIn('exec "$SHELL" -l', script)
        self.assertIn('[ -t 0 ]', script)
        self.assertLess(script.index('apply'), script.index('exec "$SHELL" -l'))
        subprocess.run(["sh", "-n", str(path)], check=True)
        scratch = pathlib.Path.home() / ".hermes/cache/scratch"
        with tempfile.TemporaryDirectory(dir=str(scratch) if scratch.is_dir() else None) as tmp:
            root = pathlib.Path(tmp)
            bootstrap = root / "source/bootstrap"
            bootstrap.mkdir(parents=True)
            wrapper = bootstrap / "server.sh"
            shutil.copyfile(path, wrapper)
            tools = root / "bin"
            tools.mkdir()
            for name, body in {
                "uname": "printf 'Linux\\n'",
                "chezmoi": 'printf "%s\\n" "$*" >> "$CALLS"; case "$*" in *" apply") exit "${APPLY_RC:-0}";; esac',
                "zsh": 'printf "HANDOFF:%s:%s\\n" "$1" "$SHELL"',
            }.items():
                tool = tools / name
                tool.write_text("#!/bin/sh\n" + body + "\n")
                tool.chmod(0o755)
            env = dict(os.environ, PATH=str(tools) + ":/usr/bin:/bin", CALLS=str(root / "calls"))
            result = subprocess.run(["/bin/sh", str(wrapper)], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertNotIn("HANDOFF:", result.stdout)
            self.assertIn("no interactive terminal", result.stdout)
            for rc in (0, 23):
                master, slave = pty.openpty()
                proc = subprocess.Popen(["/bin/sh", str(wrapper)], stdin=slave, stdout=slave, stderr=slave, env=dict(env, APPLY_RC=str(rc)))
                os.close(slave)
                try:
                    output = b""
                    deadline = time.monotonic() + 10
                    while time.monotonic() < deadline:
                        if select.select([master], [], [], 0.1)[0]:
                            try:
                                chunk = os.read(master, 65536)
                                if not chunk:
                                    break
                                output += chunk
                            except OSError:
                                break
                        elif proc.poll() is not None:
                            break
                    proc.wait(timeout=1)
                    self.assertEqual(proc.returncode, rc, output.decode())
                    if rc == 0:
                        self.assertIn("HANDOFF:-l:" + str(tools / "zsh"), output.decode())
                    else:
                        self.assertNotIn(b"HANDOFF:", output)
                finally:
                    if proc.poll() is None:
                        proc.kill()
                        proc.wait()
                    os.close(master)

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
