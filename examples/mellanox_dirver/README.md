# Include updated mellanox drivers

This example illustrates how to build and deploy custom node image with additional kernel modules prebuilt using dkms.


#### Building

Take the original Dockerfile and inject code from [this patch](Dockerfile.patch) to install `mlnx_en` kernel module:

```
cp ../../build/ltsp/Dockerfile Dockerfile
patch -p1 < Dockerfile.patch
docker build -t docker.io/yourrepo/kubefarm-ltsp:mellanox .
docker push docker.io/yourrepo/kubefarm-ltsp:mellanox
```

#### Deploying

Just specify your custom image in helm parameters:

```bash
helm install cluster1 ../../deploy/helm/kubefarm \
  --set ltsp.image.repository=docker.io/yourrepo/kubefarm-ltsp
  --set ltsp.image.tag=mellanox
```
