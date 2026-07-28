#!/usr/bin/env bash
set -euo pipefail

# Apply hardware quirks to a bare-metal host:
#   - Disable EEE on Intel I219 NICs (e1000e), whose TX queue freezes under
#     EEE Low Power Idle ("Detected Hardware Unit Hang") and never recovers
#     without a link reset.
#   - Administratively disable every physical NIC that does not hold the
#     default route: unplugged ports flap and request DHCP forever, and a
#     faulty PHY can even negotiate a link against its own echo.
#   - Show the GRUB menu for a few seconds on boot: these machines run
#     headless and their video output takes long to appear, so a visible
#     window is the only chance to act on emergencies. Release upgrades
#     reset this to hidden/0.
#   - Cap NVMe APST latency on known-flaky SSD models whose controller
#     locks up when entering deep power-saving states.
#
# It also reports, per hardware-dependent quirk, whether this host needs it
# and whether it was applied or already in place.
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

# Return every physical interface driven by e1000e, one per line
get_e1000e_interfaces() {
    local interface
    for interface in /sys/class/net/*; do
        interface=$(basename "${interface}")
        [[ "$(get_interface_driver "${interface}")" == "e1000e" ]] && echo "${interface}"
    done
    return 0
}

# Count kernel log messages of a NIC TX queue freeze, the symptom the EEE
# and TX-offload quirks address
count_nic_hang_messages() {
    journalctl -t kernel --no-pager 2>/dev/null \
        | grep -cE "Detected Hardware Unit Hang|transmit queue [0-9]+ timed out" || true
}

# Disable EEE on every e1000e NIC, reporting first whether this host needs
# the quirk and then whether it was applied or already in place.
apply_e1000e_eee_quirk() {
    local interfaces hangs
    interfaces=$(get_e1000e_interfaces)
    hangs=$(count_nic_hang_messages)

    if [[ -z "${interfaces}" ]]; then
        if [[ "${hangs}" -gt 0 ]]; then
            echo "[WARN] EEE quirk: not applicable (no e1000e NICs) but ${hangs} TX hang messages in the kernel log; another driver is hanging."
        else
            echo "[OK]  EEE quirk: not needed (no e1000e NICs)."
        fi
        return
    fi

    echo "[NEED] EEE quirk: e1000e NIC(s) present ($(echo ${interfaces} | xargs)), ${hangs} TX hang messages in the kernel log."

    local interface link_file dropin
    for interface in ${interfaces}; do
        link_file=$(udevadm info --query=property --property=ID_NET_LINK_FILE --value "/sys/class/net/${interface}" 2>/dev/null) || true
        dropin="/etc/systemd/network/$(basename "${link_file:-none}").d/50-disable-eee.conf"
        if [[ -f "${dropin}" ]] && ethtool --show-eee "${interface}" 2>/dev/null | grep -q "EEE status: disabled"; then
            echo "[OK]  EEE quirk: already applied on '${interface}'."
            continue
        fi
        persist_eee_disabled "${interface}"
        disable_eee_now "${interface}"
        echo "[DONE] EEE quirk: applied on '${interface}'."
    done
}

# Disable TSO/GSO on every e1000e interface. Escalation quirk: enable only
# on hosts where the hang persists with EEE already disabled.
apply_e1000e_tx_offloads_quirk() {
    local interface
    for interface in $(get_e1000e_interfaces); do
        disable_tx_offloads "${interface}"
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

# Make the GRUB menu visible for a few seconds on every boot, so a headless
# machine offers a recovery window before the OS loads. Only regenerates the
# GRUB config when the values actually change.
configure_grub_menu() {
    local grub_file="/etc/default/grub" timeout="10"

    if grep -q "^GRUB_TIMEOUT_STYLE=menu$" "${grub_file}" \
        && grep -q "^GRUB_TIMEOUT=${timeout}$" "${grub_file}"; then
        echo "[OK]  GRUB menu already visible with timeout ${timeout}s, nothing to do."
        return
    fi

    run_step "Setting GRUB menu visible with timeout ${timeout}s" \
        sed -i \
            -e "s/^GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=menu/" \
            -e "s/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=${timeout}/" \
            "${grub_file}"

    run_step "Regenerating GRUB configuration" update-grub
}

# Cap the APST latency for NVMe SSDs whose controller locks up in deep
# power-saving states, reporting first whether this host needs the quirk
# and then whether it was applied or already in place. The kernel log is
# also scanned for lockup symptoms to flag models missing from the list.
apply_nvme_apst_quirk() {
    local flaky_models=("KINGSTON SNV3S")
    local parameter="nvme_core.default_ps_max_latency_us=5500"
    local grub_file="/etc/default/grub"

    local lockups
    lockups=$(journalctl -t kernel --no-pager 2>/dev/null \
        | grep -ciE "nvme.*(controller is down|resetting controller|probe failure|I/O timeout)" || true)

    local model matched=""
    for model in /sys/class/nvme/*/model; do
        [[ -e "${model}" ]] || continue
        model=$(<"${model}")
        local flaky
        for flaky in "${flaky_models[@]}"; do
            if [[ "${model}" == "${flaky}"* ]]; then
                matched=$(echo "${model}" | xargs)
                break 2
            fi
        done
    done

    if [[ -z "${matched}" ]]; then
        if [[ "${lockups}" -gt 0 ]]; then
            echo "[WARN] NVMe APST quirk: no known-flaky model, but ${lockups} controller lockup messages in the kernel log; consider adding this host's model to the flaky list."
        else
            echo "[OK]  NVMe APST quirk: not needed (no known-flaky NVMe models)."
        fi
        return
    fi

    echo "[NEED] NVMe APST quirk: flaky model present (${matched}), ${lockups} controller lockup messages in the kernel log."

    if grep -q "nvme_core.default_ps_max_latency_us" "${grub_file}"; then
        echo "[OK]  NVMe APST quirk: already applied."
        return
    fi

    run_step "Adding NVMe APST latency cap to GRUB cmdline" \
        sed -i \
            "s/^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"/GRUB_CMDLINE_LINUX_DEFAULT=\"\1 ${parameter}\"/" \
            "${grub_file}"
    sed -i 's/=" /="/' "${grub_file}"

    run_step "Regenerating GRUB configuration" update-grub
    echo "[DONE] NVMe APST quirk: applied (active after next reboot)."
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
echo "[...] Applying hardware quirks"

apply_e1000e_eee_quirk
# apply_e1000e_tx_offloads_quirk
disable_unused_nics
configure_grub_menu
apply_nvme_apst_quirk

echo "[OK]  Hardware preparation complete."
