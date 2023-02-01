#!/bin/sh

keep="mainbus cpu acpicpu ioapic pci isa pcdisplay wsdisplay com virtio ld vioif"

gdb -n netbsd --batch -x drvdig.gdb -ex "loop_cfdata" | \
while read addr drv x
do
	found=0
	for k in $keep
	do
		[ "$k" = "$drv" ] && found=1 && break
	done

	[ $found -eq 1 ] && echo "not removing $drv" && continue

	echo "removing $drv"
	gdb -n netbsd --write --batch -x drvdig.gdb -ex "fstate 3 0x$addr"
done
