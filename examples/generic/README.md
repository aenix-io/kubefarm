# Generic cluster

This setup illustrates the deployment of typical cluster with the static clients.

#### Deploying

[values.yaml](values.yaml) contains following DHCP settings:

* DHCP-range: `10.28.0.0-static`
* Netmask: `255.255.0.0`
* Broadcast: `10.28.255.255`
* Gateway: `10.28.0.1`
* DNS Server: `10.28.0.1`

* 5 standard nodes
* 1 node with the labels `label1=value1,label2=value2` and `foo=bar:NoSchedule` taint


apply:

```
helm upgrade --install cluster1 kvaps/kubefarm --version 0.6.1 \
  --namespace kubefarm-cluster1 \
  --create-namespace \
  -f values.yaml
```
