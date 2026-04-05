#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

write_test="false"
for arg in "$@"; do
  case "${arg}" in
    --write-test)
      write_test="true"
      ;;
    *)
      die "Unknown argument: ${arg}" 1
      ;;
  esac
done

require_cmd curl
require_cmd git
require_cmd python3
require_cmd jq
require_cmd aws

require_env \
  GOOGLE_CLIENT_ID \
  GOOGLE_CLIENT_SECRET \
  GOOGLE_REFRESH_TOKEN \
  R2_ACCESS_KEY_ID \
  R2_SECRET_ACCESS_KEY \
  R2_ENDPOINT \
  GITHUB_TOKEN

gmail_token="$(get_gmail_access_token)"
[[ -n "${gmail_token}" ]] || die "Gmail token check failed" 2
log "Gmail token acquisition passed."

gmail_api GET "labels" >/dev/null
log "Gmail labels API check passed."

prepare_aws_env
verify_bucket="${PACEONLINE_VERIFY_BUCKET:-bushbuckridge-media}"
aws s3 ls "s3://${verify_bucket}" --endpoint-url "${R2_ENDPOINT}" >/dev/null
log "R2 list check passed for ${verify_bucket}."

if is_true "${write_test}"; then
  temp_dir="$(mktemp -d)"
  temp_file="${temp_dir}/paceonline-r2-check.txt"
  test_key="healthchecks/paceonline-$(date +%Y%m%d%H%M%S).txt"

  printf 'ok\n' > "${temp_file}"
  aws s3 cp "${temp_file}" "s3://${verify_bucket}/${test_key}" \
    --endpoint-url "${R2_ENDPOINT}" \
    --no-progress >/dev/null
  aws s3 rm "s3://${verify_bucket}/${test_key}" \
    --endpoint-url "${R2_ENDPOINT}" >/dev/null
  rm -rf "${temp_dir}"
  log "R2 write/delete check passed for ${verify_bucket}."
fi

verify_repo="${PACEONLINE_VERIFY_REPO:-PaceOnline/bbr}"
git ls-remote "$(github_repo_url "${verify_repo}")" >/dev/null
log "GitHub auth check passed for ${verify_repo}."

printf '%s\n' "verify_setup.sh completed successfully."
