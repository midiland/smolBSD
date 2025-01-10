#!/bin/sh

# switch from /sbin/init to runit!
PATH=$PATH:/usr/pkg/bin:/usr/pkg/sbin
for d in "" s
do
	mkdir -p usr/pkg/${d}bin
	cp -f /usr/pkg/${d}bin/pkg_* usr/pkg/${d}bin/
done
cp -f /etc/resolv.conf etc/
cp -R /etc/openssl/* etc/openssl/
mkdir -p usr/pkg/etc/pkgin
cp -f /usr/pkg/etc/pkgin/repositories.conf usr/pkg/etc/pkgin/
pkgin -y -c $(pwd) in runit
mkdir -p etc/runit
cp -p usr/pkg/share/examples/runit/openbsd/1 etc/runit/
sed 's/local/pkg/g' usr/pkg/share/examples/runit/openbsd/2 > etc/runit/2
sed 's,/command,/command:/usr/pkg/bin:/usr/pkg/sbin,' \
	usr/pkg/share/examples/runit/openbsd/3 > etc/runit/3
chmod +x etc/runit/[123]
install -m 0500 usr/pkg/sbin/runit* sbin/
mkdir -p etc/sv/getty-0
cat >etc/sv/getty-0/run<<EOF
#!/bin/sh
exec /usr/libexec/getty Pc constty
EOF
cat >etc/sv/getty-0/finish<<EOF
#!/bin/sh
exit 0
EOF
for s in run finish
do
	chmod +x etc/sv/getty-0/$s
done
mkdir -p service
ln -s /etc/sv/getty-0 service/
cp -p sbin/init sbin/init.bsd
cp -p sbin/runit-init sbin/init

cd dev && sh MAKEDEV all
cd -
