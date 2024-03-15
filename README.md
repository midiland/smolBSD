# mksmolnb

This is an ongoing project that aims at creating a minimal _NetBSD_ virtual machine that's
able to boot and start a service in less than a second.  
Previous _NetBSD_ installation is not required, using the provided tools the microvm can be
created from any _NetBSD_ or _GNU/Linux_ system.

When creating the image on a _NetBSD_ system, the image will be formatted using FFS, when
creating the image on a _GNU/Linux_ system, the image will be formatted using _ext2_.

Note that this is currently more a proof of concept, don't judge the scripts as they are!

As of March 2024, this method can use:

* [multiboot][1] to boot directly the kernel from [kvm][2], but warning, only `i386` virtual machines can be created as _NetBSD_ only supports [multiboot][1] with this architecture as of now.
* [PVH][4] this newer method works with _NetBSD/amd64_ and is available in my [NetBSD development branch][5] but you can still fetch a pre-built kernel at https://imil.net/NetBSD/netbsd-SMOL, warning this is a _NetBSD-current_ kernel

# Usage

## Requirements

- A GNU/Linux or NetBSD operating system
- The following tools installed
  - `curl`
  - `git`
  - `qemu-system-x86_64` or `qemu-system-i386`
  - `sudo`
- A VT-capable CPU is recommended

## Project structure

- `mkimg.sh` creates a root filesystem image
```text
Usage: mkimg.sh [-s service] [-m megabytes] [-n image] [-x set]
	Create a root image
	-s service	service name, default "rescue"
	-m megabytes	image size in megabytes, default 10
	-i image	image name, default root.img
	-x sets		list of NetBSD sets, default rescue.tgz
```
- `startnb.sh` starts a _NetBSD_ virtual machine using `qemu-system-x86_64`
- `sets` contains _NetBSD_ "sets", i.e. `base.tgz`, `rescue.tgz`...
- `etc` holds common `/etc` files to be installed in the root filesystem
- `service` structure:
- `kstrip.sh` (**legacy**, now use [confkerndev][0]) strips the kernel from any useless driver to improve boot speed

```sh
service
├── base
│   ├── etc
│   │   └── rc
│   └── postinst
│       └── dostuff.sh
├── common
│   └── basicrc
└── rescue
    └── etc
        └── rc
```
A microvm is seen as a "service", for each one:

- there **COULD** be a `postinst/anything.sh` which will be executed by `mkimg.sh` at the end of root basic filesystem preparation. **This is executed by the build host at build time**
- there **MUST** be an `etc/rc` file, which defines what is started at vm's boot. **This is executed by the microvm**.

In the `service` directory, `common/` contains scripts that will be bundled in the
`/etc/include` directory of the microvm, this would be a perfect place to have something like:

```shell
$ cat common/basicrc
export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/pkg/bin:/usr/pkg/sbin
umask 022

mount -a

ifconfig vioif0 192.168.1.100/24 up
ifconfig lo0 127.0.0.1 up
route add default 192.168.1.254
echo 'nameserver 192.168.1.254' > /etc/resolv.conf
```

And then add this to your `rc`:
```shell
. /etc/include/basicrc
```

## Warning

`postinst` operations are run as `root` **in the build host: only use relative paths** in order **not** to impair your host's filesystem.

## Example of a very minimal (10MB) virtual machine from a GNU/Linux host

### TL;DR

```shell
$ make rescue
```

### Long version

Create a `sets` directory and download the `rescue` set:

```shell
$ mkdir sets
$ rel=$(uname -r)
$ arch=$(uname -m)
$ curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/${rel}/${arch}/binary/sets/rescue.tgz
```

Build an `ext2` or `ffs` root image that will be the root filesystem device:

```shell
$ sudo ./mkimg.sh
```

**For `i386`/`multiboot`**

Download a `GENERIC` _NetBSD_ kernel

```shell
$ curl -o- https://cdn.netbsd.org/pub/NetBSD/${rel}/${arch}/binary/kernel/netbsd-GENERIC.gz | gzip -dc > netbsd-GENERIC

```

Now the main trick, in order to decrease kernel boot time, we will disable all drivers except
the ones absolutely needed to boot a virtual machine with `VirtIO` disk and network, using
https://gitlab.com/0xDRRB/confkerndev

```shell
$ git clone https://gitlab.com/0xDRRB/confkerndev.git
$ cd confkerndev && make i386
$ cp netbsd-GENERIC netbsd-SMOL
$ confkerndev/confkerndevi386 -v -i netbsd-SMOL -K virtio.list -w
```

Then start the virtual machine:
```shell
$ sudo ./startnb_nommio.sh netbsd-SMOL
```

**For `amd64`/`PVH`**

Download the `MICROVM` kernel

```shell
$ curl -O https://imil.net/NetBSD/netbsd-SMOL
```

Then start the virtual machine:
```shell
$ sudo ./startnb.sh netbsd-SMOL
```

You should be granted a shell.

## Example of an image filled with the `base` set

### TL;DR

```shell
$ make base
```
### Long version

Fetch the `base` set:

```shell
$ curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/${rel}/${arch}/binary/sets/base.tgz
```

Build an `ext2` or `ffs` root image that will be the root filesystem device:

```shell
$ sudo ./mkimg.sh -i base.img -s base -m 300 -x base.tgz
```

Following steps are identical to the previous example.

## Example of an image used to create an nginx microvm with [sailor][3]

### TL;DR

```shell
$ make nginx
```

BUT you still need to prepare `service/imgbuilder/postinst/prepare.sh` and  `service/imgbuilder/etc/rc` beforehand, see below.

### Long version

Fetch the `base` and `etc` sets:

```shell
$ for s in base.tgz etc.tgz; do curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/${rel}/${arch}/binary/sets/${s}; done
```

Prepare [sailor][3] setup:

```shell
$ cat service/imgbuilder/postinst/prepare.sh
#!/bin/sh

git clone https://gitlab.com/iMil/sailor.git

vers=$(uname -r)
pkginrepo="http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -m)/${vers%_*}/All"

mkdir -p usr/pkg/etc/pkgin
echo $pkginrepo > usr/pkg/etc/pkgin/repositories.conf

cat >sailor/examples/test.conf<<EOF
shipname=fakecracker
shippath="/sailor/fakecracker"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail"
packages="nginx"

run_at_build="echo 'creating devices'"
run_at_build="cd /dev && sh MAKEDEV all_md"
run_at_build="echo $pkginrepo >/usr/pkg/etc/pkgin/repositories.conf"
EOF

mkdir -p sailor/ships/fakecracker/etc

cat >sailor/ships/fakecracker/etc/rc<<EOF
#!/bin/sh

export HOME=/
export PATH=/sbin:/bin:/usr/sbin:/usr/bin
umask 022

mount -a
ifconfig vioif0 192.168.2.100/24 up
ifconfig lo0 127.0.0.1 up
printf "\nstarting nginx.. "
/usr/pkg/sbin/nginx
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
echo
tail -f /var/log/nginx/access.log
EOF

cat >sailor/ships/fakecracker/etc/fstab<<EOF
/dev/ld0a / ffs rw 1 1
EOF
```

Create the `etc/rc` `init` file

```shell
$ cat service/imgbuilder/etc/rc
#!/bin/sh

. /etc/include/basicrc

ver=$(uname -r)
url="http://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/$(uname -m)/${ver%_*}/All"

for pkg in pkg_install pkgin mozilla-rootcerts pkg_tarup rsync curl
do
	pkg_info $pkg >/dev/null 2>&1 || pkg_add -v ${url}/${pkg}*
done

cd sailor
mkdir fakecracker
newfs /dev/ld1a
mount /dev/ld1a fakecracker
/bin/sh ./sailor.sh build examples/test.conf

ksh # not necessary, only for check

. /etc/include/shutdown
```

Create the image maker:

```shell
$ sudo ./mkimg.sh -i imgbuilder.img -s imgbuilder -m 500 -x "etc.tgz base.tgz"
```

Create a blank image:

```shell
$ dd if=/dev/zero of=nginx.img bs=1M count=100
```

Start the image builder with the blank image as a third parameter:

```shell
$ sudo ./startnb.sh netbsd-SMOL imgbuilder.img nginx.img
```

Once the `nginx` image is baked, simply run it:

```shell
$ sudo ./startnb.sh netbsd-SMOL nginx.img
```

[0]: https://gitlab.com/0xDRRB/confkerndev
[1]: https://man.netbsd.org/x86/multiboot.8
[2]: https://www.linux-kvm.org/page/Main_Page
[3]: https://gitlab.com/iMil/sailor/-/tree/master/
[4]: https://xenbits.xen.org/docs/4.6-testing/misc/pvh.html
