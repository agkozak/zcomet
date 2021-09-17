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

# Add zcomet functions to FPATH and autoload
fpath=( "${ZCOMET[SCRIPT]:A:h}/functions" "${fpath[@]}" )
autoload -Uz zcomet_{unload,update,list,self-update,help}

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
    if [[ -s $1 &&
          ( ! -s ${1}.zwc || $1 -nt ${1}.zwc ) &&
          $1 != */test-data/* ]]; then
      # Autoloadable functions
      if [[ $1 == ${ZCOMET[SCRIPT]:A:h}/functions/zcomet_* ||
            $1 == prompt_*_setup ]]; then
        zcompile -Uz "$1"
      # Scripts to be sourced
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
# The `load' command
#
# Clones a repo (if necessary). Sources init file(s) or adds
# one of its directories to FPATH or both.
#
# Arguments:
#   The repo      A GitHub repository, in the format
#                 user/repo@branch, where @branch could also
#                 be a tag or a commit.
#   Subdirectory  [Optional] A subdirectory of a larger repo
#   Script(s)     [Optional] A list of specific scripts to
#                 source
# Outputs:
#   Confirmation and error messages, plus raw Git output
#   (for the time being)
############################################################
_zcomet_load_command() {
  if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; then
    >&2 print 'You need to specify a valid repository.' && return 1
  fi

  local repo_branch
  repo_branch=$1
  shift

  _zcomet_clone_repo "$repo_branch" || return $?
  _zcomet_load "${repo_branch%@*}" "$@"
}

############################################################
# The `fpath' command
#
# Clones a repo (if necessary). Adds one of its
# subdirectories to FPATH. This command does not try to
# guess which directory to add; it must be made explicit.
#
# Arguments:
#   The repo       A Git repository
#                  (username/repo@branch/tag/commit), as
#                  with `load'.
#   A subdirectory [Optional] A subdirectory within the
#                  repo to add to FPATH
# Output:
#   Raw Git output and error messages
############################################################
_zcomet_fpath_command() {
  if [[ $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; then
    >&2 print 'You need to specify a valid repository.' && return 1
  fi

  local repo_branch
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
}

############################################################
# The `snippet' command
#
# Downloads a script (if it has not already been
# downloaded) using either curl or wget. Sources it. This
# command understands how to translate normative Github URLs
# into raw code (and includes the OMZ:: shorthand for
# Oh-My-Zsh scripts); otherwise you must make sure that the
# snippet you direct it to is genuinely Zsh code and not a
# pretty HTML representation of it.
#
# Arguments:
#   --update  The script is being updated; don't source it
#             for now
#   $1        The snippet
# Outputs:
#   Informative messages, raw curl or wget output, error
#   messages
############################################################
_zcomet_snippet_command() {
  [[ -z $1 ]] && print 'You need to specify a snippet.' && return 1

  local update snippet url method snippet_file snippet_dir

  [[ $1 == '--update' ]] && update=1 && shift
  snippet=$1 && shift

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
}

############################################################
# The `trigger' command - lazy-loading plugins
#
# This command creates one or more functions that will, at
# some point in the future, `load` a plugin and the run a
# command from that plugin. When any of the triggers that
# have been defined is pulled, all of the triggers for that
# plugin are unfunctioned to make way for their namesake
# commands. By putting off loading a plugin until it is
# is needed, precious shell startup time can be conserved.
#
# Arguments:
#   Trigger(s)  Commands that will load a plugin and then
#               run plugin commands of the same name
#   Repo        A GitHub repository; uses the same format
#               as `load` and `fpath`
#
# TODO: Add some way to pre-clone repos to be triggered in
# the future so that the cloning process doesn't slow the
# user down.
############################################################
_zcomet_trigger_command() {
  [[ -z $1 ]] && >&2 print 'You need to name a trigger.' && return 1

  local -Ua triggers
  local trigger

  while [[ -n $1 && $1 != ?*/?* && $1 != 'ohmyzsh' && $1 != 'prezto' ]]; do
    triggers+=( "$1" )
    shift
  done

  _zcomet_clone_repo "$@"

  for trigger in "${triggers[@]}"; do
    functions[$trigger]="local i;
      for trigger in ${triggers[@]};
      do
        ZCOMET_TRIGGERS=( "\${ZCOMET_TRIGGERS[@]:#\${trigger}}" );
      done
      unfunction ${triggers[@]};
      zcomet load $@;
      eval $trigger \$@" && _zcomet_add_list "$cmd" "$trigger"
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
#   compinit
#   help
# Outputs:
#   Status updates
############################################################
zcomet() {
  local MATCH REPLY; integer MBEGIN MEND
  local -a match mbegin mend reply

  typeset -gUa zsh_loaded_plugins ZCOMET_FPATH ZCOMET_SNIPPETS ZCOMET_TRIGGERS

  local cmd
  [[ -n $1 ]] && cmd=$1 && shift

  case $cmd in
    load|fpath|snippet|trigger)
      _zcomet_${cmd}_command "$@"
      ;;
    unload|update|list|self-update) zcomet_$cmd "$@" ;;
    compinit)
      autoload -Uz compinit

      if compinit -C -d "${ZDOTDIR:-${HOME}}/.zcompdump_${ZSH_VERSION}"; then
        # If the dumpfile does not contain the _zcomet completion function, it
        # needs to be deleted and regenerated
        if (( ! ${+functions[_zcomet]} )) &&
           [[ -f ${ZCOMET[SCRIPT]:A:h}/functions/_zcomet ]]; then
          >&2 print "Regenerating ${_comp_dumpfile}"
          command rm -f "${_comp_dumpfile}"*
          compinit -C -d "${_comp_dumpfile}"
        else
          _zcomet_compile "$_comp_dumpfile"
        fi
      else
        >&2 print "Could not load Zsh completions."
      fi
      ;;
    compile)
      if [[ -z $1 ]]; then
        >&2 print 'Which script(s) would you like to zcompile?'
        return 1
      fi
      _zcomet_compile "$@"
      ;;
    -h|--help|help) zcomet_help ;;
    *)
      zcomet_help
      return 1
      ;;
  esac
}

() {
  setopt LOCAL_OPTIONS EXTENDED_GLOB

  _zcomet_compile "${ZCOMET[SCRIPT]}" \
                  "${ZCOMET[SCRIPT]:A:h}"/functions/zcomet_*~*.zwc(N.) \
                  "${ZDOTDIR:-${HOME}}"/.z(shenv|profile|shrc|login|logout)(N.)
}
