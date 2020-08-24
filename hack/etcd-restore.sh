#!/bin/sh
# The script generates commands to perform etcd restore for the kubefarm cluster
#
# Example usage:
#   ./etcd-restore.sh cluster1-kubernetes-etcd 3 snapshot.db
#
# where:
#   - cluster1-kubernetes-etcd: name of your etcd statefulset
#   - 3: amount of replicas for your cluster
#   - snapshot.db: filename of local backup

set -e
if [ $# -lt 3 ]; then
  echo "USAGE: $(basename $0) <statefulset> <replicas> <file>"
  exit 1
fi
if ! [ $2 -gt 0 ] 2>/dev/null; then
  echo "amount of replicas must be 1 or more"
  exit 2
fi

INITIAL_CLUSTER=$(for i in `seq 0 $(($2-1))`; do echo $1-$i=https://$1-$i.$1:2380; done | paste -s -d,)

cat <<EOT
# wait for all replicas
kubectl rollout status -w sts "$1"

# shutdown the cluster
kubectl patch sts "$1" --patch "
apiVersion: apps/v1
kind: StatefulSet
spec:
  template:
    spec:
      containers:
      - name: etcd
        command:
        - sleep
        - infinity
        livenessProbe: null
      terminationGracePeriodSeconds: 0
"

# wait for all replicas
kubectl rollout status -w sts "$1"
EOT

for i in `seq 0 $(($2-1))`; do
  cat <<EOT

# restore $1-$i
kubectl cp "$3" "$1-$i:/snapshot.db"
kubectl exec "$1-$i" -- sh -c "set -x; rm -rf /default.etcd && etcdctl snapshot restore snapshot.db \\
  --data-dir=/default.etcd \\
  --name=\\"$1-$i\\" \\
  --initial-cluster=\\"$INITIAL_CLUSTER\\" \\
  --initial-cluster-token=\\"$1-$1\\" \\
  --initial-advertise-peer-urls=\\"https://$1-$i.$1:2380\\""
kubectl exec "$1-$i" -- sh -c 'rm -rf /var/lib/etcd/* && mv /default.etcd/* /var/lib/etcd/'
EOT
done

cat <<EOT

# startup the cluster
kubectl rollout undo sts "$1"
EOT
