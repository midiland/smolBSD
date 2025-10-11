#!/bin/sh

# bare minimum
mknod -m 600 dev/console c 0 0
mknod -m 666 dev/null c 2 2

mkdir -p packages
VERSION=0.4.1
${FETCH} -o packages/nitro.tgz https://imil.net/NetBSD/nitro-${VERSION}.tgz?$RANDOM

PREFIX=usr/pkg
mkdir -p ${PREFIX}
$TAR zxvfp packages/nitro.tgz --exclude='+*' -C ${PREFIX}

mv ${PREFIX}/sbin/nitro sbin/init
for d in var/run/nitro \
	${PREFIX}/etc/nitro/SYS \
	${PREFIX}/etc/nitro/LOG \
	${PREFIX}/etc/nitro/sshd home
do
	mkdir -p ${d}
done

ln -sf /var/run/nitro/nitro.sock ${PREFIX}/etc/nitro.sock

# ptyfs is needed to provide ttys to clients
echo "ptyfs /dev/pts ptyfs rw 0 0" >> etc/fstab

# we want sshd to be the main process
echo 'sshd_flags="-D -e"' >> etc/rc.conf
echo 'UseDNS no' >> etc/ssh/sshd_config

# if running an agent
ssh-add -L >etc/ssh/authorized_keys 2>/dev/null
pubkeys="../service/nitrosshd/etc/*.pub"
ls $pubkeys >/dev/null 2>&1 && \
	cat $pubkeys >>etc/ssh/authorized_keys

cat >${PREFIX}/etc/nitro/SYS/setup<<EOF
#!/bin/sh

cd /dev
sh MAKEDEV -M -M all
cd -

. /etc/include/basicrc

mount -t tmpfs -o -s1M tmpfs /home
mount -t tmpfs -o -s10M tmpfs /tmp
mount -t tmpfs -o -s1M -o union tmpfs /var/run
mount -t tmpfs -o -s10M -o union tmpfs /var/log
mount -t tmpfs -o -s20M -o union tmpfs /etc
# union mount is not recursive
mount -t tmpfs -o -s1M -o union tmpfs /etc/ssh

exit 0
EOF
chmod +x ${PREFIX}/etc/nitro/SYS/setup
cat >${PREFIX}/etc/nitro/LOG/run<<EOF
#!/bin/sh
exec cat >/dev/console 2>&1
EOF
chmod +x ${PREFIX}/etc/nitro/LOG/run
cat >${PREFIX}/etc/nitro/sshd/run<<EOF
#!/bin/sh
exec 2>&1
useradd -m ssh
mkdir -p /home/ssh/.ssh
[ -f /etc/ssh/authorized_keys ] && \
	cp -f /etc/ssh/authorized_keys /home/ssh/.ssh ||
	echo "/!\ NO PUBLIC KEY, copy your SSH public key in service/${SERVICE}/etc/ssh"
chown -R ssh /home/ssh

/etc/rc.d/sshd onestart
EOF
cat >${PREFIX}/etc/nitro/sshd/finish<<EOF
#!/bin/sh
exit 0
EOF
for s in run finish
do
	chmod +x ${PREFIX}/etc/nitro/sshd/$s
done
