#!/usr/bin/env zsh
#
# Tests for output that pipes through `fold -w $COLUMNS`.

# With COLUMNS set, `zcomet help` prints its usage text.
test_help_prints_usage() {
  zc_reset   # sets COLUMNS=80
  local out
  out="$(zcomet help 2>/dev/null)"
  assert_contains "$out" 'usage'
}

# Regression for SUGGESTIONS 1.5: `fold -s -w $COLUMNS` errors out when COLUMNS
# is unset (common when output is piped or zcomet is driven non-interactively),
# so `zcomet help` produces no usage text.
test_help_works_without_columns() {
  xfail 'SUGGESTIONS 1.5: fold -w $COLUMNS breaks when COLUMNS is unset'
  zc_reset
  unset COLUMNS
  local out
  out="$(zcomet help 2>/dev/null)"
  assert_contains "$out" 'usage'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
