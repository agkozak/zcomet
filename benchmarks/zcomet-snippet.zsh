# This benchmark file for zcomet is intended to be used with
# zimfw/zsh-framework-benchmark; just place it in the
# /path/to/zsh-framework-benchmark/frameworks directory, and you will see
# zcomet's performance compared to that of the major plugin managers and
# frameworks.

() {
local -r home_dir=${1}

if [[ -f ${HOME}/.zcomet/bin/zcomet.zsh ]]; then
  cp ${HOME}/.zcomet/bin/zcomet.zsh ${home_dir}
else
# download the repository
  command curl -Ss -L https://raw.githubusercontent.com/agkozak/zcomet/master/zcomet.zsh \
    > ${home_dir}/zcomet.zsh
fi

# add modules to .zshrc
print 'source ${HOME}/zcomet.zsh
zcomet snippet https://github.com/zimfw/environment/blob/master/init.zsh
zcomet load zimfw/git
zcomet snippet https://github.com/zimfw/input/blob/master/init.zsh
zcomet snippet https://github.com/zimfw/termtitle/blob/master/init.zsh
zcomet load zimfw/utility
zcomet fpath zimfw/git-info functions
zcomet snippet https://github.com/zimfw/asciiship/blob/master/asciiship.zsh-theme
zcomet fpath zsh-users/zsh-completions src
zcomet load zsh-users/zsh-autosuggestions
zcomet load zsh-users/zsh-syntax-highlighting
zcomet snippet https://github.com/zsh-users/zsh-history-substring-search/blob/master/zsh-history-substring-search.zsh
# zcomet adds functions to fpath but does not autoload them!
autoload -Uz git-alias-lookup \\
         git-branch-current \\
         git-branch-delete-interactive \\
         git-dir \\
         git-ignore-add \\
         git-root \\
         git-stash-clear-interactive \\
         git-stash-recover \\
         git-submodule-move \\
         git-submodule-remove \\
         mkcd \\
         mkpw \\
         duration-info-precmd \\
         duration-info-prexec \\
         coalesce \\
         git-action \\
         git-info
[[ $TERM != dumb ]] && () {
  [[ -f ${HOME}/.zcompdump_${ZSH_VERSION} ]] &&
    zcomet compile ${HOME}/.zcompdump_${ZSH_VERSION}
  autoload -Uz compinit; compinit -C -d ${HOME}/.zcompdump_${ZSH_VERSION}
}

bindkey "^[[A" history-substring-search-up
bindkey "^[[B" history-substring-search-down
' >>! ${home_dir}/.zshrc

} "${@}"
