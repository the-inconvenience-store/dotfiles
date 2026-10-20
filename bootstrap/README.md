# Machine profiles

One repository provides `workstation` (the existing setup) and `server`.
The selection is local to each machine, in `~/.config/chezmoi/chezmoi.toml`:

```toml
[data]
profile = "server"
```

Existing machines with no profile retain workstation behaviour. The init
configuration also sets Neovim as chezmoi's editor. Do not `chezmoi add` this
local config: `.chezmoi.toml.tmpl` creates it and `.chezmoiignore` protects it
from being overwritten during apply.

## New server

The Linux server installer targets Ubuntu 24.04+ and Debian 13+, on amd64 or
arm64. Older distributions and non-APT distributions are not covered by this
profile. Use a normal user with sudo access, or root. The installer does not
change your login shell, SSH settings, firewall policy, or Tailscale login.

Install Git, CA certificates, curl and chezmoi first, then:

```sh
chezmoi init --promptChoice 'Machine profile=server' the-inconvenience-store/dotfiles
chezmoi diff
chezmoi apply --dry-run --verbose
chezmoi apply
exec zsh
```

These commands use the published repository, so local changes must be pushed
before another machine can use them. To use an existing clone, use its source
path, e.g. `chezmoi --source /path/to/dotfiles init --promptChoice ...`.

To make Zsh your login shell, deliberately run `chsh -s "$(command -v zsh)"`.
Keep an existing SSH session open until you have verified a new login works.

Tailscale is installed through its official Linux repository installer. On a
normal systemd VPS the package installs the daemon service. Authentication is
separate and manual:

```sh
sudo tailscale up
```

No auth key is stored in the repository and no machine is automatically joined
to a tailnet. Container tests verify installation, not daemon networking.

## Included

- Oh My Zsh with the existing robbyrussell theme, autosuggestions, zsh-hist,
  portable aliases, direnv and zoxide integration.
- Yazi, bat, eza, ripgrep, fd, fzf, jq, tmux and its existing plugins, and btop.
- Neovim with the existing NvChad appearance, editing and navigation, but
  without the workstation's language servers, Rust/Go/debugger/Herdr tooling,
  automatic external formatting/linting, or the native fff search plugin.
- Tailscale.
- Bootstrap dependencies and a small compiler toolchain for Neovim parsers.

Linux Neovim v0.11.7 and Yazi v26.9.1 use upstream binaries, pinned alongside
release SHA256 digests in `run_onchange_before_install-server-tools-linux.sh.tmpl`.
They install under `~/.local/opt`, with commands in `~/.local/bin`. This avoids
old distro Neovim versions, language toolchain bootstrapping and overwriting
system packages. Debian/Ubuntu's `batcat` and `fdfind` names are handled too.

The server post-apply installer downloads missing Neovim plugins, restores the
canonical lockfile, and checks installed Git revisions against it. Initial
plugin bootstrapping can rewrite the lockfile before an explicit restore, so
the installer preserves it across both phases. No workstation plugin upgrades
or lockfile changes are made. Normal later launches need no network access.

No GUI apps, fonts, media preview stack, Herdr, mise, lspmux, UFW installation,
or development-language stack are added by the Linux server profile. Use a
Nerd Font in the SSH client's terminal if desired. Yazi's multimedia previews
remain optional. Installing Tailscale does add its own package dependencies.

The macOS server package selection uses Homebrew for the same CLI baseline,
without casks or the full media-preview libraries. Linux is the VPS target.

## Existing machines

To deliberately change a saved profile (review the resulting diff first):

```sh
chezmoi init --prompt --promptChoice 'Machine profile=server'
chezmoi diff
chezmoi apply --dry-run --verbose
```

Select `workstation` instead to switch back. Ignoring a configuration or omitting
a package does not uninstall previous software or clean an existing machine.
Start with a fresh account/server for a genuinely stripped-down environment.

## Validation

Read-only profile/template regression tests (Python 3 + chezmoi):

```sh
python3 bootstrap/tests/test_profiles.py
```

Neovim's profile tests are in `dot_config/nvim/tests/` in the source tree and
are ignored during chezmoi apply. No tests or bootstrap documents are installed
as runtime dotfiles.

The implementation is tested with a disposable Ubuntu container, an unprivileged
sudo user, actual package/binary installs, fresh shell startup, Tailscale version,
Neovim startup and plugin installation, and a second apply/verify. No real VPS
is changed by these tests.

## References

- https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/
- https://www.chezmoi.io/reference/templates/init-functions/promptChoiceOnce/
- https://www.chezmoi.io/user-guide/advanced/install-packages-declaratively/
- https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/
- https://github.com/neovim/neovim/blob/master/INSTALL.md
- https://yazi-rs.github.io/docs/installation
