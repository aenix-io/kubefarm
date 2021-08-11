# Advanced network configuration

This setup illustrates custom network configuration for the clients using [netplan]

[netplan]: https://netplan.io/

The netplan config is generated using simple shell-script executed on the initial state, before calling the systemd

you can use one of the following variables:

```bash
DEVICE='eno1'
DNS_SERVER='10.28.0.1'
GATEWAY='10.28.0.1'
IPCONFIG_DEVICE='eno1'
IPCONFIG_DNSDOMAIN=''
IPCONFIG_HOSTNAME='m1c31'
IPCONFIG_IPV4ADDR='10.28.36.174'
IPCONFIG_IPV4BROADCAST='10.28.0.0'
IPCONFIG_IPV4DNS0='10.28.0.1'
IPCONFIG_IPV4GATEWAY='10.28.0.1'
IPCONFIG_IPV4NETMASK='255.255.0.0'
IPCONFIG_IPV4PROTO='dhcp'
IPCONFIG_PROTO='dhcp'
IPCONFIG_ROOTSERVER='10.28.0.1'
IP_ADDRESS='10.28.36.174'
MAC_ADDRESS='94:57:a5:d3:ef:92'
SERVER='10.28.0.1'
```

or just put `debug_shell` at any place you want to debug.

#### Deploying

[values.yaml](values.yaml) contains config generator, with:

- one bonding interface over eno1 and eno1d1
- one vlan interface over bonding
- the additional IPv4 address for the vlan interface generated from the first one
- mtu set to 9000

apply:

```
helm upgrade --install cluster1 kvaps/kubefarm --version 0.13.0 \
  --namespace kubefarm-cluster1 \
  --create-namespace \
  -f ../generic/values.yaml \
  -f values.yaml
```
