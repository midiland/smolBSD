#!/bin/sh

# bare minimum
mknod -m 600 dev/console c 0 0
mknod -m 600 dev/constty c 0 1
mknod -m 666 dev/tty c 1 0
mknod -m 666 dev/null c 2 2
mknod -m 666 dev/stdin c 22 0
mknod -m 666 dev/stdout c 22 1
mknod -m 666 dev/stderr c 22 2

mkdir -p packages
VERSION=0.4.1
${FETCH} -o packages/nitro.tgz https://imil.net/NetBSD/nitro-${VERSION}.tgz?$RANDOM

PREFIX=usr/pkg
mkdir -p ${PREFIX}
$TAR zxvfp packages/nitro.tgz --exclude='+*' -C ${PREFIX}

mv ${PREFIX}/sbin/nitro sbin/init
for d in var/run/nitro ${PREFIX}/etc/nitro/SYS ${PREFIX}/etc/nitro/getty-0
do
	mkdir -p $d
done

ln -sf /var/run/nitro/nitro.sock ${PREFIX}/etc/nitro.sock

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
