# SSHd service

This microservice starts an _OpenSSH_ daemon.

As it uses `union` `tmpfs` which is unsupported with `ext2`, it must be built with either a _NetBSD_ host or the [builder image][1].  
Add the desired SSH public keys in the `service/sshd/etc` directory in file(s) ending with `.pub`.

Building on GNU/Linux or MacOS
```sh
$ bmake SERVICE=sshd build
```
Building on NetBSD
```sh
$ make SERVICE=sshd base
```
Start the service:
```sh
$ ./startnb.sh -f etc/sshd.conf
```
By default it listens at port 2022, you can change it in `etc/nitrosshd.conf`.

[1]: https://github.com/NetBSDfr/smolBSD/tree/main/service/build
