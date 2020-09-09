#!/bin/sh
EC=0

version=$1
[ -z "$version" ] && echo "version is not specified as first argument" && exit 1

echo "bumping version to $version"

f=README.md
sed -i "s/\(kubefarm --version\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" README.md
git diff --exit-code "$f" && echo "$f not changed" && EC=1

f=deploy/helm/kubefarm/Chart.yaml
sed -i "s/\(^version:\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" "$f"
git diff --exit-code "$f" && echo "$f not changed" && EC=1

for f in \
  examples/advanced_network/README.md \
  examples/catchall/README.md \
  examples/dualstack_network/README.md \
  examples/generic/README.md
do
  sed -i "s/\(kubefarm --version\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" "$f"
  git diff --exit-code "$f" && echo "$f not changed" && EC=1
done

echo

kink_version=$(sed -n 's/version: //p' deploy/helm/kubefarm/charts/kubernetes/Chart.yaml)
echo "bumping kink version to $kink_version"

f=deploy/helm/kubefarm/requirements.yaml
sed -i -z "s/\(name: kubernetes\n  version:\) [0-9]\+\.[0-9]\+\.[0-9]\+/\1 ${version}/" "$f"
git diff --exit-code "$f" && echo "$f not changed" && EC=1

if [ "$EC" != 0 ]; then
  echo
  echo "not all files were changed!"
fi
exit "$EC"
