# dotfiles

Terminal environment for macOS and WSL, managed with mise. One repo, one command:
CLI tools, zsh, terminal, editor, agents, and Pi config, all tracked in `mise/`.

## Setup

```sh
git clone https://github.com/mrodrigues95/dotfiles.git
cd dotfiles
./install.sh
```

`install.sh` installs mise, links the repo to `~/.dotfiles` and the global
config into `~/.config/mise`, then runs `mise bootstrap`: OS packages, dotfile
symlinks, versioned tools, provisioning task. Every phase self skips once
converged, so rerunning is safe.

Dry run or check convergence:

```sh
mise bootstrap --dry-run
mise dot apply --dry-run
mise bootstrap status --missing
```

Set zsh as your login shell: `chsh -s $(command -v zsh)`.

## Daily use

Bootstrap sections live in `mise/config.toml`, so run them from the repo
(`install.sh` does the `cd` for you):

```sh
mise -C ~/.dotfiles bootstrap          # converge everything after pulling or editing
mise -C ~/.dotfiles dot apply          # dotfiles only (faster loop while editing configs)
mise -C ~/.dotfiles dot add -l ~/.newrc # capture a new dotfile into home/
mise -C ~/.dotfiles run bootstrap      # provisioning task only (Pi packages, WSL sync)
```

Pass `-l` when adding dotfiles: they live in `mise/config.toml`, not the global
config that only holds tools. Linked files (`.zshrc`, wezterm.lua, zed settings,
agents, …) go live immediately; `apply` is only needed to create new links.

Inspect state with `mise config ls`, `mise tasks ls`, `mise dot status`, and
`mise ls --current`.

## Repo layout

- `install.sh`: installs mise, links repo, runs bootstrap
- `mise/config.toml`: OS packages, dotfiles, `bootstrap` task
- `mise/global-config.toml`: the `[tools]` list, linked to
  `~/.config/mise/config.toml` so every shell gets tools
- `mise/tasks/bootstrap.sh`: provisioning task (Pi CLI, node-pty, WSL sync)
- `home/`: the live config files, symlinked into `~`

## Where config lives

`home/` is the real config. `mise dot apply` symlinks `~/.zshrc`, `~/.agents`,
`~/.config/{wezterm,zed,herdr,starship.toml}`, and `~/.pi/agent/*` authored files
to matching repo paths, so editing here edits your live config with no drift. On
WSL, native Windows apps cannot follow Linux symlinks, so `bootstrap` also copies
wezterm.lua and zed settings to the Windows side.

## Node

Node is managed by mise (`node = "24"` in `mise/global-config.toml`), natively.
nvm is a sourced shell function rather than a binary, so mise cannot provide its
`nvm` command as a tool.

```sh
cd ~/some/project
mise use node@20       # writes mise.toml there and installs 20.x
mise use -g node@lts   # change the global default
```

`mise use -g` edits `mise/global-config.toml`, so commit the change. Inside
`~/.dotfiles` a bare `mise use` targets `mise/config.toml` instead, so add `-g`
there or run it from a project directory.

## Pi

Pi installs via npm into `~/.local/share/npm-global` (version independent, so
Node upgrades do not orphan it). Runtime state stays local; only authored files
under `home/.pi/agent` are managed (settings, extensions, AGENTS.md, skill-gate,
pi-blackhole config).

On WSL, Pi's pinned extension needs `node-pty`, which has no Linux prebuild.
`bootstrap` rebuilds it with zig (from mise `[tools]`) against your glibc when
the load check fails. Manual fallback:

```sh
sudo apt-get install -y build-essential          # normally done by `mise bootstrap`
cd ~/.pi/agent/npm/node_modules/node-pty
GLIBC=$(getconf GNU_LIBC_VERSION | awk '{print $2}')
CC="zig cc -target x86_64-linux-gnu.$GLIBC" \
CXX="zig c++ -target x86_64-linux-gnu.$GLIBC" mise exec -- npm rebuild node-pty
```
