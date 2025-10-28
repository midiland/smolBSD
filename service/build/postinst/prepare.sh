#!/bin/sh

mkdir -p usr/pkg/etc/pkgin
echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${ARCH}/${PKGVERS}/All" > \
	usr/pkg/etc/pkgin/repositories.conf
