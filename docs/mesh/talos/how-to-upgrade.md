# Upgrading Talos and Kubernetes

Procedure for upgrading Talos OS and Kubernetes versions in a Terraform-managed cluster (`siderolabs/talos` provider).

> [!IMPORTANT]
> Talos OS and Kubernetes are upgraded independently. Bumping one does not bump the other. Each has its own variable in Terraform and its own `talosctl` command.

## Overview

Both upgrades follow the same pattern:

1. Bump the version variable in Terraform locals (declarative source of truth).
2. `terraform apply` → writes the new image references into the persistent machine config of each node. Nothing reinstalls or restarts yet.
3. Run the appropriate `talosctl` upgrade command, node by node (imperative trigger). The nodes pick up the image from the machine config and apply the upgrade.

Keeping these two steps in sync is the whole point of managing the cluster with Terraform. Skip the apply and the state diverges from reality. Skip the `talosctl` step and the cluster keeps running the old version while the manifest claims otherwise.

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

### 1. Bump the Talos version in locals

```hcl
locals {
  cluster_config = {
    globals = {
      talos = {
        version = "v1.11.5"   # ← was v1.10.2
      }
      # ...
    }
  }
}
```

This drives both `talos_machine_secrets.talos_version` and the `machine.install.image` patch in each node's config.

### 2. Apply Terraform

```bash
terragrunt plan      # review carefully
terragrunt apply
```

The plan should show `~ machine_configuration_apply` on every node, with `machine.install.image` updated to the new tag. No reinstall happens at this stage — Talos only persists the new image reference.

### 3. Verify the new image landed on the nodes

```bash
for n in <node-1.fqdn> <node-2.fqdn> ...; do
  printf "%-30s " "$n"
  talosctl -n "$n" get machineconfig v1alpha1 -o yaml \
    | grep -A2 'install:' | grep image
done
```

All nodes should report the new tag.

### 4. Upgrade workers first

```bash
for n in <worker-1.fqdn> <worker-2.fqdn> ...; do
  talosctl -n "$n" upgrade --preserve --wait
  talosctl -n "$n" health --wait-timeout 5m
done
```

> [!NOTE]
> `--preserve` keeps `/var` (containerd cache, persistent volumes, logs) across the upgrade. Always use it.
>
> No `--image` flag is needed — `talosctl upgrade` reads the target image from `machine.install.image`, which step 2 just populated.

### 5. Upgrade control-plane nodes one at a time

```bash
for n in <master-1.fqdn> <master-2.fqdn> <master-3.fqdn>; do
  talosctl -n "$n" upgrade --preserve --wait
  talosctl -n "$n" etcd status   # gate: must be healthy before the next
  kubectl get nodes
done
```

> [!CAUTION]
> If `etcd status` shows any member with a diverging `RAFT INDEX` or errors, **stop**. Wait for convergence before touching the next master. Doing two masters with an unhealthy quorum can lose the cluster.

### 6. Final check

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

Plan shows `apiServer.image`, `controllerManager.image`, `scheduler.image`, `proxy.image` and `kubelet.image` bumped to the new Kubernetes version on every node.

### 3. Trigger the Kubernetes upgrade

```bash
talosctl -n <master.fqdn> upgrade-k8s --to <X.Y.Z>
```

This single command orchestrates a rolling upgrade of all Kubernetes components across the cluster. No manual node-by-node loop needed for K8s — Talos handles it.

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

### Terraform apply without the talosctl trigger

After `terraform apply`, the node still runs the old version. The image only becomes effective when something triggers an upgrade. If steps 4/5 of the Talos section are skipped, the cluster runs the old code while the manifest claims otherwise.

### `talosctl` version mismatch

Running an older `talosctl` against an upgraded cluster works for read operations but can subtly break `upgrade` and `upgrade-k8s` flows. Match the client to the cluster.

### Provider bump mid-upgrade

Bumping the Talos provider often introduces unrelated diffs (new default fields, schema changes) on the next plan. Don't combine a provider bump with an upgrade — do them in separate PRs and applies.

### Skipping minors

Talos and Kubernetes both test only adjacent-minor migrations. Jumping `1.10 → 1.13` is unsupported and may corrupt etcd or the machine config schema. Always step through each minor's latest patch.
