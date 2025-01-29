VERS?=		10
ARCH?=		amd64
DIST=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
KDIST=		${DIST}
WHOAMI!=	whoami
USER!= 		id -un
GROUP!= 	id -gn
ifneq (${WHOAMI}, root)
SUDO!=		command -v doas >/dev/null && \
		echo "ARCH=${ARCH} VERS=${VERS} doas" || \
		echo "sudo -E ARCH=${ARCH} VERS=${VERS}"
endif
SETSEXT=tar.xz
SETSDIR=sets/${ARCH}

ifeq (${ARCH}, evbarm-aarch64)
KERNEL=		netbsd-GENERIC64.img
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/evbarm-aarch64/binary/gzimg/arm64.img.gz
else ifeq (${ARCH}, i386)
KERNEL=		netbsd-SMOL386
KDIST=		https://smolbsd.org/assets
SETSEXT=	tgz
else
KERNEL=		netbsd-SMOL
KDIST=		https://smolbsd.org/assets
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/images/NetBSD-10.99.12-amd64-live.img.gz
endif
LIVEIMG=	NetBSD-${ARCH}-live.img

# sets to fetch
RESCUE=		rescue.${SETSEXT} etc.${SETSEXT}
BASE=		base.${SETSEXT} etc.${SETSEXT}
PROF=		${BASE} comp.${SETSEXT}
NBAKERY=	${BASE} comp.${SETSEXT}
BOZO=		${BASE}
IMGBUILDER=	${BASE}

ifeq ($(shell uname -m), x86_64)
ROOTFS?=	-r ld0a
else
# unknown / aarch64
ROOTFS?=	-r ld5a
endif

# any BSD variant including MacOS
DDUNIT=		m
ifeq ($(shell uname), Linux)
DDUNIT=		M
endif

# guest root filesystem will be read-only
ifeq (${MOUNTRO}, y)
EXTRAS+=	-o
endif
# extra remote script
ifneq (${CURLSH},)
EXTRAS+=	-c ${CURLSH}
endif

# default memory amount for a guest
MEM?=		256
# default port redirect, gives network to the guest
PORT?=		::22022-:22
# default size for disk built by imgbuilder
SVCSZ?=		128

SERVICE?=	$@
IMGSIZE?=	512

kernfetch:
	@mkdir -p kernels
	@[ -f kernels/${KERNEL} ] || ( \
		echo "fetching ${KERNEL}" && \
		[ "${ARCH}" = "amd64" -o "${ARCH}" = "i386" ] && \
			curl -L -o kernels/${KERNEL} ${KDIST}/${KERNEL} || \
			curl -L -o- ${KDIST}/kernel/${KERNEL}.gz | \
				gzip -dc > kernels/${KERNEL} \
	)

setfetch:
	[ -d ${SETSDIR} ] || mkdir -p ${SETSDIR}
	for s in ${SETS}; do \
		if [ ! -f ${SETSDIR}/$$s ]; then \
			curl -L -o ${SETSDIR}/$$s ${DIST}/sets/$$s; \
		fi; \
	done

rescue:
	$(MAKE) setfetch SETS="${RESCUE}"
	${SUDO} ./mkimg.sh -m 20 -x "${RESCUE}" ${EXTRAS}
	${SUDO} chown ${USER}:${GROUP} $@-${ARCH}.img

base:
	$(MAKE) setfetch SETS="${BASE}"
	${SUDO} ./mkimg.sh -i ${SERVICE}-${ARCH}.img -s ${SERVICE} \
		-m ${IMGSIZE} -x "${BASE}" ${EXTRAS}
	${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img

prof:
	$(MAKE) setfetch SETS="${PROF}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 1024 -k kernels/${KERNEL} \
		-x "${PROF}" ${EXTRAS}
	${SUDO} chown ${WHOAMI} $@-${ARCH}.img

nbakery:
	$(MAKE) setfetch SETS="${NBAKERY}"
	${SUDO} ./mkimg.sh -i $@-${ARCH}.img -s $@ -m 2048 -x "${NBAKERY}" ${EXTRAS}
	${SUDO} chown ${USER}:${GROUP} $@-${ARCH}.img

imgbuilder:
	$(MAKE) setfetch SETS="${BASE}"
	# build the building image if ${NOIMGBUILDERBUILD} is not defined
	if [ -z "${NOIMGBUILDERBUILD}" ]; then \
		${SUDO} SVCIMG=${SVCIMG} ./mkimg.sh -i $@-${ARCH}.img -s $@ \
			-m 512 -x "${BASE}" ${EXTRAS} && \
		${SUDO} chown ${USER}:${GROUP} $@-${ARCH}.img; \
	fi
	# now start an imgbuilder microvm and build the actual service
	# image unless $NOSVCIMGBUILD is set (probably a GL pipeline)
	if [ -z "${NOSVCIMGBUILD}" ]; then \
		dd if=/dev/zero of=${SVCIMG}-${ARCH}.img bs=1${DDUNIT} count=${SVCSZ}; \
		./startnb.sh -k kernels/${KERNEL} -i $@-${ARCH}.img -a '-v' \
			-h ${SVCIMG}-${ARCH}.img -p ${PORT} ${ROOTFS} -m ${MEM}; \
	fi

live:	kernfetch
	@echo "fetching ${LIVEIMG}"
	@[ -f ${LIVEIMG} ] || curl -o- -L ${LIVEIMGGZ}|gzip -dc > ${LIVEIMG}
