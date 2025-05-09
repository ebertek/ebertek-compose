#!/bin/sh
rm /volume2/docker/npm/custom_ssl/npm-2/*.pem
cp /volume2/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume2/docker/npm/custom_ssl/npm-2/fullchain.pem
cp /volume2/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume2/docker/npm/custom_ssl/npm-2/privkey.pem
docker exec npm sh -c "/usr/sbin/nginx -s reload"
