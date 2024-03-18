#!/bin/sh

kernel=$1

img=${2:-"root.img"}

[ -n "$3" ] && \
	drive2="\
		-device virtio-blk-device,drive=smolhd1 \
		-drive file=${3},if=virtio,format=raw,id=smolhd1"

OS=$(uname -s)

case $OS in
Linux)
	accel=kvm
	;;
Darwin)
	accel=hvf
	;;
NetBSD)
	accel=nvmm
	;;
*)
	echo "Unknown hypervisor"
	exit 1
esac

qemu-system-x86_64 \
	-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off,accel=$accel \
	-m 256 -cpu host,+invtsc \
	-kernel $kernel -append "console=com root=ld0a -z" \
	-serial mon:stdio -display none \
	-device virtio-blk-device,drive=smolhd0 \
	-drive file=${img},format=raw,id=smolhd0 $drive2 \
	-device virtio-net-device,netdev=smolnet0 \
	-netdev user,id=smolnet0,hostfwd=tcp::2022-:22 \
