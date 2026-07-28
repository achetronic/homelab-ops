#!/usr/bin/env bash
set -euo pipefail

# Apply hardware quirks to a bare-metal host:
#   - Disable EEE on Intel I219 NICs (e1000e), whose TX queue freezes under
#     EEE Low Power Idle ("Detected Hardware Unit Hang") and never recovers
#     without a link reset.
#   - Administratively disable every physical NIC that does not hold the
#     default route: unplugged ports flap and request DHCP forever, and a
#     faulty PHY can even negotiate a link against its own echo.
#
# Usage: sudo bash prepare-hardware.sh

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

# Return the driver bound to a network interface, empty if none
get_interface_driver() {
    local interface="$1"
    basename "$(readlink -f "/sys/class/net/${interface}/device/driver" 2>/dev/null)" 2>/dev/null || true
}

# Persist the EEE disablement as a drop-in of the .link file already applied
# to the interface (netplan generates one; only a single .link matches per
# device, so a drop-in is the only safe way to extend it).
# Requires systemd >= 258 for the [EnergyEfficientEthernet] section.
persist_eee_disabled() {
    local interface="$1"

    local link_file
    link_file=$(udevadm info --query=property --property=ID_NET_LINK_FILE --value "/sys/class/net/${interface}" 2>/dev/null) || true
    if [[ -z "${link_file}" ]]; then
        echo "[ERROR] Could not resolve the .link file applied to '${interface}'."
        exit 1
    fi

    local dropin_dir="/etc/systemd/network/$(basename "${link_file}").d"
    run_step "Persisting EEE off for '${interface}' (${dropin_dir})" \
        mkdir -p "${dropin_dir}"

    cat > "${dropin_dir}/50-disable-eee.conf" <<'EOF'
# Intel I219 (e1000e) erratum: EEE Low Power Idle freezes the TX queue
# ("Detected Hardware Unit Hang") and only a link reset recovers it.
[EnergyEfficientEthernet]
Enable=no
EOF
}

# Turn EEE off right now, without waiting for the next boot/link renegotiation
disable_eee_now() {
    local interface="$1"
    run_step "Disabling EEE on '${interface}' (runtime)" \
        ethtool --set-eee "${interface}" eee off
}

# Disable TSO/GSO on an interface: with them the NIC's own engine segments
# large TCP buffers, and on I219 those TX descriptors can also freeze the
# queue. Costs CPU per transmitted byte, so it is a last-resort measure.
disable_tx_offloads() {
    local interface="$1"

    local link_file
    link_file=$(udevadm info --query=property --property=ID_NET_LINK_FILE --value "/sys/class/net/${interface}" 2>/dev/null) || true
    if [[ -z "${link_file}" ]]; then
        echo "[ERROR] Could not resolve the .link file applied to '${interface}'."
        exit 1
    fi

    local dropin_dir="/etc/systemd/network/$(basename "${link_file}").d"
    run_step "Persisting TSO/GSO off for '${interface}' (${dropin_dir})" \
        mkdir -p "${dropin_dir}"

    cat > "${dropin_dir}/51-disable-tx-offloads.conf" <<'EOF'
# Intel I219 (e1000e) erratum: TSO-generated TX descriptors can also freeze
# the TX queue. Escalation over the EEE disablement, at a CPU cost.
[Link]
TCPSegmentationOffload=no
GenericSegmentationOffload=no
EOF

    run_step "Disabling TSO/GSO on '${interface}' (runtime)" \
        ethtool -K "${interface}" tso off gso off
}

# Find physical interfaces driven by e1000e and disable EEE on each one.
# No-op on hosts without Intel I219 NICs (e.g. Realtek r8169 hosts).
apply_e1000e_eee_quirk() {
    local interface driver found=0
    for interface in /sys/class/net/*; do
        interface=$(basename "${interface}")
        driver=$(get_interface_driver "${interface}")
        if [[ "${driver}" == "e1000e" ]]; then
            found=1
            echo "[...] Found e1000e interface: ${interface}"
            persist_eee_disabled "${interface}"
            disable_eee_now "${interface}"
        fi
    done
    if [[ "${found}" -eq 0 ]]; then
        echo "[OK]  No e1000e interfaces found, nothing to do."
    fi
}

# Disable TSO/GSO on every e1000e interface. Escalation quirk: enable only
# on hosts where the hang persists with EEE already disabled.
apply_e1000e_tx_offloads_quirk() {
    local interface driver
    for interface in /sys/class/net/*; do
        interface=$(basename "${interface}")
        driver=$(get_interface_driver "${interface}")
        if [[ "${driver}" == "e1000e" ]]; then
            disable_tx_offloads "${interface}"
        fi
    done
}

# Administratively disable (netplan activation-mode off) every physical
# ethernet NIC other than the one holding the default route. Wireless and
# virtual interfaces (bridges, macvtap...) are left untouched.
disable_unused_nics() {
    local primary
    primary=$(ip route show default | awk '/^default/ {print $5; exit}')
    if [[ -z "${primary}" ]]; then
        echo "[ERROR] Could not determine the primary NIC (no default route)."
        exit 1
    fi

    local interface unused=()
    for interface in /sys/class/net/*; do
        interface=$(basename "${interface}")
        [[ -e "/sys/class/net/${interface}/device" ]] || continue
        [[ -d "/sys/class/net/${interface}/wireless" ]] && continue
        [[ "$(cat "/sys/class/net/${interface}/type")" == "1" ]] || continue
        [[ "${interface}" == "${primary}" ]] && continue
        unused+=("${interface}")
    done

    if [[ "${#unused[@]}" -eq 0 ]]; then
        echo "[OK]  No unused physical NICs found, nothing to do."
        return
    fi

    local netplan_file="/etc/netplan/60-disable-unused-nics.yaml"
    echo "[...] Primary NIC is '${primary}'; disabling: ${unused[*]}"
    {
        echo "# Physical NICs without the default route are administratively down:"
        echo "# unplugged ports flap and request DHCP forever, and a faulty PHY can"
        echo "# even negotiate a link against its own echo."
        echo "network:"
        echo "  version: 2"
        echo "  ethernets:"
        for interface in "${unused[@]}"; do
            echo "    ${interface}:"
            echo "      activation-mode: \"off\""
        done
    } > "${netplan_file}"
    chmod 600 "${netplan_file}"

    run_step "Applying netplan configuration" netplan apply
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "[...] Applying hardware quirks"

apply_e1000e_eee_quirk
# apply_e1000e_tx_offloads_quirk
disable_unused_nics

echo "[OK]  Hardware preparation complete."
