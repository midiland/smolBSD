#!/bin/sh

sudo kvm -kernel $1 -append "console=com root=ld0a" \
	-serial stdio -display none \
	-drive file=ext2root.img,if=virtio \
	-netdev type=tap,id=net0 -device virtio-net-pci,netdev=net0
