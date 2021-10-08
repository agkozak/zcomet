() {
  local -r home_dir=${1}

  # git clone https://github.com/agkozak/zcomet.git ${home_dir}
  () {
    setopt LOCAL_OPTIONS EXTENDED_GLOB

    cp ../zcomet.zsh $home_dir
    mkdir ${home_dir}/functions
    cp ../functions/*~*.zwc ${home_dir}/functions
  }

  # add modules to .zshrc
  >| ${home_dir}/.zshrc <<\END
source ${HOME}/zcomet.zsh
zcomet snippet https://github.com/zimfw/environment/blob/master/init.zsh
zcomet load zimfw/git
zcomet snippet https://github.com/zimfw/input/blob/master/init.zsh
zcomet snippet https://github.com/zimfw/termtitle/blob/master/init.zsh
zcomet load zimfw/utility
zcomet load zimfw/duration-info
zcomet load zimfw/git-info
zcomet snippet https://github.com/zimfw/asciiship/blob/master/asciiship.zsh-theme
zcomet fpath zsh-users/zsh-completions src
zcomet load zsh-users/zsh-autosuggestions
zcomet load zsh-users/zsh-syntax-highlighting
zcomet snippet https://github.com/zsh-users/zsh-history-substring-search/blob/master/zsh-history-substring-search.zsh

[[ $TERM != dumb ]] && zcomet compinit

bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down
END

} "${@}"
