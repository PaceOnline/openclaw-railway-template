#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR

# Source env vars written by entrypoint (needed for isolated cron sessions)
if [[ -f "${SCRIPT_DIR}/.env" ]]; then
  set -a
  source "${SCRIPT_DIR}/.env"
  set +a
fi

log() {
  printf '[paceonline] %s\n' "$*" >&2
}

die() {
  local message="$1"
  local code="${2:-1}"
  log "ERROR: ${message}"
  exit "${code}"
}

require_cmd() {
  local command_name="$1"
  command -v "${command_name}" >/dev/null 2>&1 || die "Missing required command: ${command_name}" 2
}

require_env() {
  local missing=()
  local var_name
  for var_name in "$@"; do
    if [[ -z "${!var_name:-}" ]]; then
      missing+=("${var_name}")
    fi
  done

  if ((${#missing[@]} > 0)); then
    die "Missing required environment variables: ${missing[*]}" 2
  fi
}

is_true() {
  local value
  value="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]')"
  case "${value}" in
    1|true|yes|on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_dry_run() {
  is_true "${PACEONLINE_DRY_RUN:-false}"
}

urlencode() {
  require_cmd python3
  python3 - "$1" <<'PY'
import sys
import urllib.parse

print(urllib.parse.quote(sys.argv[1]))
PY
}

get_gmail_access_token() {
  require_cmd curl
  require_cmd python3
  require_env GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET GOOGLE_REFRESH_TOKEN

  local response
  local token

  response="$(
    curl -fsS -X POST "https://oauth2.googleapis.com/token" \
      -d "client_id=${GOOGLE_CLIENT_ID}" \
      -d "client_secret=${GOOGLE_CLIENT_SECRET}" \
      -d "refresh_token=${GOOGLE_REFRESH_TOKEN}" \
      -d "grant_type=refresh_token"
  )"

  token="$(
    GMAIL_TOKEN_RESPONSE="${response}" python3 - <<'PY'
import json
import os
import sys

data = json.loads(os.environ["GMAIL_TOKEN_RESPONSE"])
print(data.get("access_token", ""))
PY
  )"

  [[ -n "${token}" ]] || die "Failed to obtain Gmail access token" 2
  printf '%s\n' "${token}"
}

gmail_api() {
  local method="$1"
  local api_path="$2"
  local payload="${3-}"
  local access_token
  local url

  access_token="$(get_gmail_access_token)"
  url="https://gmail.googleapis.com/gmail/v1/users/me/${api_path}"

  if [[ -n "${payload}" ]]; then
    curl -fsS -X "${method}" \
      -H "Authorization: Bearer ${access_token}" \
      -H "Content-Type: application/json" \
      "${url}" \
      -d "${payload}"
  else
    curl -fsS -X "${method}" \
      -H "Authorization: Bearer ${access_token}" \
      "${url}"
  fi
}

get_label_id() {
  local label_name="$1"
  local labels_json

  labels_json="$(gmail_api GET "labels")"

  GMAIL_LABELS_JSON="${labels_json}" python3 - "$label_name" <<'PY'
import json
import os
import sys

target = sys.argv[1]
data = json.loads(os.environ["GMAIL_LABELS_JSON"])

for label in data.get("labels", []):
    if label.get("name") == target:
        print(label.get("id", ""))
        sys.exit(0)

sys.exit(1)
PY
}

prepare_aws_env() {
  require_env R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_ENDPOINT

  export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
  export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
  export AWS_DEFAULT_REGION="${AWS_DEFAULT_REGION:-auto}"
  export AWS_EC2_METADATA_DISABLED="true"
}

public_url_for_bucket() {
  local bucket="$1"
  local sites_file="${SCRIPT_DIR}/sites.json"
  if [[ -f "${sites_file}" ]]; then
    local url
    url="$(python3 -c "
import json, sys
with open('${sites_file}') as f:
    for s in json.load(f):
        if s['r2Bucket'] == '${bucket}':
            print(s['r2PublicUrl']); sys.exit(0)
sys.exit(1)
" 2>/dev/null)" && { printf '%s\n' "${url}"; return 0; }
  fi
  return 1
}

# Look up site config by email domain — returns JSON object for the matching site
site_for_email_domain() {
  local domain="$1"
  local sites_file="${SCRIPT_DIR}/sites.json"
  [[ -f "${sites_file}" ]] || return 1
  python3 -c "
import json, sys
with open('${sites_file}') as f:
    for s in json.load(f):
        if s['emailDomain'].lstrip('@') == '${domain}'.lstrip('@'):
            json.dump(s, sys.stdout); sys.exit(0)
sys.exit(1)
" 2>/dev/null
}

# List all email domains from sites.json (for Gmail search queries)
all_email_domains() {
  local sites_file="${SCRIPT_DIR}/sites.json"
  [[ -f "${sites_file}" ]] || return 1
  python3 -c "
import json
with open('${sites_file}') as f:
    domains = [s['emailDomain'] for s in json.load(f)]
print(' OR '.join(f'from:{d}' for d in domains))
" 2>/dev/null
}

github_repo_url() {
  local repo_slug="$1"
  printf 'https://github.com/%s.git\n' "${repo_slug}"
}

git_author_name() {
  printf '%s\n' "${GIT_COMMIT_USER_NAME:-PaceOnline Bot}"
}

git_author_email() {
  printf '%s\n' "${GIT_COMMIT_USER_EMAIL:-support@paceonline.co.za}"
}
