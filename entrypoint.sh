#!/usr/bin/env bash

set -euo pipefail

chown -R root:root /conf
find /conf -type d -exec chmod 755 {} +
find /conf -type f -exec chmod 644 {} +
if [ -z "$(ls /conf)" ]; then
    cp -a /usr/local/etc/* /conf/
fi
chown -R kismet:kismet /data
chmod 750 /data

su -l -c 'kismet --no-ncurses --homedir=/data --confdir=/conf' kismet
