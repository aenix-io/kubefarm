#!/bin/sh
# This script is waiting until LoadBalancer service be ready
# then generates token and records it into Kubernetes secret
#
# Usage: gentoken.sh <serviceName> <secretName>

set -e

SVC=${1:-$SVC}
SECRET=${2:-$SECRET}

getip(){
  kubectl get service -w "$1" -o 'go-template={{with .status.loadBalancer.ingress}}{{range .}}{{.ip}}{{"\n"}}{{end}}{{.err}}{{end}}' 2>/tmp/error | head -n1
}

echo "Waiting for svc/$SVC"
IP=$(getip "$SVC")
if [ -z "$IP" ]; then
  cat /tmp/error
  exit 1
fi

echo "Acquiring token"
kubeadm --kubeconfig /etc/kubernetes/admin.conf token create --description kubefarm --print-join-command > /tmp/token
CONFIG=$(printf "IP=%s\nHOSTNAME=%s\nJOIN_COMMAND=%s\n" "$IP" "$(awk -F'[ :]' '{print $3}' /tmp/token)" "$(cat /tmp/token)")
CONFIG_BASE64=$(echo "$CONFIG" | base64 | tr -d '\n')

kubectl patch secret "$SECRET" --type merge -p="{\"data\":{\"kubeadm-join.env\":\"$CONFIG_BASE64\"}}"
