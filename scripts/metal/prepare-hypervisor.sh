#!/usr/bin/env bash
set -euo pipefail

# Prepare a bare-metal Ubuntu host as a KVM hypervisor.
# Steps are taken from the official Ubuntu documentation.
# Ref: https://ubuntu.com/server/docs/virtualization-libvirt
#
# Usage: sudo bash prepare-hypervisor.sh <username>
#   <username>  The OS user to add to the 'libvirt' group (must already exist).

# ---------------------------------------------------------------------------
# Guard: must run as root
# ---------------------------------------------------------------------------
if [[ "${EUID}" -ne 0 ]]; then
    echo "[ERROR] This script must be run as root."
    echo "        Usage: sudo bash $0 <username>"
    exit 1
fi

# ---------------------------------------------------------------------------
# Guard: validate the username argument
# ---------------------------------------------------------------------------
USERNAME="${1:-}"

if [[ -z "${USERNAME}" ]]; then
    echo "[ERROR] No username supplied."
    echo "        Usage: sudo bash $0 <username>"
    exit 1
fi

if ! id -u "${USERNAME}" &>/dev/null; then
    echo "[ERROR] User '${USERNAME}' does not exist on this system."
    echo "        Create the user first, then re-run this script."
    exit 1
fi

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Path to the QEMU config file used by libvirt
_QEMU_CONFIG_PATH="/etc/libvirt/qemu.conf"

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

# Check virtualization availability
install_cpu_checker() {
    run_step "Installing cpu-checker" \
        apt-get --quiet install cpu-checker
}

# Verify hardware virtualisation is exposed and usable
check_kvm() {
    run_step "Checking KVM availability" kvm-ok
}

# Update the package lists
update_packages_list() {
    run_step "Updating package lists" apt-get --quiet update
}

# Install KVM/libvirt stack
# NOTE: 'qemu-system-x86' is used instead of the historical 'qemu-kvm' alias:
# on recent Ubuntu releases 'qemu-kvm' became a virtual package with multiple
# providers and apt refuses to pick one non-interactively.
# NOTE: '--no-install-recommends' keeps the graphical stack (qemu-system-gui,
# GTK, pipewire, mesa...) out of a headless hypervisor. The recommends we DO
# need are listed explicitly instead:
#   dnsmasq-base                  -> DHCP/DNS for the default libvirt NAT network
#   libvirt-daemon-driver-qemu    -> QEMU driver (recommends of the daemon split)
#   libvirt-daemon-config-network -> default network definition
#   qemu-block-extra              -> extra block drivers for QEMU
install_virtualization_packages() {
    run_step "Installing virtualization packages" \
        apt-get --no-install-recommends --quiet install \
            qemu-system-x86 \
            qemu-utils \
            qemu-block-extra \
            libvirt-daemon-system \
            libvirt-daemon-driver-qemu \
            libvirt-daemon-config-network \
            libvirt-clients \
            ovmf \
            bridge-utils \
            dnsmasq-base
}

# Add the target user to the libvirt group (idempotent: adduser exits 0 if
# the user is already a member)
add_user_to_libvirt_group() {
    run_step "Adding user '${USERNAME}' to the 'libvirt' group" \
        adduser "${USERNAME}" libvirt
}

# Disable the QEMU security driver so that Terraform libvirt provider can
# manage VMs without requiring AppArmor/SELinux labelling on the host.
# Disabling it here is safer than disabling the host security module globally.
# Ref: https://github.com/dmacvicar/terraform-provider-libvirt/issues/546
disable_qemu_security_driver() {
    run_step "Disabling security driver for QEMU (in ${_QEMU_CONFIG_PATH})" \
        sed --in-place -E \
            s/"^#?security_driver = \".*\"$"/"security_driver = \"none\""/ \
            "${_QEMU_CONFIG_PATH}"
}

# Restart libvirtd so the qemu.conf change takes effect
restart_libvirt() {
    run_step "Restarting libvirtd to apply configuration changes" \
        systemctl restart libvirtd
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "[...] Preparing hypervisor for user: ${USERNAME}"

install_cpu_checker
check_kvm
update_packages_list
install_virtualization_packages
add_user_to_libvirt_group
disable_qemu_security_driver
restart_libvirt

echo "[OK]  Hypervisor preparation complete."
