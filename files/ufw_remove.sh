#!/bin/sh
#
# This script finds and removes all UFW rules that were created by the
# 'update-ufw.sh' script by searching for a unique comment identifier.
#
# It MUST be run with root privileges (e.g., using sudo).
#

# --- Configuration ---
# Exit on first error, and treat unset variables as an error.
set -e
set -u

# --- Pre-flight Check ---
if [ "$(id -u)" -ne 0 ]; then
    echo "Error: This script must be run as root." >&2
    exit 1
fi

# --- Variables (MUST match the creation script) ---
UFW_IPV4_RULES_FILE="/etc/ufw/user.rules"
UFW_IPV6_RULES_FILE="/etc/ufw/user6.rules"
RULE_COMMENT="7566772d626f7473" # "ufw-bots" in hex

# --- Function to clear rules from a UFW configuration file ---
clear_rules_from_file() {
    local ufw_file="$1"
    local protocol_name

    case "$ufw_file" in
        *user6.rules) protocol_name="IPv6" ;;
        *) protocol_name="IPv4" ;;
    esac

    echo "--- Clearing ${protocol_name} rules from ${ufw_file} ---"

    if [ ! -f "$ufw_file" ]; then
        echo "--> Rules file not found. Skipping."
        return
    fi

    if ! grep -q "comment=${RULE_COMMENT}" "$ufw_file"; then
        echo "--> No rules with the specific comment found. Nothing to do."
        return
    fi

    echo "--> Removing rule pairs marked with comment '${RULE_COMMENT}'..."
    sed -i.bak.removed "/### tuple.* comment=${RULE_COMMENT}/ { N; d; }" "${ufw_file}"

    echo "--> Cleaning up any leftover blank lines..."
    sed -i "${ufw_file}" -e 'N;/^\n$/D;P;D'

    echo "--> Successfully cleared rules from ${ufw_file}"
}

# --- Main Execution ---
clear_rules_from_file "$UFW_IPV4_RULES_FILE"
clear_rules_from_file "$UFW_IPV6_RULES_FILE"

echo "\n==> Reloading UFW to apply changes..."
ufw reload

echo "\n==> Cleanup finished successfully."
