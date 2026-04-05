#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

MAX_RESULTS="${1:-20}"

# Build default query dynamically from sites.json
if [[ -z "${2:-}" ]] && [[ -f "${SCRIPT_DIR}/sites.json" ]]; then
  domain_filter="$(all_email_domains)"
  DEFAULT_QUERY="(${domain_filter}) -label:Tickets/Handled has:attachment"
else
  DEFAULT_QUERY="{from:yetsagala.co.za from:harrygwaladm.gov.za from:enterpriseilembe.co.za from:isimangaliso.com from:hgda.co.za} -label:Tickets/Handled has:attachment"
fi
QUERY="${2:-${DEFAULT_QUERY}}"

require_cmd python3

encoded_query="$(urlencode "${QUERY}")"
list_json="$(gmail_api GET "messages?q=${encoded_query}&maxResults=${MAX_RESULTS}")"

message_count="$(
  GMAIL_LIST_JSON="${list_json}" python3 - <<'PY'
import json
import os

data = json.loads(os.environ["GMAIL_LIST_JSON"])
print(len(data.get("messages", [])))
PY
)"

if [[ "${message_count}" == "0" ]]; then
  log "No matching Gmail messages found."
  exit 1
fi

access_token="$(get_gmail_access_token)"

GMAIL_LIST_JSON="${list_json}" python3 - "${access_token}" <<'PY'
import json
import os
import sys
import urllib.request

token = sys.argv[1]
list_data = json.loads(os.environ["GMAIL_LIST_JSON"])
messages = list_data.get("messages", [])
output = []

for item in messages:
    message_id = item["id"]
    request = urllib.request.Request(
        f"https://gmail.googleapis.com/gmail/v1/users/me/messages/{message_id}"
        "?format=metadata&metadataHeaders=From&metadataHeaders=Subject&metadataHeaders=Date",
        headers={"Authorization": f"Bearer {token}"},
    )
    with urllib.request.urlopen(request) as response:
        payload = json.load(response)

    headers = {
        header.get("name", "").lower(): header.get("value", "")
        for header in payload.get("payload", {}).get("headers", [])
    }
    output.append(
        {
            "id": message_id,
            "threadId": payload.get("threadId", ""),
            "from": headers.get("from", ""),
            "subject": headers.get("subject", ""),
            "date": headers.get("date", ""),
            "snippet": payload.get("snippet", ""),
        }
    )

print(json.dumps(output, indent=2))
PY
