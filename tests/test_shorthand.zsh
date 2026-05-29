#!/usr/bin/env zsh
#
# Unit tests for the pure shorthand-expansion helpers:
#   _zcomet_repo_shorthand     (sets $REPLY)
#   _zcomet_snippet_shorthand  (sets $REPLY)
#
# These functions have no side effects beyond $REPLY, so they are easy to test
# directly. They should all pass against current code.

# ---- _zcomet_repo_shorthand --------------------------------------------- #

test_repo_shorthand_ohmyzsh() {
  _zcomet_repo_shorthand ohmyzsh
  assert_eq "$REPLY" 'ohmyzsh/ohmyzsh'
}

test_repo_shorthand_prezto() {
  _zcomet_repo_shorthand prezto
  assert_eq "$REPLY" 'sorin-ionescu/prezto'
}

test_repo_shorthand_passthrough() {
  _zcomet_repo_shorthand 'zsh-users/zsh-autosuggestions'
  assert_eq "$REPLY" 'zsh-users/zsh-autosuggestions'
}

test_repo_shorthand_local_path_passthrough() {
  _zcomet_repo_shorthand '/opt/plugins/foo'
  assert_eq "$REPLY" '/opt/plugins/foo'
}

test_repo_shorthand_https_url() {
  _zcomet_repo_shorthand 'https://github.com/user/repo'
  assert_eq "$REPLY" 'user/repo'
}

test_repo_shorthand_http_url() {
  _zcomet_repo_shorthand 'http://github.com/user/repo'
  assert_eq "$REPLY" 'user/repo'
}

test_repo_shorthand_url_dot_git() {
  _zcomet_repo_shorthand 'https://github.com/user/repo.git'
  assert_eq "$REPLY" 'user/repo'
}

test_repo_shorthand_url_dot_git_at_branch() {
  _zcomet_repo_shorthand 'https://github.com/user/repo.git@v1.2.3'
  assert_eq "$REPLY" 'user/repo@v1.2.3'
}

# ---- _zcomet_snippet_shorthand ------------------------------------------ #

test_snippet_shorthand_omz() {
  _zcomet_snippet_shorthand 'OMZ::plugins/git/git.plugin.zsh'
  assert_eq "$REPLY" \
    'https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/git/git.plugin.zsh'
}

test_snippet_shorthand_github_blob_to_raw() {
  _zcomet_snippet_shorthand 'https://github.com/jreese/zsh-titles/blob/master/titles.plugin.zsh'
  assert_eq "$REPLY" \
    'https://raw.githubusercontent.com/jreese/zsh-titles/master/titles.plugin.zsh'
}

test_snippet_shorthand_plain_url_passthrough() {
  _zcomet_snippet_shorthand 'https://example.com/raw/code.zsh'
  assert_eq "$REPLY" 'https://example.com/raw/code.zsh'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
