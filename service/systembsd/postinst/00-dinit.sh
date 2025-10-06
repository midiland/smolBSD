#!/bin/sh

# bare minimum
mknod -m 600 dev/console c 0 0
mknod -m 600 dev/constty c 0 1
mknod -m 666 dev/tty c 1 0
mknod -m 666 dev/null c 2 2
mknod -m 666 dev/stdin c 22 0
mknod -m 666 dev/stdout c 22 1
mknod -m 666 dev/stderr c 22 2

mkdir -p packages
# dinit is not yet part of a pkgsrc release
${FETCH} -o packages/dinit.tgz https://imil.net/NetBSD/dinit-0.19.3nb2.tgz

mkdir -p usr/pkg
$TAR zxvfp packages/dinit.tgz --exclude='+*' -C usr/pkg

mv usr/pkg/sbin/dinit sbin/init
