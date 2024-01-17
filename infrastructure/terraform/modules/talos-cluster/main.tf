## TODO
#data "gitlab_project_variable" "instance_access_compute_10_username" {
#  project           = var.GITLAB_VARIABLES_PROJECT_ID
#  environment_scope = var.GITLAB_VARIABLES_ENVIRONMENT
#
#  key     = "INSTANCE_ACCESS_COMPUTE_10_USERNAME"
#}


# Ref: https://github.com/siderolabs/contrib/blob/main/examples/terraform/basic/main.tf



# Generate initial secrets to be used in later configuration
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/resources/machine_secrets
resource "talos_machine_secrets" "this" {
  talos_version = "v1.6"
}

# Generate a machine configuration for a node type
# Equivalent to generate config YAMLs using: talosctl gen config cluster-name https://cluster-endpoint:6443
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration
data "talos_machine_configuration" "controlplane" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "controlplane"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  #docs = false
  #examples = false
  #talos_version = "v1.6"
  #kubernetes_version = "v1.29"
  #config_patches = []
}

# Generate a machine configuration for a node type
# Equivalent to generate config YAMLs using:
# talosctl gen config cluster-name https://cluster-endpoint:6443
# Ref: https://registry.terraform.io/providers/siderolabs/talos/latest/docs/data-sources/machine_configuration
data "talos_machine_configuration" "worker" {
  cluster_name     = var.cluster_name
  cluster_endpoint = var.cluster_endpoint
  machine_type     = "worker"
  machine_secrets  = talos_machine_secrets.this.machine_secrets

  #docs = false
  #examples = false
  #talos_version = "v1.6"
  #kubernetes_version = "v1.29"
  #config_patches = []
}

# Generate 'talosconfig' configuration for talosctl to perform requests
data "talos_client_configuration" "this" {
  cluster_name         = var.cluster_name
  client_configuration = talos_machine_secrets.this.client_configuration
  endpoints            = [for k, v in var.node_data.controlplanes : k]
}

# Apply configuration YAML to the controlplane machines
# Equivalent to apply config by executing:
# talosctl apply-config -n {node-ip} -e {endpoint-ip} --talosconfig={path} --file {path}
resource "talos_machine_configuration_apply" "controlplane" {
  for_each                    = var.node_data.controlplanes

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.controlplane.machine_configuration
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/machine-config-section.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-cp-%s", var.cluster_name, index(keys(var.node_data.controlplanes), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    file("${path.module}/files/controlplane-cluster-config-section-patches.yaml"),
  ]
}

# Apply configuration YAML to the worker machines
# Equivalent to apply config by executing:
# talosctl apply-config -n {node-ip} -e {endpoint-ip} --talosconfig={path} --file {path}
resource "talos_machine_configuration_apply" "worker" {
  for_each                    = var.node_data.workers

  client_configuration        = talos_machine_secrets.this.client_configuration
  machine_configuration_input = data.talos_machine_configuration.worker.machine_configuration
  node                        = each.key
  config_patches = [
    templatefile("${path.module}/templates/machine-config-section.yaml.tmpl", {
      hostname     = each.value.hostname == null ? format("%s-worker-%s", var.cluster_name, index(keys(var.node_data.workers), each.key)) : each.value.hostname
      install_disk = each.value.install_disk
    }),
    file("${path.module}/files/worker-cluster-config-section-patches.yaml"),
  ]
}

# Launch bootstrap process on controlplane machines:
# All the nodes start kubelet; one controlplane node start etcd, renders
# static pods manifests for Kubernetes controlplane components and injects them
# into API server
# Ref: https://www.talos.dev/v1.6/learn-more/control-plane/#cluster-bootstrapping
resource "talos_machine_bootstrap" "this" {
  depends_on = [talos_machine_configuration_apply.controlplane]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}

# Get Kubeconfig from one controlplane node
data "talos_cluster_kubeconfig" "kubeconfig" {
  depends_on           = [talos_machine_bootstrap.this]

  client_configuration = talos_machine_secrets.this.client_configuration
  node                 = [for k, v in var.node_data.controlplanes : k][0]
}

#
output "talosconfig" {
  value     = data.talos_client_configuration.this.talos_config
  sensitive = true
}

output "kubeconfig" {
  value     = data.talos_cluster_kubeconfig.kubeconfig.kubeconfig_raw
  sensitive = true
}
