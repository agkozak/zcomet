# zcomet Zsh Plugin Manager
#
# https://github.com/agkozak/zcomet
#
# MIT License / Copyright (c) 2021 Alexandros Kozak

typeset -A ZCOMET

# Standardized $0 Handling
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#zero-handling
0=${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}
0=${${(M)0:#/*}:-${PWD}/$0}

ZCOMET[SCRIPT]=$0

# Add zcomet completions to FPATH
fpath=( "${ZCOMET[SCRIPT]:A:h}" "${fpath[@]}" )

# Allow the user to specify custom directories
ZCOMET[HOME_DIR]=${ZCOMET[HOME_DIR]:-${HOME}/.zcomet}
ZCOMET[REPOS_DIR]=${ZCOMET[REPOS_DIR]:-${ZCOMET[HOME_DIR]}/repos}
ZCOMET[SNIPPETS_DIR]=${ZCOMET[SNIPPETS_DIR]:-${ZCOMET[HOME_DIR]}/snippets}

# Global parameter with PREFIX for make, configure, etc.
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#8-global-parameter-with-prefix-for-make-configure-etc
typeset -gx ZPFX
: ${ZPFX:=${ZCOMET[HOME_DIR]}/polaris}
[[ -z ${path[(re)${ZPFX}/bin]} ]]  &&
  [[ -d "${ZPFX}/bin" ]]           &&
  path=( "${ZPFX}/bin" "${path[@]}" )
[[ -z ${path[(re)${ZPFX}/sbin]} ]] &&
  [[ -d "${ZPFX}/sbin" ]]          &&
  path=( "${ZPFX}/sbin" "${path[@]}" )

# Global Parameter holding the plugin-manager’s capabilities
# https://github.com/zdharma/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#9-global-parameter-holding-the-plugin-managers-capabilities
typeset -g PMSPEC
PMSPEC='0fuiPs'

############################################################
# Compile scripts to wordcode or recompile them when they
# have changed.
# Arguments:
#   Files to compile or recompile
#
# Adapted from Zim's old zcompare function. Still appears to
# be faster than using zrecompile.
############################################################
_zcomet_compile() {
  while (( $# )); do
    if [[ -s $1                                &&
          ( ! -s ${1}.zwc || $1 -nt ${1}.zwc ) &&
          # Don't compile zsh-syntax-highlighting's test data
          $1 != */test-data/* ]]; then
      zcompile "$1"
    fi
    shift
  done
}

###########################################################
# Allow the user to employ the shorthand `ohmyzsh' for the
# ohmyzsh/ohmyzsh repo and `prezto' for
# sorin-ionescu/prezto
###########################################################
_zcomet_repo_shorthand() {
  emulate -L zsh
  setopt EXTENDED_GLOB WARN_CREATE_GLOBAL TYPESET_SILENT
  setopt NO_SHORT_LOOPS RC_QUOTES NO_AUTO_PUSHD

  if [[ $1 == 'ohmyzsh' ]]; then
    REPLY='ohmyzsh/ohmyzsh'
  elif [[ $1 == 'prezto' ]]; then
    REPLY='sorin-ionescu/prezto'
  else
    REPLY=$1
  fi
}

##########################################################
# This function loads plugins that have already been
# cloned. Loading consists of sourcing a main file or
# adding the root directory or a /functions/ subdirectory
# to FPATH or both.
# Globals:
#   ZCOMET
# Arguments:
#   A repo
#   A subdirectory [Optional]
#   A specific file to be sourced [Optional]
# Returns:
#   0 if a file is successfully sourced or an element is
#     added to FPATH; otherwise 1
# Outputs:
#   Error messages
##########################################################
_zcomet_load() {
  typeset repo subdir file plugin_path plugin_name plugin_loaded
  typeset -a files
  repo=$1
  _zcomet_repo_shorthand $repo
  repo=$REPLY
  shift
  if [[ -n $1 && -f ${ZCOMET[REPOS_DIR]}/${repo}/$1 ]]; then
    files=( "$@" )
  else
    (( ${+1} )) && subdir=$1 && shift
    (( $# )) && files=( "$@" )
  fi
  plugin_path=${ZCOMET[REPOS_DIR]}/${repo}${subdir:+/${subdir}}

  if (( ${#files} )); then
    for file in "${files[@]}"; do
      if source "${plugin_path}/${file}"; then
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}${file:+ ${file}}" &&
        plugin_loaded=1
      else
        return $?
      fi
    done
  else
    plugin_name=${${subdir:+${subdir##*/}}:-${repo##*/}}
    files=(
            "${plugin_path}/prompt_${plugin_name}_setup"(N.)
            "${plugin_path}/${plugin_name}.zsh-theme"(N.)
            "${plugin_path}/${plugin_name}.plugin.zsh"(N.)
            "${plugin_path}/${plugin_name}.zsh"(N.)
          )
    if ! (( ${#files} )); then
      files+=(
               "${plugin_path}"/*.zsh-theme(N.)
               "${plugin_path}"/*.plugin.zsh(N.)
               "${plugin_path}"/init.zsh(N.)
               "${plugin_path}"/*.zsh(N.)
               "${plugin_path}"/*.sh(N.)
             )
    fi
    file=${files[@]:0:1}

    if [[ -n $file ]]; then
      if source "$file"; then
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}" && plugin_loaded=1
      else
        >&2 print "Cannot source ${file}." && return 1
      fi
    fi
  fi

  if [[ -d ${plugin_path}/functions ]]; then
    if (( ! ${fpath[(Ie)${plugin_path}]} )); then
      fpath=( "${plugin_path}/functions" "${fpath[@]}" )
      if (( ! plugin_loaded )); then
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}"
      fi
    fi
  elif [[ -d ${plugin_path} ]]; then
    if (( ! ${fpath[(Ie)${plugin_path}]} )); then
      fpath=( "${plugin_path}" "${fpath[@]}" )
      if (( ! plugin_loaded )); then
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}"
      fi
    fi
  else
    >&2 print "Cannot add ${plugin_path} or ${plugin_path}/functions to FPATH." &&
      return 1
  fi
}

##########################################################
# Manage the arrays used when running `zcomet list'
# Globals:
#   zsh_loaded_plugins
#   ZCOMET_SNIPPETS
#   ZCOMET_TRIGGERS
# Arguments:
#   $1 The command being run (load/snippet/trigger)
#   $2 Repository and optional subpackage, e.g.,
#     themes/robbyrussell
##########################################################
_zcomet_add_list() {
  emulate -L zsh
  setopt EXTENDED_GLOB WARN_CREATE_GLOBAL TYPESET_SILENT
  setopt NO_SHORT_LOOPS RC_QUOTES NO_AUTO_PUSHD

  2=${2% }
  if [[ $1 == 'load' ]]; then
    zsh_loaded_plugins+=( "$2" )
  elif [[ $1 == 'snippet' ]]; then
    ZCOMET_SNIPPETS+=( "$2" )
  elif [[ $1 == 'trigger' ]]; then
    ZCOMET_TRIGGERS+=( "$2" )
  fi
}

##########################################################
# Clone a repository, switch to a branch/tag/commit if
# requested, and compile the scripts
# Globals:
#   ZCOMET
# Arguments:
#   $1 The repository and branch/tag/commit
#
# TODO: At present, this function will compile every
# script in ohmyzsh/ohmyzsh! Rein it in.
##########################################################
_zcomet_clone_repo() {
  setopt LOCAL_OPTIONS NO_KSH_ARRAYS NO_SH_WORD_SPLIT

  [[ -z $1 ]] && return 1
  local repo branch
  repo=${1%@*}
  [[ $1 == *@* ]] && branch=${1#*@}
  _zcomet_repo_shorthand "$repo"
  repo=$REPLY

  if [[ ! -d ${ZCOMET[REPOS_DIR]}/${repo} ]]; then
    print -P "%B%F{yellow}Cloning ${repo}:%f%b"
    command git clone "https://github.com/${repo}" \
      "${ZCOMET[REPOS_DIR]}/${repo}" || return $?
    if [[ -n $branch ]]; then
      command git --git-dir="${ZCOMET[REPOS_DIR]}/${repo}/.git" \
        --work-tree="${ZCOMET[REPOS_DIR]}/${repo}" checkout -q "$branch"
    fi
    local file
    for file in "${ZCOMET[REPOS_DIR]}/${repo}"/**/*.zsh(N.) \
                "${ZCOMET[REPOS_DIR]}/${repo}"/**/prompt_*_setup(N.) \
                "${ZCOMET[REPOS_DIR]}/${repo}"/**/*.zsh-theme(N.); do
      _zcomet_compile "$file"
    done
  fi
}

############################################################
# The main command
# Globals:
#   ZCOMET
#   zsh_loaded_plugins
#   ZCOMET_SNIPPETS
#   ZCOMET_TRIGGERS
# Arguments:
#   load <repo> [...]
#   trigger <trigger> <repo] [...]
#   snippet <snippet>
#   update
#   unload <repo>
#   list
#   compile
#   help
# Outputs:
#   Status updates
############################################################
zcomet() {
  local MATCH REPLY; integer MBEGIN MEND
  local -a match mbegin mend reply

  typeset -gUa zsh_loaded_plugins ZCOMET_SNIPPETS ZCOMET_TRIGGERS
  typeset -Ua triggers

  ##########################################################
  # THE MAIN ROUTINE
  ##########################################################

  local cmd update trigger snippet repo_branch
  [[ -n $1 ]] && cmd=$1 && shift

  case $cmd in
    load)
      if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]] then
        >&2 print 'You need to specify a valid repository.' && return 1
      fi
      repo_branch=$1 && shift
      _zcomet_clone_repo "$repo_branch" || return $?
      _zcomet_load "${repo_branch%@*}" "$@"
      ;;
    fpath)
      if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]] then
        >&2 print 'You need to specify a valid repository.' && return 1
      fi
      repo_branch=$1 && shift
      _zcomet_clone_repo "$repo_branch" || return $?
      _zcomet_repo_shorthand "${repo_branch%@*}"
      repo_branch=$REPLY
      [[ ! -d ${ZCOMET[REPOS_DIR]}/${repo_branch}${1:+/${1}} ]] &&
        local ret=$? && >&2 print 'Invalid directory.' && return $ret
      if (( ! ${fpath[(Ie)${ZCOMET[REPOS_DIR]}/${repo_branch}${1:+/${1}}]} )); then
        fpath=( "${ZCOMET[REPOS_DIR]}/${repo_branch}${1:+/${1}}" "${fpath[@]}" )
      fi
      ;; 
    snippet)
      [[ -z $1 ]] && print 'You need to specify a snippet.' && return 1
      [[ $1 == '--update' ]] && update=1 && shift
      snippet=$1 && shift
      local url
      url='https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/'
      if [[ ! -f ${ZCOMET[SNIPPETS_DIR]}/${snippet} ]] || (( update )); then
        if [[ ! -d ${ZCOMET[SNIPPETS_DIR]}/${snippet%/*} ]]; then
          mkdir -p "${ZCOMET[SNIPPETS_DIR]}/${snippet%/*}"
        fi
        print -P "%B%F{yellow}Downloading snippet ${snippet}:%f%b"
        if (( ${+commands[curl]} )); then
          curl "${url}${snippet#OMZ::}" > "${ZCOMET[SNIPPETS_DIR]}/${snippet}"
          ret=$?
        elif (( ${+commands[wget]} )); then
          wget -P "${ZCOMET[SNIPPETS_DIR]}/${snippet%/*}" \
            "${url}${snippet#OMZ::}"
          ret=$?
        else
          >&2 print "You need \`curl' to download snippets." && return 1
        fi
        (( ret == 0 )) && _zcomet_compile "${ZCOMET[SNIPPETS_DIR]}/${snippet}"
      fi
      (( update )) && return
      if source "${ZCOMET[SNIPPETS_DIR]}/${snippet}"; then
        _zcomet_add_list "$cmd" "$snippet"
      else
        >&2 print "Could not source snippet ${snippet}."
      fi
      ;;
    trigger)
      # TODO: Add a pre-clone option
      [[ -z $1 ]] && >&2 print 'You need to name a trigger.' && return 1
      while [[ -n $1 && $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; do
        triggers+=( "$1" )
        shift
      done
      for trigger in "${triggers[@]}"; do
        functions[$trigger]="ZCOMET_TRIGGERS=( "\${ZCOMET_TRIGGERS[@]:#${trigger}}" );
          unfunction $trigger;
          zcomet load $@;
          eval $trigger \$@" && _zcomet_add_list "$cmd" "$trigger"
      done
      ;;
    unload)
      # TODO: This routine is still rather primitive.
      [[ $1 != ?*/?* ]] &&
        >&2 print 'Specify a plugin to unload.' && return 1
      if (( ${+functions[${1#*/}_plugin_unload]} )) &&
         ${1#*/}_plugin_unload; then
        zsh_loaded_plugins=( "${zsh_loaded_plugins[@]:#${1}}" )
        zsh_loaded_plugins=( "${zsh_loaded_plugins[@]:#${1} *}" )
        fpath=( "${fpath[@]:#${ZCOMET[REPOS_DIR]}/${1}}" )
      else
        >&2 print 'I cannot find an unload function for that plugin.'
        return 1
      fi
      ;;
    update)
      local i
      for i in "${ZCOMET[REPOS_DIR]}"/**/.git(N/); do
        print -Pn "%B%F{yellow}${${i:h}#${ZCOMET[REPOS_DIR]}/}:%f%b "
        command git --git-dir="${i}" --work-tree="${i:h}" pull
        for file in "${i:h}"/*.zsh(N.) \
                    "${i:h}"/prompt_*_setup(N.) \
                    "${i:h}"/*.zsh_theme(N.); do
          _zcomet_compile "$file"
        done
        (( ${ZCOMET_PLUGINS[(Ie)$i]} )) && zcomet load "$i"
      done
      local -a snippets
      snippets=( "${ZCOMET[SNIPPETS_DIR]}"/**/*(N.) )
      for i in "${snippets[@]}"; do
        if [[ $i != *.zwc ]]; then
          print -P "%B%F{yellow}${i#${ZCOMET[SNIPPETS_DIR]}/}:%f%b"
          zcomet snippet --update "${i#${ZCOMET[SNIPPETS_DIR]}/}"
          _zcomet_compile "$i"
        fi
      done
      i=
      if (( ${#ZCOMET_SNIPPETS} )); then
        for i in "${ZCOMET_SNIPPETS[@]}"; do
          zcomet snippet "$i"
        done
      fi
      ;;
    list)
      (( ${#zsh_loaded_plugins} ))           &&
        print -P '%B%F{yellow}Plugins:%f%b'  &&
        print -l -f '  %s\n' "${(o)zsh_loaded_plugins[@]}"
      (( ${#ZCOMET_SNIPPETS} ))              &&
        print -P '%B%F{yellow}Snippets:%f%b' &&
        print -l -f '  %s\n' "${(o)ZCOMET_SNIPPETS[@]}"
      (( ${#ZCOMET_TRIGGERS} ))              &&
        print -P '%B%F{yellow}Triggers:%f%b' &&
        print "  ${(o)ZCOMET_TRIGGERS[@]}"
      ;;
    compile)
      if [[ -z $1 ]]; then
        >&2 print 'Which script(s) would you like to zcompile?'
        return 1
      fi
      _zcomet_compile "$@"
      ;;
    self-update)
      print -Pn '%B%F{yellow}zcomet:%f%b '
      if ! command git --git-dir="${${ZCOMET[SCRIPT]}:A:h}/.git" \
        --work-tree="${ZCOMET[SCRIPT]:A:h}" pull &&
        source "${ZCOMET[SCRIPT]}"; then
        >&2 print 'Could not self-update.'
        return 1
      fi
      ;;
    -h|--help|help)
      print "usage: $0 command [...]

load            clone and load a plugin
fpath           clone a plugin and add one of its directories to FPATH
trigger         create a shortcut for loading and running a plugin
snippet         load a snippet of code from Oh-My-ZSH
unload          unload a plugin
update          update all plugins and snippets
list            list all loaded plugins and snippets
compile         (re)compile script(s) (only when necessary)
self-update     update zcomet itself
help            print this help text" | fold -s -w $COLUMNS
      ;;
    *) zcomet help; return 1 ;;
  esac
}

zcomet compile "${ZCOMET[SCRIPT]}"