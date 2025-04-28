#!/bin/sh
rm /volume1/docker/plex/config/tnt.photo.pfx
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.pfx /volume1/docker/plex/config/tnt.photo.pfx
chown docker:users /volume1/docker/plex/config/tnt.photo.pfx
chmod 644 /volume1/docker/plex/config/tnt.photo.pfx
docker exec plex sh -c "kill -9 \`pidof \"Plex Media Server\"\`"
