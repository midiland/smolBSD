#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage: ${0##*/} -k kernel -i image [-a kernel parameters] [-m memory in MB] [-d drive2] [-p port]
	Boot a microvm
	-k kernel	kernel to boot on
	-a parameters	append kernel parameters
	-i image	image to use as root filesystem
	-d drive2	second drive to pass to image
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
_USAGE_
	# as per https://www.qemu.org/docs/master/system/invocation.html
	# hostfwd=[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	exit 1
}

[ $# -lt 4 ] && usage

options="k:a:p:i:m:d:p:h"

while getopts "$options" opt
do
	case $opt in
	k) kernel="$OPTARG";;
	a) append="$OPTARG";;
	i) img="$OPTARG";;
	m) mem="$OPTARG";;
	d) drive2="\
		-device virtio-blk-device,drive=smolhd1 \
		-drive file=${OPTARG},format=raw,id=smolhd1";;
	p) network="\
		-device virtio-net-device,netdev=smolnet0 \
		-netdev user,id=smolnet0,hostfwd=${OPTARG}";;
	h) usage;;
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

qemu-system-x86_64 \
	-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off${ACCEL} \
	-m $mem -cpu host,+invtsc \
	-kernel $kernel -append "console=com root=ld0a ${append}" \
	-serial mon:stdio -display none \
	-device virtio-blk-device,drive=smolhd0 \
	-drive file=${img},format=raw,id=smolhd0 $drive2 $network
