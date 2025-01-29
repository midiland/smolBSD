#!/bin/sh

# tmpfs dev is usually done by init(8)
cd /dev
# /dev is a union fs, permissions are recorded and bad
# after reboot for those. MAKEDEV doesn't re-create them
# and -f fails with "-f option works only with mknod"
rm -f tty null std*
sh MAKEDEV -M -M all
cd -

