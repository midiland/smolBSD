GENERIC=netbsd-GENERIC
#SMOL=	netbsd-SMOL
SMOL=	netbsd-perf
LIST=	virtio.list
# use a specific version
VERS=	10
ARCH=	amd64
DIST=	https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
SUDO=	sudo -E ARCH=${ARCH}
KERNURL=	https://imil.net/NetBSD

kernfetch:
	[ -n ${KERNURL} ] && curl -L -O ${KERNURL}/${SMOL} || \
	[ -f ${GENERIC} ] || curl -L -o- ${DIST}/kernel/${GENERIC}.gz | gzip -dc > ${GENERIC}

setfetch:
	setsdir=sets/${ARCH} && \
	[ -d $${setsdir} ] || mkdir -p $${setsdir} && \
	for s in $${SETS}; do \
		if [ ! -f $${setsdir}/$$s ]; then \
			curl -L -O --output-dir $${setsdir} ${DIST}/sets/$$s; \
		fi; \
	done

smol:	kernfetch
	test -f ${SMOL} || { \
		[ -d confkerndev ] || \
		git clone https://gitlab.com/0xDRRB/confkerndev.git; \
		cd confkerndev && make NBVERS=${VERS} i386; cd ..; \
		cp -f ${GENERIC} ${SMOL}; \
		confkerndev/confkerndevi386 -v -i ${SMOL} -K virtio.list -w; \
	}

rescue:	smol
	$(MAKE) setfetch SETS="rescue.tar.xz etc.tar.xz"
	${SUDO} ./mkimg.sh

base:	smol
	$(MAKE) setfetch SETS="base.tar.xz etc.tar.xz"
	${SUDO} ./mkimg.sh -i $@.img -s $@ -m 300 -x "base.tar.xz etc.tar.xz"

prof:	smol
	$(MAKE) setfetch SETS="base.tar.xz etc.tar.xz comp.tar.xz"
	${SUDO} ./mkimg.sh -i $@.img -s $@ -m 1000 -k ${KERN} -x "base.tar.xz etc.tar.xz comp.tar.xz"

imgbuilder: smol
	$(MAKE) setfetch SETS="base.tar.xz etc.tar.xz"
	${SUDO} ./mkimg.sh -i $@.img -s $@ -m 500 -x "base.tar.xz etc.tar.xz"

nginx:	imgbuilder
	dd if=/dev/zero of=$@.img bs=1M count=100
	${SUDO} ./startnb.sh ${SMOL} $<.img $@.img
