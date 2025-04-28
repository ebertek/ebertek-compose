#!/bin/sh
rm /usr/syno/etc/certificate/_archive/3lbZ7c/*.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/ca.cer /usr/syno/etc/certificate/_archive/3lbZ7c/chain.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/fullchain.cer /usr/syno/etc/certificate/_archive/3lbZ7c/fullchain.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.key /usr/syno/etc/certificate/_archive/3lbZ7c/privkey.pem
cp /volume1/docker/acmesh/tnt.photo_ecc/tnt.photo.cer /usr/syno/etc/certificate/_archive/3lbZ7c/cert.pem
chown 0:0 /usr/syno/etc/certificate/_archive/3lbZ7c/*.pem
chmod 400 /usr/syno/etc/certificate/_archive/3lbZ7c/*.pem
# /usr/syno/bin/synosystemctl restart nginx
/usr/syno/bin/synow3tool --gen-all && /bin/systemctl reload nginx
