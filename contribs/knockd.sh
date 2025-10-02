#!/bin/sh

# usage
# server side: PORTS="1050 2000 3000" SERVICE="sshd" contribs/knockd.sh
# client side: PORTS="1050 2000 3000" && \
# 	for p in $PORTS; do nc -w0 localhost $p; done
#
# unlike the real `knockd`, start ports and stop ports are
# identical

SERVICE=$1
pid=qemu-${SERVICE}.pid

while :
do
	echo "entering loop"
	for p in $PORTS
	do
		nc -l -p "$p"
		echo "got port $p"
	done
	echo "SESAME"
	[ -f "$pid" ] && \
		kill $(cat $pid) || \
		./startnb.sh -f etc/${SERVICE}.conf &
done
