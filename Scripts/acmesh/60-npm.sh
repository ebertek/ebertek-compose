#!/bin/sh
rm /volume1/docker/npm/custom_ssl/npm-2/*.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/fullchain.cer /volume1/docker/npm/custom_ssl/npm-2/fullchain.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.key /volume1/docker/npm/custom_ssl/npm-2/privkey.pem
docker exec npm sh -c "/usr/sbin/nginx -s reload"
