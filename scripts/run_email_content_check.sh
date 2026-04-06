#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

require_cmd python3

gmail_check_script="${PACEONLINE_GMAIL_CHECK_SCRIPT:-${SCRIPT_DIR}/gmail_check.sh}"
process_email_script="${PACEONLINE_PROCESS_EMAIL_SCRIPT:-${SCRIPT_DIR}/process_email.sh}"
gmail_label_script="${PACEONLINE_GMAIL_LABEL_SCRIPT:-${SCRIPT_DIR}/gmail_label.sh}"
max_results="${PACEONLINE_EMAIL_CHECK_MAX_RESULTS:-20}"

default_query="newer_than:60d has:attachment -label:Tickets/Handled ($(all_email_domains))"
query="${PACEONLINE_EMAIL_CHECK_QUERY:-${default_query}}"
work_root_base="${PACEONLINE_EMAIL_WORK_ROOT_BASE:-/data/workspace/tmp}"

tmp_dir="$(mktemp -d)"
messages_json_path="${tmp_dir}/messages.json"
process_stderr_path="${tmp_dir}/process.stderr"

cleanup() {
  rm -rf "${tmp_dir}"
}
trap cleanup EXIT

if "${gmail_check_script}" "${max_results}" "${query}" > "${messages_json_path}"; then
  :
else
  status=$?
  if [[ "${status}" -eq 1 ]]; then
    python3 - "${query}" "${max_results}" <<'PY'
import json
import sys

query, max_results = sys.argv[1:3]
print(
    json.dumps(
        {
            "ok": True,
            "status": "no_messages",
            "query": query,
            "maxResults": int(max_results),
        },
        indent=2,
    )
)
PY
    exit 0
  fi
  exit "${status}"
fi

selected_json="$(
  python3 - "${messages_json_path}" <<'PY'
import email.utils
import json
import pathlib
import sys

messages = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
if not isinstance(messages, list):
    raise SystemExit("gmail_check.sh did not return a JSON array")
if not messages:
    raise SystemExit("gmail_check.sh returned an empty array")

def sort_key(item: dict) -> tuple[int, float, str]:
    raw_date = item.get("date", "")
    try:
        parsed = email.utils.parsedate_to_datetime(raw_date)
        if parsed is not None:
            return (0, parsed.timestamp(), item.get("id", ""))
    except Exception:
        pass
    return (1, float("inf"), item.get("id", ""))

selected = sorted(messages, key=sort_key)[0]
print(
    json.dumps(
        {
            "candidateCount": len(messages),
            "selectedMessage": selected,
        },
        indent=2,
    )
)
PY
)"

selected_message_id="$(
  python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["selectedMessage"]["id"])' \
    <<<"${selected_json}"
)"

selected_thread_id="$(
  python3 -c 'import json,sys; data=json.load(sys.stdin); print(data["selectedMessage"].get("threadId",""))' \
    <<<"${selected_json}"
)"

work_root="${work_root_base}/process-${selected_message_id}"
rm -rf "${work_root}"

if "${process_email_script}" "${selected_message_id}" "${work_root}" > /dev/null 2>"${process_stderr_path}"; then
  result_json_path="${work_root}/metadata/result.json"
  python3 - "${selected_json}" "${result_json_path}" "${work_root}" "${query}" <<'PY'
import json
import pathlib
import sys

selected = json.loads(sys.argv[1])
result = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))
work_root = sys.argv[3]
query = sys.argv[4]

print(
    json.dumps(
        {
            "ok": True,
            "status": "ready",
            "query": query,
            "candidateCount": selected["candidateCount"],
            "selectedMessage": selected["selectedMessage"],
            "workRoot": work_root,
            "processResultPath": sys.argv[2],
            "processResult": result,
        },
        indent=2,
    )
)
PY
  exit 0
else
  process_exit=$?
  process_error="$(cat "${process_stderr_path}")"

  if grep -qi "No publishable attachments found" "${process_stderr_path}"; then
    "${gmail_label_script}" "${selected_message_id}" add Tickets/Handled >/dev/null
    "${gmail_label_script}" "${selected_message_id}" remove Tickets/Ongoing >/dev/null || true
    python3 - "${selected_json}" "${selected_thread_id}" "${work_root}" "${process_error}" "${query}" <<'PY'
import json
import sys

selected = json.loads(sys.argv[1])
thread_id = sys.argv[2]
work_root = sys.argv[3]
reason = sys.argv[4].strip()
query = sys.argv[5]

print(
    json.dumps(
        {
            "ok": True,
            "status": "skipped_no_publishable_attachments",
            "query": query,
            "candidateCount": selected["candidateCount"],
            "selectedMessage": selected["selectedMessage"],
            "threadId": thread_id,
            "workRoot": work_root,
            "skipReason": reason,
            "labelsApplied": ["Tickets/Handled"],
            "labelsRemoved": ["Tickets/Ongoing"],
        },
        indent=2,
    )
)
PY
    exit 0
  fi

  printf '%s\n' "${process_error}" >&2
  exit "${process_exit}"
fi
