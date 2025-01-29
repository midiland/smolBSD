FROM alpine:latest

RUN apk add --quiet --no-cache qemu-system-x86_64 uuidgen

ARG NBIMG=bozohttpd-amd64.img
ARG MEM=256m
ARG KERNEL=netbsd-SMOL
ARG PORTFWD=8080:80

ENV NBIMG=${NBIMG}
ENV MEM=${MEM}
ENV KERNEL=${KERNEL}
ENV PORTFWD=${PORTFWD}

COPY ${KERNEL} ${NBIMG} startnb.sh /

CMD ["/bin/sh", "-c", "PORTFWD=$(echo ${PORTFWD}|sed 's/:/-:/') && /startnb.sh -m ${MEM} -k ${KERNEL} -i ${NBIMG} -p ::${PORTFWD}" ]
