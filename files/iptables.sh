#!/bin/bash
# Adapted from https://gist.github.com/cyrbil/96389ef47ee5a656d0df1706e1143cfc
set -o errexit
set -o errtrace
set -o functrace
set -o pipefail
set -o nounset

[ -z ${DEBUG+x} ] || set -o xtrace

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"

SET_NAME="brahma_iplist"
IPFILE="${ROOT_DIR}/ips.txt"

echo "Downloading latest block list"
wget -q --progress=bar --show-progress -O "${IPFILE}" https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/combined.txt

echo "Importing Subnet list"
TMP_DIR="$(mktemp -d)"
(
    cd "${TMP_DIR}"
    cat "${IPFILE}" | split --suffix-length=2 --numeric-suffixes=1 --lines=65536

    for SPLIT in $( ls x* ); do
        CURRENT_SET="${SET_NAME}_${SPLIT:1:2}"
        echo "Creating ipset '${CURRENT_SET}'"
        iptables -D INPUT -m set --match-set "${CURRENT_SET}" src -j DROP 2>/dev/null || true
        sleep 1;  # wait for iptables changes
        ipset destroy "${CURRENT_SET}" 2>/dev/null || true
		  echo "Here"
        ipset create "${CURRENT_SET}" hash:net
		  echo "Here2"
        pv "${SPLIT}" | sed "s/^/add \"${CURRENT_SET}\" /" | ipset restore
        echo "Add set to iptables rules"
        iptables -A INPUT -m set --match-set "${CURRENT_SET}" src -j DROP
    done
)
rm -rf "${TMP_DIR}"