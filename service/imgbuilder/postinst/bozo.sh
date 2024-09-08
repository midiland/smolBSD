#!/bin/sh

git clone https://gitlab.com/iMil/sailor.git

ship=fakecracker

# create sailor base config - https://gitlab.com/iMil/sailor
cat >sailor/${ship}.conf<<EOF
shipname=$ship
shippath="/sailor/$ship"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail /sbin/poweroff /sbin/umount /sbin/fsck /usr/bin/netstat /sbin/dhcpcd /sbin/route"
packages="bozohttpd"
EOF

# system and service startup
mkdir -p sailor/ships/${ship}/etc
cat >>sailor/ships/${ship}/etc/rc<<EOF
. /etc/include/basicrc

# service startup

printf "\nstarting bozohttpd.. "
wwwroot=/var/www

mkdir -p \${wwwroot}

[ ! -f /var/www/index.html ] && \
        echo "<html><body>up!</body></html>" >\${wwwroot}/index.html

/usr/pkg/libexec/bozohttpd -b -c /cgi-bin \${wwwroot}
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
printf "^D to cleanly shutdown\n\n"
sh

. /etc/include/shutdown
EOF

# cgi-bin example
mkdir -p sailor/ships/${ship}/cgi-bin
cat >sailor/ships/${ship}/cgi-bin/hello.sh<<_CGI
#!/bin/sh

PATH=\$PATH:/bin:/sbin

echo "Content-Type: text/plain"
echo
echo -n "kern.version: "
sysctl kern.version
echo -n "vm.loadavg: "
sysctl vm.loadavg
echo -n "hw.physmem: "
sysctl hw.physmem
echo

[ -f /tmp/count ] && count=\$((1 + \$(cat /tmp/count))) || \
	count=1

echo "requests: \$count"
echo \$count >/tmp/count

echo "\$HTTP_X_FORWARDED_FOR \
\$QUERY_STRING \$SCRIPT_NAME \$HTTP_USER_AGENT \$HTTP_REFERER" \
	>>/var/log/http.log

exit 0
_CGI
chmod +x sailor/ships/${ship}/cgi-bin/hello.sh
