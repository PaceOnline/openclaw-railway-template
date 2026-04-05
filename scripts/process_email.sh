#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -lt 1 || $# -gt 2 ]]; then
  die "Usage: $0 <message_id> [work_root]" 1
fi

message_id="$1"
work_root="${2:-/data/workspace/tmp/process-${message_id}}"
metadata_dir="${work_root}/metadata"
attachments_dir="${work_root}/attachments"
message_json_path="${metadata_dir}/message.json"
body_text_path="${metadata_dir}/body.txt"
analysis_json_path="${metadata_dir}/analysis.json"
site_json_path="${metadata_dir}/site.json"
uploads_json_path="${metadata_dir}/uploads.json"
result_json_path="${metadata_dir}/result.json"

require_cmd python3

mkdir -p "${metadata_dir}" "${attachments_dir}"

json_get() {
  local json_file="$1"
  local key_path="$2"
  python3 - "${json_file}" "${key_path}" <<'PY'
import json
import sys

with open(sys.argv[1], "r", encoding="utf-8") as handle:
    data = json.load(handle)

value = data
for part in sys.argv[2].split("."):
    if not part:
        continue
    if isinstance(value, dict):
        value = value.get(part)
    else:
        raise SystemExit(1)

if value is None:
    raise SystemExit(1)

if isinstance(value, (dict, list)):
    print(json.dumps(value))
else:
    print(value)
PY
}

message_json="$(gmail_api GET "messages/${message_id}?format=full")"
printf '%s' "${message_json}" > "${message_json_path}"

python3 - "${message_json_path}" "${analysis_json_path}" "${body_text_path}" <<'PY'
import base64
import email.utils
import json
import pathlib
import re
import sys

message_path, analysis_path, body_path = sys.argv[1:4]
data = json.loads(pathlib.Path(message_path).read_text(encoding="utf-8"))

headers = {}
for header in (data.get("payload") or {}).get("headers") or []:
    name = header.get("name", "").lower()
    if name and name not in headers:
        headers[name] = header.get("value", "")


def decode_body(body: dict) -> str:
    raw = body.get("data") or ""
    if not raw:
        return ""
    padded = raw + "=" * (-len(raw) % 4)
    return base64.urlsafe_b64decode(padded.encode("utf-8")).decode("utf-8", "replace")


def strip_html(value: str) -> str:
    value = re.sub(r"(?is)<(script|style).*?>.*?</\1>", " ", value)
    value = re.sub(r"(?s)<[^>]+>", " ", value)
    value = value.replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", value).strip()


def sanitize_filename(name: str, used: set[str]) -> str:
    base = pathlib.Path(name).name.strip()
    base = re.sub(r"[^A-Za-z0-9._-]+", "-", base)
    base = base.strip("-._") or "attachment"
    stem, suffix = pathlib.Path(base).stem, pathlib.Path(base).suffix
    candidate = base
    counter = 2
    while candidate.lower() in used:
        candidate = f"{stem}-{counter}{suffix}"
        counter += 1
    used.add(candidate.lower())
    return candidate


def walk(part: dict, attachments: list[dict], plain_chunks: list[str], html_chunks: list[str]) -> None:
    mime_type = (part.get("mimeType") or "").lower()
    filename = part.get("filename") or ""
    body = part.get("body") or {}
    attachment_id = body.get("attachmentId") or ""
    size = body.get("size") or 0

    if mime_type == "text/plain":
        content = decode_body(body)
        if content:
            plain_chunks.append(content)
    elif mime_type == "text/html":
        content = decode_body(body)
        if content:
            html_chunks.append(content)

    if filename and attachment_id:
        attachments.append(
            {
                "filename": filename,
                "attachmentId": attachment_id,
                "mimeType": mime_type,
                "size": size,
            }
        )

    for child in part.get("parts") or []:
        walk(child, attachments, plain_chunks, html_chunks)


def keep_attachment(item: dict) -> tuple[bool, str]:
    filename = pathlib.Path(item["filename"]).name
    filename_lower = filename.lower()
    mime_type = (item.get("mimeType") or "").lower()
    size = int(item.get("size") or 0)
    ext = pathlib.Path(filename_lower).suffix

    signature_patterns = (
        r"^image\d+\.(png|jpe?g|gif|bmp|webp)$",
        r"^outlook-.*\.(png|jpe?g|gif|bmp|webp)$",
        r"^smime\.p7s$",
        r"^(logo|signature|facebook|instagram|linkedin|twitter)[-_0-9.].*",
    )
    for pattern in signature_patterns:
        if re.match(pattern, filename_lower):
            return False, "signature-artifact"

    blocked_exts = {".ics", ".vcf", ".eml"}
    if ext in blocked_exts:
        return False, "unsupported-sidecar"

    allowed_exts = {
        ".pdf",
        ".doc",
        ".docx",
        ".xls",
        ".xlsx",
        ".csv",
        ".ppt",
        ".pptx",
        ".zip",
        ".rar",
        ".7z",
        ".txt",
        ".png",
        ".jpg",
        ".jpeg",
        ".gif",
        ".webp",
    }
    if ext in {".png", ".jpg", ".jpeg", ".gif", ".webp"}:
        if size < 50000:
            return False, "small-inline-image"
        return True, "image"

    if ext in allowed_exts:
        return True, "document"

    if mime_type.startswith("application/"):
        return True, "application"

    return False, "unsupported-type"


attachments: list[dict] = []
plain_chunks: list[str] = []
html_chunks: list[str] = []
walk(data.get("payload") or {}, attachments, plain_chunks, html_chunks)

body_text = "\n\n".join(chunk.strip() for chunk in plain_chunks if chunk.strip()).strip()
if not body_text:
    body_text = "\n\n".join(strip_html(chunk) for chunk in html_chunks if chunk.strip()).strip()

used_names: set[str] = set()
selected = []
skipped = []
for item in attachments:
    keep, reason = keep_attachment(item)
    item = dict(item)
    item["reason"] = reason
    item["sanitizedFilename"] = sanitize_filename(item["filename"], used_names)
    if keep:
        selected.append(item)
    else:
        skipped.append(item)

from_header = headers.get("from", "")
email_match = re.search(r"<([^>]+)>", from_header)
sender_email = (email_match.group(1) if email_match else from_header).strip()
sender_domain = sender_email.rsplit("@", 1)[1].lower() if "@" in sender_email else ""

header_message_id = headers.get("message-id", "")
date_header = headers.get("date", "")
published_at = ""
date_path = ""
if date_header:
    try:
        parsed = email.utils.parsedate_to_datetime(date_header)
        if parsed is not None:
            published_at = parsed.isoformat()
            date_path = parsed.strftime("%Y/%m/%d")
    except Exception:
        pass

pathlib.Path(body_path).write_text(body_text, encoding="utf-8")

analysis = {
    "messageId": data.get("id") or "",
    "threadId": data.get("threadId") or "",
    "gmailMessageIdHeader": header_message_id,
    "subject": headers.get("subject", ""),
    "from": from_header,
    "senderEmail": sender_email,
    "senderDomain": sender_domain,
    "dateHeader": date_header,
    "publishedAt": published_at,
    "datePath": date_path,
    "snippet": data.get("snippet", ""),
    "bodyTextPath": body_path,
    "attachmentCount": len(selected),
    "selectedAttachments": selected,
    "skippedAttachments": skipped,
}
pathlib.Path(analysis_path).write_text(json.dumps(analysis, indent=2), encoding="utf-8")
PY

sender_domain="$(json_get "${analysis_json_path}" "senderDomain")" || die "Could not determine sender domain for Gmail message ${message_id}" 1
site_json="$(site_for_email_domain "${sender_domain}")" || die "No site config found for sender domain ${sender_domain}" 1
printf '%s' "${site_json}" > "${site_json_path}"

attachment_count="$(json_get "${analysis_json_path}" "attachmentCount")" || attachment_count="0"
if [[ "${attachment_count}" == "0" ]]; then
  die "No publishable attachments found on Gmail message ${message_id}" 1
fi

site_id="$(json_get "${site_json_path}" "id")"
repo_slug="$(json_get "${site_json_path}" "gitRepo")"
repo_dir_name="$(json_get "${site_json_path}" "repoDir")"
r2_bucket="$(json_get "${site_json_path}" "r2Bucket")"
date_path="$(json_get "${analysis_json_path}" "datePath" || true)"

if [[ -z "${date_path}" ]]; then
  date_path="$(date '+%Y/%m/%d')"
fi

python3 - "${analysis_json_path}" "${attachments_dir}" "${uploads_json_path}" "${date_path}" "${message_id}" "${r2_bucket}" <<'PY'
import json
import pathlib
import sys

analysis_path, attachments_dir, uploads_path, date_path, message_id, bucket = sys.argv[1:7]
analysis = json.loads(pathlib.Path(analysis_path).read_text(encoding="utf-8"))

planned = []
for index, item in enumerate(analysis["selectedAttachments"], start=1):
    local_path = pathlib.Path(attachments_dir) / f"{index:02d}-{item['sanitizedFilename']}"
    object_key = f"images/downloads/{date_path}/{message_id}/{item['sanitizedFilename']}"
    planned.append(
        {
            "index": index,
            "attachmentId": item["attachmentId"],
            "filename": item["filename"],
            "sanitizedFilename": item["sanitizedFilename"],
            "mimeType": item.get("mimeType") or "",
            "size": item.get("size") or 0,
            "localPath": str(local_path),
            "objectKey": object_key,
            "bucket": bucket,
        }
    )

pathlib.Path(uploads_path).write_text(json.dumps(planned, indent=2), encoding="utf-8")
PY

python3 - "${uploads_json_path}" <<'PY' | while IFS=$'\t' read -r attachment_id local_path object_key; do
import json
import pathlib
import sys

planned = json.loads(pathlib.Path(sys.argv[1]).read_text(encoding="utf-8"))
for item in planned:
    print(f"{item['attachmentId']}\t{item['localPath']}\t{item['objectKey']}")
PY
  [[ -n "${attachment_id}" ]] || continue
  "${SCRIPT_DIR}/gmail_download_attachment.sh" "${message_id}" "${attachment_id}" "${local_path}" >/dev/null
done

python3 - "${uploads_json_path}" "${site_json_path}" "${SCRIPT_DIR}" <<'PY' > "${uploads_json_path}.tmp"
import json
import pathlib
import subprocess
import sys

uploads_path, site_path, script_dir = sys.argv[1:4]
items = json.loads(pathlib.Path(uploads_path).read_text(encoding="utf-8"))
site = json.loads(pathlib.Path(site_path).read_text(encoding="utf-8"))
r2_upload = pathlib.Path(script_dir) / "r2_upload.sh"

result = []
for item in items:
    command = [str(r2_upload), site["r2Bucket"], item["localPath"], item["objectKey"]]
    public_url = subprocess.check_output(command, text=True).strip()
    row = dict(item)
    row["publicUrl"] = public_url
    result.append(row)

print(json.dumps(result, indent=2))
PY
mv "${uploads_json_path}.tmp" "${uploads_json_path}"

repo_path="/data/repos/${repo_dir_name}"
"${SCRIPT_DIR}/git_clone.sh" "${repo_slug}" "${repo_path}" >/dev/null

python3 - "${site_json_path}" "${analysis_json_path}" "${uploads_json_path}" "${result_json_path}" "${repo_path}" "${message_json_path}" "${body_text_path}" <<'PY'
import json
import pathlib
import sys

site_path, analysis_path, uploads_path, result_path, repo_path, message_json_path, body_text_path = sys.argv[1:8]
site = json.loads(pathlib.Path(site_path).read_text(encoding="utf-8"))
analysis = json.loads(pathlib.Path(analysis_path).read_text(encoding="utf-8"))
uploads = json.loads(pathlib.Path(uploads_path).read_text(encoding="utf-8"))
repo = pathlib.Path(repo_path)

guidance_candidates = []
if repo.exists():
    for candidate in [
        "CONTENT-MANAGEMENT.md",
        "WEBSITE-MAINTENANCE.md",
        "AGENTS.md",
        "MAINTENANCE.md",
        "html/CONTENT-MANAGEMENT.md",
        "html/WEBSITE-MAINTENANCE.md",
        "site/AGENTS.md",
        "site/MAINTENANCE.md",
    ]:
        target = repo / candidate
        if target.exists():
            guidance_candidates.append(str(target))

result = {
    "ok": True,
    "messageId": analysis["messageId"],
    "threadId": analysis["threadId"],
    "sender": analysis["from"],
    "senderEmail": analysis["senderEmail"],
    "senderDomain": analysis["senderDomain"],
    "subject": analysis["subject"],
    "dateHeader": analysis["dateHeader"],
    "publishedAt": analysis["publishedAt"],
    "snippet": analysis["snippet"],
    "bodyTextPath": body_text_path,
    "messageJsonPath": message_json_path,
    "site": {
        "id": site["id"],
        "name": site["name"],
        "domain": site["domain"],
        "emailDomain": site["emailDomain"],
        "r2Bucket": site["r2Bucket"],
        "r2PublicUrl": site["r2PublicUrl"],
        "gitRepo": site["gitRepo"],
        "repoDir": site["repoDir"],
        "repoPath": repo_path,
    },
    "uploadedFiles": uploads,
    "repoGuidanceCandidates": guidance_candidates,
    "targetLookupCommand": (
        f"python3 scripts/site_lookup.py --sender {analysis['senderEmail']!r} "
        f"--content-type <decide-after-reading-email> --pretty"
    ),
    "skipReasonsObserved": [item["reason"] for item in analysis["skippedAttachments"]],
}
pathlib.Path(result_path).write_text(json.dumps(result, indent=2), encoding="utf-8")
print(json.dumps(result, indent=2))
PY
