#!/usr/bin/env zsh
#
# Tests for the configurable Git server (zstyle ':zcomet:*' gitserver …).

# With no zstyle set, the default is github.com.
test_gitserver_defaults_to_github() {
  zc_reset
  unset 'ZCOMET[GITSERVER]'
  zcomet list >/dev/null 2>&1   # any command runs the option-parsing block
  assert_eq "${ZCOMET[GITSERVER]}" 'github.com'
}

# Regression for SUGGESTIONS 1.1: a configured gitserver is read into the local
# variable `git_server`, but the assignment uses `$gitserver` (a typo), so the
# value is silently discarded and ZCOMET[GITSERVER] ends up empty.
test_gitserver_honors_zstyle() {
  xfail 'SUGGESTIONS 1.1: ZCOMET[GITSERVER]=$gitserver should be $git_server'
  zc_reset
  zstyle ':zcomet:*' gitserver 'git.example.com'
  zcomet list >/dev/null 2>&1
  assert_eq "${ZCOMET[GITSERVER]}" 'git.example.com'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
