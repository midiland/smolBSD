VERS=		10
ARCH?=		amd64
SMOLI386=	netbsd-SMOLi386
DIST=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
SUDO=		sudo -E ARCH=${ARCH} VERS=${VERS}
WHOAMI!=	whoami
# sets to fetch
RESCUE=		rescue.tar.xz etc.tar.xz
BASE=		base.tar.xz etc.tar.xz
PROF=		${BASE} comp.tar.xz
BOZO=		${BASE}
IMGBUILDER=	${BASE}

ifeq (${ARCH}, evbarm-aarch64)
KERNEL=		netbsd-GENERIC64.img
else ifeq (${ARCH}, i386)
KERNEL=		netbsd-GENERIC
else
KERNEL=		netbsd-SMOL
DIST=		https://smolbsd.org/assets
endif

kernfetch:
	[ -f ${KERNEL} ] || ( \
		[ "${ARCH}" = "amd64" ] && \
			curl -L -O ${DIST}/${KERNEL} || \
			curl -L -o- ${DIST}/kernel/${KERNEL}.gz | \
				gzip -dc > ${KERNEL} \
	)

setfetch:
	setsdir=sets/${ARCH} && \
	[ -d $${setsdir} ] || mkdir -p $${setsdir} && \
	for s in $${SETS}; do \
		if [ ! -f $${setsdir}/$$s ]; then \
			curl -L -O --output-dir $${setsdir} ${DIST}/sets/$$s; \
		fi; \
	done

smoli386:	kernfetch
	[ -f ${SMOLI386} ] || { \
		[ -d confkerndev ] || \
		git clone https://gitlab.com/0xDRRB/confkerndev.git; \
		cd confkerndev && make NBVERS=${VERS} i386; cd ..; \
		cp -f ${KERNEL} ${SMOLI386}; \
		confkerndev/confkerndevi386 -v -i ${SMOLI386} -K virtio.list -w; \
		cp -f ${SMOLI386} ${KERNEL}
	}

rescue:
	$(MAKE) setfetch SETS="${RESCUE}"
	${SUDO} ./mkimg.sh -m 20 -x "${RESCUE}"
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

base:
	$(MAKE) setfetch SETS="${BASE}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 512 -x "${BASE}"
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

prof:
	$(MAKE) setfetch SETS="${PROF}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 1024 -k ${KERN} -x "${PROF}"
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

bozohttpd:
	$(MAKE) setfetch SETS="${BASE}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 512 -x "${BASE}"
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

imgbuilder:
	$(MAKE) setfetch SETS="${BASE}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 512 -x "${BASE}"
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

nginx: imgbuilder
	[ "$$(uname)" = "Linux" ] && u=M || u=m && \
	dd if=/dev/zero of=$@-${ARCH}.img bs=1$$u count=128
	[ "$$(uname -p)" = "aarch64" -o "$$(uname -m)" = "aarch64" ] && \
		rootfs="-r ld5a" || rootfs="-r ld0a" && \
	${SUDO} ./startnb.sh -k ${KERNEL} -i $<-${ARCH}.img -d $@-${ARCH}.img \
		-p ::22022-:22 $$rootfs -m 256
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img
