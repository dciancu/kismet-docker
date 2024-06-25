#!/usr/bin/env bash

set -euo pipefail

if [ -z "$(ls /usr/local/etc)" ]; then
    cp -a /usr/local/etc.orig/. /usr/local/etc/
fi
if [ ! -f /mnt/custom-conf/kismet_custom.conf ]; then
    touch /mnt/custom-conf/kismet_custom.conf
fi
chown -R root:root /usr/local/etc /mnt/custom-conf
find /usr/local/etc /mnt/custom-conf -type d -exec chmod 755 {} +
find /usr/local/etc /mnt/custom-conf -type f -exec chmod 644 {} +
if [ -z "$(ls -a /home/kismet)" ]; then
    cp -a /home/kismet.orig/. /home/kismet/
fi
chown -R kismet:kismet /home/kismet
chmod 700 /home/kismet

su -l -c 'kismet --no-ncurses' kismet
