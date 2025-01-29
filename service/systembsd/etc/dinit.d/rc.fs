type = scripted
command = /etc/dinit.d/rc.fs.sh
restart = false
options = starts-rwfs

depends-on: rc.dev
