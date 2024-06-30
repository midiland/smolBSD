#!/bin/sh

git clone https://gitlab.com/iMil/sailor.git

ship=fakecracker

# create sailor base config - https://gitlab.com/iMil/sailor
cat >sailor/${ship}.conf<<EOF
shipname=$ship
shippath="/sailor/$ship"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail /sbin/poweroff /sbin/umount /sbin/fsck /usr/bin/netstat /sbin/dhcpcd /sbin/route /sbin/mount_tmpfs"
packages="nginx"
EOF

# system and service startup
mkdir -p sailor/ships/${ship}/etc
cat >>sailor/ships/${ship}/etc/rc<<EOF
. /etc/include/basicrc

# service startup

printf "\nstarting nginx.. "
/usr/pkg/sbin/nginx
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
printf "^D to cleanly shutdown\n\n"
sh

. /etc/include/shutdown
EOF
