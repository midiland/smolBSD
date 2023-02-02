# mksmolnb

This is an ongoing project that aims at creating a minimal _NetBSD_ virtual machine that's
able to boot and start a service in less than a second.  
Previous _NetBSD_ installation is not required, using the provided tools the microvm can be
created from any _GNU/Linux_ system.

Warning. as this method uses [multiboot][1] to boot directly the kernel from [kvm][2], only
`i386` virtual machines can be created as _NetBSD_ only supports [multiboot][1] with this
architecture as of now.

# Usage

## Example of a very minimal (10MB) virtual machine

Create a `sets` directory and download the `rescue` set:

```sh
$ mkdir sets
$ curl -O --output-dir sets https://cdn.netbsd.org/pub/NetBSD/NetBSD-9.3/i386/binary/sets/rescue.tgz
```

Build an `ext2` root image that will be the root filesystem device:

```sh
# ./mkimg.sh
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

[1]: https://man.netbsd.org/x86/multiboot.8
[2]: https://www.linux-kvm.org/page/Main_Page
