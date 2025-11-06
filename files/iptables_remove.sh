#!/bin/sh
#
# This script finds and removes all iptables rules and ipset lists that were
# created by the 'update-ipset.sh' script, including legacy rule names.
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

# --- Variables ---
# Lists of base names to search for and remove.
# Add any old or alternative base names here for a comprehensive cleanup.
IPV4_SET_NAME_BASES="bad_asn_ipv4 brahma_iplist"
IPV6_SET_NAME_BASES="bad_asn_ipv6 brahma_iplist"

# --- Function to find and remove rules and sets ---
# Arguments: $1=SET_NAME_BASE, $2=IPTABLES_CMD
remove_rules() {
    local set_name_base="$1"
    local iptables_cmd="$2"
    local protocol_name

    if [ "$iptables_cmd" = "iptables" ]; then
        protocol_name="IPv4"
    else
        protocol_name="IPv6"
    fi

    echo "\n--- Removing ${protocol_name} rules and sets for base name: '${set_name_base}' ---"

    # Get a list of all existing ipset names matching our base name.
    # 'ipset list -n' lists only the names. We grep for names that start with our base.
    set_list=$(ipset list -n | grep "^${set_name_base}" || true)

    if [ -z "$set_list" ]; then
        echo "--> No matching ipsets found. Nothing to do."
        return
    fi

    # Loop through each found set name.
    for current_set in $set_list; do
        echo "--> Processing set: ${current_set}"

        # Step 1: Delete the iptables rule that uses this set.
        # We must do this first. '|| true' prevents errors if rule is already gone.
        echo "    - Deleting rule from ${iptables_cmd} INPUT chain..."
        "$iptables_cmd" -D INPUT -m set --match-set "${current_set}" src -j DROP 2>/dev_null || true

        # Step 2: Now that the rule is gone, destroy the set itself.
        echo "    - Destroying ipset..."
        ipset destroy "${current_set}" 2>/dev/null || true
    done
}

# --- Main Execution ---
echo "Starting cleanup of all known ipset rules..."

for base_name in $IPV4_SET_NAME_BASES; do
    remove_rules "$base_name" "iptables"
done

for base_name in $IPV6_SET_NAME_BASES; do
    remove_rules "$base_name" "ip6tables"
done

echo "\n==> Cleanup finished successfully."