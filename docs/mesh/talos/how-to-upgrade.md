# Upgrading Talos and Kubernetes

How to move a Terraform-managed cluster to a newer Talos OS and a newer Kubernetes.

> [!IMPORTANT]
> Talos OS and Kubernetes carry separate versions in `infrastructure/terraform/talos/kubernetes-01.tf`. Bumping one does not bump the other.

## Prerequisites

- **Adjacent minors only.** Talos and Kubernetes test the step from one minor to the next. Go from the latest patch of one minor to the latest patch of the next one. Patch jumps within a minor are fine.
- **`talosctl` matching the target minor.** Install it before starting.
- **Provider compatibility.** The `siderolabs/talos` provider has a compatibility window with each Talos minor. Check its release notes before bumping.
- **Healthy etcd.** Three members, all reachable, no errors.
- **etcd snapshot:**

  ```bash
  talosctl -n <master-ip> etcd snapshot pre-upgrade-$(date +%Y%m%d).snap
  ```

- **A Gitlab token.** The tasks read it from `temp/gitlab/access-tokens/<name>.json`, created by `task gitlab:generate-supertoken`.

---

## Talos OS

### 1. Bump the version in the locals

`infrastructure/terraform/talos/kubernetes-01.tf`:

```hcl
talos = {
  config_version = "v1.14.7"
  image          = "factory.talos.dev/metal-installer/<schematic>:v1.14.7"
}
```

- `image` is the installer reference the nodes pull. From 1.14 on, Talos publishes only through the Image Factory, so the reference carries a schematic that decides which extensions the node gets.
- `config_version` is the version contract used to generate the machine configuration. The module keeps one template per generation: up to 1.13 a single `v1alpha1` document, from 1.14 a set of documents (`UnattendedInstallConfig`, `HostnameConfig`, `KubeClusterConfig`, `KubeNetworkConfig`, `KubeAPIServerConfig`). Both values move together unless the templates do not support the new generation yet.

New VMs also need the ISO of that version, in `infrastructure/terraform/vms/compute-*.tf`. It is a separate scope.

### 2. Review the plan

```bash
task terragrunt:plan-talos GITLAB_ACCESS_TOKEN_NAME=supertoken
```

Expect `~ talos_machine` on every control plane and worker. Do not apply from here: a plain apply reboots every node at the same time.

### 3. Run the task

```bash
task talos:upgrade GITLAB_ACCESS_TOKEN_NAME=supertoken
```

It stops before every node and asks for confirmation. For each one, in order:

1. Applies the configuration to that node only.
2. Waits for the node to report `Ready`.
3. Prints the Talos version it is running.
4. On control planes, prints `etcd status` and waits for the API to answer before the next node.

Workers go first, then control planes. Answering anything but `y` stops the run where it is.

Add `SKIP_CONFIRMATION=true` to run it without asking.

### 4. Verify

```bash
talosctl -n <master-ip> version --short
kubectl get nodes
```

Every node reports the new version. Kubernetes is unchanged.

### If a node fails

```bash
talosctl -n <node-ip> upgrade --preserve --wait
```

Same upgrade driven by `talosctl`. Use it when the apply fails midway. Pass `--image` with the target reference when the node's configuration has not been updated yet. `--preserve` keeps `/var`: containerd cache, persistent volumes and logs.

---

## Kubernetes

### 1. Bump the version in the locals

```hcl
kubernetes = {
  version = "v1.37.3"
}
```

### 2. Run the task

```bash
task talos:upgrade-kubernetes GITLAB_ACCESS_TOKEN_NAME=supertoken
```

It asks for confirmation once, and refuses to run without a terminal (`--yes` to skip that).

Two applies, in this order:

1. `talos_cluster` alone. It runs Talos' `upgrade-k8s`: pre-pulls images, upgrades the static pods component by component with health gating, updates the kube-proxy DaemonSet, upgrades kubelet on every node and re-applies the bootstrap manifests.
2. The rest of the scope. The machines write the new kubelet tag into their configuration.

The order matters. The control plane has to reach the new minor first, because a kubelet newer than the API server is not a supported combination.

The five image fields (`kubelet`, `apiServer`, `controllerManager`, `scheduler`, `proxy`) belong to `upgrade-k8s`. `talos_machine` ignores drift on them (`ignore_kubernetes_upgrade_drift = true`).

### 3. Verify

```bash
kubectl version
kubectl get nodes
kubectl get pods -A | awk '$4 !~ /Running|Completed/'
```

### If the apply fails midway

```bash
talosctl -n <master-ip> upgrade-k8s --to <X.Y.Z>
```

Same procedure by hand. Use it when the resource timed out or the cluster was left between component versions.

---

## Rollback

Talos keeps the previous version in the inactive partition:

```bash
talosctl -n <node-ip> rollback
```

After a rollback, reconcile Terraform. Leaving the cluster on mixed versions is worse than the failed upgrade.

Kubernetes has no equivalent. Plan the bump, and keep the previous minor patch handy.

---

## Common pitfalls

### Configuration schema moves between minors

A new Talos minor can move fields to new configuration documents and reject a configuration that sets them twice. 1.12 moved the hostname, 1.14 moved the install, the cluster endpoint, the cluster network and the API server SANs.

The templates carry one generation each. When a minor moves something, the templates need updating before the upgrade, not after. The node reports the rejection on the first apply.

### Rebooting everything at once

Terraform's default parallelism reboots every node in a single apply. The task exists to avoid that, and it is the reason the OS upgrade goes through it.

### Out-of-band upgrades

Running `talosctl upgrade` or `talosctl upgrade-k8s` without bumping the locals leaves Terraform behind. The next plan shows drift and tries to walk the image references back. Reconcile with a Terraform change right after.

### No drain

`drain_on_upgrade` is `false`. The node is not cordoned or drained before the reboot, so its workloads restart cold. Wiring the drain needs a kubeconfig that `talos_cluster_kubeconfig` cannot provide before `talos_cluster` creates the cluster.

### `talosctl` mismatch

An older `talosctl` reads a newer cluster fine, but `upgrade` and `upgrade-k8s` can misbehave. Match the client to the target minor.

### Provider bump in the same change

A new provider version often brings unrelated diffs on the next plan. Keep the provider bump in its own change.
