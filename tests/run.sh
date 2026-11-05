#!/usr/bin/env bash
# Runs each tests/cases/<name>: `args` (one per line) and optional `stdin` against
# tf-plan-diff, comparing stdout, stderr and exit code with `expected`.
# Usage: tests/run.sh [--update]
set -uo pipefail
cd "$(dirname "$0")/.."

update=false
[[ ${1:-} == --update ]] && update=true
failed=0

for dir in tests/cases/*/; do
  name=$(basename "$dir")
  args=()
  while IFS= read -r line; do args+=("$line"); done <"$dir/args"
  input=/dev/null
  [[ -e $dir/stdin ]] && input=$dir/stdin
  actual=$(./tf-plan-diff "${args[@]}" <"$input" 2>&1; echo "exit=$?")

  if $update; then
    printf '%s\n' "$actual" >"$dir/expected"
  elif diff -u "$dir/expected" <(printf '%s\n' "$actual") >/dev/null; then
    echo "ok   $name"
  else
    echo "FAIL $name"
    diff -u "$dir/expected" <(printf '%s\n' "$actual") | sed 's/^/     /'
    failed=1
  fi
done
exit $failed
