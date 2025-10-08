.-include "service/${SERVICE}/options.mk"

VERS?=		11
PKGVERS?=	11.0_2025Q3
ARCH?=		amd64
DIST?=		https://nycdn.netbsd.org/pub/NetBSD-daily/netbsd-${VERS}/latest/${ARCH}/binary
# for an obscure reason, packages path use uname -m...
UNAME_M!=	uname -m
PKGSITE?=	https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/${UNAME_M}/${PKGVERS}/All
PKGS?=		packages
KDIST=		${DIST}
WHOAMI!=	whoami
USER!= 		id -un
GROUP!= 	id -gn
BUILDIMG=	build-${ARCH}.img
BUILDIMGURL=	https://github.com/NetBSDfr/smolBSD/releases/download/latest/${BUILDIMG}

SERVICE?=	${.TARGET}
# guest root filesystem will be read-only
.if defined(MOUNTRO) && ${MOUNTRO} == "y"
EXTRAS+=	-o
.endif

ENVVARS=	SERVICE=${SERVICE} ARCH=${ARCH} PKGVERS=${PKGVERS} MOUNTRO=${MOUNTRO}
.if ${WHOAMI} != "root"
SUDO!=		command -v doas >/dev/null && \
		echo "${ENVVARS} doas" || \
		echo "sudo -E ${ENVVARS}"
.else
SUDO=		${ENVVARS}
.endif

SETSEXT=	tar.xz
SETSDIR=	sets/${ARCH}

.if ${ARCH} == "evbarm-aarch64"
KERNEL=		netbsd-GENERIC64.img
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/evbarm-aarch64/binary/gzimg/arm64.img.gz
.elif ${ARCH} == "i386"
KERNEL=		netbsd-SMOL386
KDIST=		https://smolbsd.org/assets
SETSEXT=	tgz
.else
KERNEL=		netbsd-SMOL
KDIST=		https://smolbsd.org/assets
LIVEIMGGZ=	https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/images/NetBSD-10.99.12-amd64-live.img.gz
.endif

LIVEIMG=	NetBSD-${ARCH}-live.img

# sets to fetch
RESCUE=		rescue.${SETSEXT} etc.${SETSEXT}
BASE?=		base.${SETSEXT} etc.${SETSEXT}
PROF=		${BASE} comp.${SETSEXT}
COMP=		${BASE} comp.${SETSEXT}
BOZO=		${BASE}
IMGBUILDER=	${BASE}

.if ${UNAME_M} == "x86_64"
ROOTFS?=	-r ld0a
.else
# unknown / aarch64
ROOTFS?=	-r ld5a
.endif

# any BSD variant including MacOS
DDUNIT=		m
UNAME_S!=	uname
.if ${UNAME_S} == "Linux"
DDUNIT=		M
.endif
FETCH=		curl -L
.if ${UNAME_S} == "NetBSD"
FETCH=		ftp
.endif

# extra remote script
.if defined(CURLSH) && !empty(CURLSH)
EXTRAS+=	-c ${CURLSH}
.endif

# default memory amount for a guest
MEM?=		256
# default port redirect, gives network to the guest
PORT?=		::22022-:22
# default size for disk built by imgbuilder
SVCSZ?=		128

IMGSIZE?=	512

kernfetch:
	mkdir -p kernels
	if [ ! -f kernels/${KERNEL} ]; then \
		echo "fetching ${KERNEL}"; \
		if [ "${ARCH}" = "amd64" -o "${ARCH}" = "i386" ]; then \
			${FETCH} -o kernels/${KERNEL} ${KDIST}/${KERNEL}; \
		else \
			${FETCH} -o- ${KDIST}/kernel/${KERNEL}.gz | \
				gzip -dc > kernels/${KERNEL}; \
		fi; \
	fi

setfetch:
	[ -d ${SETSDIR} ] || mkdir -p ${SETSDIR}
	for s in ${SETS}; do \
		[ -f ${SETSDIR}/$${s} ] || ${FETCH} -o ${SETSDIR}/$${s} ${DIST}/sets/$${s}; \
	done

pkgfetch:
	[ -d ${PKGS} ] || mkdir ${PKGS}
	for p in ${ADDPKGS};do \
		[ -f ${PKGS}/$${p}* ] || ftp -o ${PKGS}/$${p}.tgz ${PKGSITE}/$${p}*; \
	done

rescue:
	${MAKE} setfetch SETS="${RESCUE}"
	${SUDO} ./mkimg.sh -m 20 -x "${RESCUE}" ${EXTRAS}
	${SUDO} chown ${USER}:${GROUP} ${.TARGET}-${ARCH}.img

base:
	${MAKE} setfetch SETS="${BASE}"
	${SUDO} ./mkimg.sh -i ${SERVICE}-${ARCH}.img -s ${SERVICE} \
		-m ${IMGSIZE} -x "${BASE}" ${EXTRAS}
	${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img

prof:
	${MAKE} setfetch SETS="${PROF}"
	${SUDO} ./mkimg.sh -i ${.TARGET}-${ARCH}.img -s ${.TARGET} -m 1024 -k kernels/${KERNEL} \
		-x "${PROF}" ${EXTRAS}
	${SUDO} chown ${WHOAMI} ${.TARGET}-${ARCH}.img

imgbuilder:
	${MAKE} setfetch SETS="${BASE}"
	# build the building image if NOIMGBUILDERBUILD is not defined
	if [ -z "${NOIMGBUILDERBUILD}" ]; then \
		${SUDO} SVCIMG=${SVCIMG} ./mkimg.sh -i ${.TARGET}-${ARCH}.img -s ${.TARGET} \
			-m 512 -x "${BASE}" ${EXTRAS} && \
		${SUDO} chown ${USER}:${GROUP} ${.TARGET}-${ARCH}.img; \
	fi
	# now start an imgbuilder microvm and build the actual service
	# image unless NOSVCIMGBUILD is set (probably a GL pipeline)
	if [ -z "${NOSVCIMGBUILD}" ]; then \
		dd if=/dev/zero of=${SVCIMG}-${ARCH}.img bs=1${DDUNIT} count=${SVCSZ}; \
		./startnb.sh -k kernels/${KERNEL} -i ${.TARGET}-${ARCH}.img -a '-v' \
			-h ${SVCIMG}-${ARCH}.img -p ${PORT} ${ROOTFS} -m ${MEM}; \
	fi

live:	kernfetch
	echo "fetching ${LIVEIMG}"
	[ -f ${LIVEIMG} ] || curl -o- -L ${LIVEIMGGZ}|gzip -dc > ${LIVEIMG}

buildimg:
	@mkdir -p images
	${MAKE} MOUNTRO=y SERVICE=build IMGSIZE=320 base
	mv -f build-${ARCH}.img images/

fetchimg:
	@mkdir -p images
	if [ ! -f images/${BUILDIMG} ]; then \
		curl -L -o- ${BUILDIMGURL}.xz | xz -dc > images/${BUILDIMG}; \
	fi

build:
	@if [ ! -f images/${.TARGET}-${ARCH}.img ]; then \
		echo "* building builder"; \
		${MAKE} buildimg; \
	fi
	@mkdir -p tmp
	@rm -f tmp/build-*
	# save variables for sourcing in the build vm
	@echo "${ENVVARS}"|sed 's/\ /\n/g' > tmp/build-${SERVICE}
	./startnb.sh -k kernels/${KERNEL} -i images/${.TARGET}-${ARCH}.img -c 2 -m 512 \
		-p ${PORT} -w . -x "-pidfile qemu-${.TARGET}.pid" &
	# wait till the build is finished, guest removes the lock
	@while [ -f tmp/build-${SERVICE} ]; do sleep 0.2; done
	kill $$(cat qemu-${.TARGET}.pid)
	${SUDO} chown ${USER}:${GROUP} ${SERVICE}-${ARCH}.img
