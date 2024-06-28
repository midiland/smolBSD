#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage:	${0##*/} -k kernel -i image [-a kernel parameters] [-m memory in MB]
	[-r root disk] [-d drive2] [-p port] [-w path]

	Boot a microvm
	-k kernel	kernel to boot on
	-a parameters	append kernel parameters
	-m memory	memory in MB
	-r root disk	root disk to boot on
	-i image	image to use as root filesystem
	-d drive2	second drive to pass to image
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	-w path		host path to share with guest (9p)
_USAGE_
	# as per https://www.qemu.org/docs/master/system/invocation.html
	# hostfwd=[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	exit 1
}

which uuidgen 1>/dev/null
if [ $? -eq 1 ]; then
	echo "uuidgen not available"
	exit 1
fi

[ $# -lt 4 ] && usage

options="k:a:p:i:m:r:d:p:w:h"

uuid="$(uuidgen | cut -d- -f1)"

while getopts "$options" opt
do
	case $opt in
	k) kernel="$OPTARG";;
	i) img="$OPTARG";;
	a) append="$OPTARG";;
	m) mem="$OPTARG";;
	r) root="$OPTARG";;
	d) drive2="\
		-device virtio-blk-device,drive=hd${uuid}1 \
		-drive if=none,file=${OPTARG},format=raw,id=hd${uuid}1"
		;;
	p) network="\
		-device virtio-net-device,netdev=net${uuid}0 \
		-netdev user,id=net${uuid}0,hostfwd=${OPTARG}"
		;;
	h) usage;;
	w) share="\
		-fsdev local,path=${OPTARG},security_model=mapped,id=shar${uuid}0 \
		-device virtio-9p-device,fsdev=shar${uuid}0,mount_tag=shar${uuid}0"
		;;
	*) usage;;
	esac
done

OS=$(uname -s)
MACHINE=$(uname -p)

# Linux on RPi
[ "$MACHINE" = "unknown" ] && MACHINE=$(uname -m)

cputype="host"

case $OS in
NetBSD)
	ACCEL=",accel=nvmm"
	;;
Linux)
	ACCEL=",accel=kvm"
	;;
Darwin)
	ACCEL=",accel=hvf"
	# Mac x86 uname -p returns i386
	[ "$MACHINE" = "i386" ] && MACHINE="x86_64"
	# Mac M1
	[ "$MACHINE" = "arm" ] && MACHINE="aarch64" cputype="cortex-a710"
	;;
*)
	echo "Unknown hypervisor, no acceleration"
esac

mem=${mem:-"256"}
append=${append:-"-z"}

case $MACHINE in
x86_64|i386)
	mflags="-M microvm,x-option-roms=off,rtc=on,acpi=off,pic=off${ACCEL}"
	cpuflags="-cpu ${cputype},+invtsc"
	root=${root:-"ld0a"}
	;;
aarch64)
	mflags="-M virt${ACCEL},highmem=off"
	cpuflags="-cpu ${cputype}"
	root=${root:-"ld4a"}
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
	-device virtio-blk-device,drive=hd${uuid}0 \
	-drive if=none,file=${img},format=raw,id=hd${uuid}0 $drive2 $network
