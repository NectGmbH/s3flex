# s3flex
Kubernetes flexvolume driver which can mount s3 compatible storages as k8s volumes

## Status
Basic functionality is implemented and it's already used in testing scenarios, production-grade testing and unittests are missing yet, so use with caution.

## Deploy
fuse and curl have to be installed on the nodes. After that the flexvolume driver can be deployed using the daemonset resource:
```
$ kubectl create ns s3flex
$ kubectl apply -f ./s3flex-ds.yaml
```

## Example
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: s3fs-example
  namespace: s3flex
type: 'nect.com/s3flex'
stringData:
  accessKeyID: SomeAccessKeyID
  secretAccessKey: SomeSecretAccessKey
---
apiVersion: v1
kind: Pod
metadata:
  name: s3fs-example
  namespace: s3flex
spec:
  containers:
  - name: busybox
    image: busybox
    command: [ "/bin/sh", "-c", "--" ]
    args: [ "while true; do sleep 60; done;" ]
    volumeMounts:
    - name: test
      mountPath: /data
  volumes:
  - name: test
    flexVolume:
      driver: "nect.com/s3flex"
      secretRef:
        name: s3fs-example
      options:
        url: 'http://example-minio.some-namespace:9000'
        bucket: 'someBucket'
```

## Acknowledgements

This project is kindly sponsored by [Nect](https://nect.com)

## License

Licensed under [MIT](./LICENSE).