# Renewing Talos Client Certificates

Procedure for renewing the client certificate embedded in `talosconfig` when the cluster CAs are still valid. Applies to clusters managed by Terraform with the `siderolabs/talos` provider.

> [!IMPORTANT]
> You typically don't need this if you manage the cluster fully with Terraform. Every `terraform apply` regenerates the client certificate as a side effect of refreshing the `talos_client_configuration` data source. As long as you apply at least once within the certificate's 1-year validity window, this never becomes an issue. This document is recovery for when the cert has already expired between applies.

## When to use this

When `talosctl` starts failing with:

```
error reading server preface: remote error: tls: expired certificate
```

…and inspection of the current `talosconfig` shows the client certificate (`subject = O = os:admin`) past its `notAfter` date, while the cluster CAs themselves are still valid.

This is the common case: client certificates are issued with **1-year validity**, while the underlying CAs have a **10-year validity**. If the CA has also expired, this procedure does **not** apply — you need a full CA rotation instead (out of scope here).

## Background

The Talos Terraform provider stores the cluster CAs (Talos OS, Kubernetes, etcd, k8s-aggregator) inside the `talos_machine_secrets` resource of the state. As long as those CAs are intact, renewing a client certificate is just a `terraform apply`:

- The `talos_client_configuration` data source signs a fresh client certificate from the CA in the state.
- All `client_configuration` blocks across resources are updated with the new cert.
- The `talosconfig` and `kubeconfig` outputs are regenerated.
- CAs, machine secrets, and node state are untouched.

The provider does **not** read your local `talosconfig`. On each apply it mints its own client cert in memory from the CA in the state and connects to the nodes with that. This is why the apply works even when your CLI is broken.

## Diagnosis

Inspect the current client certificate:

```bash
yq '.contexts.[].crt' /path/to/talosconfig.yaml \
  | base64 -d \
  | openssl x509 -noout -dates -subject
```

Look for `subject = O = os:admin` and `notAfter` in the past.

---

## Short path (default)

If the plan looks clean — only `update in-place` on `client_configuration` blocks and the two outputs, no `replace`, no `destroy`, no unexpected `machine_configuration` diffs — just apply. There is nothing to gain from manual extraction in this case.

```bash
terraform plan                                              # review carefully
terraform state pull > state.json.bak-$(date +%Y%m%d-%H%M)  # backup, just in case
terraform apply                                             # or your wrapper

# Fetch renewed outputs
mkdir -p ~/.talos ~/.kube
terraform output -raw <talosconfig_output_name> > ~/.talos/config
terraform output -raw <kubeconfig_output_name>  > ~/.kube/config
chmod 600 ~/.talos/config ~/.kube/config

# Replace short hostnames with FQDN (provider stores short ones)
talosctl config endpoint <master-1.fqdn> <master-2.fqdn> <master-3.fqdn>
talosctl config node     <master-1.fqdn> <master-2.fqdn> <master-3.fqdn>

# Verify
talosctl version --short
talosctl etcd status
kubectl get nodes
yq '.contexts.[].crt' ~/.talos/config | base64 -d | openssl x509 -noout -dates -subject
```

Done. Keep the state backup around for a few days and then delete it.

---

## Long path (when justified)

The long path manually extracts a temporary `talosconfig` from the state. It only matters when you need a working CLI **before** running `apply`. Common triggers:

- **The plan shows unexpected drift** in `machine_configuration_apply` (typically because someone ran `talosctl upgrade` or `talosctl upgrade-k8s` between Terraform runs). You want to inspect the live machine config and reconcile templates before letting `apply` overwrite the nodes.
- **You want a pre-apply etcd snapshot** as a safety net for risky changes.
- **The apply failed mid-way** in a previous attempt and you need to diagnose node state before retrying.
- **Terraform isn't readily runnable** (broken module, obsolete provider, lost wrapper, weekend laptop), but the state is reachable.

In a normal renewal where the plan is just regenerating client certs, you can skip this section entirely.

### Prerequisites

- Read access to the Terraform state.
- `talosctl` matching the cluster's Talos version.
- `python3` with `pyyaml`.

### 1. Pull the state

```bash
terraform state pull > state.json
```

> ⚠️ The state contains all cluster private keys in cleartext. Keep it on tmpfs or a restricted directory and shred it when done.

### 2. Extract a secrets bundle

The state stores secrets with Terraform's naming conventions; `talosctl` expects a different layout. This script does the translation.

```bash
mkdir -p /tmp/talos-recover && cd /tmp/talos-recover

cat > extract.py <<'PY'
import json, yaml, sys

with open(sys.argv[1]) as f:
    s = json.load(f)

ms = next(r for r in s['resources'] if r['type'] == 'talos_machine_secrets')
sec = ms['instances'][0]['attributes']['machine_secrets']

def ck(d):
    out = {}
    if d.get('cert'): out['crt'] = d['cert']
    if d.get('key'):  out['key'] = d['key']
    return out

bundle = {
    'cluster': sec['cluster'],
    'secrets': {
        'bootstraptoken': sec['secrets']['bootstrap_token'],
        'secretboxencryptionsecret': sec['secrets']['secretbox_encryption_secret'],
    },
    'trustdinfo': {'token': sec['trustdinfo']['token']},
    'certs': {
        'etcd':              ck(sec['certs']['etcd']),
        'k8s':               ck(sec['certs']['k8s']),
        'k8saggregator':     ck(sec['certs']['k8s_aggregator']),
        'k8sserviceaccount': {'key': sec['certs']['k8s_serviceaccount']['key']},
        'os':                ck(sec['certs']['os']),
    },
}

aescbc = sec['secrets'].get('aescbc_encryption_secret')
if aescbc:
    bundle['secrets']['aescbcencryptionsecret'] = aescbc

print(yaml.safe_dump(bundle, default_flow_style=False, sort_keys=False))
PY

python3 extract.py /path/to/state.json > secrets.yaml
```

> **Format gotcha.** `talosctl` expects all keys lowercased without separators (`bootstraptoken`, `secretboxencryptionsecret`, `k8saggregator`, `k8sserviceaccount`) and certificate fields named `crt`/`key`. The Terraform state uses snake_case (`bootstrap_token`, `k8s_aggregator`) and `cert`/`key`. A bad translation surfaces as `failed to parse PEM block` from `talosctl gen config`.

### 3. Generate a temporary talosconfig

```bash
talosctl gen config <CLUSTER_NAME> https://<CLUSTER_ENDPOINT>:6443 \
  --with-secrets secrets.yaml \
  --output-types talosconfig \
  --output talosconfig.yaml \
  --force
```

`<CLUSTER_NAME>` and `<CLUSTER_ENDPOINT>` should match the values your Terraform module uses.

### 4. Configure FQDN endpoints and verify access

```bash
talosctl --talosconfig talosconfig.yaml config endpoint \
  <master-1.fqdn> <master-2.fqdn> <master-3.fqdn>
talosctl --talosconfig talosconfig.yaml config node \
  <master-1.fqdn> <master-2.fqdn> <master-3.fqdn>

export TALOSCONFIG=$PWD/talosconfig.yaml
talosctl version --short
talosctl etcd status
```

### 5. Use the recovered access for whatever motivated the long path

Examples:

```bash
# Inspect live machine config to compare against templates
talosctl -n <node.fqdn> get machineconfig -o yaml > current.yaml

# Take a pre-apply etcd snapshot
talosctl -n <master.fqdn> etcd snapshot pre-apply.snap
```

### 6. Cleanup before continuing

```bash
shred -u /tmp/talos-recover/secrets.yaml
```

Then go back to the **Short path** above to run the actual apply.

---

## Notes

### Endpoints vs nodes — why control-plane only

The Talos API runs on every node, but only control-plane nodes have full access (etcd operations, kubeconfig issuance, bootstrap, etc.). Workers run a restricted subset.

Setting both `endpoint` and the default `node` to control-plane FQDNs covers day-to-day operations. For ad-hoc actions against a worker (logs, dmesg, reboot), pass `-n <worker.fqdn>` explicitly — the master proxies the request to the target node.

### Out-of-band drift

If `talosctl upgrade` or `talosctl upgrade-k8s` was used between Terraform runs, the next plan may show diffs in `machine_configuration` because the provider refreshes from the actual node state. Review those diffs carefully — apply will overwrite the live machine config with whatever your templates render. This is the main scenario where the long path earns its keep: you investigate the drift first, reconcile templates against reality, and only then apply.

### Lifetime cheat sheet

| Asset                                                 | Lifetime | Renewal                                   |
| ----------------------------------------------------- | -------- | ----------------------------------------- |
| Client cert (`os:admin`)                              | 1 year   | This procedure                            |
| Root CAs (Talos OS, Kubernetes, etcd, k8s-aggregator) | 10 years | `talosctl rotate-ca` (separate procedure) |
| Leaf certs (kubelet, apiserver, etcd peer/client)     | varies   | Auto-renewed by Talos                     |

Monitor `notAfter` of the client cert so this never becomes a surprise.
