# ufw-bots

This project provides lists of datacenter IP addresses and scripts to help you block them using `ufw` or `iptables`. By blocking these IPs, you can reduce the amount of bot traffic to your servers.

A GitHub workflow automatically updates the IP lists every 6 hours. You have two ways to use these lists:

1.  **Recommended (Safer):** Clone this repository and run the scripts locally. This allows you to review the code before it runs on your system.
2.  **Advanced (Less Safe):** Directly download and run the scripts from the repository. This is not recommended as it involves executing code from the internet without prior review.

## Safety Warning

**Modifying firewall rules can be dangerous and may lock you out of your server if not done carefully.** Before using these scripts, please ensure you have:

1.  **Backup access to your server:** This could be through a cloud provider's web console or physical access.
2.  **Whitelisted your own IP address:** Make sure your current IP address is allowed by your firewall rules to prevent losing access. You can add a rule like `sudo ufw allow from YOUR_IP_ADDRESS to any` to allow your own IP.

**Use these scripts at your own risk.**

## Prerequisites

You must have [Bun](https://bun.sh) installed on your system to generate the firewall scripts.

## Installation and Usage (Recommended Method)

This is the recommended safe method for using `ufw-bots`. It allows you to review the code before running it.

1.  **Clone the Repository**

    ```bash
    git clone https://github.com/brahma-dev/ufw-bots.git
    cd ufw-bots
    ```

2.  **Install Dependencies**

    ```bash
    bun install
    ```

3.  **Generate the lists**

    ```bash
    bun start
    ```

    This command will generate `ipv4.txt`,`ipv6.txt` and `combined.txt` in the `files` directory.

4.  **Run the Script**

    You can inspect the scripts. When you are ready, run the appropriate script for your firewall:

    *   **For UFW:**

        ```bash
        sudo ./files/ufw.sh
        ```

    *   **For IPTables:**

        (Requires `ipset` to be installed)

        ```bash
        sudo ./files/iptables.sh
        ```

## Automating with Cron

To keep your blocklist updated automatically, you can set up a cron job. The safest way to run scheduled tasks that require root permissions is to add them to the `root` user's crontab.

1.  Open the root user's crontab editor.

    ```bash
    sudo crontab -e
    ```

2.  Add one of the following lines to the file. This will run the update script every 6 hours. Make sure to replace `/path/to/ufw-bots` with the actual path to where you cloned the repository. Replace `bun` with it's full path if it's not in root's $PATH

    *   **For UFW:**

        ```cron
        0 */6 * * * cd /path/to/ufw-bots && bun install && bun start && ./files/ufw.sh
        ```

        ```cron
        0 */6 * * * cd /home/username/ufw-bots && /home/username/.bun/bin/bun install && /home/username/.bun/bin/bun start && ./files/ufw.sh
        ```

    *   **For IPTables:**

        ```cron
        0 */6 * * * cd /path/to/ufw-bots && bun install && bun start && ./files/iptables.sh
        ```
        ```cron
        0 */6 * * * cd /home/username/ufw-bots && /home/username/.bun/bin/bun install && /home/username/.bun/bin/bun start && ./files/iptables.sh
        ```

3.  Save and exit the editor. The cron job is now active.

## Uninstall

If you need to remove the firewall rules added by this script, follow these instructions.

### UFW

```bash
cd /path/to/ufw-bots
sudo ./files/ufw_remove.sh
```

### IPTables

```bash
cd /path/to/ufw-bots
sudo ./files/iptables_remove.sh
```

### Help Needed

Shell expert to vet / improve the scripts.