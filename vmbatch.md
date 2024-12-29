# VM batch creation and bench

You need [smolBSD](https://github.com/NetBSDfr/smolBSD) to test the following

## Read-only `bozohttpd` web server image

* Create the base image

```sh
$ make MOUNTRO=y bozohttpd
```
* Create a config file template

```sh
$ cat etc/bozohttpd.conf 
# optional vm name, used in pidfile
vm=bozohttpd
# mandatory
img=bozohttpd-amd64.img
# mandatory
kernel=netbsd-SMOL # https://smolbsd.org/assets/netbsd-SMOL
# optional
mem=128m
# optional
cores=1
# optional port forward
hostfwd=::4280-:80
# optional extra parameters
extra="-pidfile qemu-${vm}.pid"
# don't lock the disk image
sharerw="y"
```

* Try it

```sh
$ ./startnb.sh -f etc/bozohttpd.conf
```
exit `qemu` with `Ctrl-a x`

## Example shell script, parallel run

Just play with the `num` variable

```sh
#!/bin/sh

vmname=bozohttpd
num=10
KERNEL=netbsd-SMOL

for i in $(seq 1 $num)
do
        sed "
                s/vm=${vmname}/vm=${vmname}${i}/
                s/4280/428$i/
                s,kernel=.*,kernel=$KERNEL,
        " etc/${vmname}.conf > etc/${vmname}${i}.conf
done

for f in etc/${vmname}[0-9]*.conf; do
  . $f
  echo "starting $vm"
  ./startnb.sh -f $f -d &
done

for i in $(seq 1 $num)
do
        while ! curl -s -I --max-time 0.01 localhost:428${i}
        do
                true
        done
done

for i in $(seq 1 $num); do curl -I http://localhost:428${i}; done

for i in $(seq 1 $num); do kill $(cat qemu-${vmname}${i}.pid); done

rm -f etc/${vmname}[0-9]*.conf
```
