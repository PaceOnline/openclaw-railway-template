#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 2 || $# -gt 3 ]]; then
  die "Usage: $0 <owner/repo> <target_dir> [branch]" 1
fi

repo_slug="$1"
target_dir="$2"
branch="${3:-main}"

require_cmd git

repo_url="$(github_repo_url "${repo_slug}")"

if is_dry_run; then
  log "DRY RUN: would clone or update ${repo_url} into ${target_dir} on branch ${branch}"
  printf '%s\n' "${target_dir}"
  exit 0
fi

if [[ -d "${target_dir}/.git" ]]; then
  git -C "${target_dir}" fetch --all --prune
  git -C "${target_dir}" checkout "${branch}"
  git -C "${target_dir}" pull --ff-only origin "${branch}"
else
  mkdir -p "$(dirname "${target_dir}")"
  git clone --branch "${branch}" "${repo_url}" "${target_dir}"
fi

printf '%s\n' "${target_dir}"
