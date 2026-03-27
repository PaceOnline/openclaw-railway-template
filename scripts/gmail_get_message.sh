#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  die "Usage: $0 <message_id> [format]" 1
fi

message_id="$1"
message_format="${2:-full}"

gmail_api GET "messages/${message_id}?format=${message_format}"
