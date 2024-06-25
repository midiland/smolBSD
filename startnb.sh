#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage:	${0##*/} -k kernel -i image [-a kernel parameters] [-m memory in MB]
	[-d drive2] [-p port] [-w path]

	Boot a microvm
	-k kernel	kernel to boot on
	-a parameters	append kernel parameters
	-m memory	memory in MB
	-i image	image to use as root filesystem
	-d drive2	second drive to pass to image
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	-w path		host path to share with guest (9p)
_USAGE_
	# as per https://www.qemu.org/docs/master/system/invocation.html
	# hostfwd=[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	exit 1
}

[ $# -lt 4 ] && usage

options="k:a:p:i:m:d:p:w:h"

while getopts "$options" opt
do
	case $opt in
	k) kernel="$OPTARG";;
	a) append="$OPTARG";;
	i) img="$OPTARG";;
	m) mem="$OPTARG";;
	d) drive2="\
		-device virtio-blk-device,drive=smolhd1 \
		-drive if=none,file=${OPTARG},format=raw,id=smolhd1";;
	p) network="\
		-device virtio-net-device,netdev=smolnet0 \
		-netdev user,id=smolnet0,hostfwd=${OPTARG}";;
	h) usage;;
	w) share="\
		-fsdev local,path=${OPTARG},security_model=mapped,id=shar0 \
		-device virtio-9p-device,fsdev=shar0,mount_tag=shar0";;
	*) usage;;
	esac
done

OS=$(uname -s)

case $OS in
Linux)
	ACCEL=",accel=kvm"
	;;
Darwin)
	ACCEL=",accel=hvf"
	;;
NetBSD)
	ACCEL=",accel=nvmm"
	;;
*)
	echo "Unknown hypervisor, no acceleration"
esac

mem=${mem:-"256"}
append=${append:-"-z"}

MACHINE=$(uname -m)

case $MACHINE in
x86_64|i386)
	mflags="-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off${ACCEL}"
	cpuflags="-cpu host,+invtsc"
	root="ld0a"
	;;
aarch64)
	mflags="-M virt${ACCEL}"
	cpuflags="-cpu host"
	root="ld4a"
	extra="-device virtio-rng-pci"
	;;
*)
	echo "Unknown architecture"
esac

qemu-system-${MACHINE} \
	$mflags -m $mem $cpuflags \
	-kernel $kernel -append "console=com root=${root} ${append}" \
	-serial mon:stdio -display none ${extra} \
	-global virtio-mmio.force-legacy=false ${share} \
	-device virtio-blk-device,drive=smolhd0 \
	-drive if=none,file=${img},format=raw,id=smolhd0 $drive2 $network
