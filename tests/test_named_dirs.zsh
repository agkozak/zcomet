#!/usr/bin/env zsh
#
# Tests for zcomet's dynamic named directories (`~[name]`), implemented by
# _zcomet_named_dirs and wired up either as a zsh_directory_name hook (zsh
# >= 4.3.12) or as the zsh_directory_name function itself (zsh 4.3.11). The
# end-to-end `~[name]` test below therefore exercises whichever wiring the
# running zsh uses.

# Create a fake cloned repo <user>/<repo> under the temp REPOS_DIR.
_nd_make_repo() {  # $1 user  $2 repo
  command mkdir -p "${ZCOMET[REPOS_DIR]}/$1/$2"
}

# 'n' (name -> directory): a uniquely-named repo resolves to its path.
test_named_dir_name_to_dir() {
  zc_reset
  _nd_make_repo testuser myrepo
  _zcomet_named_dirs n myrepo
  assert_eq "${reply[1]}" "${ZCOMET[REPOS_DIR]}/testuser/myrepo"
}

# 'n': the reserved name zcomet-bin resolves to the directory of zcomet.zsh.
test_named_dir_name_zcomet_bin() {
  zc_reset
  _zcomet_named_dirs n zcomet-bin
  assert_eq "${reply[1]}" "${ZCOMET[SCRIPT]:A:h}"
}

# 'n': an unknown name does not resolve.
test_named_dir_name_unknown_unresolved() {
  zc_reset
  assert_not_ok _zcomet_named_dirs n no-such-repo
}

# 'n': a name shared by two repos is intentionally NOT resolved, to avoid
# sending the user to the wrong directory (documented "prevent mistakes" rule).
test_named_dir_name_ambiguous_unresolved() {
  zc_reset
  _nd_make_repo user1 dup
  _nd_make_repo user2 dup
  assert_not_ok _zcomet_named_dirs n dup
}

# 'd' (directory -> name): a repo path abbreviates to the repo's basename.
test_named_dir_dir_to_name() {
  zc_reset
  _nd_make_repo testuser myrepo
  _zcomet_named_dirs d "${ZCOMET[REPOS_DIR]}/testuser/myrepo"
  assert_eq "${reply[1]}" 'myrepo'
}

# 'd': the zcomet.zsh directory abbreviates to zcomet-bin.
test_named_dir_dir_zcomet_bin() {
  zc_reset
  _zcomet_named_dirs d "${ZCOMET[SCRIPT]:A:h}"
  assert_eq "${reply[1]}" 'zcomet-bin'
}

# End-to-end: `~[name]` expansion goes through the live hook/function wiring.
test_named_dir_tilde_expansion() {
  zc_reset
  _nd_make_repo testuser myrepo
  local got
  got=$(print -rn -- ~[myrepo])
  assert_eq "$got" "${ZCOMET[REPOS_DIR]}/testuser/myrepo"
}

# End-to-end: `~[zcomet-bin]` expands to the zcomet.zsh directory.
test_named_dir_tilde_zcomet_bin() {
  zc_reset
  local got
  got=$(print -rn -- ~[zcomet-bin])
  assert_eq "$got" "${ZCOMET[SCRIPT]:A:h}"
}

# vim: ft=zsh:ts=2:sts=2:sw=2
