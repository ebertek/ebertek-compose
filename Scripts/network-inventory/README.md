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
ports and **every inventoried TCP port** on discovered hosts. It limits retries,
uses a per-host timeout, and parses Nmap XML, **not grepped output**.
It excludes currently observed Docker container IP addresses from active port
tests and alerts, rather than ignoring the entire `10.4.21.0/24` subnet.

Avahi DNS-SD observations are deduplicated across interface/address family.
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
