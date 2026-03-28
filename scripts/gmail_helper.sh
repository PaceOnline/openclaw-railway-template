#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

export GMAIL_ACCESS_TOKEN="$(get_gmail_access_token)"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '%s\n' "${GMAIL_ACCESS_TOKEN}"
fi
