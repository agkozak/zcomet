#!/usr/bin/env zsh
#
# zcomet test runner — a zero-dependency, zsh-native regression suite.
#
# Usage:
#   zsh tests/runtests.zsh            # run every test
#   zsh tests/runtests.zsh shorthand  # run only tests whose name matches *shorthand*
#
# How it works:
#   * Every tests/test_*.zsh file is sourced; each defines functions named
#     `test_*`. Each such function is one test.
#   * Every test runs in its own subshell, so changes it makes to globals
#     (fpath, path, $ZCOMET, zsh_loaded_plugins, options, …) cannot leak into
#     other tests. State isolation is therefore free.
#   * A test passes if it returns without an assertion firing. The first failed
#     assertion aborts that test (via `exit`) and is reported.
#
# Expected failures (xfail):
#   A test may call `xfail "<reason>"` at its top to declare that it documents a
#   known, not-yet-fixed bug (see ../SUGGESTIONS.md). Such a test:
#     * is reported as `xfail` (and does NOT fail the suite) when it fails, and
#     * is reported as `XPASS` (loudly) when it unexpectedly passes — which is
#       the signal that the bug is fixed: remove the `xfail` line so it becomes
#       a normal guard.
#   The suite's exit status is non-zero only on a real FAIL.

emulate -L zsh
setopt EXTENDED_GLOB NO_NOMATCH

# --------------------------------------------------------------------------- #
# Locations
# --------------------------------------------------------------------------- #
typeset -g ZCOMET_TEST_DIR=${0:A:h}
typeset -g ZCOMET_TEST_ROOT=${ZCOMET_TEST_DIR:h}
typeset -g ZCOMET_TEST_FIXTURES=${ZCOMET_TEST_DIR}/fixtures

# A suite-wide scratch directory, cleaned up on exit. Individual tests create
# their throwaway dirs under here via `mktempdir`, so they never need to clean
# up after themselves.
typeset -g SUITE_TMP
SUITE_TMP=$(command mktemp -d "${TMPDIR:-/tmp}/zcomet-tests.XXXXXX") || {
  print -u2 'Could not create a temporary directory for the test suite.'
  exit 1
}
trap 'command rm -rf -- "$SUITE_TMP"' EXIT INT TERM

# --------------------------------------------------------------------------- #
# Counters and colours
# --------------------------------------------------------------------------- #
typeset -gi PASS=0 FAIL=0 SKIP=0 XFAIL=0 XPASS=0
typeset -ga FAILED_NAMES=()

if [[ -t 1 ]]; then
  typeset -g C_RED=$'\e[31m' C_GREEN=$'\e[32m' C_YELLOW=$'\e[33m' \
            C_BLUE=$'\e[34m' C_BOLD=$'\e[1m' C_RESET=$'\e[0m'
else
  typeset -g C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD='' C_RESET=''
fi

# --------------------------------------------------------------------------- #
# Assertions — each aborts the current test (subshell) on failure.
#
# `==`/`!=` do pattern matching on their right-hand side in zsh, so every
# literal comparison quotes the RHS to force a plain string compare.
# --------------------------------------------------------------------------- #
_zc_fail() {
  print -r -- "      ${C_RED}${1}${C_RESET}"
  [[ -n $_ZC_XFAIL ]] && exit 3   # expected failure
  exit 1                          # real failure
}

assert_eq() {  # actual expected [msg]
  [[ $1 == "$2" ]] && return 0
  _zc_fail "${3:-assert_eq}: expected [$2], got [$1]"
}

assert_ne() {  # actual unexpected [msg]
  [[ $1 != "$2" ]] && return 0
  _zc_fail "${3:-assert_ne}: expected value to differ from [$2]"
}

assert_match() {  # actual pattern [msg]
  [[ $1 == ${~2} ]] && return 0
  _zc_fail "${3:-assert_match}: [$1] does not match pattern [$2]"
}

assert_contains() {  # haystack needle [msg]
  [[ $1 == *"$2"* ]] && return 0
  _zc_fail "${3:-assert_contains}: [$1] does not contain [$2]"
}

assert_not_contains() {  # haystack needle [msg]
  [[ $1 != *"$2"* ]] && return 0
  _zc_fail "${3:-assert_not_contains}: [$1] unexpectedly contains [$2]"
}

assert_empty() {  # value [msg]
  [[ -z $1 ]] && return 0
  _zc_fail "${2:-assert_empty}: expected empty, got [$1]"
}

assert_nonempty() {  # value [msg]
  [[ -n $1 ]] && return 0
  _zc_fail "${2:-assert_nonempty}: expected a non-empty value"
}

assert_file() {  # path [msg]
  [[ -f $1 ]] && return 0
  _zc_fail "${2:-assert_file}: file does not exist: [$1]"
}

assert_dir() {  # path [msg]
  [[ -d $1 ]] && return 0
  _zc_fail "${2:-assert_dir}: directory does not exist: [$1]"
}

# Join array elements for diagnostics, truncating very long lists (e.g. fpath).
_zc_arr() {
  local joined="$*"
  (( ${#joined} > 160 )) && joined="${joined[1,160]}…"
  print -r -- "$joined"
}

# assert_array_contains <needle> <element>...   (pass the array as "${arr[@]}")
assert_array_contains() {
  local needle=$1; shift
  local e
  for e in "$@"; do [[ $e == "$needle" ]] && return 0; done
  _zc_fail "assert_array_contains: [$needle] not found in ($(_zc_arr "$@"))"
}

# assert_array_lacks <needle> <element>...
assert_array_lacks() {
  local needle=$1; shift
  local e
  for e in "$@"; do
    [[ $e == "$needle" ]] &&
      _zc_fail "assert_array_lacks: [$needle] unexpectedly present in ($(_zc_arr "$@"))"
  done
  return 0
}

# assert_count <expected-n> <element>...   (how many array elements were passed)
assert_count() {
  local -i want=$1; shift
  (( $# == want )) && return 0
  _zc_fail "assert_count: expected $want element(s), got $# ($*)"
}

# assert_ok <cmd> [args...]      — command must exit 0
assert_ok() {
  if ! "$@" >/dev/null 2>&1; then
    _zc_fail "assert_ok: command failed: $*"
  fi
}

# assert_not_ok <cmd> [args...]  — command must exit non-zero
assert_not_ok() {
  if "$@" >/dev/null 2>&1; then
    _zc_fail "assert_not_ok: command unexpectedly succeeded: $*"
  fi
}

# --------------------------------------------------------------------------- #
# Test directives (used inside a test body)
# --------------------------------------------------------------------------- #
xfail() { typeset -g _ZC_XFAIL=${1:-'known bug'}; }   # mark expected failure
skip()  { print -r -- "      ${C_YELLOW}skipped: ${1:-}${C_RESET}"; exit 2; }

# --------------------------------------------------------------------------- #
# Helpers available to tests
# --------------------------------------------------------------------------- #
mktempdir() { command mktemp -d "${SUITE_TMP}/d.XXXXXX"; }

# Give the current test a clean, isolated zcomet environment rooted in a temp
# directory. Safe to call once at the top of a test.
zc_reset() {
  local home
  home=$(mktempdir)
  typeset -gA ZCOMET
  ZCOMET[HOME_DIR]=$home
  ZCOMET[REPOS_DIR]=${home}/repos
  ZCOMET[SNIPPETS_DIR]=${home}/snippets
  ZCOMET[GITSERVER]='github.com'
  command mkdir -p "${ZCOMET[REPOS_DIR]}" "${ZCOMET[SNIPPETS_DIR]}"

  # Fresh bookkeeping arrays
  typeset -gUa zsh_loaded_plugins ZCOMET_FPATH ZCOMET_SNIPPETS ZCOMET_TRIGGERS
  typeset -gUA ZCOMET_PLUGINS
  zsh_loaded_plugins=() ZCOMET_FPATH=() ZCOMET_SNIPPETS=() ZCOMET_TRIGGERS=()
  ZCOMET_PLUGINS=()

  # Keep fold/COLUMNS-dependent commands quiet unless a test opts out.
  typeset -g COLUMNS=80
}

# --------------------------------------------------------------------------- #
# Runner
# --------------------------------------------------------------------------- #
_zc_run_one() {
  local name=$1 out
  integer rc
  out="$( { zc_reset; $name; [[ -n $_ZC_XFAIL ]] && exit 4; exit 0; } 2>&1 )"
  rc=$?
  case $rc in
    0) (( PASS++ ));  print -r -- "  ${C_GREEN}✓${C_RESET} ${name#test_}" ;;
    2) (( SKIP++ ));  print -r -- "  ${C_YELLOW}○${C_RESET} ${name#test_}"
       [[ -n $out ]] && print -r -- "$out" ;;
    3) (( XFAIL++ )); print -r -- "  ${C_YELLOW}✗ ${name#test_} (xfail)${C_RESET}"
       [[ -n $out ]] && print -r -- "$out" ;;
    4) (( XPASS++ )); print -r -- "  ${C_RED}${C_BOLD}! ${name#test_} (XPASS — fixed? remove xfail)${C_RESET}"
       [[ -n $out ]] && print -r -- "$out" ;;
    *) (( FAIL++ )); FAILED_NAMES+=( "${name#test_}" )
       print -r -- "  ${C_RED}✗ ${name#test_}${C_RESET}"
       [[ -n $out ]] && print -r -- "$out" ;;
  esac
}

main() {
  local filter=${1:-}

  print -r -- "${C_BOLD}Sourcing zcomet from ${ZCOMET_TEST_ROOT}/zcomet.zsh${C_RESET}"
  source "${ZCOMET_TEST_ROOT}/zcomet.zsh" || {
    print -u2 'Failed to source zcomet.zsh'; exit 1
  }

  local -a files=( "${ZCOMET_TEST_DIR}"/test_*.zsh(N) )
  if (( ! ${#files} )); then
    print -u2 'No test files (tests/test_*.zsh) found.'; exit 1
  fi

  local f name
  for f in "${files[@]}"; do
    source "$f"
  done

  # Discover every test_* function, in sorted order.
  local -a tests=( ${(ko)functions[(I)test_*]} )
  if [[ -n $filter ]]; then
    tests=( ${(M)tests:#*${filter}*} )
  fi
  if (( ! ${#tests} )); then
    print -u2 "No tests matched filter: ${filter}"; exit 1
  fi

  print -- "${C_BOLD}Running ${#tests} test(s)…${C_RESET}\n"
  for name in "${tests[@]}"; do
    _zc_run_one "$name"
  done

  # Summary
  print -- "\n${C_BOLD}── Summary ──${C_RESET}"
  print -r -- "  ${C_GREEN}pass:  ${PASS}${C_RESET}"
  (( FAIL ))  && print -r -- "  ${C_RED}fail:  ${FAIL}${C_RESET}"
  (( XFAIL )) && print -r -- "  ${C_YELLOW}xfail: ${XFAIL}${C_RESET}  (known bugs — see SUGGESTIONS.md)"
  (( XPASS )) && print -r -- "  ${C_RED}${C_BOLD}xpass: ${XPASS}${C_RESET}  (now passing — remove the xfail marker)"
  (( SKIP ))  && print -r -- "  ${C_YELLOW}skip:  ${SKIP}${C_RESET}"

  if (( FAIL )); then
    print -- "\n${C_RED}FAILED: ${(j:, :)FAILED_NAMES}${C_RESET}"
    return 1
  fi
  print -- "\n${C_GREEN}OK${C_RESET}"
  return 0
}

main "$@"
