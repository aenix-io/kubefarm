#!/usr/bin/env sh
set -e

kubectl=kubectl
generator=""
nodefaultctx=0
nodefaultns=0
custom=false

while [ $# -gt 0 ]; do
  key="$1"

  case $key in
  --context)
    nodefaultctx=1
    kubectl="$kubectl --context $2"
    shift
    shift
    ;;
  --kubecontext=*)
    nodefaultctx=1
    kubectl="$kubectl --context=${key##*=}"
    shift
    ;;
  --kubeconfig)
    kubectl="$kubectl --kubeconfig $2"
    shift
    shift
    ;;
  --kubeconfig=*)
    kubectl="$kubectl --kubeconfig=${key##*=}"
    shift
    ;;
  -n | --namespace)
    nodefaultns=1
    kubectl="$kubectl --namespace $2"
    shift
    shift
    ;;
  --namespace=*)
    nodefaultns=1
    kubectl="$kubectl --namespace=${key##*=}"
    shift
    ;;
  --)
    shift
    break
    ;;
  *)
    if [ -z "$sts" ]; then
      sts="$1"
      shift
    elif [ -z "$file" ]; then
      file="$1"
      shift
    else
      echo "too many arguments"
      exit 1
    fi
    ;;
  esac
done

# Set the default context and namespace to avoid situations where the user switch them during the build process
[ "$nodefaultctx" = 1 ] || kubectl="$kubectl --context=$(kubectl config current-context)"
[ "$nodefaultns" = 1 ] || kubectl="$kubectl --namespace=$(kubectl config view --minify --output 'jsonpath={.contexts..namespace}')"

if [ -z "$sts" ]; then
  echo "Please specify etcd statefusset name as first argument"
  exit 1
fi

if [ -z "$sts" ]; then
  echo "Please specify etcd file name to save as second argument"
  exit 1
fi

image="docker.io/library/alpine"
pod="$sts-backup-$(env LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 6)"

# Check the statefulset
$kubectl get statefulset "$sts" >/dev/null || exit 1

overrides="$(
  cat <<EOT
{
  "spec": {
    "automountServiceAccountToken": false,
    "initContainers": [
      {
        "command": [
          "/bin/sh",
          "-c",
          "etcdctl snapshot save /data/snapshot.db"
        ],
        "env": [
          {
            "name": "POD_NAME",
            "valueFrom": {
              "fieldRef": {
                "fieldPath": "metadata.name"
              }
            }
          },
          {
            "name": "ETCDCTL_API",
            "value": "3"
          },
          {
            "name": "ETCDCTL_CACERT",
            "value": "/pki/etcd/peer/ca.crt"
          },
          {
            "name": "ETCDCTL_CERT",
            "value": "/pki/etcd/peer/tls.crt"
          },
          {
            "name": "ETCDCTL_KEY",
            "value": "/pki/etcd/peer/tls.key"
          },
          {
            "name": "ETCDCTL_ENDPOINTS",
            "value": "https://${sts}:2379"
          }
        ],
        "image": "k8s.gcr.io/etcd:3.4.13-0",
        "name": "etcd",
        "volumeMounts": [
          {
            "mountPath": "/pki/etcd/ca",
            "name": "pki-etcd-certs-ca"
          },
          {
            "mountPath": "/pki/etcd/peer",
            "name": "pki-etcd-certs-peer"
          },
          {
            "mountPath": "/pki/etcd/server",
            "name": "pki-etcd-certs-server"
          },
          {
            "mountPath": "/data",
            "name": "data"
          }
        ]
      }
    ],
    "containers": [
      {
        "name": "busybox",
        "image": "mirror.gcr.io/library/busybox:1.31.1-uclibc",
        "command": [
          "sleep",
          "infinity"
        ],
        "livenessProbe": null,
        "volumeMounts": [
          {
            "mountPath": "/data",
            "name": "data"
          }
        ]
      }
    ],
    "serviceAccountName": "default",
    "volumes": [
      {
        "name": "data",
        "emptyDir": {}
      },
      {
        "name": "pki-etcd-certs-ca",
        "secret": {
          "secretName": "${sts%-*}-pki-etcd-ca"
        }
      },
      {
        "name": "pki-etcd-certs-peer",
        "secret": {
          "secretName": "${sts%-*}-pki-etcd-peer"
        }
      },
      {
        "name": "pki-etcd-certs-server",
        "secret": {
          "secretName": "${sts%-*}-pki-etcd-server"
        }
      }
    ]
  }
}
EOT
)"

# Support Kubectl <1.18
m=$(kubectl version --client -o yaml | awk -F'[ :"]+' '$2 == "minor" {print $3+0}')
if [ "$m" -lt 18 ]; then
  generator="--generator=run-pod/v1"
fi

trap "EC=\$?; $kubectl delete pod --wait=false $pod 2>/dev/null || true; exit \$EC" EXIT INT TERM

echo "spawning \"$pod\" for \"$sts\""
$kubectl run --image "$image" --restart=Never --overrides="$overrides" "$pod" $generator
$kubectl wait --for=condition=ready pod "$pod"
$kubectl cp "$pod:data/snapshot.db" "$file"
