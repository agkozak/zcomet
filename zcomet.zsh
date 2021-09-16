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
if [[ -z ${ZINIT[HOME_DIR]} ]]; then
  # Use ~/.zcomet, if it already exists
  if [[ -d ${HOME}/.zcomet ]]; then
    ZCOMET[HOME_DIR]="${HOME}/.zcomet"
  # Otherwise respect ZDOTDIR
  else
    : ${ZCOMET[HOME_DIR]:=${ZDOTDIR:-${HOME}}/.zcomet}
  fi
fi

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
    # Only zcompile if there isn't already a .zwc file or the .zwc is outdated,
    # and never compile zsh-syntax-highlighting's test data
    if [[ -s $1                                &&
          ( ! -s ${1}.zwc || $1 -nt ${1}.zwc ) &&
          $1 != */test-data/* ]]; then
      # prompt_*_setup files are autoloadable functions
      if [[ $1 == prompt_*_setup ]]; then
        zcompile -Uz "$1"
      else
        zcompile -UzR "$1"
      fi
    fi
    shift
  done
}

############################################################
# Allows the user to employ the shorthand `ohmyzsh' for the
# ohmyzsh/ohmyzsh repo and `prezto' for
# sorin-ionescu/prezto
# Arguments:
#   $1 A repo or its shorthand
# Outputs:
#   The repo
############################################################
_zcomet_repo_shorthand() {
  if [[ $1 == 'ohmyzsh' ]]; then
    REPLY='ohmyzsh/ohmyzsh'
  elif [[ $1 == 'prezto' ]]; then
    REPLY='sorin-ionescu/prezto'
  else
    REPLY=$1
  fi
}

############################################################
# Allows the user to use the shorthand OMZ:: for Oh-My-Zsh
# snippets or an https://github.com address that gets
# translated into https://raw.githubuser.com; otherwise, a
# simple URL of raw shell code.
# Arguments:
#   $1 A URL to raw code, a normative github.com URL, or
#      shorthand
# Outputs:
#   A URL to raw code
############################################################
_zcomet_snippet_shorthand() {
  if [[ $1 == OMZ::* ]]; then
    REPLY="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/${1#OMZ::}"
  elif [[ $1 == https://github.com/* ]]; then
    REPLY=${${1/github/raw.githubusercontent}/\/blob/}
  else
    REPLY=$1
  fi
}

############################################################
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
############################################################
_zcomet_load() {
  typeset repo subdir file plugin_path plugin_name plugin_loaded
  typeset -a files
  _zcomet_repo_shorthand "$1"
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
        >&2 print "Cannot source ${file}."
        return 1
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
    >&2 print "Cannot add ${plugin_path} or ${plugin_path}/functions to FPATH."
    return 1
  fi
}

############################################################
# Manage the arrays used when running `zcomet list'
# Globals:
#   zsh_loaded_plugins
#   ZCOMET_SNIPPETS
#   ZCOMET_TRIGGERS
# Arguments:
#   $1 The command being run (load/snippet/trigger)
#   $2 Repository and optional subpackage, e.g.,
#     ohmyzsh/ohmyzsh plugins/extract
############################################################
_zcomet_add_list() {
  if [[ $1 == 'load' ]]; then
    zsh_loaded_plugins+=( "$2" )
  elif [[ $1 == 'fpath' ]]; then
    ZCOMET_FPATH+=( "$2" )
  elif [[ $1 == 'snippet' ]]; then
    ZCOMET_SNIPPETS+=( "$2" )
  elif [[ $1 == 'trigger' ]]; then
    ZCOMET_TRIGGERS+=( "$2" )
  fi
}

############################################################
# Clone a repository, switch to a branch/tag/commit if
# requested, and compile the scripts
# Globals:
#   ZCOMET
# Arguments:
#   $1 The repository and branch/tag/commit
#
# TODO: At present, this function will compile every
# script in ohmyzsh/ohmyzsh! Rein it in.
############################################################
_zcomet_clone_repo() {
  [[ $1 == ?*/?* || $1 == 'ohmyzsh' || $1 == 'prezto' ]] || return 1
  local repo branch repo_dir ret file
  _zcomet_repo_shorthand "${1%@*}"
  repo=$REPLY
  repo_dir="${ZCOMET[REPOS_DIR]}/${repo}"
  [[ $1 == *@* ]] && branch=${1#*@}

  [[ -d ${repo_dir} ]] && return

  print -P "%B%F{yellow}Cloning ${repo}:%f%b"
  if ! command git clone "https://github.com/${repo}" "${repo_dir}"; then
    ret=$?
    >&2 print "Could not clone repository ${repo}."
    return $ret
  fi
  if [[ -n $branch ]] && ! command git --git-dir="${repo_dir}/.git" \
    --work-tree="${repo_dir}" checkout -q "$branch"; then
    ret=$?
    >&2 print "Could not checkout branch ${branch}."
    return $ret
  fi
  for file in "${repo_dir}"/**/*.zsh(|-theme)(N.) \
              "${repo_dir}"/**/prompt_*_setup(N.); do
    _zcomet_compile "$file"
  done
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
#   fpath <repo> [...]
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

  typeset -gUa zsh_loaded_plugins ZCOMET_FPATH ZCOMET_SNIPPETS ZCOMET_TRIGGERS
  typeset -Ua triggers

  local cmd update trigger snippet repo_branch
  [[ -n $1 ]] && cmd=$1 && shift

  case $cmd in
    load)
      if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; then
        >&2 print 'You need to specify a valid repository.' && return 1
      fi
      repo_branch=$1 && shift
      _zcomet_clone_repo "$repo_branch" || return $?
      _zcomet_load "${repo_branch%@*}" "$@"
      ;;
    fpath)
      if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; then
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
        _zcomet_add_list "$cmd" "$repo_branch${@:+ $@}"
      fi
      ;; 
    snippet)
      [[ -z $1 ]] && print 'You need to specify a snippet.' && return 1
      [[ $1 == '--update' ]] && update=1 && shift
      snippet=$1 && shift
      local url method snippet_file snippet_dir
      _zcomet_snippet_shorthand "$snippet"
      url=$REPLY
      snippet_file=${snippet##*/}
      snippet_dir=${snippet%/*}
      snippet_dir=${snippet_dir/:\//}
      if [[ ! -f ${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file} ]] ||
         (( update )); then
        if [[ ! -d /tmp/${snippet_dir} ]]; then
          mkdir -p "/tmp/${snippet_dir}"
        fi
        print -P "%B%F{yellow}Downloading snippet ${snippet}:%f%b"
        if (( ${+commands[curl]} )); then
          method='curl'
          curl "${url}" > "/tmp/${snippet_dir}/${snippet_file}"
          ret=$?
        elif (( ${+commands[wget]} )); then
          method='wget'
          wget "${url}" \
               -O "/tmp/${snippet_dir}/${snippet_file}"
          ret=$?
        else
          >&2 print "You need \`curl' or \`wget' to download snippets."
          return 1
        fi
        if (( ret == 0 )); then
          [[ ! -d ${ZCOMET[SNIPPETS_DIR]}/${snippet_dir} ]] &&
            mkdir -p "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}"
          command mv "/tmp/${snippet_dir}/${snippet_file}" \
            "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}" &&
            _zcomet_compile \
              "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file}"
        else
          >&2 print "Could not ${method} snippet ${snippet}."
        fi
      fi
      (( update )) && return
      if source "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file}"; then
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
        functions[$trigger]="local i;
          for i in ${triggers[@]};
          do
            ZCOMET_TRIGGERS=( "\${ZCOMET_TRIGGERS[@]:#\${i}}" );
          done
          unfunction ${triggers[@]};
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
      local file
      for i in "${ZCOMET[REPOS_DIR]}"/**/.git(N/); do
        print -Pn "%B%F{yellow}${${i:h}#${ZCOMET[REPOS_DIR]}/}:%f%b "
        command git --git-dir="${i}" --work-tree="${i:h}" pull
        for file in "${i:h}"/**/*.zsh(|-theme)(N.) \
                    "${i:h}"/**/prompt_*_setup(N.); do
          _zcomet_compile "$file"
        done
        (( ${ZCOMET_PLUGINS[(Ie)$i]} )) && zcomet load "$i"
      done
      local -a snippets
      snippets=( "${ZCOMET[SNIPPETS_DIR]}"/**/*(N.) )
      for file in "${snippets[@]}"; do
        snippet=${file#${ZCOMET[SNIPPETS_DIR]}/}
        if [[ $snippet == *.zwc ]]; then
          continue
        elif [[ $snippet == OMZ::* ]]; then
          :
        elif [[ $snippet == https/* ]]; then
          snippet="https:/${snippet#https}"
        elif [[ $snippet == http/* ]]; then
          snippet="http:/${snippet#http}"
        else
          >&2 print "Snippet ${file} not supported."
        fi
        zcomet snippet --update "${snippet}"
        _zcomet_compile "$file"
      done
      i=
      if (( ${#ZCOMET_SNIPPETS} )); then
        for i in "${ZCOMET_SNIPPETS[@]}"; do
          zcomet snippet "$i"
        done
      fi
      ;;
    list)
      (( ${#zsh_loaded_plugins} )) &&
        print -P '%B%F{yellow}Plugins:%f%b' &&
        print -l -f '  %s\n' "${(o)zsh_loaded_plugins[@]}"
      (( ${#ZCOMET_FPATH} )) &&
        print -P '%B%F{yellow}FPATH elements:%f%b' &&
        print -l -f '  %s\n' "${(o)ZCOMET_FPATH[@]}"
      (( ${#ZCOMET_SNIPPETS} )) &&
        print -P '%B%F{yellow}Snippets:%f%b' &&
        print -l -f '  %s\n' "${(o)ZCOMET_SNIPPETS[@]}"
      (( ${#ZCOMET_TRIGGERS} )) &&
        print -P '%B%F{yellow}Triggers:%f%b' &&
        print "  ${(o)ZCOMET_TRIGGERS[@]}"
      ;;
    compinit)
      autoload -Uz compinit
      compinit -C -d "${HOME}/.zcompdump_${ZSH_VERSION}" &&
        _zcomet_compile "${HOME}/.zcompdump_${ZSH_VERSION}"
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

compile         (re)compile script(s) (only when necessary)
compinit        run compinit and compile its cache
fpath           clone a plugin and add one of its directories to FPATH
help            print this help text
list            list all loaded plugins and snippets
load            clone and load a plugin
self-update     update zcomet itself
snippet         load a snippet of code
trigger         create a shortcut for loading and running a plugin
unload          unload a plugin
update          update all plugins and snippets" | fold -s -w $COLUMNS
      ;;
    *)
      zcomet help
      return 1
      ;;
  esac
}

_zcomet_compile "${ZCOMET[SCRIPT]}" \
               "${ZDOTDIR:-${HOME}}"/.z(shenv|profile|shrc|login|logout)(N.)
