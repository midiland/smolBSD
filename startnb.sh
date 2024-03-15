#!/bin/sh

kernel=$1

img=${2:-"root.img"}

[ -n "$3" ] && \
	drive2="\
		-device virtio-blk-device,drive=hd1 \
		-drive file=${3},if=virtio,format=raw,id=hd1"

qemu-system-x86_64 \
	-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off \
	-enable-kvm -m 256 -cpu host,+invtsc \
	-kernel $kernel -append "console=com root=ld0a -z" \
	-serial mon:stdio -display none \
	-device virtio-blk-device,drive=hd0 \
	-drive file=${img},format=raw,id=hd0 $drive2 \
	-device virtio-net-device,netdev=net0 \
	-netdev user,id=net0,hostfwd=tcp::2022-:22 \
	-device virtio-net-device,netdev=tap0 \
	-netdev tap,id=tap0,script=no,downscript=no
