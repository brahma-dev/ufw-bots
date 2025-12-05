#!/bin/sh
#
# This script updates UFW rules to block IP subnets listed in the ipv4.txt
# and ipv6.txt files. It clears old rules before applying the new set.
#
# It is designed to be POSIX-compliant and run on any standard shell.
# It MUST be run with root privileges (e.g., using sudo).
#
# USAGE:
#   sudo ./ufw.sh          - Use local 'ipv4.txt' and 'ipv6.txt' files.
#   sudo ./ufw.sh download - Download the latest lists before applying.
#

# --- Configuration ---
# Exit on first error, and treat unset variables as an error.
set -e
set -u

# Enable debug mode if DEBUG variable is set to a non-empty string.
[ -n "${DEBUG-}" ] && set -x

# --- Pre-flight Check ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# --- Variables ---
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_URL="https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files"

# Configuration for IPv4
IPV4_FILE="${ROOT_DIR}/ipv4.txt"
IPV4_URL="${BASE_URL}/ipv4.txt"
UFW_IPV4_RULES_FILE="/etc/ufw/user.rules"

# Configuration for IPv6
IPV6_FILE="${ROOT_DIR}/ipv6.txt"
IPV6_URL="${BASE_URL}/ipv6.txt"
UFW_IPV6_RULES_FILE="/etc/ufw/user6.rules"

# Unique comment to identify rules managed by this script
RULE_COMMENT="7566772d626f7473" # "ufw-bots" in hex

# --- Argument Handling ---
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

# --- Temporary File and Cleanup ---
TMP_RULES_FILE=$(mktemp)
trap 'echo "==> Cleaning up temporary file..."; rm -f "$TMP_RULES_FILE"' EXIT HUP INT QUIT TERM

# --- Function to process a UFW rules file ---
process_ufw_rules() {
    local ip_list_file="$1"
    local ufw_config_file="$2"
    local any_ip_cidr="$3"
    local protocol_name

    if [ "$any_ip_cidr" = "0.0.0.0/0" ]; then
        protocol_name="IPv4"
    else
        protocol_name="IPv6"
    fi

    echo "\n--- Processing ${protocol_name} rules for ${ufw_config_file} ---"

    echo "--> Clearing old ${protocol_name} rules..."
    sed -i.bak.old "/### tuple.* comment=${RULE_COMMENT}/ { N; d; }" "${ufw_config_file}"
    sed -i "${ufw_config_file}" -e 'N;/^\n$/D;P;D'


    echo "--> Generating new ${protocol_name} rules..."
    > "$TMP_RULES_FILE"
    while read -r subnet; do
        [ -z "$subnet" ] && continue
        {
            echo "### tuple ### deny any any ${any_ip_cidr} any ${subnet} in comment=${RULE_COMMENT}"
            echo "-A ufw-user-input -s ${subnet} -j DROP"
            echo ""
        } >> "$TMP_RULES_FILE"
    done < "${ip_list_file}"

    echo "--> Applying new ${protocol_name} rules..."
    sed -i.bak.clean "/### RULES ###/r ${TMP_RULES_FILE}" "${ufw_config_file}"
}

# --- Main Execution ---
process_ufw_rules "$IPV4_FILE" "$UFW_IPV4_RULES_FILE" "0.0.0.0/0"

process_ufw_rules "$IPV6_FILE" "$UFW_IPV6_RULES_FILE" "::/0" | sed 's/-A ufw-user-input/-A ufw6-user-input/' > "$TMP_RULES_FILE"
sed -i.bak.clean "/### RULES ###/r ${TMP_RULES_FILE}" "${UFW_IPV6_RULES_FILE}"


echo "\n==> Reloading UFW to apply changes..."
ufw reload

echo "\n==> Script finished successfully."
