#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -ne 2 ]]; then
  die "Usage: $0 <message_id> <output_dir>" 1
fi

message_id="$1"
output_dir="$2"

require_cmd python3
mkdir -p "${output_dir}"

message_json="$(gmail_api GET "messages/${message_id}?format=full")"

attachment_plan=""
attachment_plan_status=0
attachment_plan="$(
  GMAIL_MESSAGE_JSON="${message_json}" python3 - <<'PY'
import json
import os
import pathlib
import re
import sys

data = json.loads(os.environ["GMAIL_MESSAGE_JSON"])
attachments = []

def walk(part):
    filename = part.get("filename") or ""
    body = part.get("body") or {}
    attachment_id = body.get("attachmentId") or ""
    if filename and attachment_id:
        attachments.append((filename, attachment_id))

    for child in part.get("parts") or []:
        walk(child)

walk(data.get("payload") or {})

if not attachments:
    sys.exit(3)

def sanitize_filename(filename: str) -> str:
    safe = pathlib.Path(filename).name.strip()
    safe = re.sub(r"[^A-Za-z0-9._-]+", "-", safe)
    safe = safe.strip("-._")
    return safe or "attachment"

for index, (filename, attachment_id) in enumerate(attachments, start=1):
    safe_name = sanitize_filename(filename)
    print(f"{index}\t{attachment_id}\t{index:02d}-{safe_name}")
PY
)" || attachment_plan_status=$?

case "${attachment_plan_status}" in
  0)
    ;;
  3)
    die "No downloadable attachments found on Gmail message ${message_id}" 1
    ;;
  *)
    die "Failed to extract attachment info from Gmail message ${message_id}" 1
    ;;
esac

[[ -n "${attachment_plan}" ]] || die "No downloadable attachments found on Gmail message ${message_id}" 1

while IFS=$'\t' read -r attachment_index attachment_id target_name; do
  [[ -n "${attachment_id}" ]] || continue
  output_path="${output_dir}/${target_name}"
  "${SCRIPT_DIR}/gmail_download_attachment.sh" "${message_id}" "${attachment_id}" "${output_path}" >/dev/null
  printf '%s\n' "${output_path}"
done <<< "${attachment_plan}"
