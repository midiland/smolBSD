# VM batch creation and bench

You need the [mksmolnb](https://gitlab.com/iMil/mksmolnb) to test the following

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
kernel=/path/to/netbsd-SMOL # https://smolbsd.org/assets/netbsd-SMOL
# optional
mem=128m
# optional
cores=1
# optional port forward
hostfwd=::8180-:80
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

## Batch process

* Declare the number of vms to spawn

```sh
num=5
vmname=bozohttpd
```

* Create the configuration files for the vms

```sh
$ for i in $(seq 1 $num); do sed "s/vm=${vmname}/vm=${vmname}${i}/;s/8180/818$i/;s,kernel=.*,kernel=$KERNEL," etc/${vmname}.conf > etc/${vmname}${i}.conf; done
```

* Start them headless
```sh
$ for f in etc/${vmname}?.conf; do . $f; echo "starting $vm"; ./startnb.sh -f $f -d; done
```
* Or in `tmux`
```sh
$ for f in etc/${vmname}?.conf; do . $f; tmux new -s $vm -d ./startnb.sh -f $f; done
```

## Test!

You should be able to query the servers

```sh
$ for i in $(seq 1 $num); do curl -I http://localhost:818${i}; done
```

Finally get rid of the vms

```sh
$ for i in $(seq 1 $num); do kill $(cat qemu-${vmname}${i}.pid); done
```

