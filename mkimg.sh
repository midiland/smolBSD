#!/bin/sh

dd if=/dev/zero of=./ext2root.img bs=1M count=10

mke2fs ext2root.img

mkdir -p mnt
mount -o loop ext2root.img mnt

tar zxvfp sets/rescue.tgz -C mnt/
cd mnt
mkdir -p sbin bin dev
cp -f ../etc/* etc/
for b in init mount_ext2fs
do
	ln -s /rescue/$b sbin/
done
ln -s /rescue/sh bin/

cd dev

mknod console c 0 0 -m  600
mknod constty c 0 1 -m  600
mknod drum    c 4 0 -m  640
mknod kmem    c 2 1 -m  640
mknod mem     c 2 0 -m  640
mknod null    c 2 2 -m  666
mknod full    c 2 11 -m 666
mknod zero    c 2 12 -m 666
mknod klog    c 7 0 -m  600
mknod ksyms   c 85 0 -m 444
mknod random  c 46 0 -m 444
mknod urandom c 46 1 -m 644
mknod ld0a    b 19 0 -m 640

cd ../..

umount mnt
