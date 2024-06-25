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
	-k kernel	kernel to copy in the image
_USAGE_
	exit 1
}

options="s:m:i:x:k:h"

while getopts "$options" opt
do
	case $opt in
	s) svc="$OPTARG";;
	m) megs="$OPTARG";;
	i) img="$OPTARG";;
	x) sets="$OPTARG";;
	k) kernel="$OPTARG";;
	h) usage;;
	*) usage;;
	esac
done

[ -z "$svc" ] && svc=rescue
[ -z "$megs" ] && megs=20
[ -z "$img" ] && img=rescue.img
[ -z "$sets" ] && sets=rescue.tar.xz

[ ! -f service/${svc}/etc/rc ] && \
	echo "no service/${svc}/etc/rc available" && exit 1

OS=$(uname -s)

[ "$OS" = "Linux" ] && is_linux=1

[ -n "$is_linux" ] && u=M || u=m

dd if=/dev/zero of=./${img} bs=1${u} count=${megs}

mkdir -p mnt

if [ -n "$is_linux" ]; then
	mke2fs -O none $img
	mount -o loop $img mnt
else
	vnd=$(vndconfig -l|grep -m1 'not'|cut -f1 -d:)
	vndconfig $vnd $img
	newfs /dev/${vnd}a
	mount /dev/${vnd}a mnt
fi

for s in ${sets}
do
	[ -n "$ARCH" ] && s="${ARCH}/${s}"
	tar xfp sets/${s} -C mnt/ || exit 1
done

[ -n "$kernel" ] && cp -f $kernel mnt/

cd mnt
mkdir -p sbin bin dev etc/include

cp -f ../etc/fstab.${OS} etc/fstab
cp -f ../service/${svc}/etc/* etc/
cp -f ../service/common/* etc/include/

# warning, postinst operations are done on the builder

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

cd ..

umount mnt

[ -z "$is_linux" ] && vndconfig -u $vnd

exit 0
