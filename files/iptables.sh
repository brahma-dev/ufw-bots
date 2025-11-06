#!/bin/sh
#
# This script creates ipset lists from a list of IP subnets and adds rules
# to the INPUT iptables chain to drop traffic from those sources.
#
# It is designed to be POSIX-compliant and run on any standard shell.
#
# USAGE:
#   ./iptables.sh          - Use the local 'combined.txt' file.
#   ./iptables.sh download - Download the list before applying.
#

# --- Configuration ---
# Exit on first error, and treat unset variables as an error.
set -e
set -u

# Enable debug mode if DEBUG variable is set to a non-empty string.
[ -n "${DEBUG-}" ] && set -x

# --- Variables ---
# Get the absolute directory where the script is located.
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
SET_NAME="bad_asn_ips"
# By default, use the local combined.txt file from the same directory.
IPFILE="${ROOT_DIR}/combined.txt"
DOWNLOAD_URL="https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/combined.txt"

# --- Argument Handling ---
# Check if the first argument is "download".
if [ "$#" -gt 0 ] && [ "$1" = "download" ]; then
    echo "==> Download option specified. Fetching the latest block list..."
    wget -q --progress=bar --show-progress -O "${IPFILE}" "${DOWNLOAD_URL}"
else
    echo "==> Using local IP list from ${IPFILE}"
    if [ ! -f "${IPFILE}" ]; then
        echo "Error: Local file not found at '${IPFILE}'" >&2
        echo "Please generate it first, or run this script with the 'download' argument." >&2
        exit 1
    fi
fi

# --- Temporary Directory and Cleanup ---
# Create a secure temporary directory for split files.
TMP_DIR="$(mktemp -d)"
# Set a trap to ensure the temporary directory is removed on script exit,
# whether it's successful, an error, or an interruption (Ctrl+C).
trap 'echo "==> Cleaning up temporary files..."; rm -rf "${TMP_DIR}"' EXIT HUP INT QUIT TERM

# --- Main Logic ---
echo "==> Importing subnet list into ipset(s)..."
# Use a subshell to avoid changing the main script's directory.
(
    cd "${TMP_DIR}"
    # Split the main IP file into chunks that ipset can handle.
    cat "${IPFILE}" | split --suffix-length=2 --numeric-suffixes=1 --lines=65536

    # Loop through the generated chunk files (e.g., x01, x02, ...).
    # 'for file in x*' is a safe, portable way to iterate over files.
    for SPLIT_FILE in x*; do
        # If the input file was empty, 'split' creates no files, and the loop
        # would fail on a literal "x*". This check prevents that.
        [ -f "$SPLIT_FILE" ] || continue

        # Get the numeric suffix from the filename (e.g., '01' from 'x01').
        # 'sed' is a portable way to perform this substitution.
        SUFFIX=$(echo "$SPLIT_FILE" | sed 's/x//')
        CURRENT_SET="${SET_NAME}_${SUFFIX}"

        echo "--> Processing chunk ${SUFFIX}: creating ipset '${CURRENT_SET}'"

        # Clean up any old iptables rule and ipset with this name.
        # '2>/dev/null || true' suppresses errors if they don't exist, which is expected.
        iptables -D INPUT -m set --match-set "${CURRENT_SET}" src -j DROP 2>/dev/null || true
        ipset destroy "${CURRENT_SET}" 2>/dev/null || true

        # Create the new ipset.
        ipset create "${CURRENT_SET}" hash:net

        # Prepare the chunk file and restore it into the new ipset.
        # We use 'pv' for a progress bar if available, otherwise just 'cat'.
        if command -v pv >/dev/null; then
            pv "${SPLIT_FILE}" | sed "s/^/add \"${CURRENT_SET}\" /" | ipset restore
        else
            sed "s/^/add \"${CURRENT_SET}\" /" < "${SPLIT_FILE}" | ipset restore
        fi

        echo "--> Adding set '${CURRENT_SET}' to iptables INPUT chain"
        iptables -A INPUT -m set --match-set "${CURRENT_SET}" src -j DROP
    done
)

echo "==> Script finished successfully."