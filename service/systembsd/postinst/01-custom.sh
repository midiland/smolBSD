#!/bin/sh

cat >>root/.shrc<<EOF
LANG=en_US.UTF-8; export LANG

alias d='dinitctl'
alias shutdown="dinitctl shutdown"

[ "\$SHELL" = "/bin/ksh" ] && \
	PS1="\$(printf '\e[1;37msystem\e[1;31mBSD\e[0m# ')"

last \UID | grep -q still || cat /etc/banner.ans
printf "\n%20s\n\n" " :: powered by 🚩 + smolBSD"
EOF
