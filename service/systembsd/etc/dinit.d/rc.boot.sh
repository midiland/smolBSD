#!/bin/sh

# basic services to start at boot
STARTSVC="
bootconf.sh
ttys
sysctl
entropy
network
local
"

for svc in $STARTSVC
do
	/etc/rc.d/${svc} start
done
