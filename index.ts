import pLimit from 'p-limit';
import { chmodSync, existsSync, mkdirSync } from 'fs';
import cidrTools from 'cidr-tools';

const notSoBadASNs: string[] = ["13335"]; // Cloudflare
const outputDir = "./files";

interface RipeStatResponse {
    data: {
        prefixes: {
            v4: { originating: string[]; transiting: string[]; };
            v6: { originating: string[]; transiting: string[]; };
        };
    };
}


async function fetchBadASNs(): Promise<string[]> {
    console.log("Fetching bad ASN list...");
    const url = "https://raw.githubusercontent.com/brianhama/bad-asn-list/master/bad-asn-list.csv";
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Failed to fetch bad ASN list: ${response.statusText}`);
    const text = await response.text();
    const asns = text.split(/\r\n|\r|\n/).slice(1).map(line => line.split(",")[0].replaceAll('"', '')).filter(asn => asn && !notSoBadASNs.includes(asn));
    console.log(`Found ${asns.length} bad ASNs to process.`);
    return asns.map(asn => `AS${asn}`);
}

async function fetchASNData(asn: string): Promise<{ ipv4: string[], ipv6: string[] }> {
    const url = `https://stat.ripe.net/data/ris-prefixes/data.json?list_prefixes=true&types=o&resource=${asn}`;
    try {
        const response = await fetch(url, { headers: { 'User-Agent': 'Bun/1.0' } });
        if (!response.ok) throw new Error(`Request failed with status ${response.status}`);
        const data = await response.json() as RipeStatResponse;
        return {
            ipv4: [...(data.data.prefixes.v4.originating || [])],
            ipv6: [...(data.data.prefixes.v6.originating || [])],
        };
    } catch (error) {
        console.warn(`\nFailed to fetch data for ${asn}: ${(error as Error).message}. Retrying in 5s...`);
        await new Promise(resolve => setTimeout(resolve, 5000));
        return fetchASNData(asn);
    }
}

async function main() {
    try {
        if (!existsSync(outputDir)) mkdirSync(outputDir, { recursive: true });

        const badASNs = await fetchBadASNs();
        const ipv4Set = new Set<string>();
        const ipv6Set = new Set<string>();
        const limit = pLimit(10);
        let completed = 0;

        const tasks = badASNs.map(asn => limit(async () => {
            const { ipv4, ipv6 } = await fetchASNData(asn);
            ipv4.forEach(p => ipv4Set.add(p));
            ipv6.forEach(p => ipv6Set.add(p));
            completed++;
            process.stdout.write(`\rProgress: ${Math.floor(completed * 100 / badASNs.length)}% (${completed}/${badASNs.length}) - Fetched ${asn}`);
        }));

        await Promise.all(tasks);
        console.log("\n\n100% : Finished downloading IP prefixes.");

        const initialIpv4 = Array.from(ipv4Set).filter(ip => ip !== "0.0.0.0/0");
        const initialIpv6 = Array.from(ipv6Set).filter(ip => ip !== "::/0");
        
        console.log(`\nCollected ${initialIpv4.length} unique IPv4 and ${initialIpv6.length} unique IPv6 prefixes.`);
        console.log("Merging subnets...");

        const mergedIpv4 = cidrTools.mergeCidr(initialIpv4);
        const mergedIpv6 = cidrTools.mergeCidr(initialIpv6);

        console.log(`IPv4 list optimized from ${initialIpv4.length} to ${mergedIpv4.length} subnets.`);
        console.log(`IPv6 list optimized from ${initialIpv6.length} to ${mergedIpv6.length} subnets.`);

        await Bun.write(`${outputDir}/ipv4.txt`, mergedIpv4.join("\n"));
        console.log(`List of bad IPs saved to ${outputDir}/ipv4.txt`);
        await Bun.write(`${outputDir}/ipv6.txt`, mergedIpv6.join("\n"));
        console.log(`List of bad IPs saved to ${outputDir}/ipv6.txt`);
        await Bun.write(`${outputDir}/combined.txt`, `${mergedIpv4.join("\n")}\n${mergedIpv6.join("\n")}`);
        console.log(`List of bad IPs saved to ${outputDir}/combined.txt`);
        
        console.log("\nScript finished successfully!");

    } catch (error) {
        console.error("\nAn unexpected error occurred:", error);
        process.exit(1);
    }
}

main();