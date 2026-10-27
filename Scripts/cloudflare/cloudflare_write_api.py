"""Write-only Cloudflare API extension with a strict set of permitted methods.

No delete, resource replacement, policy creation, or arbitrary HTTP request API
is exposed. Every write is made through an explicitly scoped method.
"""

import json
from ipaddress import ip_address
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from cloudflare_api import (
    CloudflareClient,
    CloudflareError,
    checked_id,
    checked_tunnel_id,
)
from cloudflare_desired import HOST, UUID
from cloudflare_live_diff import DOCKER_NETWORK


def policy_links(policies):
    """Convert ordered reusable policy IDs into Cloudflare Access links."""
    if (
        not isinstance(policies, list)
        or not policies
        or len(policies) != len(set(policies))
        or not all(
            isinstance(value, str) and UUID.fullmatch(value) for value in policies
        )
    ):
        raise ValueError("Access policies must be a unique, nonempty list of UUIDs")
    return [
        {"id": identifier, "precedence": rank}
        for rank, identifier in enumerate(policies, start=1)
    ]


class CloudflareWriter(CloudflareClient):
    """Allow only known, non-destructive Cloudflare write operations."""

    def _write(self, method, path, body):
        """Send one explicitly scoped mutation, withholding error payloads."""
        if method not in {"POST", "PUT", "PATCH"}:
            raise ValueError("Cloudflare write method is not allowed")
        request = Request(
            self.base_url + path,
            data=json.dumps(body, allow_nan=False).encode("utf-8"),
            headers={
                "Authorization": "Bearer " + self._token,
                "Content-Type": "application/json",
                "Accept": "application/json",
            },
            method=method,
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                result = json.load(response)
        except HTTPError as error:
            raise CloudflareError(
                f"Cloudflare returned HTTP {error.code} for {method} {path}"
            ) from None
        except (URLError, TimeoutError, ValueError) as error:
            raise CloudflareError(f"Cloudflare {method} {path} failed") from error
        if not isinstance(result, dict) or result.get("success") is not True:
            raise CloudflareError(f"Cloudflare rejected {method} {path}")
        return result.get("result")

    def create_access_app(self, account, hostname, policies):
        """Create a self-hosted, reusable-policy-backed Access application."""
        if not HOST.fullmatch(hostname):
            raise ValueError("Only one-label ebi.nu hostnames can be created")
        body = {
            "name": hostname.split(".", maxsplit=1)[0],
            "domain": hostname,
            "type": "self_hosted",
            "session_duration": "24h",
            "destinations": [{"type": "public", "uri": hostname}],
            "policies": policy_links(policies),
        }
        return self._write("POST", f"/accounts/{checked_id(account)}/access/apps", body)

    def put_tunnel_ingress(self, account, tunnel, config):
        """Replace a validated complete Tunnel config; never omit existing routes."""
        if not isinstance(config, dict) or not isinstance(config.get("ingress"), list):
            raise TypeError("Tunnel configuration must have ingress entries")
        if set(config) - {"ingress", "originRequest"}:
            raise ValueError("Unexpected Tunnel config keys; refusing replacement")
        return self._write(
            "PUT",
            f"/accounts/{checked_id(account)}/cfd_tunnel/"
            f"{checked_tunnel_id(tunnel)}/configurations",
            {"config": config},
        )

    def create_dns_cname(self, zone, hostname, target):
        """Create only a proxied ebi.nu Tunnel CNAME."""
        if not HOST.fullmatch(hostname) or not target.endswith(".cfargotunnel.com"):
            raise ValueError("Invalid managed DNS CNAME request")
        return self._write(
            "POST",
            f"/zones/{checked_id(zone)}/dns_records",
            {
                "name": hostname,
                "type": "CNAME",
                "content": target,
                "ttl": 1,
                "proxied": True,
            },
        )

    def patch_docker_a(self, zone, record_id, address):
        """Change an existing Docker A record's content without touching its flags."""
        if ip_address(address) not in DOCKER_NETWORK:
            raise ValueError("Refusing a DNS update outside the Docker subnet")
        return self._write(
            "PATCH",
            f"/zones/{checked_id(zone)}/dns_records/{checked_id(record_id)}",
            {"content": address},
        )

    def get_dns_record(self, zone, record_id):
        """Read one DNS record immediately before an update."""
        return self.get(
            f"/zones/{checked_id(zone)}/dns_records/{checked_id(record_id)}"
        )["result"]
