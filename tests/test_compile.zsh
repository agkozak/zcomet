#!/usr/bin/env zsh
#
# Tests for `zcomet compile`.

# Compiling a script produces a .zwc next to it.
test_compile_creates_zwc() {
  zc_reset
  local d f
  d=$(mktempdir)
  f="${d}/script.zsh"
  print 'print hello' > "$f"
  zcomet compile "$f" >/dev/null 2>&1
  assert_file "${f}.zwc"
}

# Re-compiling an up-to-date script is a no-op but must not error or remove the
# wordcode.
test_compile_is_idempotent() {
  zc_reset
  local d f
  d=$(mktempdir)
  f="${d}/script.zsh"
  print 'print hello' > "$f"
  zcomet compile "$f" >/dev/null 2>&1
  assert_ok zcomet compile "$f"
  assert_file "${f}.zwc"
}

# `zcomet compile` with no argument is an error (and the message is on stderr).
test_compile_requires_argument() {
  zc_reset
  local out
  out="$(zcomet compile 2>/dev/null)"
  assert_not_ok zcomet compile
  assert_empty "$out" 'error should not be on stdout'
}

# vim: ft=zsh:ts=2:sts=2:sw=2
