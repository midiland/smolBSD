#!/bin/sh

# sample script to use with knockd.sh, I use it from Termux
# on my Android phone

echo -n "port: "
stty -echo
read port
stty echo
echo

DEST=$1
PORTS="$port $(($port + 1)) $port"

knock()
{
	for p in $PORTS
	do
		echo "knocking"
		echo|nc -w5 $DEST $p
	done
}

knock
ssh -p $(($port + 2)) ssh@$DEST
knock
