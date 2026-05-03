# Shell completions for `gitb`

Tab-completion for top-level commands, subcommands, and (where it makes sense)
branch names. Bash, Zsh, and Fish are supported.

## Quick install

From this repo:

```sh
completion/install.sh                # auto-detect from $SHELL
completion/install.sh bash zsh fish  # install for specific shells
completion/install.sh --uninstall    # remove
```

Or via `make`:

```sh
make install-completions
```

## Manual install

### Bash

```sh
# Homebrew on macOS
cp completion/gitb.bash "$(brew --prefix)/etc/bash_completion.d/gitb"

# User-local
cp completion/gitb.bash ~/.local/share/bash-completion/completions/gitb

# Or source it directly from your ~/.bashrc
echo "source $PWD/completion/gitb.bash" >> ~/.bashrc
```

### Zsh

```sh
mkdir -p ~/.zsh/completions
cp completion/gitb.zsh ~/.zsh/completions/_gitb

# In ~/.zshrc:
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
```

Oh-my-zsh users:

```sh
cp completion/gitb.zsh ~/.oh-my-zsh/completions/_gitb
```

### Fish

```sh
cp completion/gitb.fish ~/.config/fish/completions/gitb.fish
```

Fish picks the file up automatically — no shell restart needed.

## What gets completed

- Top-level commands and aliases (`commit`, `c`, `co`, …).
- Second-level subcommands (e.g. `gitb commit <TAB>` → `ai fast push …`).
- Local branch names where the command takes one (`branch`, `merge`,
  `rebase`, `cherry`, `pull`, `log`).
- Third-level subcommands for `log branch …` and `wip up|down …`.
