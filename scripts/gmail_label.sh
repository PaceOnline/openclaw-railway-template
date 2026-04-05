#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 1 ]]; then
  die "Usage: $0 <message_id> [add|remove] [label_name...]" 1
fi

message_id="$1"
shift

action="add"
if [[ $# -gt 0 && ( "$1" == "add" || "$1" == "remove" ) ]]; then
  action="$1"
  shift
fi

if [[ $# -eq 0 ]]; then
  set -- "Tickets/Handled"
fi

declare -a label_ids=()
declare -a label_names=("$@")
declare -A seen_labels=()
label_name=""

for label_name in "${label_names[@]}"; do
  if [[ -n "${seen_labels[$label_name]:-}" ]]; then
    continue
  fi

  label_id="$(get_label_id "${label_name}")" || die "Gmail label not found: ${label_name}" 2
  label_ids+=("${label_id}")
  seen_labels["${label_name}"]=1

  if [[ "${action}" == "add" && "${label_name}" == Tickets/* && -z "${seen_labels[Tickets]:-}" ]]; then
    parent_id="$(get_label_id "Tickets")" || die "Gmail label not found: Tickets" 2
    label_ids+=("${parent_id}")
    seen_labels["Tickets"]=1
  fi
done

payload="$(
  python3 - "${action}" "${label_ids[@]}" <<'PY'
import json
import sys

action = sys.argv[1]
label_ids = sys.argv[2:]
key = "addLabelIds" if action == "add" else "removeLabelIds"
print(json.dumps({key: label_ids}))
PY
)"

if is_dry_run; then
  log "DRY RUN: would ${action} labels ${label_names[*]} on Gmail message ${message_id}"
  printf '%s\n' "dry-run"
  exit 0
fi

gmail_api POST "messages/${message_id}/modify" "${payload}" >/dev/null
printf '%s\n' "${action} labels applied successfully."
