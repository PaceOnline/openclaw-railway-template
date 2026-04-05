#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  die "Usage: $0 <repo_dir> <commit_message> [branch]" 1
fi

repo_dir="$1"
commit_message="$2"
branch="${3:-main}"

[[ -d "${repo_dir}/.git" ]] || die "Not a git repository: ${repo_dir}" 1
require_cmd git

if [[ -z "$(git -C "${repo_dir}" status --short)" ]]; then
  printf '%s\n' "No changes to commit."
  exit 0
fi

if is_dry_run; then
  log "DRY RUN: would commit and push ${repo_dir} to ${branch} with message: ${commit_message}"
  git -C "${repo_dir}" status --short
  exit 0
fi

git -C "${repo_dir}" add -A

if git -C "${repo_dir}" diff --cached --quiet; then
  printf '%s\n' "No staged changes to commit."
  exit 0
fi

git -C "${repo_dir}" \
  -c user.name="$(git_author_name)" \
  -c user.email="$(git_author_email)" \
  commit -m "${commit_message}" >/dev/null

git -C "${repo_dir}" push origin "${branch}" >/dev/null
git -C "${repo_dir}" rev-parse --short HEAD
