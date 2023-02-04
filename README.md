# mksmolnb

This is an ongoing project that aims at creating a minimal _NetBSD_ virtual machine that's
able to boot and start a service in less than a second.  
Previous _NetBSD_ installation is not required, using the provided tools the microvm can be
created from any _NetBSD_ or _GNU/Linux_ system.

When creating the image on a _NetBSD_ system, the image will be formatted using FFS, when
creating the image on a _GNU/Linux_ system, the image will be formatted using _ext2_.

Note that this is currently more a proof of concept, don't judge the scripts as they are!

Warning. as this method uses [multiboot][1] to boot directly the kernel from [kvm][2], only
`i386` virtual machines can be created as _NetBSD_ only supports [multiboot][1] with this
architecture as of now.

# Usage

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
- `kstrip.sh` strips the kernel from any useless driver to improve boot speed
- `startnb.sh` starts a _NetBSD_ virtual machine using `qemu-system-x64_64`
- `sets` contains _NetBSD_ "sets", i.e. `base.tgz`, `rescue.tgz`...
- `etc` holds common `/etc` files to be installed in the root filesystem
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

ifconfig vioif0 192.168.1.100/24 up
ifconfig lo0 127.0.0.1 up
route add default 192.168.1.254
echo 'nameserver 192.168.1.254' > /etc/resolv.conf
```

And then add this to your `rc`:
```sh
. /etc/include/basicrc
```

## Warning

`postinst` operations are run as `root` **in the build host only use relative paths** in order **not** to impair your host's filesystem.

## Example of a very minimal (10MB) virtual machine from a GNU/Linux host

Create a `sets` directory and download the `rescue` set:

```sh
$ mkdir sets
$ curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.3/i386/binary/sets/rescue.tgz
```

Build an `ext2` or `ffs` root image that will be the root filesystem device:

```sh
$ sudo ./mkimg.sh
```

Download a `GENERIC` _NetBSD_ kernel

```sh
$ curl -o- https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.3/i386/binary/kernel/netbsd-GENERIC.gz | gzip -dc > netbsd-9.3

```

Now the main trick, in order to decrease kernel boot time, we will disable all drivers except
the ones absolutely needed to boot a virtual machine with `VirtIO` disk and network:

```sh
$ ./kstrip.sh netbsd-9.3
```

Once the kernel is stripped, start the virtual machine:

```sh
$ sudo ./startnb.sh netbsd-9.3
```

You should be granted a shell.

## Example of an image filled with the `base` set

```sh
$ curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.3/i386/binary/sets/base.tgz
```

Build an `ext2` or `ffs` root image that will be the root filesystem device:

```sh
$ sudo ./mkimg.sh -i base.img -s base -m 300 -x base.tgz
```

Following steps are identical to the previous example.

[1]: https://man.netbsd.org/x86/multiboot.8
[2]: https://www.linux-kvm.org/page/Main_Page
