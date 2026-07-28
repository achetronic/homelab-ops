#!/usr/bin/env bash
set -euo pipefail

# Install the Cockpit web UI with the virtual-machine management plugin.
# Kept as its own role so the UI can eventually live on a dedicated machine
# instead of one instance per hypervisor.
#
# Usage: sudo bash prepare-ui.sh

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
# Step functions
# ---------------------------------------------------------------------------

# Update the package lists
update_packages_list() {
    run_step "Updating package lists" apt-get --quiet update
}

# Install Cockpit with the virtual-machine management plugin
# NOTE: no '--no-install-recommends' here on purpose: 'cockpit' is a
# metapackage whose actual components (cockpit-ws, cockpit-system...) are
# pulled in via Recommends. The exception is cockpit-networkmanager, vetoed
# because it drags NetworkManager into networkd-managed hosts.
install_cockpit() {
    run_step "Installing Cockpit and cockpit-machines" \
        apt-get --quiet install \
            cockpit \
            cockpit-machines \
            cockpit-networkmanager-
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "[...] Preparing UI"

update_packages_list
install_cockpit

echo "[OK]  UI preparation complete."
