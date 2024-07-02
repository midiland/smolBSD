# mksmolnb

This is an ongoing project that aims at creating a minimal _NetBSD_ virtual machine that's
able to boot and start a service in less than a second.  
Previous _NetBSD_ installation is not required, using the provided tools the microvm can be
created from any _NetBSD_ or _GNU/Linux_ system.

When creating the image on a _NetBSD_ system, the image will be formatted using FFS, when
creating the image on a _GNU/Linux_ system, the image will be formatted using _ext2_.

Note that this is currently more a proof of concept, don't judge the scripts as they are!

As of March 2024, this method can use to create or fetch a low footprint kernel for use with the images:

* [multiboot][1] to boot directly the kernel from [kvm][2], but warning, only `i386` virtual machines can be created as _NetBSD_ only supports [multiboot][1] with this architecture as of now.
* [PVH][4] this newer method works with _NetBSD/amd64_ and is available in my [NetBSD development branch][5] but you can still fetch a pre-built kernel at https://smolbsd.org/assets/netbsd-SMOL, warning this is a _NetBSD-current_ kernel

`aarch64` `netbsd-GENERIC64` kernels are able to boot directly to the kernel with no modification

# Usage

## Requirements

- A GNU/Linux or NetBSD operating system
- The following tools installed
  - `curl`
  - `git`
  - `qemu-system-x86_64`, `qemu-system-i386` or `qemu-system-aarch64`
  - `sudo`
- A x86 VT-capable, or ARM64 CPU is recommended

## Project structure

- `mkimg.sh` creates a root filesystem image
```text
Usage: mkimg.sh [-s service] [-m megabytes] [-n image] [-x set]
	Create a root image
	-s service	service name, default "rescue"
	-m megabytes	image size in megabytes, default 10
	-i image	image name, default root.img
	-x sets		list of NetBSD sets, default rescue.tgz
	-k kernel	kernel to copy in the image
```
- `startnb.sh` starts a _NetBSD_ virtual machine using `qemu-system-x86_64` or `qemu-system-aarch64`
```text
Usage:	startnb.sh -k kernel -i image [-a kernel parameters] [-m memory in MB]
	[-r root disk] [-f drive2] [-p port] [-w path] [-d]

	Boot a microvm
	-k kernel	kernel to boot on
	-a parameters	append kernel parameters
	-m memory	memory in MB
	-r root disk	root disk to boot on
	-i image	image to use as root filesystem
	-f drive2	second drive to pass to image
	-p ports	[tcp|udp]:[hostaddr]:hostport-[guestaddr]:guestport
	-w path		host path to share with guest (9p)
	-d		daemonize
```
- `startnb_nommio.sh` (**deprecated**) starts a _NetBSD_ virtual machine with no support for _MMIO_
- `sets` contains _NetBSD_ "sets", i.e. `base.tgz`, `rescue.tgz`...
- `etc` holds common `/etc` files to be installed in the root filesystem
- `kstrip.sh` (**deprecated**, now use [confkerndev][0]) strips the kernel from any useless driver to improve boot speed on `i386`
- `service` structure:

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

if ifconfig vioif0 >/dev/null 2>&1; then
        # default qemu addresses and routing
        ifconfig vioif0 10.0.2.15/24
        route add default 10.0.2.2
        echo "nameserver 10.0.2.3" > /etc/resolv.conf
fi

ifconfig lo0 127.0.0.1 up

export TERM=dumb
```

And then add this to your `rc`:
```shell
. /etc/include/basicrc
```

## ⚠️  Warning ⚠️

`postinst` operations are run as `root` **in the build host: only use relative paths** in order **not** to impair your host's filesystem.

## Prerequisite

For the microvm to start instantly, you will need a kernel that is capable of "direct booting" with the `qemu -kernel` flag.

**For `i386`/`multiboot` (deprecated)**

> &#x26A0; Unless demand arises, `i386` version of this project is considered archived and will not evolve anymore

Download a `GENERIC` _NetBSD_ kernel

```shell
$ curl -L -o- https://cdn.netbsd.org/pub/NetBSD/${rel}/${arch}/binary/kernel/netbsd-GENERIC.gz | gzip -dc > netbsd-GENERIC

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

**For `amd64`/`PVH`**

Download the `SMOL` kernel

```shell
$ curl -O https://smolbsd.org/assets/netbsd-SMOL
```

**For `aarch64`**

Download a regular `netbsd-GENERIC64.img` kernel

```shell
$ curl -L -o- -s https://nycdn.netbsd.org/pub/NetBSD-daily/HEAD/latest/evbarm-aarch64/binary/kernel/netbsd-GENERIC64.img.gz|gunzip -c >netbsd-GENERIC64.img
```

## Example of a very minimal (10MB) virtual machine

> Note: you can use the ARCH variable to specify an architecture to build your image for, default is amd64.

```shell
$ make rescue
```
Will create a `rescue-amd64.img` file for use with an _amd64_ kernel.
```shell
$ make ARCH=evbarm-aarch64 rescue
```
Will create a `rescue-evbarm-aarch64.img` file for use with an _aarch64_ kernel.

```shell
$ ./startnb.sh -k netbsd-SMOL -i rescue-amd64.img
```

## Example of an image filled with the `base` set

```shell
$ make base
$ ./startnb.sh -k netbsd-GENERIC64.img -i base-evbarm-aarch64.img
```

## Example of an image used to create an nginx microvm with [sailor][3]

```shell
$ make nginx
```
This will spawn an image builder host which will populate an `nginx` minimal image.

Once the `nginx` image is baked, simply run it:

```shell
$ ./startnb.sh -k netbsd-SMOL -i nginx-amd64.img -p tcp::8080-:80
```

And try it:

```shell
$ curl -I http://localhost:8008
HTTP/1.1 200 OK
Server: nginx/1.24.0
Date: Sun, 30 Jun 2024 07:58:14 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Mon, 08 Apr 2024 14:01:28 GMT
Connection: keep-alive
ETag: "6613f8b8-267"
Accept-Ranges: bytes
```

### Example configuration for the `nginx` service

```shell
$ cat service/imgbuilder/postinst/prepare.sh
#!/bin/sh

git clone https://gitlab.com/iMil/sailor.git

ship=fakecracker

# create sailor base config - https://gitlab.com/iMil/sailor
cat >sailor/${ship}.conf<<EOF
shipname=$ship
shippath="/sailor/$ship"
shipbins="/bin/sh /sbin/init /usr/bin/printf /sbin/mount /sbin/mount_ffs /bin/ls /sbin/mknod /sbin/ifconfig /usr/bin/nc /usr/bin/tail /sbin/poweroff /sbin/umount /sbin/fsck /usr/bin/netstat /sbin/dhcpcd /sbin/route /sbin/mount_tmpfs"
packages="nginx"
EOF

# system and service startup
mkdir -p sailor/ships/${ship}/etc
cat >>sailor/ships/${ship}/etc/rc<<EOF
. /etc/include/basicrc

# service startup

printf "\nstarting nginx.. "
/usr/pkg/sbin/nginx
echo "done"
printf "\nTesting web server:\n"
printf "HEAD / HTTP/1.0\r\n\r\n"|nc -n 127.0.0.1 80
printf "^D to cleanly shutdown\n\n"
sh

. /etc/include/shutdown
EOF
```

[0]: https://gitlab.com/0xDRRB/confkerndev
[1]: https://man.netbsd.org/x86/multiboot.8
[2]: https://www.linux-kvm.org/page/Main_Page
[3]: https://gitlab.com/iMil/sailor/-/tree/master/
[4]: https://xenbits.xen.org/docs/4.6-testing/misc/pvh.html
[5]: https://github.com/NetBSDfr/NetBSD-src/tree/nbfr_master
