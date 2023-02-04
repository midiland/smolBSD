#!/bin/sh

kernel=$1

[ -n "$2" ] && img=$2 || img=root.img

qemu-system-x86_64 -enable-kvm -kernel $kernel -append "console=com root=ld0a" \
	-serial stdio -display none \
	-drive file=${img},if=virtio \
	-netdev type=tap,id=net0 -device virtio-net-pci,netdev=net0
