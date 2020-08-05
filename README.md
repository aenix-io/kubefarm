
Kubefarm
========

<img align="left" src="https://avatars1.githubusercontent.com/u/68351149?s=150&u=b8b4cb0f364281274159d4098090c0e229370cf0">

---

Kubefarm combines everything need to spawn multiple Kubernetes-in-Kubernetes clusters and network booting configuration to simple bootstrap the physical servers from the scratch.

The project goals is to provide simple and unified way for deploying Kubernetes on bare metal.

---

## Components

- **[Kubernetes-in-Kubernetes](https://github.com/kvaps/kubernetes-in-kubernetes)** - Kubernetes control-plane packed to Helm-chart
- **[Dnsmasq-controller](https://github.com/kvaps/dnsmasq-controller)** - DNS and DHCP service
- **[LTSP](https://github.com/ltsp/ltsp)** - Allows to boot OS over the network

*optional:*

- **[kube-fencing](https://github.com/kvaps/kube-fencing)** - Fencing implementation, kills the failed nodes and cleans up the resources.
- **[kube-linstor](https://github.com/kvaps/kube-linstor)** - A storage orchestration platform and csi-driver for it.
- **[metallb](https://github.com/metallb/metallb)** - A network load-balancer implementation for Kubernetes.

## Cluster Preparation

* [Deploy three-node Kubernetes cluster](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/)

* Deploy cert-manager

      kubectl apply --validate=false -f https://github.com/jetstack/cert-manager/releases/download/v0.15.2/cert-manager.yaml

* Deploy local-path-provisioner

      kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/master/deploy/local-path-storage.yaml

* Deploy dnsmasq-controller for DHCP

      kubectl create namespace dnsmasq
      kubectl create -n dnsmasq clusterrolebinding dnsmasq-controller --clusterrole dnsmasq-controller --serviceaccount dnsmasq:dnsmasq-controller
      kubectl create -n dnsmasq rolebinding dnsmasq-controller-leader-election --role dnsmasq-controller-leader-election --serviceaccount dnsmasq:dnsmasq-controller
      kubectl apply -n dnsmasq \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/crd/bases/dnsmasq.kvaps.cf_dhcphosts.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/crd/bases/dnsmasq.kvaps.cf_dhcpoptions.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/crd/bases/dnsmasq.kvaps.cf_dnshosts.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/crd/bases/dnsmasq.kvaps.cf_dnsmasqoptions.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/rbac/service_account.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/rbac/role.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/rbac/leader_election_role.yaml \
        -f https://raw.githubusercontent.com/kvaps/dnsmasq-controller/master/config/controller/dhcp-server.yaml
      kubectl label node --all node-role.kubernetes.io/dnsmasq=

* Deploy platform matchers



* Deploy MetalLB

      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/namespace.yaml
      kubectl apply -f https://raw.githubusercontent.com/metallb/metallb/v0.9.3/manifests/metallb.yaml
      kubectl create secret generic -n metallb-system memberlist --from-literal=secretkey="$(openssl rand -base64 128)"

## Quick Start

TODO

## Author

* [Kubefarm Authors](graphs/contributors)

## License

* [Apache-2.0 License](LICENSE)
