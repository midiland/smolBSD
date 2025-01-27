# smolBSD pod example

A _smolBSD_ system can be spawned inside a container, thus bringing a decent level of security to the service which will be isolated in a virtual machine.  

## Building the _docker_ image

Let's use the [bozohttpd service][0] as an example image.

Fetch the kernel image and generate the _smolBSD_ image as usual

```sh
$ make kernfetch
$ make SERVICE=bozohttpd base
```
Build the docker image using the created _smolBSD_ image

```sh
$ docker build -t smolbozo -f k8s/Dockerfile .
```
The following arguments can be passed to the build process using the `--build-arg` flag:

* `NBIMG`: the name of the _smolBSD_ image, defaults to `bozohttpd-amd64.img`
* `MEM`: the amount of memory for the virtual machine, defaults to `256m`
* `KERNEL`: the name of the kernel to use, defaults to `netbsd-SMOL`
* `PORTFWD`: port forwarding between host and guest, defaults to `8080:80`

Try launching the container:
```sh
$ docker run -it --rm --device=/dev/kvm -p 8080:8080 smolbozo
```
And access it
```sh
$ curl http://localhost:8080
<html><body>up!</body></html>
```

## smolBSD pod

The [generic device plugin][1] is needed in order to expose `/dev/kvm` to the container without running the _smolBSD_ pod it in privileged mode.

Apply this [modified version][2] of `k8s/generic-device-plugin.yaml` to your _k8s_ cluster:

```sh
$ kubectl apply -f k8s/generic-device-plugin.yaml
```
Check it is running:
```sh
$ kubectl get pods -n kube-system -l app.kubernetes.io/name=generic-device-plugin
NAME                          READY   STATUS    RESTARTS   AGE
generic-device-plugin-c74cc   1/1     Running   0          40h
```

Finally, here is a simple pod example for the `bozohttpd` _smolBSD_ image:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: smolbozo
  namespace: smolbsd
  labels:
    app: smolbozo
spec:
  containers:
  - name: bozohttpd
    image: localhost:5000/smolbozo
    ports:
    - containerPort: 8080
    resources:
      limits:
        squat.ai/kvm: 1
```
> [!note]
> you will either need to change the repository address for the `image` or setup a local repository:
> * [with Kind][3]
> * [with K3s][4]
> With _Kind_, you can also [import the image][5] into the cluster, but beware to use fixed versions for the image, if `:latest` is used, the pull policy defaults to `Always`.

Create the `smolbsd` _namespace_ and apply the manifest:
```sh
$ kubectl create namespace smolbsd
$ kubectl apply -f k8s/smolbozo.yaml
```
Check it is running
```sh
$ kubectl get pods -n smolbsd -o wide
NAME       READY   STATUS    RESTARTS   AGE   IP           NODE   NOMINATED NODE   READINESS GATES
smolbozo   1/1     Running   0          41h   10.42.0.21   k3s    <none>           <none>
```
And curl it!
```sh
$ curl http://10.42.0.21:8080
<html><body>up!</body></html>
 ```

[0]: https://github.com/NetBSDfr/smolBSD/tree/main/service/bozohttpd
[1]: https://github.com/squat/generic-device-plugin
[2]: https://github.com/NetBSDfr/smolBSD/blob/main/k8s/generic-device-plugin.yaml
[3]: https://kind.sigs.k8s.io/docs/user/local-registry/
[4]: https://docs.k3s.io/installation/private-registry
[5]: https://kind.sigs.k8s.io/docs/user/quick-start/#loading-an-image-into-your-cluster
