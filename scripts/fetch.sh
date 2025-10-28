#!/bin/sh

shift # remove -o

case $2 in
*\**)
	dldir=${1%/*} # pkgs/amd64/pkgin.tgz
	fetchurl=${2%/*} 
	matchfile=${2##*/}
	matchfile=${matchfile%\*}
	curl -L -s "$fetchurl" | grep -oE "\"${matchfile}\-[^\"]*(xz|gz)" | \
		while read f; do
			f=${f#\"}
			# mimic NetBSD's ftp parameters
			destfile=${f%%-*}.${f##*.}
			curl -L -s -o ${dldir}/${destfile} ${fetchurl}/${f}
			exit 0
		done
	;;
*)
	curl -L -s -o $1 $2
	;;
esac
