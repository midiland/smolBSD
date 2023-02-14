#!/bin/sh

[ $# -lt 1 ] && exit 1

kern=$1

keep="mainbus cpu acpicpu ioapic pci isa pcdisplay wsdisplay com virtio ld vioif"

gdb -n $kern --batch -x drvdig.gdb -ex "loop_cfdata" | \
while read addr drv x
do
	found=0
	for k in $keep
	do
		[ "$k" = "$drv" ] && found=1 && break
	done

	[ $found -eq 1 ] && echo "not removing $drv" && continue

	echo "removing $drv"
	gdb -n $kern --write --batch -x drvdig.gdb -ex "fstate 3 0x$addr"

        status=$?
        if [ $status -ne 0 ]
        then
                echo "Something terribly wrong has happened! GDB return $status"
                exit 1
        fi
done
