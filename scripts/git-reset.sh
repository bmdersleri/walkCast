#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'USAGE'
Usage:
  ./scripts/git-reset.sh <soft|hard> [target]

Examples:
  ./scripts/git-reset.sh soft
  ./scripts/git-reset.sh hard
  ./scripts/git-reset.sh soft HEAD~1
  ./scripts/git-reset.sh hard origin/main

Notes:
  - default target is origin/main
  - soft: keeps index and working tree changes
  - hard: resets tracked files and removes untracked files/dirs
USAGE
}

if [[ ${1:-} == "-h" || ${1:-} == "--help" || $# -lt 1 ]]; then
  usage
  exit 0
fi

mode="$1"
target="${2:-origin/main}"

repo_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "$repo_root" ]]; then
  echo "Error: not inside a git repository." >&2
  exit 1
fi

cd "$repo_root"

echo "Repository: $repo_root"
echo "Mode: $mode"
echo "Target: $target"

case "$mode" in
  soft)
    git fetch origin
    git reset --soft "$target"
    ;;
  hard)
    git fetch origin
    git reset --hard "$target"
    git clean -fd
    ;;
  *)
    echo "Error: mode must be 'soft' or 'hard'." >&2
    usage
    exit 1
    ;;
esac

echo "Done."
