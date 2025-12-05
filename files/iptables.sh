#!/bin/sh
#
# This script creates ipset lists for IPv4 and IPv6 subnets and adds rules to
# iptables and ip6tables to drop traffic from those sources.
#
# It is designed to be POSIX-compliant and run on any standard shell.
#
# USAGE:
#   ./iptables.sh          - Use local 'ipv4.txt' and 'ipv6.txt' files.
#   ./iptables.sh download - Download the latest lists before applying.
#

# --- Configuration ---
# Exit on first error, and treat unset variables as an error.
set -e
set -u

# Enable debug mode if DEBUG variable is set to a non-empty string.
[ -n "${DEBUG-}" ] && set -x

# --- Variables ---
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files"

IPV4_SET_NAME_BASE="bad_asn_ipv4"
IPV4_FILE="${ROOT_DIR}/ipv4.txt"
IPV4_URL="${BASE_URL}/ipv4.txt"

IPV6_SET_NAME_BASE="bad_asn_ipv6"
IPV6_FILE="${ROOT_DIR}/ipv6.txt"
IPV6_URL="${BASE_URL}/ipv6.txt"

if [ "$#" -gt 0 ] && [ "$1" = "download" ]; then
    echo "==> Download option specified. Fetching the latest block lists..."
    wget -q --progress=bar --show-progress -O "${IPV4_FILE}" "${IPV4_URL}"
    wget -q --progress=bar --show-progress -O "${IPV6_FILE}" "${IPV6_URL}"
else
    echo "==> Using local IP lists from ${ROOT_DIR}/"
    if [ ! -f "${IPV4_FILE}" ] || [ ! -f "${IPV6_FILE}" ]; then
        echo "Error: One or both local files not found ('ipv4.txt', 'ipv6.txt')." >&2
        echo "Please generate them first, or run this script with the 'download' argument." >&2
        exit 1
    fi
fi

# --- Temporary Directory and Cleanup ---
TMP_DIR="$(mktemp -d)"
trap 'echo "==> Cleaning up temporary directory..."; rm -rf "${TMP_DIR}"' EXIT HUP INT QUIT TERM

# --- Function to process an IP list ---
process_ip_list() {
    ip_file="$1"
    set_name_base="$2"
    family="$3" # 'inet' for IPv4, 'inet6' for IPv6
    iptables_cmd="$4"

    echo "\n--- Processing ${family} rules ---"

    (
        cd "${TMP_DIR}"
        cat "${ip_file}" | split --suffix-length=2 --numeric-suffixes=1 --lines=65536

        for SPLIT_FILE in x*; do
            [ -f "$SPLIT_FILE" ] || continue

            SUFFIX=$(echo "$SPLIT_FILE" | sed 's/x//')
            CURRENT_SET="${set_name_base}_${SUFFIX}"

            echo "--> Processing chunk ${SUFFIX}: creating ipset '${CURRENT_SET}'"

            "$iptables_cmd" -D INPUT -m set --match-set "${CURRENT_SET}" src -j DROP 2>/dev/null || true
            ipset destroy "${CURRENT_SET}" 2>/dev/null || true

            ipset create "${CURRENT_SET}" hash:net family "${family}"

            sed "s/^/add \"${CURRENT_SET}\" /" < "${SPLIT_FILE}" | ipset restore

            echo "--> Adding set '${CURRENT_SET}' to ${iptables_cmd} INPUT chain"
            "$iptables_cmd" -A INPUT -m set --match-set "${CURRENT_SET}" src -j DROP
        done
    )
}

# --- Main Execution ---
process_ip_list "$IPV4_FILE" "$IPV4_SET_NAME_BASE" "inet" "iptables"

process_ip_list "$IPV6_FILE" "$IPV6_SET_NAME_BASE" "inet6" "ip6tables"

echo "\n==> Script finished successfully."
