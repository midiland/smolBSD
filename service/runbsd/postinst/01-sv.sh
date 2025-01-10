#!/bin/sh

mkdir -p etc/sv/sshd
for l in run finish
do
	ln -s /bin/rcd2run.sh etc/sv/sshd/$l
done

ln -s /etc/sv/sshd service/

# runit needs the service to not bg
cat >>etc/rc.conf<<EOF
sshd_flags="-D"
sshd=YES
EOF
