# ufw-bots

Script to automatically block IPs from datacenter ASNs (https://github.com/brianhama/bad-asn-list)

`I have excluded the following ASNs from the above list`
- Cloudflare (See https://www.cloudflare.com/ips/ for list of IPs to block if you want)

List of IPs is available at [files/ipv4.txt](files/ipv4.txt) and [files/ipv6.txt](files/ipv6.txt) and [files/combined.txt](files/combined.txt)

A bash script for ufw is available at [files/ufw.sh](files/ufw.sh)

A bash script for iptables is available at [files/iptables.sh](files/iptables.sh). Requires `ipset` and `pv` to be installed.

`>> The lists/files are automatically updated every 6 hours.`

You can download the latest script using the following commands.

### Manually download the script and run

#### UFW

```bash
wget https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/ufw.sh
cat ufw.sh
chmod +x ufw.sh
sudo ./ufw.sh
```
#### IPTABLES

```bash
wget https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/iptables.sh
cat iptables.sh
chmod +x iptables.sh
sudo ./iptables.sh
```

### One-Step 

> Piping to bash is controversial, as it prevents you from reading code that is about to run on your system. Not recommended. Only use it if you know what you're doing. Run it frequently to have the latest IPs.

#### UFW

```bash
curl -sL https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/ufw.sh | sudo -E bash -
```

#### IPTABLES

```bash
curl -sL https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/iptables.sh | sudo -E bash -
```
### Uninstall

In case you want to remove the firewall rules created by this script

#### UFW

```bash
echo "Clearing old ipv4 rules"
sudo sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\n.*DROP//gm" /etc/ufw/user.rules
sudo sed -i 'N;/^\n$/d;P;D' /etc/ufw/user.rules

echo "Clearing old ipv6 rules"
sudo sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\n.*DROP//gm" /etc/ufw/user6.rules
sudo sed -i 'N;/^\n$/d;P;D' /etc/ufw/user6.rules
```

#### IPTABLES

```bash
export SET_NAME="brahma_iplist"
echo "Clearing iptable rules"
for i in `seq -w 1 10`; do
sudo iptables -D INPUT -m set --match-set "${SET_NAME}_$i" src -j DROP 2>/dev/null || true;
sudo ipset -X "${SET_NAME}_$i"
done
```

This will print warning that `The set with the given name does not exist`. It can be safely ignored.

### Help Needed

A script for cronjob that can download the two list of IPs, parse/validate the IPs and update the firewall likewise. I don't happen to have the bash skill/time to pull it off.
