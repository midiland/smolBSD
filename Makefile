VERS?=		10
ARCH?=		amd64
SMOLI386=	netbsd-SMOLi386
DIST=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
KDIST=		${DIST}
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
KDIST=		https://smolbsd.org/assets
endif

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

# default memory amount for a guest
MEM?=		256
# default port redirect, gives network to the guest
PORT?=		::22022-:22
# default size for disk built by imgbuilder
SVCSZ?=		128

kernfetch:
	[ -f ${KERNEL} ] || ( \
		[ "${ARCH}" = "amd64" ] && \
			curl -L -O ${KDIST}/${KERNEL} || \
			curl -L -o- ${KDIST}/kernel/${KERNEL}.gz | \
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
	# build the building image if ${NOIMGBUILDERBUILD} is not defined
	if [ -z "${NOIMGBUILDERBUILD}" ]; then \
		${SUDO} SVCIMG=${SVCIMG} ./mkimg.sh -i $@-${ARCH}.img -s $@ \
			-m 512 -x "${BASE}" && \
		${SUDO} chown ${WHOAMI} $@-${ARCH}.img; \
	fi
	# now start an imgbuilder microvm and build the actual service
	# image unless $NOSVCIMGBUILD is set (probably a GL pipeline)
	if [ -z "${NOSVCIMGBUILD}" ]; then \
		dd if=/dev/zero of=${SVCIMG}-${ARCH}.img bs=1${DDUNIT} count=${SVCSZ}; \
		./startnb.sh -k ${KERNEL} -i $@-${ARCH}.img -a '-v' \
			-f ${SVCIMG}-${ARCH}.img -p ${PORT} ${ROOTFS} -m ${MEM}; \
	fi
