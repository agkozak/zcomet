# zcomet Zsh Plugin Manager
#
# https://github.com/agkozak/zcomet
#
# MIT License / Copyright (c) 2021 Alexandros Kozak

typeset -gA ZCOMET

ZCOMET[SCRIPT]=$0

autoload -Uz is-at-least
if ! is-at-least 4.3.11; then
  zcomet() {
    >&2 print 'zcomet only supports Zsh v4.3.11+.'
    return 1
  }
  zcomet; return 1
fi

# Add zcomet functions to FPATH and autoload some things
fpath=( "${ZCOMET[SCRIPT]:A:h}/functions" "${fpath[@]}" )
autoload -Uz add-zsh-hook \
             zcomet_{unload,update,list,self-update,help}

# Global Parameter holding the plugin-manager’s capabilities
# https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#9-global-parameter-holding-the-plugin-managers-capabilities
typeset -g PMSPEC
PMSPEC='0fbuiPs'

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
    if [[ -s $1 && $1 != *.zwc &&
          ( ! -s ${1}.zwc || $1 -nt ${1}.zwc ) &&
          $1 != *.zwc &&
          $1 != */test-data/* ]]; then
      # Autoloadable functions
      if [[ $1 == ${ZCOMET[SCRIPT]:A:h}/functions/zcomet_* ||
            ${1:t} == prompt_*_setup ||
            ${1:t} == _* ]]; then
        builtin zcompile -Uz "$1"
      # Scripts to be sourced
      else
        builtin zcompile -R "$1"
      fi
    fi
    shift
  done
}

############################################################
# Allows the user to employ the shorthand `ohmyzsh' for the
# ohmyzsh/ohmyzsh repo and `prezto' for
# sorin-ionescu/prezto
# Globals:
#   REPLY
# Arguments:
#   $1 A repo or its shorthand
# Outputs:
#   The repo
############################################################
_zcomet_repo_shorthand() {
  if [[ $1 == 'ohmyzsh' ]]; then
    typeset -g REPLY='ohmyzsh/ohmyzsh'
  elif [[ $1 == 'prezto' ]]; then
    typeset -g REPLY='sorin-ionescu/prezto'
  else
    typeset -g REPLY=$1
  fi
}

############################################################
# Allows the user to use the shorthand OMZ:: for Oh-My-Zsh
# snippets or an https://github.com address that gets
# translated into https://raw.githubuser.com; otherwise, a
# simple URL of raw shell code.
# Globals:
#   REPLY
# Arguments:
#   $1 A URL to raw code, a normative github.com URL, or
#      shorthand
# Outputs:
#   A URL to raw code
############################################################
_zcomet_snippet_shorthand() {
  if [[ $1 == OMZ::* ]]; then
    typeset -g REPLY="https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/${1#OMZ::}"
  elif [[ $1 == https://github.com/* ]]; then
    typeset -g REPLY=${${1/github/raw.githubusercontent}/\/blob/}
  else
    typeset -g REPLY=$1
  fi
}

############################################################
# Captures `compdef' calls that will actually be run
# after `zcomet compinit' is run.
# Globals:
#   ZCOMET_COMPDEFS
############################################################
compdef() {
  setopt NO_WARN_NESTED_VAR 2> /dev/null

  typeset -gUa ZCOMET_COMPDEFS
  ZCOMET_COMPDEFS=( "${ZCOMET_COMPDEFS[@]}" "$*" )
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
  typeset repo base_path subdir file plugin_path plugin_name plugin_loaded
  typeset -a files
  _zcomet_repo_shorthand "$1"
  repo=$REPLY
  shift

  if [[ $repo == /* ]]; then
    base_path=$repo
  else
    base_path="${ZCOMET[REPOS_DIR]}/${repo}"
  fi

  if [[ -n $1 ]]; then
    if [[ -f ${base_path}/$1 ]]; then
      files=( "$@" )
      set --
    elif [[ -d ${base_path}/$1 ]]; then
      subdir=$1 && shift
      (( $# )) && files=( "$@" )
      set --
    else
      >&2 print "zcomet: ${repo}: invalid arguments." && return 1
    fi
  fi
  plugin_path=${base_path}${subdir:+/${subdir}}

  # Add repo dir or the functions/ subdirectory to FPATH
  local dir fpath_added prezto_style
  if [[ -d ${plugin_path}/functions ]]; then
    dir="${plugin_path}/functions"
    prezto_style=1
  elif [[ -d $plugin_path ]]; then
    dir=$plugin_path
  else
    >&2 print "zcomet: ${plugin_path} does not appear to be a directory."
    return 1
  fi

  if (( ! ${fpath[(Ie)${dir}]} )); then
    fpath=( "$dir" "${fpath[@]}" )
    if (( ! ${#files} )); then
      _zcomet_add_list load "${repo}${subdir:+ ${subdir}}" && fpath_added=1
    fi
  fi

  # Autoload prezto-style functions
  if (( prezto_style )); then
    () {
      setopt LOCAL_OPTIONS EXTENDED_GLOB

      local zfunction

      for zfunction in "${dir}"/^(*~|*.zwc(|.old)|_*|prompt_*_setup)(N-.:t); do
        autoload -Uz ${zfunction}
      done
    }
  fi

  if (( ${#files} )); then
    for file in "${files[@]}"; do
      if ZERO="${plugin_path}/${file}" source "${plugin_path}/${file}"; then
        (( ZCOMET[DEBUG] )) && >&2 print "Sourced ${file}."
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}${file:+ ${file}}" &&
        plugin_loaded=1
      else
        return $?
      fi
    done
  else
    plugin_name=${${subdir:+${subdir##*/}}:-${repo##*/}}
    files=(
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
      if ZERO=$file source "$file"; then
        (( ZCOMET[DEBUG] )) && >&2 print "Sourced ${file:t}."
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}" && plugin_loaded=1
      else
        >&2 print "Cannot source ${file}."
        return 1
      fi
    fi
  fi

  # Add the bin/ subdirectory, if it exists, to PATH
  if [[ -d ${base_path}/bin ]]; then
    if (( ! ${path[(Ie)${base_path}/bin]} )); then
      path=( "${base_path}/bin" "${path[@]}" )
      (( ! plugin_added  && ! fpath_added )) &&
        _zcomet_add_list load "${repo}${subdir:+ ${subdir}}"
    fi
  fi
}

############################################################
# Manage the arrays used when running `zcomet list'
# Globals:
#   zsh_loaded_plugins
#   ZCOMET_FPATH
#   ZCOMET_SNIPPETS
#   ZCOMET_TRIGGERS
# Arguments:
#   $1 The command being run (load/snippet/trigger)
#   $2 Repository and optional subpackage, e.g.,
#     ohmyzsh/ohmyzsh plugins/extract
############################################################
_zcomet_add_list() {
  setopt NO_WARN_NESTED_VAR 2> /dev/null

  if [[ $1 == 'load' ]]; then
    zsh_loaded_plugins=( "${zsh_loaded_plugins[@]}" "$2" )
  elif [[ $1 == 'fpath' ]]; then
    ZCOMET_FPATH=( "${ZCOMET_FPATH[@]}" "$2" )
  elif [[ $1 == 'snippet' ]]; then
    ZCOMET_SNIPPETS=( "${ZCOMET_SNIPPETS[@]}" "$2" )
  elif [[ $1 == 'trigger' ]]; then
    ZCOMET_TRIGGERS=( "${ZCOMET_TRIGGERS[@]}" "$2" )
  fi
}

############################################################
# Checks to make sure that the user has provided a valid
# plugin name
#
# Arguments:
#   The supposed plugin
############################################################
_zcomet_is_valid_plugin() {
  [[ $1 == ?*/?*     ||
     $1 == 'ohmyzsh' ||
     $1 == 'prezto'  ||
     $1 == /* ]]
}

############################################################
# Clone a repository, switch to a branch/tag/commit if
# requested, and compile the scripts
# Globals:
#   ZCOMET
# Arguments:
#   --no-submodules [Optional] Do not clone submodules
#                   The repository and branch/tag/commit
############################################################
_zcomet_clone_repo() {
  local clone_options
  if [[ $1 != '--no-submodules' ]]; then
    clone_options='--recursive'
  else
    shift
  fi

  [[ $1 == ?*/?* || $1 == 'ohmyzsh' || $1 == 'prezto' ]] || return 1
  local repo branch repo_dir ret file
  _zcomet_repo_shorthand "${1%@*}"
  repo=$REPLY
  repo_dir="${ZCOMET[REPOS_DIR]}/${repo}"
  [[ $1 == *@* ]] && branch=${1#*@}

  [[ -d $repo_dir ]] && return

  print -P "%B%F{yellow}Cloning ${repo}:%f%b"
  if ! command git clone ${clone_options} "https://github.com/${repo}" "$repo_dir"; then
    ret=$?
    >&2 print "Could not clone repository ${repo}."
    return $ret
  fi
  if [[ -n $branch ]] && ! command git --git-dir="${repo_dir}/.git" \
      --work-tree=$repo_dir checkout -q "$branch"; then
    ret=$?
    >&2 print "Could not checkout \`${branch}'."
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
#   --no-submodules [Optional] Do not clone submodules
#   The repo        A GitHub repository, in the format
#                   user/repo@branch, where @branch could
#                   also be a tag or a commit.
#   Subdirectory    [Optional] A subdirectory of a larger
#                   repo
#   Script(s)       [Optional] A list of specific scripts to
#                   source
# Outputs:
#   Confirmation and error messages, plus raw Git output
#   (for the time being)
############################################################
_zcomet_load_command() {
  local clone_options
  [[ $1 == '--no-submodules' ]] && clone_options=$1 && shift

  if ! _zcomet_is_valid_plugin "$1"; then
    >&2 print 'You need to specify a valid plugin name.' && return 1
  fi

  local repo_branch
  repo_branch=$1
  shift

  # Don't try to clone local plugins
  if [[ $repo_branch != /* ]]; then
    _zcomet_clone_repo ${clone_options} "$repo_branch" || return $?
  # Do keep local plugins zcompiled
  else
    for file in "${repo_branch}"/**/*.zsh(|-theme)(N.) \
                "${repo_branch}"/**/prompt_*_setup(N.); do
      _zcomet_compile "$file"
    done
  fi
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
#   --no-submodules  Do not clone submodules
#   The repo         A Git repository
#                    (username/repo@branch/tag/commit), as
#                    with `load'.
#   A subdirectory   [Optional] A subdirectory within the
#                    repo to add to FPATH
# Output:
#   Raw Git output and error messages
############################################################
_zcomet_fpath_command() {
  local clone_options
  [[ $1 == '--no-submodules' ]] && clone_options=$1 && shift

  if ! _zcomet_is_valid_plugin "$1"; then
    >&2 print 'You need to specify a valid plugin name.' && return 1
  fi

  local repo_branch plugin_path
  repo_branch=$1 && shift

  # Don't clone local plugins
  if [[ $repo_branch != /* ]]; then
    _zcomet_clone_repo ${clone_options} "$repo_branch" || return $?
  fi

  _zcomet_repo_shorthand "${repo_branch%@*}"
  repo_branch=$REPLY

  if [[ $repo_branch == /* ]]; then
    plugin_path="${repo_branch}${1:+/${1}}"
  else
    plugin_path="${ZCOMET[REPOS_DIR]}/${repo_branch}${1:+/${1}}"
  fi

  [[ ! -d $plugin_path ]] && local ret=$? && >&2 print 'Invalid directory.' &&
    return $ret
  if (( ! ${fpath[(Ie)${plugin_path}]} )); then
    fpath=( "${plugin_path}" "${fpath[@]}" )
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

  local update snippet url method snippet_file snippet_dir ret

  [[ $1 == '--update' ]] && update=1 && shift
  snippet=$1 && shift

  # Local snippets
  if [[ $snippet != http(|s)://* && $snippet != OMZ::* ]]; then
    snippet=${snippet/\~/${HOME}}
    _zcomet_compile "$snippet"
    if [[ -f $snippet ]] && ZERO=$snippet source $snippet; then
      _zcomet_add_list "$cmd" "${${snippet:a}/${HOME}/~}"
      return
    fi
    >&2 print "Could not source snippet ${snippet}."
    return 1
  fi

  # Remote snippets
  _zcomet_snippet_shorthand "$snippet"
  url=$REPLY
  snippet_file=${snippet##*/}
  snippet_dir=${snippet%/*}
  snippet_dir=${snippet_dir/:\//}

  if [[ ! -f ${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file} ]] ||
     (( update )); then
    if [[ ! -d /tmp/${snippet_dir} ]]; then
      command mkdir -p "/tmp/${snippet_dir}"
    fi
    print -P "%B%F{yellow}Downloading snippet ${snippet}:%f%b"
    if (( ${+commands[curl]} )); then
      method='curl'
      curl "$url" > "/tmp/${snippet_dir}/${snippet_file}"
      ret=$?
    elif (( ${+commands[wget]} )); then
      method='wget'
      wget "$url" -O "/tmp/${snippet_dir}/${snippet_file}"
      ret=$?
    else
      >&2 print "You need \`curl' or \`wget' to download snippets."
      return 1
    fi
    if (( ret == 0 )); then
      [[ ! -d ${ZCOMET[SNIPPETS_DIR]}/${snippet_dir} ]] &&
        command mkdir -p "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}"
      command mv "/tmp/${snippet_dir}/${snippet_file}" \
        "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}" &&
        _zcomet_compile \
          "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file}"
    else
      >&2 print "Could not ${method} snippet ${snippet}."
    fi
  fi

  (( update )) && return

  if ZERO="${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file}" \
      source "${ZCOMET[SNIPPETS_DIR]}/${snippet_dir}/${snippet_file}"; then
    _zcomet_add_list "$cmd" "$snippet"
  else
    ret=$?
    >&2 print "Could not source snippet ${snippet}."
    return $ret
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
#   --no-submodules [Optional] Do not clone submodules
#   Trigger(s)      Commands that will load a plugin and
#                   then run plugin commands of the same
#                   name
#   Repo            A GitHub repository; uses the same
#                   format as `load` and `fpath`
#
# TODO: Add some way to pre-clone repos to be triggered in
# the future so that the cloning process doesn't slow the
# user down.
############################################################
_zcomet_trigger_command() {
  local clone_options
  [[ $1 == '--no-submodules' ]] && clone_options=$1 && shift

  [[ -z $1 ]] && >&2 print 'You need to name a trigger.' && return 1

  local -Ua triggers
  local trigger

  while [[ -n $1 ]] && ! _zcomet_is_valid_plugin "$1"; do
    triggers+=( "$1" )
    shift
  done

  # Don't clone local plugins
  # TODO: Check to make sure local plugins exist?
  if [[ $1 != /* ]]; then
    _zcomet_clone_repo ${clone_options} "$@"
  fi

  for trigger in "${triggers[@]}"; do
    functions[$trigger]="local trigger;
      for trigger in ${triggers[@]};
      do
        ZCOMET_TRIGGERS=( "\${ZCOMET_TRIGGERS[@]:#\${trigger}}" );
      done
      unfunction ${triggers[@]};
      zcomet load $clone_options $@;
      eval $trigger \$@" && _zcomet_add_list "$cmd" "$trigger"
  done

  _zcomet_repo_shorthand $1
  1=$REPLY

  local base_dir
  if [[ $1 == /* ]]; then
    base_dir=$1
  else
    base_dir="${ZCOMET[REPOS_DIR]}/${1%@*}"
  fi
}

############################################################
# The main command
# Globals:
#   ZCOMET
#   zsh_loaded_plugins
#   ZCOMET_SNIPPETS
#   ZCOMET_TRIGGERS
#   ZCOMET_NAMED_DIRS
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
  typeset -gUa zsh_loaded_plugins ZCOMET_FPATH ZCOMET_SNIPPETS ZCOMET_TRIGGERS

  typeset -g REPLY

  # Allow the user to specify custom directories
  local home_dir repos_dir snippets_dir

  # E.g., zstyle ':zcomet:*' home-dir ~/.my_dir
  if zstyle -s :zcomet: home-dir home_dir; then
    ZCOMET[HOME_DIR]=$home_dir
  else
    : ${ZCOMET[HOME_DIR]:=${ZDOTDIR:-${HOME}}/.zcomet}
  fi

  if zstyle -s :zcomet: repos-dir repos_dir; then
    ZCOMET[REPOS_DIR]=$repos_dir
  else
    : ${ZCOMET[REPOS_DIR]:=${ZCOMET[HOME_DIR]}/repos}
  fi

  if zstyle -s :zcomet: snippets-dir snippets_dir; then
    ZCOMET[SNIPPETS_DIR]=$snippets_dir
  else
    : ${ZCOMET[SNIPPETS_DIR]:=${ZCOMET[HOME_DIR]}/snippets}
  fi

  # Global parameter with PREFIX for make, configure, etc.
  # https://github.com/agkozak/Zsh-100-Commits-Club/blob/master/Zsh-Plugin-Standard.adoc#8-global-parameter-with-prefix-for-make-configure-etc
  [[ -z $ZPFX ]] && {
    typeset -gx ZPFX
    : ${ZPFX:=${ZCOMET[HOME_DIR]}/polaris}
    [[ -z ${path[(re)${ZPFX}/bin]} ]]  &&
      [[ -d "${ZPFX}/bin" ]]           &&
      path=( "${ZPFX}/bin" "${path[@]}" )
    [[ -z ${path[(re)${ZPFX}/sbin]} ]] &&
      [[ -d "${ZPFX}/sbin" ]]          &&
      path=( "${ZPFX}/sbin" "${path[@]}" )
  }

  local cmd
  [[ -n $1 ]] && cmd=$1 && shift

  case $cmd in
    load|fpath|snippet|trigger)
      _zcomet_${cmd}_command "$@"
      ;;
    unload|update|list|self-update) zcomet_$cmd "$@" ;;
    compinit)
      autoload -Uz compinit

      if [[ $TERM != 'dumb' ]]; then 
        () {
          setopt LOCAL_OPTIONS EQUALS EXTENDED_GLOB

          local dump_file
          zstyle -s ':zcomet:compinit' dump-file dump_file
          if [[ -n $dump_file ]]; then
            typeset -g _comp_dumpfile=$dump_file
          else
            typeset -g _comp_dumpfile="${ZDOTDIR:-${HOME}}/.zcompdump_${EUID}_${OSTYPE}_${ZSH_VERSION}"
          fi

          local -a compinit_opts
          zstyle -a ':zcomet:compinit' arguments compinit_opts
          compinit -d "$_comp_dumpfile" ${compinit_opts[@]}

          # Run compdef calls that were deferred earlier
          local def
          for def in "${ZCOMET_COMPDEFS[@]}"; do
            [[ -n $def ]] && compdef ${=def}
          done
          (( ${+ZCOMET_COMPDEFS} )) && unset ZCOMET_COMPDEFS

          # Compile the dumpfile
          ( _zcomet_compile "$_comp_dumpfile" ) &!
        }
      fi
      ;;
    compile)
      if [[ -z $1 ]]; then
        >&2 print 'Which script(s) would you like to zcompile?'
        return 1
      fi
      _zcomet_compile "$@"
      ;;
    -h|--help|help) zcomet_help "$@" ;;
    *)
      zcomet_help
      return 1
      ;;
  esac
}

() {
  setopt LOCAL_OPTIONS EXTENDED_GLOB

  _zcomet_compile "${ZCOMET[SCRIPT]}" \
                  "${ZCOMET[SCRIPT]:A:h}"/functions/zcomet_*~*.zwc(N.)
}

############################################################
# zcomet's plugin directories are dynamic named
# directories - an idea inspired by Marlon Richert's Znap.
#
# Note that if two repos of the same name appear under the
# ${ZCOMET[REPOS_DIR]} directory, neither will be assigned a
# name -- the idea being to prevent terrible mistakes.
############################################################
_zcomet_named_dirs() {
  emulate -L zsh

  typeset -ga reply
  local -a dirs names
  local expl

  if [[ $1 == 'n' ]]; then
    [[ $2 == 'zcomet-bin' ]] && reply=( ${ZCOMET[SCRIPT]:A:h} ) && return 0
    dirs=( ${ZCOMET[REPOS_DIR]}/*/$2(N/) )
    (( ${#dirs} != 1 )) && return 1
    reply=( ${dirs[1]} ) && return 0
  elif [[ $1 == 'd' ]]; then
    if [[ $2 == ${ZCOMET[SCRIPT]:A:h} ]]; then
      reply=( 'zcomet-bin' ${#2} )
      return 0
    elif [[ ${${2:h}:h} == ${ZCOMET[REPOS_DIR]} ]]; then
      dirs=( ${ZCOMET[REPOS_DIR]}/*/${2:t}(N/) )
      (( ${#dirs} != 1 )) && return 1
      reply=( ${2:t} ${#2} )
      return 0
    fi
    return 1
  elif [[ $1 == 'c' ]]; then
    dirs=( ${ZCOMET[REPOS_DIR]}/*/*(N/) )
    names=( ${dirs:t} )
    local -A names_tally
    local name
    for name in $names; do
      (( names_tally[$name]++ ))
    done
    name=''
    names=()
    for name in ${(k)names_tally}; do
      (( names_tally[$name] == 1 )) && names+=( $name )
    done
    _tags named-directories
    _tags && _requested named-directories expl 'dynamic named directories' &&
      compadd $expl -S\] -- $names 'zcomet-bin'
    return 1
  fi
}

# The zsh_directory_name hook did not appear till Zsh v4.3.12, so for v4.3.11
# we'll just have to use the zsh_directory_name function directly
if is-at-least 4.3.12; then
  add-zsh-hook zsh_directory_name _zcomet_named_dirs
else
  zsh_directory_name() {
    _zcomet_named_dirs $@
  }
fi
