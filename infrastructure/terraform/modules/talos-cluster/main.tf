# Ref: https://github.com/siderolabs/contrib/blob/main/examples/terraform/basic/main.tf

# Generate initial secrets to be used in later configuration
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets
resource "talos_machine_secrets" "this" {
  talos_version = var.globals.talos.version
}

# Generate a machine configuration for a node type
# Equivalent to generate config YAMLs using: talosctl gen config cluster-name https://cluster-endpoint:6443
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.globals.config.cluster_name
  cluster_endpoint = var.globals.config.controlplane_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  docs = false
  examples = false

  talos_version = var.globals.talos.version
  #config_patches = []
}

# Generate 'talosconfig' configuration for talosctl to perform requests
data "talos_client_configuration" "this" {
  cluster_name     = var.globals.config.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.node_data.controlplanes : k]
}

# Generate a machine configuration for a node type
# Equivalent to generate config YAMLs using:
# talosctl gen config cluster-name https://cluster-endpoint:6443
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.globals.config.cluster_name
  cluster_endpoint = var.globals.config.controlplane_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  docs = false
  examples = false
  talos_version = var.globals.talos.version
  #config_patches = []
}

# Apply configuration YAML to the controlplane machines
# Equivalent to apply config by executing:
# talosctl apply-config -n {node-ip} -e {endpoint-ip} --talosconfig={path} --file {path}
resource "talos_machine_configuration_apply" "controlplane" {
  for_each                    = var.node_data.controlplanes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.value.node_address

  config_patches = [templatefile(each.value.config_template_path, each.value.config_template_vars)]
}

# Apply configuration YAML to the worker machines
# Equivalent to apply config by executing:
# talosctl apply-config -n {node-ip} -e {endpoint-ip} --talosconfig={path} --file {path}
resource "talos_machine_configuration_apply" "worker" {
  for_each                    = var.node_data.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.value.node_address

  config_patches = [templatefile(each.value.config_template_path, each.value.config_template_vars)]
}

# Launch bootstrap process on controlplane machines:
# All the nodes start kubelet; one controlplane node start etcd, renders
# static pods manifests for Kubernetes controlplane components and injects them
# into API server
# Ref: https://www.talos.dev/v1.6/learn-more/control-plane/#cluster-bootstrapping
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.node_address][0]
}

# Get Kubeconfig from one controlplane node
resource "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : v.node_address][0]
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
