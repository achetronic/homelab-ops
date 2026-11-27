# Upgrading Talos and Kubernetes

Procedure for upgrading Talos OS and Kubernetes versions in a Terraform-managed cluster (`siderolabs/talos` provider).

> [!IMPORTANT]
> Talos OS and Kubernetes are upgraded independently. Bumping one does not bump the other. Each has its own variable in Terraform and its own `talosctl` command.

## Overview

Talos OS and Kubernetes take different paths in this module.

**Kubernetes is declarative.** Bump `globals.kubernetes.version` and `terraform apply` runs Talos' `upgrade-k8s` procedure. Nothing else to trigger.

**Talos OS is declarative too.** `talos_machine` carries the installer image, so bumping `globals.talos.image` and applying upgrades the OS on each node whose running version differs.

The two are not symmetric: the OS upgrade reboots the node, `talos_machine` does not drain it (`drain_on_upgrade = false`, see the note at the end of this section) and Terraform does not gate control-plane upgrades on etcd. Sequence it by hand, below.

## Prerequisites

Verify all of these before starting:

- **`talosctl` version matches the target Talos version.** Same minor at minimum.
- **Provider compatibility.** The `siderolabs/talos` Terraform provider has compatibility windows with each Talos minor. Check the provider release notes before bumping.
- **`talosconfig` endpoints resolve from your machine.** The provider stores short hostnames; use FQDNs. See the certificate-renewal procedure for details.
- **Cert SANs include `localhost` and `127.0.0.1`.** `talosctl upgrade-k8s` calls the Kubernetes API via `127.0.0.1` on the target master. Without those SANs, the upgrade fails midway.
- **Healthy etcd quorum with an odd number of voting members** (3, 5, 7…). Talos refuses to upgrade a master if doing so would break quorum.
- **Adjacent minor versions only.** Don't jump `v1.10 → v1.13`. Go `v1.10.x` (latest patch) → `v1.11.x` (latest patch) → `v1.12.x` → `v1.13.x`. Same for Kubernetes. Patch jumps within a minor are fine.
- **Pre-upgrade etcd snapshot:**

  ```bash
  talosctl -n <master.fqdn> etcd snapshot pre-upgrade-$(date +%Y%m%d).snap
  ```

---

## Talos OS upgrade

### 1. Bump the image in locals

```hcl
locals {
  cluster_config = {
    globals = {
      talos = {
        version        = "v1.14.7"
        config_version = "v1.13.13"
        image          = "factory.talos.dev/metal-installer/376567988ad...:v1.14.7"
      }
      # ...
    }
  }
}
```

Three fields, three different jobs:

- `image` is the full installer reference that gets pulled. Since 1.14 Talos only publishes through the Image Factory, so it is not `ghcr.io/siderolabs/installer` any more. The schematic in the path decides which extensions the node gets.
- `version` is the version the nodes should report. It is only used to name the target, not to build the image reference.
- `config_version` is the contract used to generate the machine configuration. Keep it at the last Talos whose generated config the templates can patch: 1.14 started emitting multi-document configs that conflict with the templates, so generating with 1.13 keeps the config applicable.

### 2. Plan, do not apply

```bash
terragrunt plan
```

The plan shows `~ talos_machine` on every control plane and worker: the configuration changes and the installer image moves to the new tag.

A plain `terragrunt apply` here upgrades **all six nodes at once**. Do not run it.

### 3. Upgrade one node at a time, workers first

The node is selected with `-target`:

```bash
terragrunt apply -parallelism=1 \
  -target='module.talos_kubernetes_01.talos_machine.worker["compute-13"]'
talosctl -n <worker-1.fqdn> health --wait-timeout 5m
```

Then each control plane in its own apply, with the etcd gate in between:

```bash
terragrunt apply -parallelism=1 \
  -target='module.talos_kubernetes_01.talos_machine.controlplane["compute-11"]'
talosctl -n <master-1.fqdn> etcd status   # gate: must be healthy before the next
kubectl get nodes
```

> [!CAUTION]
> If `etcd status` shows any member with a diverging `RAFT INDEX` or errors, **stop**. Wait for convergence before touching the next master. Doing two masters with an unhealthy quorum can lose the cluster.
>
> Terraform does not know about this gate. With the default parallelism it reboots all three control planes in the same apply.

### 4. Fallback if an upgrade fails

```bash
talosctl -n <node.fqdn> upgrade --preserve --wait
```

Same upgrade, driven by `talosctl` instead of the apply. Use it when the apply fails midway. Pass `--image` with the target version when the node's machine config has not been updated yet.

> [!NOTE]
> `--preserve` keeps `/var` (containerd cache, persistent volumes, logs) across the upgrade.

> [!NOTE]
> `drain_on_upgrade` is `false`: the node gets no cordon or drain, so the kubelet dies with the reboot and its workloads restart cold. Wiring it needs a kubeconfig, which `talos_cluster_kubeconfig` cannot supply before `talos_cluster` creates the cluster.

### 5. Final check

```bash
talosctl -n <master.fqdn>,<...> version --short
kubectl get nodes
```

All nodes should report the new Talos version. Kubernetes is unchanged.

---

## Kubernetes upgrade

### 1. Bump the Kubernetes version in locals

```hcl
locals {
  cluster_config = {
    globals = {
      kubernetes = {
        version = "v1.34.0"   # ← was v1.33.0
      }
      # ...
    }
  }
}
```

### 2. Apply Terraform

```bash
terragrunt plan
terragrunt apply
```

`talos_cluster` sees the new `kubernetes_version` and runs Talos' `upgrade-k8s` procedure: pre-pulls images, upgrades the static pods component by component with health gating, updates the kube-proxy DaemonSet, upgrades kubelet on every node in sequence and re-applies the bootstrap manifests. The apply blocks until it finishes, up to the resource timeout.

The five image fields (`kubelet`, `apiServer`, `controllerManager`, `scheduler`, `proxy`) belong to `upgrade-k8s`. `talos_machine` ignores drift on them (`ignore_kubernetes_upgrade_drift = true`), so the two resources do not fight over the same values.

### 3. Fallback if the apply fails midway

```bash
talosctl -n <master.fqdn> upgrade-k8s --to <X.Y.Z>
```

Same procedure, run by hand. Use it only when the resource timed out or the cluster was left between component versions.

### 4. Verify

```bash
kubectl version
kubectl get nodes
kubectl get pods -A | awk '$4 !~ /Running|Completed/'
```

---

## Rollback

If a node fails to come up after upgrade, Talos' A/B partition scheme allows reverting:

```bash
talosctl -n <node.fqdn> rollback
```

This boots the previous Talos version. After rollback, fix the underlying cause and reconcile Terraform — don't leave the cluster with mixed versions for long.

For Kubernetes, there is no equivalent one-shot rollback. Plan the bump carefully, verify in a non-production cluster first when possible.

---

## Common pitfalls

### Out-of-band upgrades without Terraform reconciliation

Running `talosctl upgrade` or `talosctl upgrade-k8s` without first bumping locals leaves Terraform's view stale. The next plan will show drift and try to "downgrade" the image references back. **Always reconcile with a Terraform PR right after any out-of-band upgrade.**

### OS upgrades without draining

`talos_machine` reboots the node on an OS upgrade without cordoning or draining it first. The kubelet dies with the reboot and the workloads on that node restart cold. Until `drain_on_upgrade` is wired, run control-plane upgrades one at a time with `-target`.

### `talosctl` version mismatch

Running an older `talosctl` against an upgraded cluster works for read operations but can subtly break `upgrade` and `upgrade-k8s` flows. Match the client to the cluster.

### Provider bump mid-upgrade

Bumping the Talos provider often introduces unrelated diffs (new default fields, schema changes) on the next plan. Don't combine a provider bump with an upgrade — do them in separate PRs and applies.

### Skipping minors

Talos and Kubernetes both test only adjacent-minor migrations. Jumping `1.10 → 1.13` is unsupported and may corrupt etcd or the machine config schema. Always step through each minor's latest patch.
