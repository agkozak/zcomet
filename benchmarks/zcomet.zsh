() {
  local -r home_dir=${1}

  # git clone https://github.com/agkozak/zcomet.git $home_dir
  () {
    setopt LOCAL_OPTIONS EXTENDED_GLOB

    cp ~[zcomet-bin]/zcomet.zsh $home_dir
    mkdir ${home_dir}/functions
    cp -r ~[zcomet-bin]/functions ${home_dir}/functions
  }

  # add modules to .zshrc
  >| ${home_dir}/.zshrc <<\END
source ${HOME}/zcomet.zsh
zcomet load zimfw/environment
zcomet load zimfw/git
zcomet load zimfw/input
zcomet load zimfw/termtitle
zcomet load zimfw/utility
zcomet load zimfw/duration-info
zcomet load zimfw/git-info
zcomet load zimfw/asciiship
zcomet fpath zsh-users/zsh-completions src
zcomet load zsh-users/zsh-autosuggestions
zcomet load zsh-users/zsh-syntax-highlighting
zcomet load zsh-users/zsh-history-substring-search

[[ $TERM != dumb ]] && zcomet compinit

bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down
END

} "${@}"
