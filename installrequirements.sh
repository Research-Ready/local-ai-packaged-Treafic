#!/usr/bin/env bash
# Idempotent prerequisites installer for Debian 12 (run as root, no sudo).
set -euo pipefail

log(){ printf "\033[1;32m[OK]\033[0m %s\n" "$*"; }
info(){ printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err(){ printf "\033[1;31m[ERR]\033[0m %s\n" "$*" >&2; }

require_root() {
  if [ "$(id -u)" -ne 0 ]; then
    err "Run as root (no sudo)."
    exit 1
  fi
}

has_cmd(){ command -v "$1" >/dev/null 2>&1; }

apt_install_if_missing() {
  # Installs packages only if any of them are missing.
  local missing=()
  for pkg in "$@"; do
    dpkg -s "$pkg" >/dev/null 2>&1 || missing+=("$pkg")
  done
  if [ "${#missing[@]}" -gt 0 ]; then
    info "Installing: ${missing[*]}"
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y
    apt-get install -y "${missing[@]}"
    log "Installed: ${missing[*]}"
  else
    log "All requested packages already present: $*"
  fi
}

ensure_docker_repo() {
  # Adds Docker's official apt repo only if not present.
  local list="/etc/apt/sources.list.d/docker.list"
  local key="/etc/apt/keyrings/docker.gpg"

  if [ -f "$list" ] && grep -q "download.docker.com" "$list"; then
    log "Docker apt repository already configured."
    return 0
  fi

  info "Configuring Docker apt repository…"
  install -m 0755 -d /etc/apt/keyrings
  if [ ! -f "$key" ]; then
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o "$key"
    chmod a+r "$key"
  fi

  . /etc/os-release
  echo \
"deb [arch=$(dpkg --print-architecture) signed-by=$key] https://download.docker.com/linux/debian ${VERSION_CODENAME} stable" \
  > "$list"

  apt-get update -y
  log "Docker repository added."
}

ensure_docker_engine() {
  if has_cmd docker && has_cmd docker-compose; then
    # docker-compose (v1) might exist; we still want the compose plugin (v2).
    :
  fi

  if has_cmd docker; then
    log "Docker already installed: $(docker --version || true)"
  else
    info "Installing Docker Engine + CLI…"
    apt_install_if_missing docker-ce docker-ce-cli containerd.io
  fi

  # Compose plugin (v2)
  if docker compose version >/dev/null 2>&1; then
    log "Docker Compose plugin already installed: $(docker compose version | head -n1)"
  else
    info "Installing Docker Compose plugin…"
    apt_install_if_missing docker-buildx-plugin docker-compose-plugin
  fi

  # Enable/start docker service if not active
  if systemctl is-enabled docker >/dev/null 2>&1; then
    :
  else
    info "Enabling docker service…"
    systemctl enable docker
  fi

  if systemctl is-active docker >/dev/null 2>&1; then
    log "Docker service already active."
  else
    info "Starting docker service…"
    systemctl start docker
    log "Docker service started."
  fi
}

main() {
  require_root

  info "Installing baseline tools (idempotent)…"
  apt_install_if_missing \
    ca-certificates curl wget gnupg lsb-release \
    git jq openssl \
    python3 python3-venv python3-pip \
    iproute2 net-tools traceroute \
    apt-transport-https

  # Set up Docker repo & engine (only if needed)
  ensure_docker_repo
  ensure_docker_engine

  log "All prerequisites ready."
  echo
  echo "Next steps (manual):"
  echo "  1) git clone https://github.com/Research-Ready/local-ai-packaged.git -b Research-ReadyBranch /opt/local-ai-packaged"
  echo "  2) cd /opt/local-ai-packaged"
  echo "  3) Create and edit your .env (do NOT commit secrets)."
  echo "  4) Start with:   python3 start_services.py --profile cpu --environment public"
  echo "     or fallback:  docker compose -f docker-compose.yml --profile cpu up -d"
}

main "$@"
