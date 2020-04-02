# ufw-bots

Script to automatically block IPs from datacenter ASNs (https://github.com/Conticop/bad-asn-list)

`I have excluded the following ASNs from the above list`
- Cloudflare (See https://www.cloudflare.com/ips/ for list of IPs to block if you want)

List of IPs is available at [files/ipv4.txt](files/ipv4.txt) and [files/ipv6.txt](files/ipv6.txt)

A bash script for ufw is available at [files/ufw.sh](files/ufw.sh)

`>> The lists/files are automatically updated every 6 hours.`

You can download the latest script using the following commands.

### Manually download the script and run

```bash
wget https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/ufw.sh
cat ufw.sh
chmod +x ufw.sh
sudo ./ufw.sh
```

### One-Step 

> Piping to bash is controversial, as it prevents you from reading code that is about to run on your system. Not recommended. Only use it if you know what you're doing. Run it frequently to have the latest IPs.

```bash
curl -sL https://raw.githubusercontent.com/brahma-dev/ufw-bots/master/files/ufw.sh | sudo -E bash -
```
### Uninstall

In case you want to remove the firewall rules created by this script
```bash
echo "Clearing old ipv4 rules"
sudo sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\n.*DROP//gm" /etc/ufw/user.rules
sudo sed -i 'N;/^\n$/d;P;D' /etc/ufw/user.rules

echo "Clearing old ipv6 rules"
sudo sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\n.*DROP//gm" /etc/ufw/user6.rules
sudo sed -i 'N;/^\n$/d;P;D' /etc/ufw/user6.rules
```

### Help Needed

A script for cronjob that can download the two list of IPs, parse/validate the IPs and update the firewall likewise. I don't happen to have the bash skill/time to pull it off.
