#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/common.sh"

if [[ $# -ne 3 ]]; then
  die "Usage: $0 <bucket_name> <local_file_path> <r2_object_key>" 1
fi

bucket_name="$1"
local_file="$2"
object_key="$3"

[[ -f "${local_file}" ]] || die "Local file not found: ${local_file}" 1

public_url="$(public_url_for_bucket "${bucket_name}")" || die "Unknown R2 bucket: ${bucket_name}" 1

if is_dry_run; then
  log "DRY RUN: would upload ${local_file} to s3://${bucket_name}/${object_key}"
  printf '%s\n' "${public_url}/${object_key}"
  exit 0
fi

require_cmd aws
prepare_aws_env

aws s3 cp "${local_file}" "s3://${bucket_name}/${object_key}" \
  --endpoint-url "${R2_ENDPOINT}" \
  --no-progress >/dev/null

printf '%s\n' "${public_url}/${object_key}"
