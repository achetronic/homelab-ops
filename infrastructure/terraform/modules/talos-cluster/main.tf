# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs

locals {
  # Templates shipped with the module. They populate machine.install.image
  # using globals.talos.version so the installer image matches the Talos
  # version used to generate the configuration.
  controlplane_template_path = "${path.module}/templates/controlplane.yaml"
  worker_template_path       = "${path.module}/templates/worker.yaml"

  controlplane_addresses = [for k, v in var.node_data.controlplanes : v.node_address]
  bootstrap_node         = local.controlplane_addresses[0]
}

# Generate initial secrets to be used in later configuration
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.globals.talos.version
}

# One configuration per node. The provider takes the full YAML per machine, so the
# per-node patches go here instead of on top of a shared configuration.
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration
data "talos_machine_configuration" "controlplane" {
  for_each = var.node_data.controlplanes

  cluster_name     = var.globals.config.cluster_name
  cluster_endpoint = var.globals.config.controlplane_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  docs     = false
  examples = false

  talos_version      = var.globals.talos.version
  kubernetes_version = var.globals.kubernetes.version

  config_patches = [templatefile(local.controlplane_template_path, merge(
    try(each.value.config_template_vars, {}),
    { talos_version = var.globals.talos.version }
  ))]
}

data "talos_machine_configuration" "worker" {
  for_each = var.node_data.workers

  cluster_name     = var.globals.config.cluster_name
  cluster_endpoint = var.globals.config.controlplane_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  docs     = false
  examples = false

  talos_version      = var.globals.talos.version
  kubernetes_version = var.globals.kubernetes.version

  config_patches = [templatefile(local.worker_template_path, merge(
    try(each.value.config_template_vars, {}),
    { talos_version = var.globals.talos.version }
  ))]
}

# Generate 'talosconfig' configuration for talosctl to perform requests
data "talos_client_configuration" "this" {
  cluster_name         = var.globals.config.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.node_data.controlplanes : k]
}

# Apply the configuration to the machines
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine
resource "talos_machine" "controlplane" {
  for_each = var.node_data.controlplanes

  node                  = each.value.node_address
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.controlplane[each.key].machine_configuration

  # upgrade-k8s owns these five image fields.
  ignore_kubernetes_upgrade_drift = true
}

resource "talos_machine" "worker" {
  for_each = var.node_data.workers

  node                  = each.value.node_address
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.worker[each.key].machine_configuration

  # upgrade-k8s owns these five image fields.
  ignore_kubernetes_upgrade_drift = true
}

# Bootstrap etcd and track the Kubernetes version. Changing kubernetes_version
# runs Talos' upgrade-k8s procedure.
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/cluster
resource "talos_cluster" "this" {
  depends_on = [talos_machine.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node
  control_plane_nodes  = local.controlplane_addresses
  kubernetes_version   = var.globals.kubernetes.version
}

# Get Kubeconfig from one controlplane node
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [talos_cluster.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = local.bootstrap_node
}

#
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}
