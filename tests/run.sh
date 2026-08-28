#!/usr/bin/env bash
# Dependency-free smoke tests for espvm's dangerous paths.
# Run: bash tests/run.sh   (needs only bash + git + python3)
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

PASS=0 FAIL=0
ok()  { echo "ok   - $1"; PASS=$((PASS+1)); }
bad() { echo "not ok - $1"; FAIL=$((FAIL+1)); }
# assert <desc> <shell-condition>
assert() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

export HOME="$(mktemp -d)"
source "$ROOT/espvm" || { echo "cannot source espvm"; exit 1; }

# -- safe_rm_rf guards (destructive ops) --
assert "safe_rm_rf refuses /"            '! _espvm_safe_rm_rf /'
assert "safe_rm_rf refuses empty"        '! _espvm_safe_rm_rf ""'
WT="$HOME/.espressif/versions"
mkdir -p "$WT/esp-idf/vX"; echo x > "$WT/esp-idf/vX/f"
assert "safe_rm_rf removes inside worktree" \
      '_espvm_safe_rm_rf "$WT/esp-idf/vX" && [[ ! -e "$WT/esp-idf/vX" ]]'
EXT="$HOME/outside"; mkdir -p "$EXT"
assert "safe_rm_rf refuses outside-safe" '! _espvm_safe_rm_rf "$EXT"'

# -- concurrency lock --
assert "lock acquires"       '_espvm_lock "$_ESPVM_LOCK_DIR"'
assert "unlock releases"     '_espvm_unlock && [[ ! -d "$_ESPVM_LOCK_DIR" ]]'
mkdir -p "$_ESPVM_LOCK_DIR"; echo "999999" > "$_ESPVM_LOCK_DIR/pid"
assert "lock reclaims stale (dead pid)" '_espvm_lock "$_ESPVM_LOCK_DIR" && [[ -f "$_ESPVM_LOCK_DIR/pid" ]]'
_espvm_unlock

# -- config worktree-dir guard (no silent orphaning) --
mkdir -p "$HOME/.espressif/versions/esp-idf/v5.4.1"
printf 'idf\tv5.4.1\tv5.4.1\t%s/esp-idf/v5.4.1\n' "$HOME/.espressif/versions" > "$ESPVM_CONFIG_DIR/installs"
assert "config refuses worktree change with installs" '! espvm config set worktree-dir /tmp/wt2'
assert "config allows --force" 'espvm config set worktree-dir /tmp/wt2 --force'

# -- hash verification refuses when unhashable (no silent pass) --
_espvm_sha256() { echo ""; }
F="$(mktemp)"; echo "#!/bin/sh" > "$F"
assert "verify_script_hash refuses when unhashable" '! _espvm_verify_script_hash "$F" unit'
unset -f _espvm_sha256

# -- read-only commands must not prompt or write config (smell #2) --
assert "'current' does not write config file" '
  rm -f "$ESPVM_CONFIG_DIR/config"
  espvm current >/dev/null 2>&1
  [[ ! -f "$ESPVM_CONFIG_DIR/config" ]]
'
assert "'ls' does not write config file" '
  rm -f "$ESPVM_CONFIG_DIR/config"
  espvm ls >/dev/null 2>&1
  [[ ! -f "$ESPVM_CONFIG_DIR/config" ]]
'

# -- path resolvers fail hard on bad input (smell #1) --
assert "get_worktree_dir rejects relative dir" '
  ESPVM_WORKTREE_DIR="rel/path" && ! _espvm_get_worktree_dir; unset ESPVM_WORKTREE_DIR
'
assert "get_sdk_dir propagates worktree failure" '
  ESPVM_WORKTREE_DIR="rel" && ! _espvm_get_sdk_dir idf; unset ESPVM_WORKTREE_DIR
'
assert "install_dir propagates worktree failure" '
  ESPVM_WORKTREE_DIR="rel" && ! _espvm_install_dir idf vX; unset ESPVM_WORKTREE_DIR
'

# -- completion must derive from the single command source (no drift) --
if [[ -n "${BASH_VERSION:-}" ]] && command -v compgen >/dev/null 2>&1; then
  assert "completion derives from single command source" '
    COMP_WORDS=(espvm ""); COMP_CWORD=1; _espvm_completions
    local got; got=$(printf "%s\n" "${COMPREPLY[@]}" | sort | tr "\n" " ")
    local want; want=$(printf "%s\n" -i -m "${_ESPVM_COMMANDS[@]}" | sort | tr "\n" " ")
    [[ "$got" == "$want" ]]
  '
fi

echo "1..$((PASS+FAIL))"
echo "pass=$PASS fail=$FAIL"
[[ $FAIL -eq 0 ]]
