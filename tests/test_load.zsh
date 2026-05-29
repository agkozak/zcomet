#!/usr/bin/env zsh
#
# Tests for `zcomet load` using local fixture plugins (no network).

# A plain plugin's init file is sourced and the plugin is recorded.
test_load_sources_init_file() {
  zc_reset
  local p="${ZCOMET_TEST_FIXTURES}/simple"
  zcomet load "$p" >/dev/null 2>&1
  assert_eq "${SIMPLE_LOADED:-}" 1 'init file was sourced'
  assert_array_contains "$p" "${zsh_loaded_plugins[@]}"
}

# Init-file selection order: *.zsh-theme should win over *.plugin.zsh.
test_load_theme_precedence() {
  zc_reset
  zcomet load "${ZCOMET_TEST_FIXTURES}/theme-precedence" >/dev/null 2>&1
  assert_eq "${LOADED_VIA:-}" 'theme' '*.zsh-theme should be chosen first'
}

# A plugin's bin/ directory is prepended to PATH.
test_load_bin_added_to_path() {
  zc_reset
  local base="${ZCOMET_TEST_FIXTURES}/withbin"
  zcomet load "$base" sub sub.plugin.zsh >/dev/null 2>&1
  assert_eq "${SUB_LOADED:-}" 1 'sub-directory file sourced'
  assert_array_contains "${base}/bin" "${path[@]}"
}

# Regression for SUGGESTIONS 1.2/1.3: when a plugin both sources an explicit
# file AND has a bin/ directory, the bin/ bookkeeping adds a second, malformed
# (space-separated) entry to zsh_loaded_plugins because it tests an undefined
# `plugin_added` variable and formats the subdir with a space instead of a
# slash. There should be exactly ONE entry for the plugin.
test_load_no_duplicate_list_entry() {
  xfail 'SUGGESTIONS 1.2/1.3: undefined plugin_added + space-vs-slash subdir'
  zc_reset
  local base="${ZCOMET_TEST_FIXTURES}/withbin"
  zcomet load "$base" sub sub.plugin.zsh >/dev/null 2>&1
  local -a matches; matches=( ${(M)zsh_loaded_plugins:#*withbin*} )
  assert_count 1 "${matches[@]}"
  assert_array_lacks "${base} sub" "${zsh_loaded_plugins[@]}"
}

# Prezto-style functions/ directory is added to FPATH and its functions are
# autoloaded.
test_load_prezto_functions_autoloaded() {
  zc_reset
  local p="${ZCOMET_TEST_FIXTURES}/prezto-mod"
  zcomet load "$p" >/dev/null 2>&1
  assert_array_contains "${p}/functions" "${fpath[@]}"
  assert_eq "${+functions[preztofunc]}" 1 'preztofunc was autoloaded'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
