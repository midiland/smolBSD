GENERIC=netbsd-GENERIC
SMOL=	netbsd-SMOL
LIST=	virtio.list
# use a specific version
# VERS=	9.3
# DIST=	https://cdn.netbsd.org/pub/NetBSD/NetBSD-${VERS}/i386/binary
#
# current
DIST=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/i386/binary

kernfetch:
	[ -f ${GENERIC} ] || curl -o- ${DIST}/kernel/${GENERIC}.gz | gzip -dc > ${GENERIC}

setfetch:
	[ -d sets ] || mkdir sets
	for s in ${SETS}; do \
		if [ ! -f sets/$$s ]; then \
			curl -O --output-dir sets ${DIST}/sets/$$s; \
		fi; \
	done

smol:	kernfetch
	test -f ${SMOL} || { \
		[ -d confkerndev ] || \
		git clone https://gitlab.com/0xDRRB/confkerndev.git; \
		cd confkerndev && make i386; cd ..; \
		cp -f ${GENERIC} ${SMOL}; \
		confkerndev/confkerndevi386 -v -i ${SMOL} -K virtio.list -w; \
	}

rescue:	smol
	./mkimg.sh

base:	smol
	$(MAKE) setfetch SETS="base.tgz etc.tgz"
	sudo ./mkimg.sh -i $@.img -s $@ -m 300 -x "base.tgz etc.tgz"

prof:	smol
	$(MAKE) setfetch SETS="base.tgz etc.tgz comp.tgz"
	sudo ./mkimg.sh -i $@.img -s $@ -m 1000 -k ${KERN} -x "base.tgz etc.tgz comp.tgz"

imgbuilder: smol
	$(MAKE) setfetch SETS="base.tgz etc.tgz"
	sudo ./mkimg.sh -i $@.img -s $@ -m 500 -x "base.tgz etc.tgz"

nginx:	imgbuilder
	dd if=/dev/zero of=$@.img bs=1M count=100
	sudo ./startnb.sh ${SMOL} $<.img $@.img
