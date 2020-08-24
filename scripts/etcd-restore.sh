#!/bin/sh
set -e
if [ $# -lt 2 ]; then
  echo "USAGE: $(basename $0) <statefulset> <file>"
  exit 1
fi
if [ ! -f $2 ]; then
  echo "$2 is not a file"
  exit 1
fi

rand="$(env LC_ALL=C tr -dc a-z0-9 < /dev/urandom | head -c 8)"

kubectl rollout status -w sts "$1"

kubectl patch sts "$1" --patch "$(cat <<EOT
apiVersion: apps/v1
kind: StatefulSet
spec:
  template:
    metadata:
      labels:
        etcd-restore: "$rand"
    spec:
      containers:
      - name: etcd
        command:
        - sleep
        - infinity
        livenessProbe: null
      terminationGracePeriodSeconds: 0
EOT
)"
trap 'kubectl rollout undo sts "$1"' EXIT HUP TERM

kubectl rollout status -w sts "$1"

PODS=$(kubectl get pod -l "etcd-restore=$rand" --template='{{range .items}}{{.metadata.name}} {{end}}')
INITIAL_CLUSTER=$(for i in $PODS; do echo $i=https://$i.$1:2380; done | paste -s -d,)

for i in $PODS; do
  set -x
  kubectl cp "$2" "$i":/snapshot.db 
  kubectl exec "$i" -- sh -c "set -x; rm -rf /default.etcd &&
    etcdctl snapshot restore snapshot.db \
      --data-dir=/default.etcd \
      --name=\"$i\" \
      --initial-cluster=\"$INITIAL_CLUSTER\" \
      --initial-cluster-token=\"$1\" \
      --initial-advertise-peer-urls=\"https://$i.$1:2380\"
    "
  kubectl exec "$i" -- sh -c 'rm -rf /var/lib/etcd/* && mv /default.etcd/* /var/lib/etcd/'
done
