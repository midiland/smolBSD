type = scripted
command = /etc/dinit.d/rc.fs.sh start
stop-command = /etc/dinit.d/rc.fs.sh stop
restart = false
options = starts-rwfs

depends-on: rc.dev
