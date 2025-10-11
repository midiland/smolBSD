# nitroSSHd

This microservice starts an _OpenSSH_ daemon with the [nitro][1] `init` system.

As it uses `union` `tmpfs` which is unsupported with `ext2`, it must be built with either a _NetBSD_ host or the [builder image][2].
You need to create the `service/nitrosshd/etc/ssh/authorized_keys` file containing your SSH public key(s).

Building on GNU/Linux or MacOS
```sh
$ bmake SERVICE=nitrosshd build
```
Building on NetBSD
```sh
$ make SERVICE=nitrosshd base
```
Start the service:
```sh
$ ./startnb.sh -f etc/nitrosshd.conf
```
By default it listens at port 2022, you can change it in `etc/nitrosshd.conf`.

[1]: https://github.com/leahneukirchen/nitro
[2]: https://github.com/NetBSDfr/smolBSD/tree/main/service/build
