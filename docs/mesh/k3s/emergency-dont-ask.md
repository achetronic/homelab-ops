# Control Plane nodes:

## Installing:

```console
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san=kubernetes-01.internal.place --cluster-cidr=10.90.0.0/16 --service-cidr=10.96.0.0/16 --disable-helm-controller --disable=traefik --disable=local-storage --disable=servicelb" sh -s -
cat /var/lib/rancher/k3s/server/node-token > K3S_CLUSTER_TOKEN

kubectl taint node orangepi-01 node-role.kubernetes.io/control-plane=:NoSchedule
kubectl drain orangepi-01 --delete-emptydir-data
```

## Get Kubeconfig:
```console
cat /etc/rancher/k3s/k3s.yaml
```

## Uninstalling:

```console
/usr/local/bin/k3s-uninstall.sh
```

# Agent nodes:

## Installing:

```console
curl -sfL https://get.k3s.io | K3S_URL=https://compute-04.internal.place:6443 K3S_TOKEN=<K3S_CLUSTER_TOKEN> sh -
```

## Uninstalling:

```console
/usr/local/bin/k3s-agent-uninstall.sh
```
