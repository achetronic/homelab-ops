# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs

locals {
  controlplane_addresses = [for k, v in var.node_data.controlplanes : v.node_address]
  bootstrap_node         = local.controlplane_addresses[0]

  # Talos 1.12 moved the hostname to its own config document and 1.14 moved the
  # install, cluster endpoint, cluster network and API server SANs. Each
  # generation has its own templates.
  config_style = can(regex("^v?1\\.(1[4-9]|[2-9][0-9])", var.globals.talos.config_version)) ? "v1.14" : "legacy"

  # Talos 1.12 rejects a config that sets the hostname in both the document and
  # the machine config.
  hostname_style = can(regex("^v?1\\.(1[2-9]|[2-9][0-9])", var.globals.talos.config_version)) ? "document" : "v1alpha1"

  controlplane_template_path = "${path.module}/templates/${local.config_style == "v1.14" ? "controlplane-v1.14" : "controlplane"}.yaml"
  worker_template_path       = "${path.module}/templates/${local.config_style == "v1.14" ? "worker-v1.14" : "worker"}.yaml"
}

# Generate initial secrets to be used in later configuration
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.globals.talos.config_version
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

  talos_version      = var.globals.talos.config_version
  kubernetes_version = var.globals.kubernetes.version

  config_patches = [templatefile(local.controlplane_template_path, merge(
    try(each.value.config_template_vars, {}),
    {
      install_image  = var.globals.talos.image
      hostname_style = local.hostname_style
      cluster_name   = var.globals.config.cluster_name
    }
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

  talos_version      = var.globals.talos.config_version
  kubernetes_version = var.globals.kubernetes.version

  config_patches = [templatefile(local.worker_template_path, merge(
    try(each.value.config_template_vars, {}),
    {
      install_image  = var.globals.talos.image
      hostname_style = local.hostname_style
      cluster_name   = var.globals.config.cluster_name
    }
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

  # Installer image the configuration declares. The provider fails the create
  # when it is unset.
  image = var.globals.talos.image

  # Draining needs a kubeconfig, which talos_cluster_kubeconfig cannot provide
  # before talos_cluster creates the cluster.
  drain_on_upgrade = false

  # upgrade-k8s owns these five image fields.
  ignore_kubernetes_upgrade_drift = true
}

resource "talos_machine" "worker" {
  for_each = var.node_data.workers

  node                  = each.value.node_address
  client_configuration  = talos_machine_secrets.this.client_configuration
  machine_configuration = data.talos_machine_configuration.worker[each.key].machine_configuration

  # Installer image the configuration declares. The provider fails the create
  # when it is unset.
  image = var.globals.talos.image

  # Draining needs a kubeconfig, which talos_cluster_kubeconfig cannot provide
  # before talos_cluster creates the cluster.
  drain_on_upgrade = false

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
