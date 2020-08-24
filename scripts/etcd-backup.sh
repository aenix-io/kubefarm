#!/bin/sh
set -e
if [ $# -lt 2 ]; then
  echo "USAGE: $(basename $0) <etcd_pod> <file>"
  exit 1
fi

cat <<EOT

# perform backup
kubectl exec "$1" -- sh -c 'ETCDCTL_ENDPOINTS= etcdctl snapshot save /snapshot.db'

# download file
kubectl cp "$1:/snapshot.db" "$2"

# remove remote copy
kubectl exec "$1" -- sh -c 'rm -fv /snapshot.db'

EOT
