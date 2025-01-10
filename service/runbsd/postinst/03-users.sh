#!/bin/sh

passwd=$(openssl passwd 'runbsd')

chroot $(pwd) \
	useradd -m -g wheel -p "$passwd" runbsd
