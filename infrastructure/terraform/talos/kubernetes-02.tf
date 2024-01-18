# Ref: https://github.com/siderolabs/contrib/blob/main/examples/terraform/basic/main.tf

locals {

  ####################################################
  # TODO
  ####################################################
  kubernetes_02_reusable_vars = {
    cluster_name = "kubernetes-02"
    controlplane_endpoint = "https://kubernetes-02.internal.place:6443"
    cert_sans = [
      "kubernetes-02.internal.place",
      "compute-11.internal.place",
      "compute-12.internal.place"]
    pod_subnets = ["10.90.0.0/16"]
    service_subnets = ["10.96.0.0/16"]

    templates = {
      controlplane = "/home/achetronic/Documents/Github/achetronic/homelab-ops/infrastructure/terraform/talos/templates/controlplane.yaml"
      worker = "/home/achetronic/Documents/Github/achetronic/homelab-ops/infrastructure/terraform/talos/templates/worker.yaml"
    }
  }

  ####################################################
  # TODO
  ####################################################
  kubernetes_02_config = {

    # TODO
    globals = {
      talos = {
        version = "v1.6.1"
      }
      config = {
        cluster_name = "kubernetes-02"
        controlplane_endpoint = "https://kubernetes-02.internal.place:6443"
      }
    }

    # TODO
    nodes_data = {
      controlplanes = {
        compute-11 = {
          node_address = "192.168.2.11"
          config_template_path = local.kubernetes_02_reusable_vars.templates.controlplane
          config_template_vars = {
            hostname      = "compute-11"
            install_disk  = "/dev/sda"
            cluster_name  = local.kubernetes_02_reusable_vars.cluster_name
            cert_sans     = local.kubernetes_02_reusable_vars.cert_sans
            pod_subnets   = local.kubernetes_02_reusable_vars.pod_subnets
            service_subnets = local.kubernetes_02_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_02_reusable_vars.controlplane_endpoint
          }
        },
        compute-12 = {
          node_address = "192.168.2.12"
          config_template_path = local.kubernetes_02_reusable_vars.templates.controlplane
          config_template_vars = {
            hostname      = "compute-12"
            install_disk  = "/dev/sda"
            cluster_name  = local.kubernetes_02_reusable_vars.cluster_name
            cert_sans     = local.kubernetes_02_reusable_vars.cert_sans
            pod_subnets   = local.kubernetes_02_reusable_vars.pod_subnets
            service_subnets = local.kubernetes_02_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_02_reusable_vars.controlplane_endpoint
          }
        }
      }
      workers = {
        compute-13 = {
          node_address = "192.168.2.13"
          config_template_path = local.kubernetes_02_reusable_vars.templates.worker
          config_template_vars = {
            hostname      = "compute-13"
            install_disk  = "/dev/sda"
            cert_sans     = local.kubernetes_02_reusable_vars.cert_sans
            pod_subnets   = local.kubernetes_02_reusable_vars.pod_subnets
            service_subnets = local.kubernetes_02_reusable_vars.service_subnets
            controlplane_endpoint = local.kubernetes_02_reusable_vars.controlplane_endpoint
          }
        }
      }
    }
  }

}

# Create the workload resources in the target host through SSH
module "talos_kubernetes_02" {

  source = "../modules/talos-cluster"

  globals   = local.kubernetes_02_config.globals
  node_data = local.kubernetes_02_config.nodes_data
}

output "kubeconfig_kubernetes_02" {
  sensitive = true
  value = module.talos_kubernetes_02.kubeconfig
}

output "talosconfig_kubernetes_02" {
  sensitive = true
  value = module.talos_kubernetes_02.talosconfig
}
