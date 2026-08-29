#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
ENV_FILE="${1:-${PROJECT_DIR}/.env}"

die() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

command -v envsubst >/dev/null 2>&1 || die "envsubst is required (Debian/Ubuntu: apt install gettext-base)"
command -v jq >/dev/null 2>&1 || die "jq is required (Debian/Ubuntu: apt install jq)"

[[ -f "${ENV_FILE}" ]] || die "Environment file not found: ${ENV_FILE}. Run: cp .env.example .env"

set -a
# shellcheck disable=SC1090
source "${ENV_FILE}"
set +a

required_variables=(
  DOMAIN ORIGIN_IP ORIGIN_PORT NGINX_INTERNAL_PORT XRAY_LISTEN_IP
  XRAY_XHTTP_PORT XRAY_INBOUND_TAG XHTTP_PATH ORIGIN_CERT_DAYS
  COVER_ROOT COVER_TITLE STREAM_MAP_DIR STREAM_MAP_FILE
  CONFIG_PROFILE_NAME SQUAD_NAME
)

for variable_name in "${required_variables[@]}"; do
  [[ -n "${!variable_name:-}" ]] || die "${variable_name} is empty"
done

[[ "${DOMAIN}" =~ ^[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?(\.[A-Za-z0-9]([A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$ ]] \
  || die "DOMAIN is invalid: ${DOMAIN}"

[[ "${ORIGIN_IP}" =~ ^[0-9A-Fa-f:.]+$ ]] || die "ORIGIN_IP contains unsupported characters"
[[ "${XRAY_LISTEN_IP}" =~ ^[0-9A-Fa-f:.]+$ ]] || die "XRAY_LISTEN_IP contains unsupported characters"
[[ "${XRAY_INBOUND_TAG}" =~ ^[A-Za-z0-9_-]+$ ]] || die "XRAY_INBOUND_TAG may contain only A-Z, a-z, 0-9, _ and -"
[[ "${XHTTP_PATH}" =~ ^/[A-Za-z0-9._~/-]+$ ]] || die "XHTTP_PATH must start with / and contain only URL-safe path characters"
[[ "${COVER_ROOT}" =~ ^/var/www/[A-Za-z0-9._/-]+$ ]] || die "COVER_ROOT must be a path below /var/www"
[[ "${STREAM_MAP_DIR}" =~ ^/etc/nginx/[A-Za-z0-9._/-]+$ ]] || die "STREAM_MAP_DIR must be a path below /etc/nginx"
[[ "${COVER_ROOT}" != *".."* ]] || die "COVER_ROOT may not contain .."
[[ "${STREAM_MAP_DIR}" != *".."* ]] || die "STREAM_MAP_DIR may not contain .."
[[ "${STREAM_MAP_FILE}" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*\.map$ ]] || die "STREAM_MAP_FILE must be a simple filename ending in .map"
SAFE_LABEL_REGEX='^[[:alnum:]_. -]+$'
[[ "${COVER_TITLE}" =~ ${SAFE_LABEL_REGEX} ]] || die "COVER_TITLE contains unsupported characters"
[[ "${CONFIG_PROFILE_NAME}" =~ ${SAFE_LABEL_REGEX} ]] || die "CONFIG_PROFILE_NAME contains unsupported characters"
[[ "${SQUAD_NAME}" =~ ${SAFE_LABEL_REGEX} ]] || die "SQUAD_NAME contains unsupported characters"

for port_name in ORIGIN_PORT NGINX_INTERNAL_PORT XRAY_XHTTP_PORT; do
  port_value="${!port_name}"
  [[ "${port_value}" =~ ^[0-9]+$ ]] || die "${port_name} must be numeric"
  (( port_value >= 1 && port_value <= 65535 )) || die "${port_name} must be between 1 and 65535"
done

[[ "${ORIGIN_CERT_DAYS}" =~ ^[0-9]+$ ]] || die "ORIGIN_CERT_DAYS must be numeric"
(( ORIGIN_CERT_DAYS >= 1 && ORIGIN_CERT_DAYS <= 36500 )) || die "ORIGIN_CERT_DAYS must be between 1 and 36500"

BUILD_DIR="${PROJECT_DIR}/build/${DOMAIN}"
mkdir -p "${BUILD_DIR}"

export DOMAIN ORIGIN_IP ORIGIN_PORT NGINX_INTERNAL_PORT XRAY_LISTEN_IP
export XRAY_XHTTP_PORT XRAY_INBOUND_TAG XHTTP_PATH ORIGIN_CERT_DAYS
export COVER_ROOT COVER_TITLE STREAM_MAP_DIR STREAM_MAP_FILE
export CONFIG_PROFILE_NAME SQUAD_NAME

SUBST_VARIABLES='${DOMAIN} ${ORIGIN_IP} ${ORIGIN_PORT} ${NGINX_INTERNAL_PORT} ${XRAY_LISTEN_IP} ${XRAY_XHTTP_PORT} ${XRAY_INBOUND_TAG} ${XHTTP_PATH} ${ORIGIN_CERT_DAYS} ${COVER_ROOT} ${COVER_TITLE} ${STREAM_MAP_DIR} ${STREAM_MAP_FILE} ${CONFIG_PROFILE_NAME} ${SQUAD_NAME}'

render() {
  local source_file="$1"
  local destination_file="$2"
  envsubst "${SUBST_VARIABLES}" < "${source_file}" > "${destination_file}"
}

render "${PROJECT_DIR}/templates/nginx-site.conf.template" "${BUILD_DIR}/nginx-site.conf"
render "${PROJECT_DIR}/templates/nginx-stream-map-entry.conf.template" "${BUILD_DIR}/nginx-stream-map-entry.map"
render "${PROJECT_DIR}/templates/xray-inbound.json.template" "${BUILD_DIR}/xray-inbound.json"
render "${PROJECT_DIR}/templates/remnawave-xhttp-extra.json.template" "${BUILD_DIR}/remnawave-xhttp-extra.json"
render "${PROJECT_DIR}/templates/remnawave-host-values.md.template" "${BUILD_DIR}/remnawave-host-values.md"

jq empty "${BUILD_DIR}/xray-inbound.json"
jq empty "${BUILD_DIR}/remnawave-xhttp-extra.json"

chmod 600 "${BUILD_DIR}"/*

printf 'Generated configuration: %s\n' "${BUILD_DIR}"
printf '  - nginx-site.conf\n'
printf '  - nginx-stream-map-entry.map\n'
printf '  - xray-inbound.json\n'
printf '  - remnawave-xhttp-extra.json\n'
printf '  - remnawave-host-values.md\n'
