type = scripted
command = /etc/dinit.d/rc.boot.sh
restart = false
logfile = /var/log/rc.boot.log

depends-on: rc.fs
