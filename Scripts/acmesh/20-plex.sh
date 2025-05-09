#!/bin/sh
rm /volume2/docker/plex/config/tnt.photo.pfx
cp /volume2/docker/acmesh/tnt.photo_ecc/tnt.photo.pfx /volume2/docker/plex/config/tnt.photo.pfx
chown docker:users /volume2/docker/plex/config/tnt.photo.pfx
chmod 644 /volume2/docker/plex/config/tnt.photo.pfx
docker exec plex sh -c "kill -9 \`pidof \"Plex Media Server\"\`"
