#!/bin/sh
set -e
if [ $# -lt 2 ]; then
  echo "USAGE: $(basename $0) <etcd_pod> <file>"
  exit 1
fi
if [ -d $2 ]; then
  echo "destination must not be directory"
  exit 1
fi

kubectl exec "$1" -- sh -c 'ETCDCTL_ENDPOINTS= etcdctl snapshot save /snapshot.db'
kubectl cp "$1":/snapshot.db "$2"
kubectl exec "$1" -- sh -c 'rm -fv /snapshot.db'
