#!/bin/sh

usage()
{
	cat 1>&2 << _USAGE_
Usage: ${0##*/} [-s service] [-m megabytes] [-n image] [-x set]
	Create a root image
	-s service	service name, default "rescue"
	-m megabytes	image size in megabytes, default 10
	-i image	image name, default root.img
	-x sets		list of NetBSD sets, default rescue.tgz
_USAGE_
	exit 1
}

options="s:m:i:x:h"

while getopts "$options" opt
do
	case $opt in
	s) svc="$OPTARG";;
	m) megs="$OPTARG";;
	i) img="$OPTARG";;
	x) sets="$OPTARG";;
	h) usage;;
	*) usage;;
	esac
done

[ -z "$svc" ] && svc=rescue
[ -z "$megs" ] && megs=10
[ -z "$img" ] && img=root.img
[ -z "$sets" ] && sets=rescue.tgz

[ ! -f service/${svc}/etc/rc ] && \
	echo "no service/${svc}/etc/rc available" && exit 1

OS=$(uname -s)

[ "$OS" = "Linux" ] && is_linux=1

[ -n "$is_linux" ] && u=M || u=m

dd if=/dev/zero of=./${img} bs=1${u} count=${megs}

mkdir -p mnt

if [ -n "$is_linux" ]; then
	mke2fs $img
	mount -o loop $img mnt
else
	vnd=$(vndconfig -l|grep -m1 'not'|cut -f1 -d:)
	vndconfig $vnd $img
	newfs /dev/${vnd}a
	mount /dev/${vnd}a mnt
fi

for s in ${sets}
do
	tar zxvfp sets/${s} -C mnt/
done

cd mnt
mkdir -p sbin bin dev etc/include

cp -f ../etc/fstab.${OS} etc/fstab
cp -f ../service/${svc}/etc/* etc/
cp -f ../service/common/* etc/include/

[ -d ../service/${svc}/postinst ] &&
	for x in ../service/${svc}/postinst/*.sh
	do
		sh $x
	done

if [ "$svc" = "rescue" ]; then
	for b in init mount_ext2fs
	do
		ln -s /rescue/$b sbin/
	done
	ln -s /rescue/sh bin/
fi

cd dev

mknod -m 600 console c 0 0
mknod -m 600 constty c 0 1
mknod -m 640 drum    c 4 0
mknod -m 640 kmem    c 2 1
mknod -m 640 mem     c 2 0
mknod -m 666 null    c 2 2
mknod -m 666 full    c 2 11
mknod -m 666 zero    c 2 12
mknod -m 600 klog    c 7 0
mknod -m 444 ksyms   c 85 0
mknod -m 444 random  c 46 0
mknod -m 644 urandom c 46 1
mknod -m 666 tty     c 1 0
mknod -m 666 stdin   c 22 0
mknod -m 666 stdout  c 22 1
mknod -m 666 stderr  c 22 2
mknod -m 640 ld0a    b 19 0
mknod -m 640 rld0a   c 69 0
mknod -m 640 ld1a    b 19 1

cd ../..

umount mnt

[ -z "$is_linux" ] && vndconfig -u $vnd

exit 0
