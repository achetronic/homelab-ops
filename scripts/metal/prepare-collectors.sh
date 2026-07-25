#!/usr/bin/env bash
set -euo pipefail

# Install Prometheus node_exporter and smartctl_exporter as systemd services
# on a bare-metal Ubuntu hypervisor so that a Grafana Alloy instance running
# inside Kubernetes can scrape metrics over the LAN.
#
# Ref: https://github.com/prometheus/node_exporter
# Ref: https://github.com/prometheus-community/smartctl_exporter
#
# Usage: sudo bash prepare-collectors.sh

# ---------------------------------------------------------------------------
# Pinned release versions
# Update these variables when upgrading; verify checksums on the release page.
# ---------------------------------------------------------------------------
NODE_EXPORTER_VERSION="1.12.1"
SMARTCTL_EXPORTER_VERSION="0.14.0"

# ---------------------------------------------------------------------------
# Derived constants (do not edit below this line)
# ---------------------------------------------------------------------------
_NE_TARBALL="node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
_NE_BASE_URL="https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}"

_SC_TARBALL="smartctl_exporter-${SMARTCTL_EXPORTER_VERSION}.linux-amd64.tar.gz"
_SC_BASE_URL="https://github.com/prometheus-community/smartctl_exporter/releases/download/v${SMARTCTL_EXPORTER_VERSION}"

_INSTALL_DIR="/usr/local/bin"
_SYSTEMD_DIR="/etc/systemd/system"

# ---------------------------------------------------------------------------
# Guard: must run as root
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root."
    echo "        Usage: sudo bash $0"
    exit 1
fi

# ---------------------------------------------------------------------------
# Helper: run_step <description> <command> [args...]
# Prints a progress line, runs the command, and exits with a clear [ERROR]
# message on failure. Safe to use with set -euo pipefail.
# ---------------------------------------------------------------------------
run_step() {
    local description="$1"
    shift
    echo "[...] ${description}"
    local exit_code=0
    "$@" || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then
        echo "[ERROR] Failed: ${description}"
        exit "${exit_code}"
    fi
}

# ---------------------------------------------------------------------------
# Helper: is_version_installed <binary_path> <expected_version>
# Returns 0 (true) if the binary exists and reports the expected version.
# Prometheus binaries print "name, version X.Y.Z ..." to stderr on --version.
# ---------------------------------------------------------------------------
is_version_installed() {
    local binary="$1"
    local expected="$2"
    if [[ ! -x "${binary}" ]]; then
        return 1
    fi
    "${binary}" --version 2>&1 | head -1 | grep -q "version ${expected}"
}

# ---------------------------------------------------------------------------
# Step: install smartmontools (required by smartctl_exporter for device access)
# ---------------------------------------------------------------------------
install_smartmontools() {
    run_step "Installing smartmontools" \
        apt-get --quiet install smartmontools
}

# ---------------------------------------------------------------------------
# Step: download, verify, and install a binary from a GitHub release tarball.
#
# Arguments:
#   $1  human name         (e.g. "node_exporter")
#   $2  tarball filename   (e.g. "node_exporter-1.12.1.linux-amd64.tar.gz")
#   $3  base download URL  (directory part, no trailing slash)
#   $4  binary name inside the extracted directory (e.g. "node_exporter")
# ---------------------------------------------------------------------------
download_and_install() {
    local name="$1"
    local tarball="$2"
    local base_url="$3"
    local binary_name="$4"

    local tmpdir
    tmpdir=$(mktemp -d)
    # Always clean up on exit, even if we fail early
    trap 'rm -rf "${tmpdir}"' EXIT

    run_step "Downloading ${name} tarball" \
        wget --quiet --show-progress \
            -O "${tmpdir}/${tarball}" \
            "${base_url}/${tarball}"

    run_step "Downloading ${name} checksums" \
        wget --quiet \
            -O "${tmpdir}/sha256sums.txt" \
            "${base_url}/sha256sums.txt"

    echo "[...] Verifying ${name} SHA-256 checksum"
    local exit_code=0
    # Run in a subshell so that 'cd' does not affect the parent environment
    (
        cd "${tmpdir}"
        grep "${tarball}" sha256sums.txt | sha256sum --check
    ) || exit_code=$?
    if [[ "${exit_code}" -ne 0 ]]; then
        echo "[ERROR] Checksum verification failed for ${tarball} - aborting installation"
        exit "${exit_code}"
    fi

    run_step "Extracting ${name}" \
        tar -xzf "${tmpdir}/${tarball}" -C "${tmpdir}"

    # The tarball extracts to a directory named after the tarball minus .tar.gz
    local extracted_dir="${tmpdir}/${tarball%.tar.gz}"
    run_step "Installing ${name} to ${_INSTALL_DIR}/${binary_name}" \
        install -o root -g root -m 755 \
            "${extracted_dir}/${binary_name}" \
            "${_INSTALL_DIR}/${binary_name}"

    # Disarm the trap; tmpdir will be removed by the trap on EXIT naturally,
    # but we reset it so that nested calls do not interfere with each other.
    trap - EXIT
    rm -rf "${tmpdir}"
}

# ---------------------------------------------------------------------------
# Step: create the node_exporter system user (idempotent)
# ---------------------------------------------------------------------------
create_node_exporter_user() {
    if id -u node_exporter &>/dev/null; then
        echo "[...] System user 'node_exporter' already exists, skipping"
        return 0
    fi
    run_step "Creating system user 'node_exporter'" \
        useradd \
            --system \
            --no-create-home \
            --shell /usr/sbin/nologin \
            node_exporter
}

# ---------------------------------------------------------------------------
# Step: write the node_exporter systemd unit
# ---------------------------------------------------------------------------
write_node_exporter_unit() {
    run_step "Writing /etc/systemd/system/node_exporter.service" \
        bash -c "cat > '${_SYSTEMD_DIR}/node_exporter.service'" <<'UNIT'
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com/prometheus/node_exporter
After=network.target

[Service]
User=node_exporter
Group=node_exporter
Type=simple
ExecStart=/usr/local/bin/node_exporter --web.listen-address=:9100
Restart=on-failure

# Security hardening
NoNewPrivileges=yes
ProtectSystem=strict
ProtectHome=yes
PrivateTmp=yes
PrivateDevices=yes

[Install]
WantedBy=multi-user.target
UNIT
}

# ---------------------------------------------------------------------------
# Step: write the smartctl_exporter systemd unit
#
# NOTE: smartctl_exporter runs as root because issuing NVMe Admin Commands
# (required to read SMART data from NVMe devices) requires CAP_SYS_ADMIN or
# direct raw device access. Running as root is the simplest supported approach
# for a bare-metal hypervisor; restrict further if your threat model demands it.
# ---------------------------------------------------------------------------
write_smartctl_exporter_unit() {
    run_step "Writing /etc/systemd/system/smartctl_exporter.service" \
        bash -c "cat > '${_SYSTEMD_DIR}/smartctl_exporter.service'" <<'UNIT'
[Unit]
Description=Prometheus smartctl Exporter
Documentation=https://github.com/prometheus-community/smartctl_exporter
After=network.target

[Service]
# Runs as root: NVMe Admin Commands require raw device access (CAP_SYS_ADMIN).
User=root
Type=simple
ExecStart=/usr/local/bin/smartctl_exporter --web.listen-address=:9633
Restart=on-failure

[Install]
WantedBy=multi-user.target
UNIT
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "[...] Preparing Prometheus metrics collectors"

# Track whether binaries were (re)installed so we can restart affected units
_NODE_CHANGED=false
_SMARTCTL_CHANGED=false

install_smartmontools

# --- node_exporter ---
if is_version_installed "${_INSTALL_DIR}/node_exporter" "${NODE_EXPORTER_VERSION}"; then
    echo "[...] node_exporter ${NODE_EXPORTER_VERSION} is already installed, skipping download"
else
    download_and_install \
        "node_exporter" \
        "${_NE_TARBALL}" \
        "${_NE_BASE_URL}" \
        "node_exporter"
    _NODE_CHANGED=true
fi

# --- smartctl_exporter ---
if is_version_installed "${_INSTALL_DIR}/smartctl_exporter" "${SMARTCTL_EXPORTER_VERSION}"; then
    echo "[...] smartctl_exporter ${SMARTCTL_EXPORTER_VERSION} is already installed, skipping download"
else
    download_and_install \
        "smartctl_exporter" \
        "${_SC_TARBALL}" \
        "${_SC_BASE_URL}" \
        "smartctl_exporter"
    _SMARTCTL_CHANGED=true
fi

create_node_exporter_user
write_node_exporter_unit
write_smartctl_exporter_unit

run_step "Reloading systemd daemon" systemctl daemon-reload

run_step "Enabling node_exporter service" systemctl enable node_exporter.service
run_step "Enabling smartctl_exporter service" systemctl enable smartctl_exporter.service

# Start or restart each service: restart if the binary was updated (to pick up
# the new binary), otherwise start it if it is not already running.
if [[ "${_NODE_CHANGED}" == "true" ]]; then
    run_step "Restarting node_exporter (binary updated)" systemctl restart node_exporter.service
elif ! systemctl is-active --quiet node_exporter.service; then
    run_step "Starting node_exporter" systemctl start node_exporter.service
else
    echo "[...] node_exporter is already running, no restart needed"
fi

if [[ "${_SMARTCTL_CHANGED}" == "true" ]]; then
    run_step "Restarting smartctl_exporter (binary updated)" systemctl restart smartctl_exporter.service
elif ! systemctl is-active --quiet smartctl_exporter.service; then
    run_step "Starting smartctl_exporter" systemctl start smartctl_exporter.service
else
    echo "[...] smartctl_exporter is already running, no restart needed"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
HOST_IP=$(hostname -I | awk '{print $1}')
echo ""
echo "[OK]  Metrics collectors are active. Scrape endpoints:"
echo "      node_exporter    -> http://${HOST_IP}:9100/metrics"
echo "      smartctl_exporter -> http://${HOST_IP}:9633/metrics"
