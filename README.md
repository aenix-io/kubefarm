
Kubefarm
========

<img align=left src="https://avatars1.githubusercontent.com/u/68351149?s=150&u=b8b4cb0f364281274159d4098090c0e229370cf0">

Kubefarm combines everything you need to spawn multiple Kubernetes-in-Kubernetes clusters, along with the network booting configurations to simplify bootstraping your physical servers from scratch.

The project's goals are to provide a simple and unified way to deploy Kubernetes on bare metal.

<p align="center">
<img src="https://gist.githubusercontent.com/kvaps/c969930f561b24c1f4c09802d5e225c8/raw/6347f81814d1eb56ccd2d4cbdb2a8617965cfa9d/kubefarm.png">
</p>

## Why

#### Fast & Simple

There is no installation process, so you just run your physical servers, andd during boot, they download the system image over the network and run it! Similar to docker containers that have `overlayfs` root.

You don't have to think about redundancy and performing updates for your OS anymore! A simple reboot is enough to apply the new image!

#### Declarative

You can spawn new Kubernetes clusters and PXE-servers just using Helm, very quickly! Just provide all the parameters in the wonderfully simple Yaml format. 

#### Customizable

You can build your own image for the physical servers simply by just using a [Dockerfile]. The default image is based on Ubuntu. You can put anything you need! Simply add any additional packages and custom kernel modules, and initiate the build!

[Dockerfile]: https://github.com/kubefarm/kubefarm/blob/master/build/ltsp/Dockerfile

#### Secure

You can deploy as many clusters as you want! All of them will have a separate control-plane, non visible to its consumers. Cert-manager will take care of  the certificates.

#### Known components

The whole setup consists of a few0 components:

- **[Kubernetes-in-Kubernetes]** - Kubernetes control-plane packed to a Helm-chart. It is based on the official Kubernetes static pod manifests and using the official Kubernetes docker images.
- **[Dnsmasq-controller]** - A simple wrapper for `Dnsmasq`, which automates the configuration using Kubernetes CRDs and will perform leader-election for DHCP high availability.
- **[LTSP]** - Network boot server and boot time configuration framework for clients. It allows you to boot the OS over the network, directly to RAM and perform initial configurations for each server.

[Kubernetes-in-Kubernetes]: https://github.com/kubefarm/kubernetes-in-kubernetes
[Dnsmasq-controller]: https://github.com/kubefarm/dnsmasq-controller
[LTSP]: https://github.com/ltsp/ltsp

## Preparation

There is a number of dependencies needed to make kubefarm work:

* **[Kubernetes]**

  The parent admin Kubernetes cluster is required to deploy user Kubernetes-in-Kubernetes control-planes and network booting servers.
  You can deploy admin Kubernetes clusters using your favorite installation method. For example, you can use [kubeadm] or [kubespray].
  
  [kubeadm]: https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/
  [kubespray]: https://github.com/kubernetes-sigs/kubespray

  You might want to untaint your master nodes to run workloads on them

  ```bash
  kubectl taint nodes --all node-role.kubernetes.io/master-
  ```

* **[Cert-manager]**

  The cert-manager issues the certificates for Kubernetes-in-Kubernetes and its etcd-cluster.
  
  ```bash
  kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v1.0.1/cert-manager.yaml
  ```
  
* **[Local Path Provisioner]**

  You need an automated, persistent volumes management for your cluster. Local-path-provisioner is the simpliest way to achieve that.

  ```bash
  kubectl apply -f https://github.com/rancher/local-path-provisioner/raw/master/deploy/local-path-storage.yaml
  ```

  Optionaly, any other csi-driver can be used.
  
* **[MetalLB]**

  You also need an automated, external IP-address maganement. MetalLB is able to provide this.
  
  ```bash
  kubectl apply -f https://github.com/metallb/metallb/raw/v0.10.2/manifests/namespace.yaml
  kubectl apply -f https://github.com/metallb/metallb/raw/v0.10.2/manifests/metallb.yaml
  ```

  Also [configure MetalLB Layer 2 address range](https://metallb.universe.tf/configuration/#layer-2-configuration) after the installation.  
  These IP addresses will be used for the child Kubernetes clusters and network booting servers.

* **[Dnsmasq-controller]**

  Highly available DHCP server wrapper allows you to configure DHCP leases over Kubernetes. Additional DNS-server modes are allowed:

  ```bash
  kubectl create namespace dnsmasq
  kubectl create -n dnsmasq clusterrolebinding dnsmasq-controller --clusterrole dnsmasq-controller --serviceaccount dnsmasq:dnsmasq-controller
  kubectl create -n dnsmasq rolebinding dnsmasq-controller-leader-election --role dnsmasq-controller-leader-election --serviceaccount dnsmasq:dnsmasq-controller
  
  kubectl apply -n dnsmasq \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dhcphosts.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dhcpoptions.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dnshosts.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/crd/bases/dnsmasq.kvaps.cf_dnsmasqoptions.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/rbac/service_account.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/rbac/role.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/rbac/leader_election_role.yaml \
    -f https://github.com/kubefarm/dnsmasq-controller/raw/master/config/controller/dhcp-server.yaml
  kubectl label node --all node-role.kubernetes.io/dnsmasq=
  ```
  
You also need to deploy basic platform matchers for DHCP. They allow you to detect the clients architecture (PC or EFI) to allow sending proper bootloader binaries:

```bash
kubectl apply -n dnsmasq -f https://github.com/kubefarm/kubefarm/raw/master/deploy/dhcp-platform-matchers.yaml
```

[Kubernetes]: https://kubernetes.io/
[Cert-manager]: https://cert-manager.io
[Local Path Provisioner]: https://github.com/rancher/local-path-provisioner
[MetalLB]: https://metallb.universe.tf
[Dnsmasq-controller]: https://github.com/kubefarm/dnsmasq-controller

## Quick Start

Spawn a new cluster:

```bash
helm repo add kvaps https://kvaps.github.io/charts
helm show values kvaps/kubefarm --version 0.13.4 > values.yaml
${EDITOR} values.yaml
helm install ${cluster_name} kvaps/kubefarm --version 0.13.4 \
  --namespace kubefarm-cluster1 \
  --create-namespace \
  -f values.yaml
```

> **Warning:** As is standard, clusters are bootstrapped without the CNI-plugin installed. Please follow official Kubernetes to choose and install the CNI-plugin to complete the installation.


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

To achieve that you need to specify the correct hostname or IP address for the `kubernetes.apiserver.certSANs` in your [`values.yaml`](deploy/helm/kubefarm/values.yaml) file:

  Now you can get kubeconfig for your cluster:

    ```bash
    kubectl exec -ti deploy/microservices-kubernetes-admin -- kubectl config view --flatten
    ```

  You only need to correct the server address in it.

## License

* [Apache-2.0 License](LICENSE)
