#!/bin/sh

# bare minimum
mknod -m 600 dev/console c 0 0
mknod -m 666 dev/null c 2 2

mkdir -p packages
if [ "$ARCH" = "amd64" ]; then # I keep the binary package updated
	VERSION=0.5
	${FETCH} -o packages/nitro.tgz https://imil.net/NetBSD/nitro-${VERSION}.tgz?$RANDOM
else
	PKGARCH=${ARCH#evbarm-}
	${FETCH} -o packages/nitro.tgz https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${PKGARCH}/nitro-*
fi

PREFIX=usr/pkg
mkdir -p ${PREFIX}
$TAR zxvfp packages/nitro.tgz --exclude='+*' -C ${PREFIX}

mv ${PREFIX}/sbin/nitro sbin/init
for d in var/run/nitro ${PREFIX}/etc/nitro/SYS ${PREFIX}/etc/nitro/getty-0
do
	mkdir -p $d
done

ln -sf /var/run/nitro/nitro.sock ${PREFIX}/etc/nitro.sock

cat >${PREFIX}/etc/nitro/SYS/setup<<EOF
#!/bin/sh

cd /dev
sh MAKEDEV -M -M all
cd -
EOF
chmod +x ${PREFIX}/etc/nitro/SYS/setup

cat >${PREFIX}/etc/nitro/getty-0/run<<EOF
#!/bin/sh
exec /usr/libexec/getty Pc constty
EOF
cat >${PREFIX}/etc/nitro/getty-0/finish<<EOF
#!/bin/sh
exit 0
EOF
for s in run finish
do
	chmod +x ${PREFIX}/etc/nitro/getty-0/$s
done

cat >etc/motd<<EOF

Welcome to nitroBSD! 🔥

EOF
