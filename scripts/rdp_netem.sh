#!/usr/bin/env bash
set -euo pipefail

# RDP network emulation for macOS using pf + dummynet
# Usage:
#   sudo ./rdp_netem.sh start --host 192.168.64.2 --port 3389 --loss 2 --delay 50
#   sudo ./rdp_netem.sh status
#   sudo ./rdp_netem.sh stop
#
# Notes:
# - Targets outbound traffic TO host:port (default TCP/3389).
# - Applies delay+loss via dummynet pipe.
# - Restores pf rules and disables dummynet on stop.

CMD="${1:-}"
shift || true

HOST=""
PORT="3389"
LOSS="2"     # percent
DELAY="50"   # ms
PIPE_ID="3389"
ANCHOR_NAME="cautus_rdp_netem"
PF_CONF_PATH="/etc/pf.conf"
PF_BAK_PATH="/tmp/pf.conf.cautus.bak"
ANCHOR_RULES_PATH="/tmp/pf.anchors.${ANCHOR_NAME}.conf"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"; }

require_sudo() {
  if [[ "${EUID}" -ne 0 ]]; then
    echo "ERROR: must be run as root (use sudo)" >&2
    exit 1
  fi
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host) HOST="$2"; shift 2 ;;
      --port) PORT="$2"; shift 2 ;;
      --loss) LOSS="$2"; shift 2 ;;
      --delay) DELAY="$2"; shift 2 ;;
      --pipe) PIPE_ID="$2"; shift 2 ;;
      *) echo "Unknown arg: $1" >&2; exit 2 ;;
    esac
  done

  if [[ -z "${HOST}" && "${CMD}" == "start" ]]; then
    echo "ERROR: --host is required for start (avoid affecting all RDP traffic)" >&2
    exit 2
  fi
}

pf_has_anchor() {
  pfctl -s Anchors 2>/dev/null | grep -q "^${ANCHOR_NAME}$" || return 1
}

start_netem() {
  require_sudo
  parse_args "$@"

  log "Starting RDP netem: host=${HOST} port=${PORT} loss=${LOSS}% delay=${DELAY}ms pipe=${PIPE_ID}"

  # 1) Configure dummynet pipe
  # Flush existing pipe config for id
  dnctl -q pipe delete "${PIPE_ID}" >/dev/null 2>&1 || true
  dnctl pipe "${PIPE_ID}" config delay "${DELAY}ms" plr "$(awk "BEGIN {print ${LOSS}/100}")"

  # 2) Create anchor rules to divert matching traffic into dummynet pipe
  # Use 'dummynet in' on outbound packets to destination host:port
  cat > "${ANCHOR_RULES_PATH}" <<EOF
# Cautus RDP netem rules (auto-generated)
dummynet out proto tcp from any to ${HOST} port ${PORT} pipe ${PIPE_ID}
EOF

  # 3) Ensure /etc/pf.conf loads the anchor; back it up first if we haven't
  if [[ ! -f "${PF_BAK_PATH}" ]]; then
    cp "${PF_CONF_PATH}" "${PF_BAK_PATH}"
    log "Backed up ${PF_CONF_PATH} to ${PF_BAK_PATH}"
  fi

  if ! grep -q "anchor \"${ANCHOR_NAME}\"" "${PF_CONF_PATH}"; then
    log "Adding anchor load lines to ${PF_CONF_PATH}"
    cat >> "${PF_CONF_PATH}" <<EOF

# --- Cautus RDP netem anchor (added by rdp_netem.sh) ---
anchor "${ANCHOR_NAME}"
load anchor "${ANCHOR_NAME}" from "${ANCHOR_RULES_PATH}"
# --- end ---
EOF
  else
    log "Anchor lines already present in ${PF_CONF_PATH}"
  fi

  # 4) Enable pf + load rules
  pfctl -f "${PF_CONF_PATH}"
  pfctl -E >/dev/null 2>&1 || true

  log "Applied. Verify with: sudo ./rdp_netem.sh status"
}

status_netem() {
  require_sudo
  log "pf enabled?"; pfctl -s info | sed -n '1,5p' || true
  log "Anchor present?"; pfctl -s Anchors | grep -E "^${ANCHOR_NAME}$" || echo "(not found)"
  log "Anchor rules:"; pfctl -a "${ANCHOR_NAME}" -s rules 2>/dev/null || echo "(none loaded)"
  log "Dummynet pipe:"; dnctl pipe show "${PIPE_ID}" 2>/dev/null || echo "(pipe not found)"
}

stop_netem() {
  require_sudo
  log "Stopping RDP netem: pipe=${PIPE_ID}"

  # Remove dummynet pipe
  dnctl -q pipe delete "${PIPE_ID}" >/dev/null 2>&1 || true

  # Restore pf.conf if we have a backup (most reliable cleanup)
  if [[ -f "${PF_BAK_PATH}" ]]; then
    cp "${PF_BAK_PATH}" "${PF_CONF_PATH}"
    rm -f "${PF_BAK_PATH}"
    log "Restored ${PF_CONF_PATH} from backup"
  else
    log "No pf.conf backup found; leaving pf.conf unchanged"
  fi

  # Remove anchor rules file
  rm -f "${ANCHOR_RULES_PATH}" || true

  # Reload pf rules
  pfctl -f "${PF_CONF_PATH}" >/dev/null 2>&1 || true

  log "Netem stopped. (pf remains enabled if it was enabled before.)"
}

case "${CMD}" in
  start) start_netem "$@" ;;
  status) status_netem ;;
  stop) stop_netem ;;
  *)
    cat <<EOF
Usage:
  sudo $0 start --host <ip-or-hostname> [--port 3389] [--loss 2] [--delay 50] [--pipe 3389]
  sudo $0 status
  sudo $0 stop
EOF
    exit 1
    ;;
esac
