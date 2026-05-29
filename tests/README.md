# zcomet test suite

A zero-dependency, zsh-native regression suite. It needs nothing but `zsh`
itself (and the standard `git`/`mktemp`/`wc` already required to use zcomet),
so it runs anywhere zcomet runs and in CI without a bootstrap step.

## Running

```sh
zsh tests/runtests.zsh            # run everything
zsh tests/runtests.zsh shorthand  # run only tests whose name matches *shorthand*
zsh tests/runtests.zsh load       # e.g. just the load tests
```

Exit status is `0` unless a real (non-xfail) test fails, so it is CI-ready.

## What you'll see

```
  ✓ load_sources_init_file            a passing test
  ○ something                         a skipped test
  ✗ gitserver_honors_zstyle (xfail)   a known bug, reproduced (does NOT fail the suite)
  ! gitserver_honors_zstyle (XPASS …) a known bug that now passes — go remove the xfail
  ✗ something                         a real failure (fails the suite)
```

## Expected failures (`xfail`)

Several tests document **confirmed but not-yet-fixed** bugs (see
[`../SUGGESTIONS.md`](../SUGGESTIONS.md), Tier 1). Each calls `xfail "<reason>"`
at its top. An xfail test:

* is reported as `xfail` and **does not fail the suite** while the bug exists, and
* flips to a loud `XPASS` once the bug is fixed.

**When you fix a bug, run the suite, find the `XPASS`, and delete that test's
`xfail` line.** It then becomes an ordinary regression guard.

Currently xfail (each maps to a SUGGESTIONS.md item):

| Test | Bug |
|------|-----|
| `gitserver_honors_zstyle`            | 1.1 — `ZCOMET[GITSERVER]=$gitserver` typo |
| `load_no_duplicate_list_entry`       | 1.2/1.3 — undefined `plugin_added` + space-vs-slash subdir |
| `unload_removes_functions_from_fpath`| 1.4 — unload builds double-slash paths |
| `help_works_without_columns`         | 1.5 — `fold -w $COLUMNS` breaks when `COLUMNS` is unset |
| `list_no_stray_trigger_line`         | 1.6 — trigger block in `zcomet list` runs unconditionally |

## Layout

```
tests/
  runtests.zsh        the runner + assertion library (no deps)
  test_*.zsh          one file per area; each defines test_* functions
  fixtures/           local fixture plugins/snippets (no network access)
  tests               the original manual smoke script (kept for reference)
```

## Writing a test

Add a `test_<area>_<behavior>` function to a `tests/test_*.zsh` file (or a new
one). Keep names unique across files — they are discovered globally.

```zsh
test_load_sources_init_file() {
  zc_reset                                   # fresh, isolated zcomet env in a tempdir
  local p="${ZCOMET_TEST_FIXTURES}/simple"
  zcomet load "$p" >/dev/null 2>&1
  assert_eq "${SIMPLE_LOADED:-}" 1
  assert_array_contains "$p" "${zsh_loaded_plugins[@]}"
}
```

* Each test runs in its own subshell, so changes to `$fpath`, `$path`,
  `$ZCOMET`, `zsh_loaded_plugins`, options, `zstyle`, … cannot leak between
  tests. No teardown needed.
* Call `zc_reset` first for a clean zcomet rooted in a throwaway tempdir
  (cleaned up automatically when the suite exits).
* Use **local fixtures** (absolute paths) so tests never hit the network. A
  local plugin path must be absolute — zcomet treats relative paths as repos to
  clone.

### Assertions

`assert_eq` · `assert_ne` · `assert_match` (glob) · `assert_contains` ·
`assert_not_contains` · `assert_empty` · `assert_nonempty` · `assert_file` ·
`assert_dir` · `assert_array_contains` · `assert_array_lacks` · `assert_count` ·
`assert_ok <cmd…>` · `assert_not_ok <cmd…>`

### Directives

`xfail "<reason>"` — mark the current test an expected failure (known bug).
`skip "<reason>"` — skip the current test.

### Helpers

`zc_reset` — fresh isolated zcomet environment.
`mktempdir` — a throwaway directory under the auto-cleaned suite tempdir.
`$ZCOMET_TEST_ROOT` · `$ZCOMET_TEST_DIR` · `$ZCOMET_TEST_FIXTURES` — locations.

## zsh 4.3.11 compatibility

zcomet supports zsh 4.3.11+, so the suite must run there too
(`~/path/to/zsh-4.3.11 tests/runtests.zsh`). One non-obvious gotcha:

**Never combine an array declaration with its initializer.** On 4.3.11 `typeset`
and `local` are ordinary *builtins*, not *reserved words* (they only became
reserved words later). That means `typeset -ga NAME=( … )` / `local -a NAME=( … )`
do **not** get array-assignment parsing — the `=( … )` is misparsed (an empty
`=()` even defines a bogus function literally named `typeset`/`local`, shadowing
the builtin and causing unbounded recursion the next time it's called). Always
split the declaration from the assignment:

```zsh
local -a files            # NOT: local -a files=( … )
files=( … )               # bare array assignment is fine on 4.3.11
```

Bare assignments (`name=( … )`, `name+=( … )`) and scalar `local x=…` are fine;
only the *declaration-with-array-initializer* form is unsafe. Likewise, `trap`
on 4.3.11 accepts only `EXIT` and numeric signals, not signal *names* like
`INT`/`TERM`.
