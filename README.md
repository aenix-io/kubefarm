
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

## Author

* [Kubefarm Authors](graphs/contributors)

## License

* [Apache-2.0 License](LICENSE)
