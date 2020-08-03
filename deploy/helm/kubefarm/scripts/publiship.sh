#!/bin/sh
# This script is waiting until two LoadBalancer service be ready
# then performs checks if they are having identical externalIP
# and records the IP-address to DhcpOptions object 
#
# Usage: publiship.sh <serviceName> <serviceName> <tagName> <DhcpOptionsName>

set -e

SVC1=${1:-$SVC1}
SVC2=${2:-$SVC2}
TAG=${3:-$TAG}
DHCPOPTIONS=${4:-$DHCPOPTIONS}

getip(){
  kubectl get service -w "$1" -o 'go-template={{with .status.loadBalancer.ingress}}{{range .}}{{.ip}}{{"\n"}}{{end}}{{.err}}{{end}}' 2>/tmp/error | head -n1
}

echo "Waiting for svc/$SVC1"
IP1=$(getip $SVC1)
if [ -z "$IP1" ]; then
  cat /tmp/error
  exit 1
fi

echo "Waiting for svc/$SVC2"
IP2=$(getip $SVC2)
if [ -z "$IP1" ]; then
  cat /tmp/error
  exit 1
fi

if [ "$IP1" != "$IP2" ]; then
  echo "IP for $SVC1 and $SVC2 not match"
  exit 1
fi

#kubectl patch dnshosts $DNSHOST --type merge -p "{\"spec\":{\"hosts\":[{\"hostnames\":[\"$HOSTNAME\"],\"ip\":\"$IP1\"}]}}"
kubectl patch dhcpoptions $DHCPOPTIONS --type merge -p "{\"spec\":{\"options\":[{\"key\":\"option:server-ip-address\",\"tags\":[\"$TAG\"],\"values\":[\"$IP1\"]}]}}"
