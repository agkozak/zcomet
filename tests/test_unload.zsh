#!/usr/bin/env zsh
#
# Tests for `zcomet unload`.

# The plugin's <name>_plugin_unload hook is invoked.
test_unload_runs_plugin_hook() {
  zc_reset
  local p="${ZCOMET_TEST_FIXTURES}/unloadable"
  zcomet load "$p" >/dev/null 2>&1
  assert_eq "${UNLOAD_DEF:-}" 1 'plugin was sourced'
  zcomet unload "$p" >/dev/null 2>&1
  assert_eq "${UNLOAD_RAN:-}" 1 'unload hook ran'
}

# Regression for SUGGESTIONS 1.4: unload constructs the FPATH/PATH entries to
# remove with an extra slash (e.g. repos//author/repo/functions), so the
# functions/ directory added at load time is never actually removed.
test_unload_removes_functions_from_fpath() {
  xfail 'SUGGESTIONS 1.4: unload builds double-slash paths and never removes functions/'
  zc_reset
  local p="${ZCOMET_TEST_FIXTURES}/unloadable"
  zcomet load "$p" >/dev/null 2>&1
  assert_array_contains "${p}/functions" "${fpath[@]}"   # added on load
  zcomet unload "$p" >/dev/null 2>&1
  assert_array_lacks "${p}/functions" "${fpath[@]}"       # should be gone
}

# vim: ft=zsh:ts=2:sts=2:sw=2
