#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
Usage: bootstrap_server.sh [app-root] [options]

Bootstraps an Ubuntu server for the production deploy stack:
- installs base operator packages
- installs/updates Docker Engine + Docker Compose plugin
- prepares /opt/wukongim-prod style runtime directories
- optionally configures UFW for the published ports
- optionally adds a user to the docker group

Arguments:
  app-root                    Target app root (default: /opt/wukongim-prod)

Options:
  --app-root <path>           Explicit target app root
  --docker-user <name>        User to add to docker group
  --skip-docker-install       Skip Docker installation steps
  --skip-firewall             Skip UFW configuration
  -h, --help                  Show this help
EOF
}

log() {
    printf '[bootstrap] %s\n' "$*"
}

die() {
    printf '[bootstrap][error] %s\n' "$*" >&2
    exit 1
}

run_as_root() {
    if [[ "$(id -u)" -eq 0 ]]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || die "sudo is required when not running as root."
        sudo "$@"
    fi
}

APP_ROOT="/opt/wukongim-prod"
DOCKER_USER="${SUDO_USER:-$(id -un)}"
SKIP_DOCKER_INSTALL=0
SKIP_FIREWALL=0

POSITIONAL_APP_ROOT=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --app-root)
            [[ $# -ge 2 ]] || die "--app-root requires a value."
            APP_ROOT="$2"
            shift 2
            ;;
        --docker-user)
            [[ $# -ge 2 ]] || die "--docker-user requires a value."
            DOCKER_USER="$2"
            shift 2
            ;;
        --skip-docker-install)
            SKIP_DOCKER_INSTALL=1
            shift
            ;;
        --skip-firewall)
            SKIP_FIREWALL=1
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            die "Unknown argument: $1"
            ;;
        *)
            if [[ -n "${POSITIONAL_APP_ROOT}" ]]; then
                die "Only one app root may be provided."
            fi
            POSITIONAL_APP_ROOT="$1"
            shift
            ;;
    esac
done

if [[ -n "${POSITIONAL_APP_ROOT}" ]]; then
    APP_ROOT="${POSITIONAL_APP_ROOT}"
fi

APP_ROOT="$(cd "$(dirname "${APP_ROOT}")" && pwd)/$(basename "${APP_ROOT}")"
SRC_ROOT="${APP_ROOT}/src"
PROD_DIR="${SRC_ROOT}/deploy/production"
ENV_FILE="${PROD_DIR}/.env"

PUBLIC_HTTP_PORT=80
PUBLIC_HTTPS_PORT=443
PUBLIC_WK_API_PORT=5001
PUBLIC_WK_API_BIND="127.0.0.1:5001"

load_port_config() {
    if [[ ! -f "${ENV_FILE}" ]]; then
        log "No .env found at ${ENV_FILE}; using default published ports."
        return
    fi

    log "Loading published ports from ${ENV_FILE}."
    local value

    value="$(read_env_value PUBLIC_HTTP_PORT)"
    if [[ -n "${value}" ]]; then
        PUBLIC_HTTP_PORT="${value}"
    fi

    value="$(read_env_value PUBLIC_HTTPS_PORT)"
    if [[ -n "${value}" ]]; then
        PUBLIC_HTTPS_PORT="${value}"
    fi

    value="$(read_env_value PUBLIC_WK_API_PORT)"
    if [[ -n "${value}" ]]; then
        PUBLIC_WK_API_PORT="${value}"
    fi

    value="$(read_env_value PUBLIC_WK_API_BIND)"
    if [[ -n "${value}" ]]; then
        PUBLIC_WK_API_BIND="${value}"
    fi
}

read_env_value() {
    local key="$1"
    local line

    line="$(grep -E "^${key}=" "${ENV_FILE}" | tail -n 1 || true)"
    if [[ -z "${line}" ]]; then
        return 0
    fi

    printf '%s\n' "${line#*=}"
}

extract_published_port() {
    local binding="$1"
    if [[ "${binding}" =~ ^[0-9]+$ ]]; then
        printf '%s\n' "${binding}"
        return 0
    fi

    if [[ "${binding}" =~ ^[^:]+:([0-9]+)$ ]]; then
        printf '%s\n' "${BASH_REMATCH[1]}"
        return 0
    fi

    return 1
}

is_host_local_bind() {
    local binding="$1"
    [[ "${binding}" =~ ^127\.0\.0\.1: ]] || [[ "${binding}" =~ ^localhost: ]] || [[ "${binding}" =~ ^::1: ]] || [[ "${binding}" =~ ^\[::1\]: ]]
}

allow_tcp_port_if_public() {
    local binding="$1"
    local fallback_port="$2"
    local port="${fallback_port}"

    if ! extract_published_port "${binding}" >/dev/null 2>&1; then
        log "Could not parse published port from '${binding}', falling back to ${fallback_port}."
    else
        port="$(extract_published_port "${binding}")"
    fi

    if is_host_local_bind "${binding}"; then
        log "Skipping UFW allow for host-local bind ${binding}."
        return
    fi

    run_as_root ufw allow "${port}/tcp"
}

install_base_packages() {
    log "Installing base packages."
    run_as_root apt-get update -y
    run_as_root apt-get install -y \
        ca-certificates \
        curl \
        gnupg \
        jq \
        lsb-release \
        python3 \
        python3-pip \
        python3-venv \
        tar \
        ufw
}

install_docker() {
    if command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
        log "Docker and docker compose already available; skipping install."
        return
    fi

    [[ -f /etc/os-release ]] || die "/etc/os-release not found."
    # shellcheck disable=SC1091
    source /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || log "Non-Ubuntu system detected (${ID:-unknown}); attempting Ubuntu-style Docker install."

    local codename="${VERSION_CODENAME:-}"
    if [[ -z "${codename}" ]]; then
        codename="$(lsb_release -cs)"
    fi

    local arch
    arch="$(dpkg --print-architecture)"
    local docker_repo
    docker_repo="deb [arch=${arch} signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu ${codename} stable"

    log "Installing Docker Engine and Compose plugin."
    run_as_root install -m 0755 -d /etc/apt/keyrings
    if [[ ! -f /etc/apt/keyrings/docker.asc ]]; then
        run_as_root sh -c "curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc"
        run_as_root chmod a+r /etc/apt/keyrings/docker.asc
    fi

    if ! run_as_root grep -Fq "${docker_repo}" /etc/apt/sources.list.d/docker.list 2>/dev/null; then
        printf '%s\n' "${docker_repo}" | run_as_root tee /etc/apt/sources.list.d/docker.list >/dev/null
    fi

    run_as_root apt-get update -y
    run_as_root apt-get install -y \
        docker-ce \
        docker-ce-cli \
        containerd.io \
        docker-buildx-plugin \
        docker-compose-plugin
    run_as_root systemctl enable --now docker
}

ensure_docker_group() {
    local user="$1"
    if ! id "${user}" >/dev/null 2>&1; then
        log "User '${user}' does not exist; skipping docker group assignment."
        return
    fi

    run_as_root groupadd -f docker
    if id -nG "${user}" | tr ' ' '\n' | grep -qx docker; then
        log "User '${user}' is already in docker group."
    else
        run_as_root usermod -aG docker "${user}"
        log "Added '${user}' to docker group (re-login required to apply group membership)."
    fi
}

ensure_runtime_dirs() {
    log "Preparing runtime directories under ${APP_ROOT}."

    local rel_dirs=(
        "rendered"
        "data/mysql"
        "data/redis"
        "data/wukongim"
        "data/minio"
        "data/tsdd"
        "logs/wukongim"
        "logs/tsdd"
        "backups/mysql"
    )

    run_as_root mkdir -p "${SRC_ROOT}" "${PROD_DIR}"

    local rel_dir
    for rel_dir in "${rel_dirs[@]}"; do
        run_as_root mkdir -p "${PROD_DIR}/${rel_dir}"
    done

    if id "${DOCKER_USER}" >/dev/null 2>&1; then
        run_as_root chown -R "${DOCKER_USER}:${DOCKER_USER}" "${APP_ROOT}"
    fi
}

configure_firewall() {
    if [[ "${SKIP_FIREWALL}" -eq 1 ]]; then
        log "--skip-firewall set; skipping UFW configuration."
        return
    fi

    if ! command -v ufw >/dev/null 2>&1; then
        log "ufw is not available; skipping firewall configuration."
        return
    fi

    log "Configuring UFW for published ports."
    run_as_root ufw allow 22/tcp
    run_as_root ufw allow "${PUBLIC_HTTP_PORT}/tcp"
    run_as_root ufw allow "${PUBLIC_HTTPS_PORT}/tcp"
    allow_tcp_port_if_public "${PUBLIC_WK_API_BIND}" "${PUBLIC_WK_API_PORT}"
    run_as_root ufw --force enable
    run_as_root ufw status
}

main() {
    log "Bootstrap started for app root: ${APP_ROOT}"
    install_base_packages

    if [[ "${SKIP_DOCKER_INSTALL}" -eq 1 ]]; then
        log "--skip-docker-install set; skipping Docker installation."
    else
        install_docker
    fi

    command -v docker >/dev/null 2>&1 || die "docker command is not available."
    docker compose version >/dev/null 2>&1 || die "docker compose plugin is not available."

    ensure_docker_group "${DOCKER_USER}"
    ensure_runtime_dirs
    load_port_config
    configure_firewall

    log "Verification:"
    docker --version
    docker compose version
    python3 --version
    log "Bootstrap completed."
}

main "$@"
