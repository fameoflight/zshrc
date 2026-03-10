# ZSH & Development Environment Configuration

This repository contains a modular shell and workstation setup centered on zsh, with companion `bashrc`, `profile`, install scripts, app-setting backups, and CLI tooling.

## Layout

- `zshrc` is the main startup file linked to `~/.zshrc`.
- `environment.zsh` loads shared environment defaults from `shell/env.shared.sh`.
- `bashrc` and `profile` are thin shims for systems where bash or login-shell integration still matters.
- `Settings/` stores portable app settings backups.
- `bin/` and `scripts/` contain setup, backup, and utility commands.

## Install

Clone the repository to `~/zshrc`, then run:

```bash
make install
```

For a full macOS bootstrap:

```bash
make mac
```

The install target links:

- `~/zshrc/zshrc` -> `~/.zshrc`
- `~/zshrc/bashrc` -> `~/.bashrc`
- `~/zshrc/profile` -> `~/.profile`
- `~/zshrc` -> `~/.config/zsh`

## Startup Model

The shell startup path is intentionally split:

1. `shell/env.shared.sh` sets common environment variables and base PATH entries.
2. `environment.zsh` adds zsh-specific behavior like deduplicated `path`.
3. `zshrc` loads common functional modules first.
4. Interactive-only modules such as prompt, completions, syntax highlighting, `fasd`, and SSH key loading are loaded only for interactive shells.

## Private And Generated Data

The repo should contain portable configuration, not machine state.

- Keep local secrets in `private.zsh` or `private.env`.
- `Settings/Claude/memory/`, `credentials/*.json`, iTerm private preference plists, and Xcode `.xcuserstate` files are intentionally ignored.
- Backup scripts may still create those files locally; they just should not be committed.

## Common Commands

- `make help` shows the main setup and maintenance targets.
- `make install` installs shell entrypoints and submodules.
- `make mac` runs the full macOS-oriented setup.
- `make app-settings` restores tracked application settings.
- `make debug` profiles zsh startup behavior.

## Validation

The repository includes a lightweight validation workflow and can also be checked locally with:

```bash
zsh -n zshrc $(git ls-files '*.zsh')
shellcheck bashrc profile $(git ls-files '*.sh')
```

## Credits

- Originally based on Sebastian Tramp's zsh configuration.
- Customized and extended by Hemant Verma.
