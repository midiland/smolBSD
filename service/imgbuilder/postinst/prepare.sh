#!/bin/sh

git clone https://gitlab.com/iMil/sailor.git

ship=fakecracker

# create sailor base config - https://gitlab.com/iMil/sailor
cat >sailor/examples/${ship}.conf<<EOF
shipname=$ship
shippath="/sailor/$ship"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail /sbin/poweroff /sbin/umount /sbin/fsck /usr/bin/netstat /sbin/dhcpcd /sbin/route"
packages="nginx"

run_at_build="echo 'creating devices'"
run_at_build="cd /dev && sh MAKEDEV all_md"
run_at_build="echo $pkginrepo >/usr/pkg/etc/pkgin/repositories.conf"
EOF

# boot setup
mkdir -p sailor/ships/$ship/etc

cp dev/MAKEDEV etc/

cp etc/include/basicrc sailor/ships/$ship/etc/rc
cat >sailor/ships/$ship/etc/fstab<<EOF
/dev/ld0a / ffs rw 1 1
EOF

cat >>sailor/ships/$ship/etc/rc<<EOF

# service startup

printf "\nstarting nginx.. "
/usr/pkg/sbin/nginx
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
echo
echo "^D to cleanly shutdown"
#tail -f /var/log/nginx/access.log
sh
poweroff
umount -a
fsck -q -y /dev/ld0a
EOF

