#!/usr/bin/env zsh
#
# Tests for `zcomet list`.

# A loaded plugin shows up under the Plugins heading.
test_list_shows_loaded_plugin() {
  zc_reset
  zcomet load "${ZCOMET_TEST_FIXTURES}/simple" >/dev/null 2>&1
  local out
  out="$(zcomet list 2>/dev/null)"
  assert_contains "$out" 'Plugins'
  assert_contains "$out" 'simple'
}

# Regression for SUGGESTIONS 1.6: the Triggers section of zcomet_list is not
# fully guarded by its `&&` chain, so its `print -z`/`read -z` block runs even
# when no triggers are defined, emitting a stray blank line. With exactly one
# plugin and no triggers, correct output is 2 lines (header + plugin); the bug
# produces 3.
test_list_no_stray_trigger_line() {
  xfail 'SUGGESTIONS 1.6: trigger block in zcomet_list runs unconditionally'
  zc_reset
  zcomet load "${ZCOMET_TEST_FIXTURES}/simple" >/dev/null 2>&1
  local n
  n=$(zcomet list 2>/dev/null | command wc -l)
  n=${n//[[:space:]]/}
  assert_eq "$n" 2 'zcomet list emitted a stray line'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
