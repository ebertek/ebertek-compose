# Ygg network inventory drift audit

A bounded **read-only** LAN inventory check running on Pleiades. It reads the
private `Scripts/cloudflare/static-hosts.json` and records observations under
`/home/docker/cloudflare/network-inventory/state.json`. It never writes to either GitOps
repository, Cloudflare DNS, Home Assistant, DHCP, or the inventory file.

## Requirements

Install `nmap`, `avahi-utils`, `python3`, and `util-linux` (for `flock`)
on Pleiades. Run as root to permit Nmap SYN/ARP probes. Running the scheduled
job also requires the merged private static-hosts inventory on Pleiades.

```bash
sudo apt-get install nmap avahi-utils python3 util-linux
sudo bash /home/docker/ygg-compose/Scripts/network-inventory/run.sh
```

The Komodo **Network inventory audit** action runs daily at 05:15
(after the usual 03:00 stack update window). The first observation is
persisted but does **not** generate Discord notifications. Review that
baseline before enabling notifications.

### Optional Discord alerts

Create `ebertek-compose-secrets/Scripts/network-inventory/network-inventory.env`
with a Discord webhook URL stored privately, for example:

```bash
YGG_NETWORK_DISCORD_WEBHOOK_URL='https://discord.com/api/webhooks/REPLACE_ME'
```

The webhook must remain secret, must never be logged, and is optional.
Do **not** commit an actual webhook URL to the public repository. For initial
testing simply omit this file; the action logs findings to Komodo.

### What is detected

- New responsive IPv4 addresses and MACs not in the static inventory.
- Changed MACs for known IPv4 addresses (potentially noisy on bridged devices).
- Confirmed open TCP ports not listed in the current static inventory.
- New resolved DNS-SD advertisements, compared with the last observation.
- Events only notify once while continuously observed; a recurrence after
  disappearance produces another event.

The scanner discovers `10.4.20.0/23`, then scans the union of common TCP
ports and **every inventoried TCP port** on discovered hosts, plus a second\npass through Nmap's top 100 TCP ports. Both passes are combined; the second\nnever discards services found in the first. It limits retries,
uses a per-host timeout, and parses Nmap XML, **not grepped output**.
It excludes currently observed Docker container IP addresses from active port
tests and alerts, rather than ignoring the entire `10.4.21.0/24` subnet.

Avahi DNS-SD observations include locally advertised services and are\ndeduplicated across interface/address family.
They are **advertisements, not verified listening services**. UDP is not
actively scanned in this initial implementation.

### Operational limits

- A sleeping/unresponsive host is never deemed permanently removed.
- Unobserved/missing ports are not yet reported: negative reachability is
  ambiguous, especially with firewalls and power-saving devices.
- New ports on the **first** scan are logged but not pushed to Discord.
- DNS-SD discovery is best effort; failure will not erase its prior state.
- MAC addresses are not authoritative proof of physical device identity.
- The scanner is intentionally **not a complete vulnerability scanner**.
- File-based state is outside the read-only deployed checkout. Protect it.
- Offline regression testing:
  `python3 -m unittest discover -s Scripts/network-inventory -p 'test_*.py'`
- Dry test with XML:
  `python3 Scripts/network-inventory/audit.py --discovery-xml example.xml --state-dir /tmp/network-inventory-test`

Later phases can add bounded UDP probes, UniFi client correlation, time-series
retention and persistence-based missing-service warnings. Do not auto-update
the source-of-truth inventory from ephemeral observations.

## Deeper service discovery (on demand)

For an explicit device, the standalone `probe_services.py` performs a
bounded top-1000 TCP scan. Use `--fingerprint` to enable Nmap's active
`-sV --version-light` probes and collect the protocol, product, version and
confidence that Nmap can identify. These are heuristic observations, not proof
of installed firmware versions. Some embedded devices may react badly to
unexpected probes, so do **not** enable fingerprinting automatically on all
devices. The default scanner remains less intrusive.

```bash
sudo python3 /home/docker/ygg-compose/Scripts/network-inventory/probe_services.py \
  --top-ports 1000 10.4.20.101 10.4.20.110

# More intrusive: inspect the service fingerprints for a selected device.
sudo python3 /home/docker/ygg-compose/Scripts/network-inventory/probe_services.py \
  --fingerprint 10.4.20.33
```

To inventory advertised service types independently of the TCP probes:

```bash
avahi-browse -a -r -p -t
# An additional read-only broadcast DNS-SD query:
sudo nmap --script=broadcast-dns-service-discovery
```

mDNS/DNS-SD tells you that a host **advertises** a service. An advertised
port can be UDP, TCP, firewalled or unreachable; do not automatically treat
it as a verified open port.

## Propose confirmed port additions to private inventory

`propose_ports.py` is a **manual, idempotent proposal helper** containing
the five observed services from the initial audit (aircon, Alexa, doorbell,
Sonos Sub, Fire TV). It preserves all other fields and the older
`open_ports` format, refuses in-place mutation, and produces a separate
review file. Do not apply unverified descriptions or changing iPhone ephemeral
ports as canonical expectations.

Run the helper **on Pleiades from the merged `ygg-compose` runtime checkout**.
It reads the deployed inventory but writes its proposal outside that checkout:

```bash
cd /home/docker/ygg-compose
python3 Scripts/network-inventory/propose_ports.py \
  Scripts/cloudflare/static-hosts.json \
  --output /tmp/proposed-static-hosts.json
diff -u Scripts/cloudflare/static-hosts.json /tmp/proposed-static-hosts.json
```

Review the proposed JSON, then commit any accepted inventory changes to
`ebertek-compose-secrets` through the normal source-repository workflow.
Do **not** copy the proposal into tracked files under `ygg-compose`.
This helper does not change DHCP, Cloudflare or the deployed inventory.

## MAC discrepancy investigation

Nmap's observed MACs come from link-layer responses, not the device label.
Compare them with UniFi's live client identity and ARP neighbors before
changing canonical MAC values. For LG TVs, independently check the wired
and Wi-Fi MACs on the TV and the UniFi switch port for the wired interface.
For Sonos, identify the MAC of other Sonos devices and the Sub's connection
type. A stale neighbor entry, proxy ARP, bridge or alternate interface can
produce misleading IP-to-MAC correlations.
