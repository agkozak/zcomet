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

# Regression for SUGGESTIONS 1.7: "You need to specify a snippet." is printed to
# stdout instead of stderr. Asking for a snippet with no argument should write
# nothing to stdout.
test_snippet_missing_arg_error_on_stderr() {
  xfail 'SUGGESTIONS 1.7: missing-snippet message goes to stdout, not stderr'
  zc_reset
  local out
  out="$(zcomet snippet 2>/dev/null)"
  assert_empty "$out" 'error message should not be on stdout'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
