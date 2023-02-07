#!/bin/sh

kernel=$1

[ -n "$2" ] && img=$2 || img=root.img

[ -n "$3" ] && drive2="-drive file=${3},if=virtio"

qemu-system-x86_64 -enable-kvm -m 256 \
	-kernel $kernel -append "console=com root=ld0a" \
	-serial mon:stdio -display none \
	-drive file=${img},if=virtio $drive2 \
	-netdev type=tap,id=net0 -device virtio-net-pci,netdev=net0
