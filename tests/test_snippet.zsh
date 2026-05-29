#!/usr/bin/env zsh
#
# Tests for `zcomet snippet` (local snippets only — no network).

# A local snippet is sourced and recorded. zcomet abbreviates $HOME to ~ in the
# recorded path, so match on the tail rather than an absolute path.
test_snippet_local_sourced() {
  zc_reset
  local s="${ZCOMET_TEST_FIXTURES}/snippet/snip.zsh"
  zcomet snippet "$s" >/dev/null 2>&1
  assert_eq "${SNIPPET_LOADED:-}" 1 'snippet was sourced'
  assert_count 1 "${ZCOMET_SNIPPETS[@]}"
  assert_match "${ZCOMET_SNIPPETS[1]}" '*fixtures/snippet/snip.zsh'
}

# Regression guard for SUGGESTIONS 1.7 (fixed): asking for a snippet with no
# argument must write its error to stderr, not stdout.
test_snippet_missing_arg_error_on_stderr() {
  zc_reset
  local out err
  out="$(zcomet snippet 2>/dev/null)"
  err="$(zcomet snippet 2>&1 >/dev/null)"
  assert_empty "$out" 'error message should not be on stdout'
  assert_contains "$err" 'specify a snippet'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
