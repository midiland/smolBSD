#!/bin/sh

# dinit is not yet part of a pkgsrc release
curl -L -s -o packages/dinit.tgz https://imil.net/NetBSD/dinit-0.19.3nb1.tgz

mkdir -p usr/pkg
$TAR zxvfp packages/dinit.tgz --exclude='+*' -C usr/pkg

mv usr/pkg/sbin/dinit sbin/init
