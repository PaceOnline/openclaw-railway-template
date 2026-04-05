#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
  # Running from /data/workspace/scripts or the repo checkout.
  source "${SCRIPT_DIR}/common.sh"
elif [[ -f "${SCRIPT_DIR}/scripts/common.sh" ]]; then
  # Running from the workspace root compatibility copy.
  source "${SCRIPT_DIR}/scripts/common.sh"
else
  printf '[paceonline] ERROR: common.sh not found for gmail_helper.sh\n' >&2
  exit 2
fi

export GMAIL_ACCESS_TOKEN="$(get_gmail_access_token)"

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  printf '%s\n' "${GMAIL_ACCESS_TOKEN}"
fi
