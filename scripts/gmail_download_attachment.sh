#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -ne 3 ]]; then
  die "Usage: $0 <message_id> <attachment_id> <output_path>" 1
fi

message_id="$1"
attachment_id="$2"
output_path="$3"

attachment_json="$(gmail_api GET "messages/${message_id}/attachments/${attachment_id}")"

ATTACHMENT_JSON="${attachment_json}" python3 - "${output_path}" <<'PY'
import base64
import json
import os
import pathlib
import sys

data = json.loads(os.environ["ATTACHMENT_JSON"])
raw = data.get("data", "")
if not raw:
    raise SystemExit("Attachment payload was empty")

padding = "=" * (-len(raw) % 4)
content = base64.urlsafe_b64decode(raw + padding)
target = pathlib.Path(sys.argv[1])
target.parent.mkdir(parents=True, exist_ok=True)
target.write_bytes(content)
print(str(target))
PY
