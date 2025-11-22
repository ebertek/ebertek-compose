#!/bin/sh
PLEX_CONTAINER=$(docker ps --filter "label=com.docker.compose.service=plex" --format '{{.ID}}' | head -n1)

rm /volume2/docker/plex/config/ebi.nu.pfx
cp /volume2/docker/acmesh/ebi.nu_ecc/ebi.nu.pfx /volume2/docker/plex/config/ebi.nu.pfx
chown docker:users /volume2/docker/plex/config/ebi.nu.pfx
chmod 644 /volume2/docker/plex/config/ebi.nu.pfx
docker exec "$PLEX_CONTAINER" sh -c "kill -9 \`pidof \"Plex Media Server\"\`"
