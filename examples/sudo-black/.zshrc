# ZCOMET
## Clone zcomet if necessary
if [[ ! -f ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh ]]; then
  git clone https://github.com/agkozak/zcomet.git ${ZDOTDIR:-${HOME}}/.zcomet/bin
fi

## Source zcomet.zsh
source ${ZDOTDIR:-${HOME}}/.zcomet/bin/zcomet.zsh


# P10K PROMPT
zcomet load romkatv/powerlevel10k

if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  zcomet snippet "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

[[ ! -f ~/.p10k.zsh ]] || zcomet snippet ~/.p10k.zsh

# OPTIONS
## history
HISTDB_TABULATE_CMD=(sed -e $'s/\x1f/\t/g')
HISTSIZE=1000000   # the number of items for the internal history list
SAVEHIST=1000000   # maximum number of items for the history file

# setopt HIST_IGNORE_ALL_DUPS  # do not put duplicated command into history list
# setopt HIST_SAVE_NO_DUPS  # do not save duplicated command
# setopt HIST_REDUCE_BLANKS  # remove unnecessary blanks
setopt APPEND_HISTORY
setopt HIST_FCNTL_LOCK
setopt HIST_LEX_WORDS
# setopt INC_APPEND_HISTORY
setopt SHARE_HISTORY
setopt INC_APPEND_HISTORY_TIME  # append command to history file immediately after execution
# setopt EXTENDED_HISTORY  # record command start time

## autosuggestions
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#4895a3,bold,underline"

# KEYBINDINDINGS
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey "^[[A" up-line-or-beginning-search # Up
bindkey "^[[B" down-line-or-beginning-search # Down

# PLUGINS
## History db
zcomet load larkery/zsh-histdb

# SNIPPETS
## OMZ plugins
zcomet snippet https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/git/git.plugin.zsh

## Rancher desktop
export PATH=~/.rd/bin/:$PATH

## Local custom aliases
[ -f ~/.custom_alias.zsh ] || touch ~/.custom_alias.zsh
zcomet snippet ~/.custom_alias.zsh

# COMPETIONS
## brew completions
# zcomet fpath $(brew --prefix)/share/zsh/site-functions/

## custom competions
[ -d ~/.zsh_completions ] || mkdir ~/.zsh_completions
zcomet fpath ~/.zsh_completions/

# FZF
# [ -f ~/.fzf.zsh ] && zcomet snippet ~/.fzf.zsh

## auto suggestions
zcomet load zsh-users/zsh-autosuggestions

## syntax highlighting
zcomet load zsh-users/zsh-syntax-highlighting

# Run compinit and compile its cache
zcomet compinit
