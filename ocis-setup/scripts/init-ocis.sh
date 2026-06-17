#!/usr/bin/env bash
set -euo pipefail

CONFIG_DIR="${OCIS_CONFIG_DIR_INPUT:-${HOME}/.ocis/config}"
mkdir -p "$CONFIG_DIR"

OCIS_URL="${OCIS_URL:-https://localhost:9200}" OCIS_CONFIG_DIR="$CONFIG_DIR" ocis init --insecure true

cp "${OCIS_ACTION_PATH}/config/app-registry.yaml" "${CONFIG_DIR}/app-registry.yaml"

echo "oCIS config initialized at ${CONFIG_DIR}"
