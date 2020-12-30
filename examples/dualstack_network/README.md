# Install Kubernetes cluster with cilium and IPv6

This example illustrates cluster configuration for dual stack network. The following options will be used:

| -                   | IPv4 CIDR       | IPv6 CIDR         |
|---------------------|-----------------|-------------------|
| **Node network**    | `10.28.0.0/16`  | `1234::/64`       |
| **Pod network**     | `10.112.0.0/12` | `fd00::/104`      |
| **Service network** | `10.96.0.0/12`  | `fd00:ffff::/112` |

Cilium will be installed with IPAM and kube-proxy free configuration.

---

Enable IPv6 router advertisement for your router.

If you're using dnsmasq you can configure it like this:

```bash
dhcp-range=1234::,slaac
```

where `1234::` is your IPv6 network

You might want using server with dnsmasq-dhcp as a gateway this way you can configure it like this:

```yaml
kubectl apply -n dnsmasq -f- <<EOT
apiVersion: dnsmasq.kvaps.cf/v1beta1
kind: DnsmasqOptions
metadata:
  name: ipv6-slaac-range
spec:
  controller: ""
  options:
  - key: dhcp-range
    values: [1234::,slaac]
EOT
```

your server should have an IP from `1234::` range assigned on interface and ipv6 forwarding enabled:

```bash
sysctl -w net.ipv6.conf.all.forwarding=1
```

deploy kubernetes cluster without kube-proxy:

```bash
helm upgrade --install cluster1 kvaps/kubefarm --version 0.8.0 \
  --namespace kubefarm-cluster1 \
  --create-namespace \
  -f ../generic/values.yaml \
  -f values.yaml
```

Install [Cilium](https://cilium.io/):

```bash
helm upgrade \
  --install cilium cilium/cilium \
  --version 1.9.1 \
  --namespace kube-system \
  --set kubeProxyReplacement=strict \
  --set k8sServiceHost=cluster1-kubernetes-apiserver \
  --set k8sServicePort=6443 \
  --set ipv4.enabled=true \
  --set ipv6.enabled=true \
  --set tunnel=disabled \
  --set autoDirectNodeRoutes=true \
  --set nativeRoutingCIDR=10.112.0.0/12 \
  --set ipam.operator.clusterPoolIPv4PodCIDR=10.112.0.0/12 \
  --set ipam.operator.clusterPoolIPv4MaskSize=24 \
  --set ipam.operator.clusterPoolIPv6PodCIDR=fd00::/104 \
  --set ipam.operator.clusterPoolIPv6MaskSize=112
```
