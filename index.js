import pkg from 'follow-redirects';
const { https } = pkg;
import fs from 'fs';
import pLimit from 'p-limit';
const limit = pLimit(1);
const httpsAgent = new https.Agent({ keepAlive: true })
const httpsRequest = (opts) => new Promise((resolve, reject) => {
	var options = {
		'method': opts.method || 'GET',
		'hostname': opts.hostname,
		'path': opts.path,
		'headers': opts.headers || {
			'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:109.0) Gecko/20100101 Firefox/117.0'
		},
		'maxRedirects': 5,
		'agent': httpsAgent
	};

	var req = https.request(options, function (res) {
		var chunks = [];

		res.on("data", function (chunk) {
			chunks.push(chunk);
		});

		res.on("end", function (chunk) {
			var body = Buffer.concat(chunks);
			let type = res.headers["content-type"];
			if (type.indexOf("json") !== -1)
				return resolve(JSON.parse(body.toString()));
			resolve(body.toString());
		});

		res.on("error", function (error) {
			reject(error);
		});
	});

	req.end();
})

const notSoBadASNs = [
	"13335", //Cloudflare
	"" //Filters out blank Endline
];
const badASNs = [];
const ipv4_subnets = [];
const ipv6_subnets = [];

const forcedDelay = (timeout) => {
	return new Promise((resolve, reject) => {
		setTimeout(function () { resolve() }, timeout);
	})
}

const fetchASNData = (asn, asnIndex) => {
	return new Promise((resolve, reject) => {
		let options = {
			'hostname': 'api.bgpview.io',
			'path': `/asn/${asn}/prefixes`,
		};
		console.log(Math.floor(asnIndex * 100 / badASNs.length), "% : Fetching", asn);
		return httpsRequest(options).then((data) => {
			data.data.ipv4_prefixes.forEach((e) => {
				if (ipv4_subnets.indexOf(e.prefix) == -1)
					ipv4_subnets.push(e.prefix)
			});
			data.data.ipv6_prefixes.forEach((e) => {
				if (ipv6_subnets.indexOf(e.prefix) == -1)
					ipv6_subnets.push(e.prefix)
			});
			resolve();
		}).catch((e) => {
			console.info(Math.floor(asnIndex * 100 / badASNs.length), "% : Retrying", asn);
			return forcedDelay(10000).then(() => httpsRequest(options)).then((data) => {
				data.data.ipv4_prefixes.forEach((e) => {
					if (ipv4_subnets.indexOf(e.prefix) == -1)
						ipv4_subnets.push(e.prefix)
				});
				data.data.ipv6_prefixes.forEach((e) => {
					if (ipv6_subnets.indexOf(e.prefix) == -1)
						ipv6_subnets.push(e.prefix)
				});
				resolve();
			}).catch(reject);
		});
	});
};

const fetchBadASNs = () => {
	let options = {
		'hostname': 'raw.githubusercontent.com',
		'path': '/brianhama/bad-asn-list/master/bad-asn-list.csv'
	};
	return httpsRequest(options)
		.then((data) => data.split(/\r\n|\r|\n/).slice(1))
		.then((data) => data.map((e) => parseInt(e.split(",")[0].replaceAll('"', ''))))
		.then((data) => data.filter((e) => !notSoBadASNs.includes(e)).forEach((e) => e && badASNs.push("AS" + e)));
}

const sortIPs = (a, b) => {
	a = a.split(/[\.\/:]/).map(z => z.length ? parseInt(z, 16) : 0)
	b = b.split(/[\.\/:]/).map(z => z.length ? parseInt(z, 16) : 0)
	for (let i = 0; i < a.length; i++) {
		if ((a[i] = parseInt(a[i])) < (b[i] = parseInt(b[i])))
			return -1;
		else if (a[i] > b[i])
			return 1;
	}
	return 0;
}

fetchBadASNs().then(() => Promise.all(badASNs.map((e, i) => limit(() => fetchASNData(e, i))))).then(() => {
	console.log("100% : Finished downloading"); // For continuity 
	ipv4_subnets.sort(sortIPs);
	ipv6_subnets.sort(sortIPs);
	let badIPs = [ipv4_subnets.join("\n"), ipv6_subnets.join("\n")];
	let ufw = [
		ipv4_subnets.map((e) => `### tuple ### deny any any 0.0.0.0/0 any ${e} in comment=7566772d626f7473\n-A ufw-user-input -s ${e} -j DROP`).join("\n\n"),
		ipv6_subnets.map((e) => `### tuple ### deny any any ::/0 any ${e} in comment=7566772d626f7473\n-A ufw6-user-input -s  ${e} -j DROP`).join("\n\n"),
	]
	fs.writeFile("./files/ipv4.txt", badIPs[0], function (err) {
		if (err) { throw err; }
		console.log("List of bad IPs saved to files/ipv4.txt");
	});
	fs.writeFile("./files/ipv6.txt", badIPs[1], function (err) {
		if (err) { throw err; }
		console.log("List of bad IPs saved to files/ipv6.txt");
	});
	fs.writeFile("./files/combined.txt", badIPs[0] + "\n" + badIPs[1], function (err) {
		if (err) { throw err; }
		console.log("List of bad IPs saved to files/combined.txt");
	});
	fs.writeFile("./files/ufw.sh", `#!/usr/bin/env bash

echo "Clearing old ipv4 rules"
sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\\n.*DROP//gm" /etc/ufw/user.rules
sed -i 'N;/^\\n$/d;P;D' /etc/ufw/user.rules

echo "Clearing old ipv6 rules"
sed -z -i.bak.old -u "s/### tuple.* comment=7566772d626f7473\\n.*DROP//gm" /etc/ufw/user6.rules
sed -i 'N;/^\\n$/d;P;D' /etc/ufw/user6.rules

IPV4="${ufw[0]}"

IPV6="${ufw[1]}"

sed -i.bak.clean '/### RULES ###/r /dev/stdin' /etc/ufw/user.rules <<< "$IPV4"
echo "New ipv4 rules in place"

sed -i.bak.clean '/### RULES ###/r /dev/stdin' /etc/ufw/user6.rules <<< "$IPV6"
echo "New ipv6 rules in place"

echo "Reloading ufw"
ufw reload
`, function (err) {
		if (err) { throw err; }
		fs.chmod("./files/ufw.sh", 0o755, (err) => {
			if (err) { throw err; }
		});
		console.log("Batch file for ufw saved to files/ufw.sh");
	});
}).catch((e) => {
	console.error(e);
	process.exit(1);
});
