#!/bin/sh

kernel=$1

img=${2:-"root.img"}

[ -n "$3" ] && drive2="-drive file=${3},if=virtio"

qemu-system-x86_64 -enable-kvm -m 256 -cpu host \
	-kernel $kernel -append "console=com root=ld0a" \
	-serial mon:stdio -display none \
	-drive file=${img},if=virtio $drive2 \
	-netdev type=tap,id=net0 -device virtio-net-pci,netdev=net0 \
	-netdev user,id=net1,hostfwd=tcp::8080-:80 -device virtio-net,netdev=net1
