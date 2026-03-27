#!/bin/bash
set -e

STATE_DIR="${OPENCLAW_STATE_DIR:-/data/.openclaw}"
WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/data/workspace}"
SCRIPT_SOURCE_DIR="/app/scripts"
SCRIPT_TARGET_DIR="${WORKSPACE_DIR}/scripts"

chown -R openclaw:openclaw /data
chmod 700 /data

if [ ! -d /data/.linuxbrew ]; then
  cp -a /home/linuxbrew/.linuxbrew /data/.linuxbrew
fi

rm -rf /home/linuxbrew/.linuxbrew
ln -sfn /data/.linuxbrew /home/linuxbrew/.linuxbrew

mkdir -p "${STATE_DIR}" "${WORKSPACE_DIR}" "${SCRIPT_TARGET_DIR}" /data/repos

if [ -d "${SCRIPT_SOURCE_DIR}" ]; then
  cp -f "${SCRIPT_SOURCE_DIR}"/*.sh "${SCRIPT_TARGET_DIR}/"
  chmod 755 "${SCRIPT_TARGET_DIR}"/*.sh
fi

chown -R openclaw:openclaw "${STATE_DIR}" "${WORKSPACE_DIR}" /data/repos

gosu openclaw git config --global user.email "${GIT_COMMIT_USER_EMAIL:-support@paceonline.co.za}"
gosu openclaw git config --global user.name "${GIT_COMMIT_USER_NAME:-PaceOnline Bot}"
gosu openclaw git config --global init.defaultBranch main
gosu openclaw git config --global credential.useHttpPath true
gosu openclaw git config --global credential.helper \
  '!f() { test "$1" = get || exit 0; if [ -n "${GITHUB_USERNAME:-}" ]; then echo "username=${GITHUB_USERNAME}"; else echo "username=x-access-token"; fi; if [ -n "${GITHUB_TOKEN:-}" ]; then echo "password=${GITHUB_TOKEN}"; fi; }; f'

exec gosu openclaw node src/server.js
