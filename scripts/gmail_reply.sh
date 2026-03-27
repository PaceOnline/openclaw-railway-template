#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -ne 5 ]]; then
  die "Usage: $0 <thread_id> <message_id> <to_email> <subject> <body_or_body_file>" 1
fi

thread_id="$1"
message_id="$2"
to_email="$3"
subject="$4"
body_input="$5"

if [[ -f "${body_input}" ]]; then
  body="$(cat "${body_input}")"
else
  body="${body_input}"
fi

reply_subject="${subject}"
if [[ "${reply_subject}" != Re:* && "${reply_subject}" != RE:* ]]; then
  reply_subject="Re: ${reply_subject}"
fi

payload="$(
  python3 - "${thread_id}" "${message_id}" "${to_email}" "${reply_subject}" "${body}" <<'PY'
import base64
import json
import sys

thread_id, message_id, to_email, subject, body = sys.argv[1:6]
message = "\n".join(
    [
        "From: support@paceonline.co.za",
        f"To: {to_email}",
        f"Subject: {subject}",
        f"In-Reply-To: {message_id}",
        f"References: {message_id}",
        "Content-Type: text/plain; charset=utf-8",
        "",
        body,
    ]
)
encoded = base64.urlsafe_b64encode(message.encode("utf-8")).decode("utf-8")
print(json.dumps({"raw": encoded, "threadId": thread_id}))
PY
)"

if is_dry_run; then
  log "DRY RUN: would send Gmail reply for thread ${thread_id} to ${to_email}"
  printf '%s\n' "dry-run"
  exit 0
fi

gmail_api POST "messages/send" "${payload}" >/dev/null
printf '%s\n' "Reply sent successfully."
