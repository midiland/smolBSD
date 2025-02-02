#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage:	${0##*/} -f conffile | -k kernel -i image [-c CPUs] [-m memory]
	[-a kernel parameters] [-r root disk] [-h drive2] [-p port] [-b]
	[-t tcp serial port] [-w path] [-x qemu extra args] [-s] [-d] [-v]

	Boot a microvm
	-f conffile	vm config file
	-k kernel	kernel to boot on
	-i image	image to use as root filesystem
	-c cores	number of CPUs
	-m memory	memory in MB
	-a parameters	append kernel parameters
	-r root disk	root disk to boot on
	-l drive2	second drive to pass to image
	-t serial port	TCP serial port
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	-w path		host path to share with guest (9p)
	-x arguments	extra qemu arguments
	-b		bridge mode
	-s		don't lock image file
	-d		daemonize
	-v		verbose
	-h		this help
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

# Check if VirtualBox VM is running
if pgrep VirtualBoxVM >/dev/null 2>&1; then
	echo "Unable to start KVM: VirtualBox is running"
	exit 1
fi

options="f:k:a:p:i:m:c:r:l:p:w:x:t:hbdsv"

uuid="$(uuidgen | cut -d- -f1)"

# and possibly override its values
while getopts "$options" opt
do
	case $opt in
	# first load vm config file
	f) . $OPTARG;;
	# and possibly override values
	k) kernel="$OPTARG";;
	i) img="$OPTARG";;
	a) append="$OPTARG";;
	m) mem="$OPTARG";;
	c) cores="$OPTARG";;
	r) root="$OPTARG";;
	l) drive2=$OPTARG;;
	p) hostfwd=$OPTARG;;
	w) share=$OPTARG;;
	t) serial_port=$OPTARG;;
	x) extra=$OPTARG;;
	b) bridgenet=yes;;
	s) sharerw=yes;;
	d) DAEMON=yes;;
	v) VERBOSE=yes;;
	h) usage;;
	*) usage;;
	esac
done

# fallback to those
kernel=${kernel:-$KERNEL}
img=${img:-$NBIMG}

if [ -z "$kernel" -o -z "$img" ]; then
	echo "" 1>&2
	[ -z "$kernel" ] && echo "'kernel' is not defined" 1>&2
	[ -z "$img" ] && echo "'image' is not defined" 1>&2
	echo "" 1>&2
	usage
fi

[ -n "$hostfwd" ] && network="\
-device virtio-net-device,netdev=net${uuid}0 \
-netdev user,id=net${uuid}0,ipv6=off,$(echo "$hostfwd"|sed 's/::/hostfwd=::/g')"

[ -n "$bridgenet" ] && network="$network \
-device virtio-net-device,netdev=net${uuid}1 \
-netdev type=tap,id=net${uuid}1"

[ -n "$drive2" ] && drive2="\
-device virtio-blk-device,drive=hd${uuid}1 \
-drive if=none,file=${drive2},format=raw,id=hd${uuid}1"

[ -n "$share" ] && share="\
-fsdev local,path=${share},security_model=mapped,id=shar${uuid}0 \
-device virtio-9p-device,fsdev=shar${uuid}0,mount_tag=shar${uuid}0"

[ -n "$sharerw" ] && sharerw=",share-rw=on"

OS=$(uname -s)
MACHINE=$(uname -m) # Linux and macos x86

cputype="host"

case $OS in
NetBSD)
	MACHINE=$(uname -p)
	ACCEL=",accel=nvmm"
	;;
Linux)
	ACCEL=",accel=kvm"
	# Some weird Ryzen CPUs
	[ "$MACHINE" = "AMD" ] && MACHINE="x86_64"
	;;
Darwin)
	ACCEL=",accel=hvf"
	# Mac M1
	[ "$MACHINE" = "arm64" ] && MACHINE="aarch64" cputype="cortex-a710"
	;;
OpenBSD)
	MACHINE=$(uname -p)
	ACCEL=",accel=tcg"
	# uname -m == "amd64" but qemu-system is "qemu-system-x86_64"
	if [ "$MACHINE" = "amd64" ]; then
		MACHINE="x86_64"
	fi
	cputype="qemu64"
	;;
*)
	echo "Unknown hypervisor, no acceleration"
esac

QEMU="qemu-system-${MACHINE}"

mem=${mem:-"256"}
cores=${cores:-"1"}
append=${append:-"-z"}

case $MACHINE in
x86_64|i386)
	mflags="-M microvm,rtc=on,acpi=off,pic=off${ACCEL}"
	cpuflags="-cpu ${cputype},+invtsc"
	root=${root:-"ld0a"}
	# stack smashing with version 9.0 and 9.1
	${QEMU} --version|egrep -q '9\.[01]' && \
		extra="$extra -L bios -bios bios-microvm.bin"
	;;
aarch64)
	mflags="-M virt${ACCEL},highmem=off,gic-version=3"
	cpuflags="-cpu ${cputype}"
	root=${root:-"ld4a"}
	extra="$extra -device virtio-rng-pci"
	;;
*)
	echo "Unknown architecture"
esac

d="-display none"
if [ -n "$DAEMON" ]; then
	# a TCP port is specified
	[ -n "${serial_port}" ] && \
		serial="-serial telnet:localhost:${serial_port},server,nowait"
	d="$d -daemonize $serial"
else
	# console output
	d="$d -serial mon:stdio"
fi
# QMP is available
[ -n "${qmp_port}" ] && extra="$extra -qmp tcp:localhost:${qmp_port},server,wait=off"

cmd="${QEMU} -smp $cores \
	$mflags -m $mem $cpuflags \
	-kernel $kernel -append \"console=com root=${root} ${append}\" \
	-global virtio-mmio.force-legacy=false ${share} \
	-device virtio-blk-device,drive=hd${uuid}0${sharerw} \
	-drive if=none,file=${img},format=raw,id=hd${uuid}0 \
	${drive2} ${network} ${d} ${extra}"

[ -n "$VERBOSE" ] && echo "$cmd" && exit

eval $cmd
