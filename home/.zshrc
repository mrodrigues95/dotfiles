# Symlinked from ~/.dotfiles/home/.zshrc by mise — edit the repo copy.

# Version-independent bins first, so `mise` resolves below without a full path.
export PATH="$HOME/.local/share/npm-global/bin:$HOME/.local/bin:$PATH"
[ -d "$HOME/.opencode/bin" ] && export PATH="$HOME/.opencode/bin:$PATH"

# Must precede the mise block below: `mise completion` registers itself with
# `compdef`, which only exists once compinit has run.
autoload -Uz compinit
_comp_dump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompdump"
mkdir -p "${_comp_dump:h}"
compinit -C -d "$_comp_dump"
unset _comp_dump

if [ -x "$HOME/.local/bin/mise" ]; then
  eval "$(mise activate zsh)"
  eval "$(mise completion zsh)"
fi

HISTFILE="$HOME/.zsh_history" HISTSIZE=10000 SAVEHIST=10000
setopt SHARE_HISTORY HIST_IGNORE_DUPS AUTO_CD

# Inline autosuggestions, wherever the package manager put them.
for _asp in \
  /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /usr/local/share/zsh-autosuggestions/zsh-autosuggestions.zsh \
  /home/linuxbrew/.linuxbrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
do
  [ -f "$_asp" ] && source "$_asp" && break
done
unset _asp

# `--version`, not `command -v`: a versionless mise shim can exist but fail.
fzf --version >/dev/null 2>&1 && source <(fzf --zsh)
starship --version >/dev/null 2>&1 && eval "$(starship init zsh)"
eza --version >/dev/null 2>&1 && alias ls='eza' ll='eza -l' la='eza -la'

# WezTerm: OSC 7 reports the cwd so new tabs/splits open where you are rather
# than the Windows home dir; OSC 0 titles the tab with the directory instead of
# the process name (wslhost.exe).
_wezterm_shell_integration() {
  printf '\033]7;file://%s%s\033\\' "$HOST" "$PWD"
  print -Pn '\e]0;%~\a'
}
autoload -Uz add-zsh-hook
add-zsh-hook precmd _wezterm_shell_integration

# Machine-local settings that must not be committed (work hosts, secrets).
# Sourced last so it can override anything above; absent on most machines.
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
