
Kubefarm
========

<img align=left src="https://avatars1.githubusercontent.com/u/68351149?s=150&u=b8b4cb0f364281274159d4098090c0e229370cf0">

Kubefarm combines everything need to spawn multiple Kubernetes-in-Kubernetes clusters and network booting configuration to simple bootstrap the physical servers from the scratch.

The project goals is to provide simple and unified way for deploying Kubernetes on bare metal.

<p align="center">
<img src="https://gist.githubusercontent.com/kvaps/c969930f561b24c1f4c09802d5e225c8/raw/6347f81814d1eb56ccd2d4cbdb2a8617965cfa9d/kubefarm.png">
</p>

## Why

#### Fast & Simple

There is no installation process as such, you just run your physical servers from scratch, during the boot they download the system image over the network and run it similar docker containers with overlayfs root.

You don't have to think about redundancy and performing the updates for your OS anymore. Simple reboot is enough to apply new image.

#### Declarative

You can spawn new Kubernetes clusters and PXE-servers using Helm very quickly, just providing all the parameters in simple Yaml form.

#### Customizable

You can build your own image for the physical servers simple using [Dockerfile]. The default image is based on Ubuntu. You can put there anything need, simple add any additional packages and custom kernel modules.

[Dockerfile]: https://github.com/kvaps/kubefarm/blob/master/build/ltsp/Dockerfile

#### Secure

You can deploy so many clusters as you want. All of them will have separated control-plane non visible for its consumers. Cert-manager will take care about the certificates.

#### Known components


Whole setup consist of few known components:

- **[Kubernetes-in-Kubernetes]** - Kubernetes control-plane packed to Helm-chart, it is based on official Kubernetes static pod manifests and using the official Kubernetes docker images.
- **[Dnsmasq-controller]** - simple wrapper for Dnsmasq which automates the configuration using Kubernetes CRDs and perform leader-election for the DHCP high availability.
- **[LTSP]** - network booting server and boot time configuration framework for the clients written in shell. It allows to boot OS over the network directly to RAM and perform initial initial configuration for each server.

[Kubernetes-in-Kubernetes]: https://github.com/kvaps/kubernetes-in-kubernetes
[Dnsmasq-controller]: https://github.com/kvaps/dnsmasq-controller
[LTSP]: https://github.com/ltsp/ltsp

## Preparation

There is a number of dependencies needed to make kubefarm working:

* **[Kubernetes]**

  The parent admin Kubernetes cluster is required to deploy user Kubernetes-in-Kubernetes control-planes and network booting servers for them.
  You can deploy admin Kubernetes cluster using your favorite installation method, for example you can use [kubeadm] or [kubespray].
  
  [kubeadm]: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
  [kubespray]: https://github.com/kubernetes-sigs/kubespray

  You might want untaint master nodes to allow run workload on them

  ```bash
  kubectl taint nodes --all node-role.kubernetes.io/master-
  ```

* **[Cert-manager]**

  The cert-manager performs the certificates issuing for Kubernetes-in-Kubernetes and its etcd-cluster.
  
  ```bash
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml
  ```
  
* **[Local Path Provisioner]**

  You need an automated persistent volumes management for your cluster, local-path-provisioner is simpliest way to achieve that.

  ```bash
  kubectl apply -f https://github.com/rancher/local-path-provisioner/raw/master/deploy/local-path-storage.yaml
  ```

  Optionaly any other csi-driver can be used.
  
* **[MetalLB]**

  You also need an automated external IP-addresses management, MetalLB is providing this opportunity.
  
  ```bash
  kubectl apply -f https://github.com/metallb/metallb/raw/v0.9.3/manifests/namespace.yaml
  kubectl apply -f https://github.com/metallb/metallb/raw/v0.9.3/manifests/metallb.yaml
  kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"
  ```

  There is currently a bug in MetalLB that may block the use of multiple services on shared IP [metallb/metallb#558](https://github.com/metallb/metallb/issues/558).
  However you can simple use patched images from this PR [metallb/metallb#562 (comment)](https://github.com/metallb/metallb/pull/562#issuecomment-724066537):

  ```bash
  kubectl set image -n metallb-system deploy/controller controller=docker.io/kvaps/metallb-controller:a3047c4d
  kubectl set image -n metallb-system ds/speaker speaker=docker.io/kvaps/metallb-controller:a3047c4d
  ```

  Also [configure MetalLB Layer 2 address range](https://metallb.universe.tf/configuration/#layer-2-configuration) after the installation.  
  These IP-addresses will be used for the child Kubernetes clusters and network booting servers.

* **[Dnsmasq-controller]**

  High available DHCP-server wrapper allows to configure DHCP leases over Kubernetes. Additional DNS-server mode is allowed.

  ```bash
  kubectl create namespace dnsmasq
  kubectl create -n dnsmasq clusterrolebinding dnsmasq-controller --clusterrole dnsmasq-controller --serviceaccount dnsmasq:dnsmasq-controller
  kubectl create -n dnsmasq rolebinding dnsmasq-controller-leader-election --role dnsmasq-controller-leader-election --serviceaccount dnsmasq:dnsmasq-controller
  kubectl apply -n dnsmasq \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dhcphosts.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dhcpoptions.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dnshosts.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dnsmasqoptions.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/rbac/service_account.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/rbac/role.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/rbac/leader_election_role.yaml \
    -f https://github.com/kvaps/dnsmasq-controller/raw/master/config/controller/dhcp-server.yaml
  kubectl label node --all node-role.kubernetes.io/dnsmasq=
  ```
  
You also need to deploy basic platform matchers for DHCP, they allows to detect the clients architecture (PC or EFI) to allow sending proper bootloader binary.

```bash
kubectl apply -n dnsmasq -f https://github.com/kvaps/kubefarm/raw/master/deploy/dhcp-platform-matchers.yaml
```

[Kubernetes]: https://kubernetes.io/
[Cert-manager]: https://cert-manager.io
[Local Path Provisioner]: https://github.com/rancher/local-path-provisioner
[MetalLB]: https://metallb.universe.tf
[Dnsmasq-controller]: https://github.com/kvaps/dnsmasq-controller



## Quick Start

Spawn new cluster:

```bash
helm repo add kvaps https://kvaps.github.io/charts
helm show values kvaps/kubefarm --version 0.10.2 > values.yaml
vim values.yaml
helm install cluster1 kvaps/kubefarm --version 0.10.2 \
  --namespace kubefarm-cluster1 \
  --create-namespace \
  -f values.yaml
```

### Cleanup

```bash
kubectl delete namespace cluster1
```

## Usage

You can access your newly deployed cluster very quickly:

```bash
kubectl exec -ti deploy/cluster1-kubernetes-admin -- sh
```

#### External clients

To achieve that you need to specify correct hostname or IP-address for `kubernetes.apiserver.certSANs` in your [`values.yaml`](deploy/helm/kubefarm/values.yaml) file.

Now you can get kubeconfig for your cluster:

```bash
kubectl exec -ti deploy/microservices-kubernetes-admin -- kubectl config view --flatten
```

you only need to correct the server address in it.

## License

* [Apache-2.0 License](LICENSE)
